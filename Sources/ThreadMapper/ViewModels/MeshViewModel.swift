import SwiftUI
import Observation

@Observable
final class MeshViewModel {
    var devices: [ThreadDevice] = [] {
        didSet { applyFilters() }
    }
    var nodes: [MeshNode] = []
    var links: [MeshLink] = []
    var selectedDevice: ThreadDevice?
    var selectedNode: MeshNode?
    var isScanning = false
    var scanError: String?

    /// Latest health score, computed once per poll tick.
    /// Views read this instead of recomputing in `body`.
    private(set) var health = NetworkHealthScore.compute(devices: [])

    /// Set from the scene phase — the poll loop idles while backgrounded
    /// instead of burning CPU until the OS suspends the process.
    @ObservationIgnored var isAppActive = true

    struct TopologyChange: Identifiable {
        let id = UUID()
        let timestamp: Date
        let joined: [String]
        let left: [String]
    }
    var recentTopologyChanges: [TopologyChange] = []

    var selectedRoom: String? = nil { didSet { applyFilters() } }
    var selectedChannel: Int? = nil { didSet { applyFilters() } }

    var rooms: [String] {
        Set(devices.compactMap(\.room)).sorted()
    }
    var channels: [Int] {
        Set(devices.compactMap(\.channel)).sorted()
    }

    var visibleDeviceCount: Int {
        nodes.count
    }

    private let discovery = MatterDiscoveryService.shared
    @ObservationIgnored private var keepAliveTask: Task<Void, Error>?
    @ObservationIgnored private var pollTick = 0
    @ObservationIgnored private var knownDeviceNames: Set<String> = []
    @ObservationIgnored private var offlineDeviceNames: Set<String> = []
    @ObservationIgnored private var pendingOfflineTasks: [String: Task<Void, Never>] = [:]
    @ObservationIgnored private var previousHealthScore: Int? = nil

    private var effectiveGracePeriod: TimeInterval {
        let stored = UserDefaults.standard.double(forKey: "offlineGracePeriod")
        return stored > 0 ? stored : 60
    }

