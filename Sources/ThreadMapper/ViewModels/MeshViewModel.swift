import SwiftUI
import Observation

@Observable
final class MeshViewModel {
    var devices: [ThreadDevice] = []
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
        nodes.filter { $0.deviceID != nil }.count
    }

    /// Real Thread network facts (channel, PAN ID, name) when a diagnostics
    /// provider supplies them — empty for HomeKit-only setups (Feature #2).
    var threadNetworks: [ThreadNetworkInfo] = []

    @ObservationIgnored private let discovery: any DiscoveryService
    @ObservationIgnored private(set) var diagnosticsProvider: any DiagnosticsProvider
    /// Latest real per-node routing, applied by the topology builder when present.
    @ObservationIgnored private(set) var latestDiagnostics: [UUID: ThreadNodeDiagnostics] = [:]
    @ObservationIgnored private var keepAliveTask: Task<Void, Error>?
    @ObservationIgnored private var pollTick = 0
    @ObservationIgnored private var knownDeviceNames: Set<String> = []
    @ObservationIgnored private var offlineDeviceIDs: Set<UUID> = []
    @ObservationIgnored private var pendingOfflineTasks: [UUID: Task<Void, Never>] = [:]
    @ObservationIgnored private var previousHealthScore: Int? = nil

    private var effectiveGracePeriod: TimeInterval {
        let stored = UserDefaults.standard.double(forKey: "offlineGracePeriod")
        return stored > 0 ? stored : 60
    }

    init(discovery: any DiscoveryService = MatterDiscoveryService.shared,
         diagnostics: any DiagnosticsProvider = ThreadCredentialsService()) {
        self.discovery = discovery
        self.diagnosticsProvider = diagnostics
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
                                DeviceStatsStore.shared.record(deviceID: device.uniqueIdentifier, rssi: q)
                            }
                        }
                    }
                }

                await MainActor.run {
                    let latest = self.discovery.devices
                    let errorMsg = self.discovery.discoveryError?.userMessage

                    // Merge HomeKit updates into existing @Observable device objects
                    // in-place so SwiftUI views that observe individual device properties
                    // re-render without a full array replacement. The metadataSignature
                    // workaround is no longer needed — @Observable tracks each property.
                    let latestByUID = Dictionary(uniqueKeysWithValues: latest.map { ($0.uniqueIdentifier, $0) })
                    let existingByUID = Dictionary(uniqueKeysWithValues: self.devices.map { ($0.uniqueIdentifier, $0) })
                    var graphNeedsRebuild = false

                    // Update properties of existing devices
                    for device in self.devices {
                        guard let updated = latestByUID[device.uniqueIdentifier] else { continue }
                        if device.name != updated.name { device.name = updated.name; graphNeedsRebuild = true }
                        if device.room != updated.room { device.room = updated.room; graphNeedsRebuild = true }
                        if device.channel != updated.channel { device.channel = updated.channel; graphNeedsRebuild = true }
                        if device.isBorderRouter != updated.isBorderRouter { device.isBorderRouter = updated.isBorderRouter; graphNeedsRebuild = true }
                        if device.isRouter != updated.isRouter { device.isRouter = updated.isRouter; graphNeedsRebuild = true }
                        if device.isSleepyEndDevice != updated.isSleepyEndDevice { device.isSleepyEndDevice = updated.isSleepyEndDevice }
                        if device.batteryPercentage != updated.batteryPercentage { device.batteryPercentage = updated.batteryPercentage }
                        // rssi is intentionally NOT updated here — we measure it ourselves
                        // via measureSignalQualities() and don't want HomeKit to overwrite it.
                    }

                    // Add newly discovered devices
                    let newDevices = latest.filter { existingByUID[$0.uniqueIdentifier] == nil }
                    if !newDevices.isEmpty {
                        self.devices.append(contentsOf: newDevices)
                        graphNeedsRebuild = true
                    }

                    // Remove devices that disappeared from HomeKit
                    let prevCount = self.devices.count
                    self.devices.removeAll { latestByUID[$0.uniqueIdentifier] == nil }
                    if self.devices.count != prevCount { graphNeedsRebuild = true }

                    // Topology change events (join / leave)
                    let currentNames = Set(self.devices.map(\.name))
                    if !self.knownDeviceNames.isEmpty {
                        let joined = currentNames.subtracting(self.knownDeviceNames)
                        let left   = self.knownDeviceNames.subtracting(currentNames)
                        if !joined.isEmpty || !left.isEmpty {
                            let change = TopologyChange(timestamp: Date(),
                                                        joined: Array(joined).sorted(),
                                                        left: Array(left).sorted())
                            self.recentTopologyChanges.insert(change, at: 0)
                            // Keep at most 20 entries; prune any older than 5 minutes so
                            // the topology banner never shows stale events.
                            let cutoff = Date().addingTimeInterval(-300)
                            self.recentTopologyChanges = Array(
                                self.recentTopologyChanges
                                    .filter { $0.timestamp > cutoff }
                                    .prefix(20)
                            )
                            NotificationService.shared.notifyTopologyChange(
                                joined: Array(joined), left: Array(left))
                            for name in joined.sorted() {
                                ActivityStore.shared.record(kind: .topologyJoined, deviceName: name, detail: "\(name) joined the Thread network")
                            }
                            for name in left.sorted() {
                                ActivityStore.shared.record(kind: .topologyLeft, deviceName: name, detail: "\(name) left the Thread network")
                            }
                            graphNeedsRebuild = true
                        }
                    }
                    self.knownDeviceNames = currentNames

                    if graphNeedsRebuild { self.applyFilters() }
                    self.scanError = errorMsg

                    // Offline / online transitions (with grace period to avoid false positives)
                    for device in self.devices {
                        let uuid = device.uniqueIdentifier
                        let name = device.name
                        let room = device.room
                        if device.isOffline && !self.offlineDeviceIDs.contains(uuid) {
                            self.offlineDeviceIDs.insert(uuid)
                            let gracePeriod = self.effectiveGracePeriod
                            let isBR = device.isBorderRouter
                            let t = Task {
                                try? await Task.sleep(for: .seconds(gracePeriod))
                                guard !Task.isCancelled else { return }
                                await MainActor.run {
                                    if self.offlineDeviceIDs.contains(uuid) {
                                        NotificationService.shared.notifyDeviceOffline(name, room: room, deviceID: uuid)
                                        let kind: ActivityEvent.Kind = isBR ? .borderRouterOffline : .deviceOffline
                                        let loc = room.map { " in \($0)" } ?? ""
                                        ActivityStore.shared.record(kind: kind, deviceName: name, room: room,
                                            detail: "\(name)\(loc) has been unreachable for over \(Int(gracePeriod / 60) > 0 ? "\(Int(gracePeriod / 60))m" : "\(Int(gracePeriod))s")")
                                    }
                                    self.pendingOfflineTasks[uuid] = nil
                                }
                            }
                            self.pendingOfflineTasks[uuid] = t
                        } else if !device.isOffline && self.offlineDeviceIDs.contains(uuid) {
                            self.pendingOfflineTasks[uuid]?.cancel()
                            self.pendingOfflineTasks[uuid] = nil
                            self.offlineDeviceIDs.remove(uuid)
                            NotificationService.shared.clearOfflineNotification(for: uuid)
                            let loc = room.map { " in \($0)" } ?? ""
                            ActivityStore.shared.record(kind: .deviceOnline, deviceName: name, room: room,
                                detail: "\(name)\(loc) is back online")
                        }
                    }

                    // Single pass — compute all per-device aggregates at once instead of
                    // six separate filter/map passes (offlineCount, weakCount, roomGroups,
                    // offlineNames, deviceStates, brCount/routerCount).
                    var offlineCount = 0, weakCount = 0, brCount = 0, routerCount = 0
                    var offlineNames: [String] = []
                    var deviceStates: [String: Bool] = [:]
                    var roomBuckets: [String: (count: Int, offline: Int, weak: Int)] = [:]
                    for d in self.devices {
                        let isOff  = d.isOffline
                        let isWeak = d.isWeak
                        let room   = d.room ?? "Unknown"
                        if isOff  { offlineCount += 1; offlineNames.append(d.name) }
                        if isWeak { weakCount += 1 }
                        if d.isBorderRouter    { brCount += 1 }
                        if d.isRoutingCapable  { routerCount += 1 }
                        deviceStates[d.name] = !isOff
                        var b = roomBuckets[room, default: (0, 0, 0)]
                        b.count += 1
                        if isOff  { b.offline += 1 }
                        if isWeak { b.weak += 1 }
                        roomBuckets[room] = b
                    }
                    offlineNames.sort()

                    NotificationService.shared.updateBadge(offlineCount)

                    // Write snapshot to App Group for widget and BGTask
                    let health = NetworkHealthScore.compute(devices: self.devices)
                    // Assign only on change — NetworkHealthScore is Equatable, so an
                    // identical tick no longer invalidates every Dashboard observer (D4).
                    if health != self.health { self.health = health }
                    let roomSnaps = roomBuckets
                        .map { room, b in
                            WidgetSnapshot.RoomSnapshot(name: room, deviceCount: b.count,
                                                        offlineCount: b.offline, weakCount: b.weak)
                        }
                        .sorted { $0.name < $1.name }
                    let snapshotSummary = offlineNames.isEmpty
                        ? health.summary
                        : "\(health.summary) — \(offlineNames.count) device\(offlineNames.count == 1 ? "" : "s") offline"
                    AppGroupStore.writeSnapshot(WidgetSnapshot(
                        grade: health.grade,
                        score: health.score,
                        summary: snapshotSummary,
                        deviceCount: self.devices.count,
                        offlineCount: offlineCount,
                        weakCount: weakCount,
                        offlineDeviceNames: offlineNames,
                        updatedAt: Date(),
                        rooms: roomSnaps
                    ))
                    AppGroupStore.writeDeviceStates(deviceStates)
                    HealthHistoryStore.shared.record(score: health.score, grade: health.grade)
                    HealthStreakStore.shared.record(grade: health.grade)
                    if health.grade == "A" { AchievementStore.shared.unlock("firstGradeA") }
                    if brCount >= 2 && routerCount >= 4 { AchievementStore.shared.unlock("resilienceA") }

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
        await refreshDiagnostics()
        await MainActor.run { isScanning = false }
    }

    func stopScan() {
        discovery.stopScanning()
    }

    /// Swap the diagnostics provider at runtime (e.g. when the user updates the
    /// border router URL in Settings). Immediately re-fetches diagnostics so the
    /// mesh reflects the new source without requiring an app restart.
    func updateDiagnosticsProvider(_ provider: any DiagnosticsProvider) {
        diagnosticsProvider = provider
        Task { await refreshDiagnostics() }
    }

    /// Pull real Thread data from the provider (network facts + per-node routing).
    /// No-op in effect for HomeKit-only setups (empty results → inferred mesh).
    func refreshDiagnostics() async {
        let currentDevices = await MainActor.run { self.devices }
        let diags = await diagnosticsProvider.nodeDiagnostics(for: currentDevices)
        let networks = await diagnosticsProvider.threadNetworks()
        await MainActor.run {
            self.latestDiagnostics = diags
            self.threadNetworks = networks
            self.applyFilters()   // rebuild the graph with any real routing applied
        }
    }

    private func rebuildGraph() {
        let graph = MeshTopologyBuilder.buildGraph(from: devices, diagnostics: latestDiagnostics)
        nodes = graph.0
        links = graph.1
    }

    func routerDensity(for room: String? = nil) -> Int {
        let subset = room == nil ? devices : devices.filter { $0.room == room }
        return subset.filter(\.isRoutingCapable).count
    }

    func warnings() -> [String] {
        var msgs: [String] = []
        let routers = devices.filter(\.isRoutingCapable)
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
        let graph = MeshTopologyBuilder.buildGraph(from: subset, diagnostics: latestDiagnostics)
        nodes = graph.0
        links = graph.1
    }
}