    init() {
        keepAliveTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { break }

                // Idle while backgrounded — nothing on screen, widget updates
                // are throttled in AppGroupStore anyway.
                let active = await MainActor.run { self.isAppActive }
                guard active else {
                    try? await Task.sleep(for: .seconds(2))
                    continue
                }

                // Every 5 seconds: measure latency-based signal quality for all devices
                self.pollTick += 1
                if self.pollTick % 5 == 0 {
                    let qualities = await self.discovery.measureSignalQualities()
                    await MainActor.run {
                        for device in self.devices {
                            if let q = qualities[device.uniqueIdentifier] {
                                device.rssi = q
                                DeviceStatsStore.shared.record(deviceName: device.name, rssi: q)
                            }
                        }
                    }
                }

                await MainActor.run {
                    let latest = self.discovery.devices
                    let errorMsg = self.discovery.discoveryError?.userMessage
                    // Compare metadata signatures, not just `!=` —
                    // ThreadDevice.== is identity-only (uniqueIdentifier), so
                    // renames, room moves, and battery changes would
                    // otherwise never reach the UI (review issue H2).
                    let changed = latest.map(\.metadataSignature).sorted()
                        != self.devices.map(\.metadataSignature).sorted()
                    if changed {
                        // Preserve measured rssi values when HomeKit refreshes the list
                        let existingRSSI = Dictionary(uniqueKeysWithValues:
                            self.devices.compactMap { d in d.rssi.map { (d.uniqueIdentifier, $0) } })
                        for device in latest {
                            device.rssi = existingRSSI[device.uniqueIdentifier] ?? device.rssi
                        }

                        // Topology change detection (skip on first population)
                        if !self.knownDeviceNames.isEmpty {
                            let currentNames = Set(latest.map(\.name))
                            let joined = currentNames.subtracting(self.knownDeviceNames)
                            let left   = self.knownDeviceNames.subtracting(currentNames)
                            if !joined.isEmpty || !left.isEmpty {
                                let change = TopologyChange(timestamp: Date(),
                                                            joined: Array(joined).sorted(),
                                                            left: Array(left).sorted())
                                self.recentTopologyChanges.insert(change, at: 0)
                                if self.recentTopologyChanges.count > 20 {
                                    self.recentTopologyChanges = Array(self.recentTopologyChanges.prefix(20))
                                }
                                NotificationService.shared.notifyTopologyChange(
                                    joined: Array(joined), left: Array(left))
                                for name in joined.sorted() {
                                    ActivityStore.shared.record(kind: .topologyJoined, deviceName: name, detail: "\(name) joined the Thread network")
                                }
                                for name in left.sorted() {
                                    ActivityStore.shared.record(kind: .topologyLeft, deviceName: name, detail: "\(name) left the Thread network")
                                }
                            }
                        }
                        self.knownDeviceNames = Set(latest.map(\.name))
                        self.devices = latest
                    }
                    self.scanError = errorMsg

                    // Offline / online transitions (with grace period to avoid false positives)
                    for device in self.devices {
                        let isOffline = device.rssi == -100
                        if isOffline && !self.offlineDeviceNames.contains(device.name) {
                            self.offlineDeviceNames.insert(device.name)
                            let name = device.name; let room = device.room
                            let gracePeriod = self.effectiveGracePeriod
                        let isBR = device.isBorderRouter
                        let t = Task {
                                try? await Task.sleep(for: .seconds(gracePeriod))
                                guard !Task.isCancelled else { return }
                                await MainActor.run {
                                    if self.offlineDeviceNames.contains(name) {
                                        NotificationService.shared.notifyDeviceOffline(name, room: room)
                                        let kind: ActivityEvent.Kind = isBR ? .borderRouterOffline : .deviceOffline
                                        let loc = room.map { " in \($0)" } ?? ""
                                        ActivityStore.shared.record(kind: kind, deviceName: name, room: room,
                                            detail: "\(name)\(loc) has been unreachable for over \(Int(gracePeriod / 60) > 0 ? "\(Int(gracePeriod / 60))m" : "\(Int(gracePeriod))s")")
                                    }
                                    self.pendingOfflineTasks[name] = nil
                                }
                            }
                            self.pendingOfflineTasks[device.name] = t
                        } else if !isOffline && self.offlineDeviceNames.contains(device.name) {
                            self.pendingOfflineTasks[device.name]?.cancel()
                            self.pendingOfflineTasks[device.name] = nil
                            self.offlineDeviceNames.remove(device.name)
                            NotificationService.shared.clearOfflineNotification(for: device.name)
                            let loc = device.room.map { " in \($0)" } ?? ""
                            ActivityStore.shared.record(kind: .deviceOnline, deviceName: device.name, room: device.room,
                                detail: "\(device.name)\(loc) is back online")
                        }
                    }

                    // Badge = number of confirmed offline devices
                    let offlineCount = self.devices.filter { $0.rssi == -100 }.count
                    NotificationService.shared.updateBadge(offlineCount)

                    // Write snapshot to App Group for widget and BGTask
                    let health = NetworkHealthScore.compute(devices: self.devices)
                    self.health = health
                    let roomGroups = Dictionary(grouping: self.devices) { $0.room ?? "Unknown" }
                    let roomSnaps = roomGroups.map { room, devs in
                        WidgetSnapshot.RoomSnapshot(
                            name: room,
                            deviceCount: devs.count,
                            offlineCount: devs.filter { $0.rssi == -100 }.count,
                            weakCount: devs.filter { let r = $0.rssi ?? -65; return r < -80 && r > -100 }.count
                        )
                    }.sorted { $0.name < $1.name }
                    AppGroupStore.writeSnapshot(WidgetSnapshot(
                        grade: health.grade,
                        score: health.score,
                        deviceCount: self.devices.count,
                        offlineCount: offlineCount,
                        weakCount: self.devices.filter { let r = $0.rssi ?? -65; return r < -80 && r > -100 }.count,
                        updatedAt: Date(),
                        rooms: roomSnaps
                    ))
                    AppGroupStore.writeDeviceStates(
                        Dictionary(self.devices.map { ($0.name, $0.rssi != -100) }, uniquingKeysWith: { _, new in new })
                    )
                    HealthHistoryStore.shared.record(score: health.score, grade: health.grade)

                    // Emit activity event when health score shifts by 15+ points
                    if let prev = self.previousHealthScore {
                        let delta = health.score - prev
                        if delta <= -15 {
                            ActivityStore.shared.record(kind: .healthDegraded,
                                detail: "Network health dropped from \(prev) to \(health.score) — Grade \(health.grade)")
                        } else if delta >= 15 {
                            ActivityStore.shared.record(kind: .healthImproved,
                                detail: "Network health improved from \(prev) to \(health.score) — Grade \(health.grade)")
                        }
                    }
                    self.previousHealthScore = health.score
                }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    deinit {
        keepAliveTask?.cancel()
    }

    func startScan() async {
        await MainActor.run { isScanning = true; scanError = nil }
        do {
            // HomeKit discovery is async via callbacks; startScanning just kicks off the tracker.
            try await discovery.startScanning()
        } catch {
            await MainActor.run { scanError = error.localizedDescription }
        }
        await MainActor.run { isScanning = false }
    }

    func stopScan() {
        discovery.stopScanning()
    }

    private func rebuildGraph() {
        let graph = MeshTopologyBuilder.buildGraph(from: devices)
        nodes = graph.0
        links = graph.1
    }

    func routerDensity(for room: String? = nil) -> Int {
        let subset = room == nil ? devices : devices.filter { $0.room == room }
        return subset.filter { $0.isRouter || $0.isBorderRouter }.count
    }

    func warnings() -> [String] {
        var msgs: [String] = []
        let routers = devices.filter { $0.isRouter || $0.isBorderRouter }
        if routers.isEmpty {
            msgs.append("No Thread border router detected.")
        }
        let batteryDevices = devices.filter { ($0.batteryPercentage ?? 100) < 20 }
        if !batteryDevices.isEmpty {
            msgs.append("\(batteryDevices.count) device(s) low on battery.")
        }
        return msgs
    }

    private func applyFilters() {
        let subset = devices.filter { device in
            if let room = selectedRoom, device.room != room { return false }
            if let channel = selectedChannel, device.channel != channel { return false }
            return true
        }
        let graph = MeshTopologyBuilder.buildGraph(from: subset)
        nodes = graph.0
        links = graph.1
    }
}
