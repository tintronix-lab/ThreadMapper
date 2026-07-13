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

    var selectedRoom: String? = nil { didSet { MainActor.assumeIsolated { applyFilters() } } }
    var selectedChannel: Int? = nil { didSet { MainActor.assumeIsolated { applyFilters() } } }

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
    /// Topology membership tracked by stable identity, not name — a rename must
    /// not read as a leave+join, and duplicate names must not collide.
    @ObservationIgnored private var knownDeviceIDs: Set<UUID> = []
    /// Last-seen display name per device ID, so a device that has *left* (and is
    /// gone from `devices`) can still be named in the banner / notification.
    @ObservationIgnored private var knownDeviceNamesByID: [UUID: String] = [:]
    @ObservationIgnored private var offlineDeviceIDs: Set<UUID> = []
    @ObservationIgnored private var pendingOfflineTasks: [UUID: Task<Void, Never>] = [:]
    @ObservationIgnored private var previousHealthScore: Int? = nil
    /// Fingerprint of the last-written aggregate snapshot — used to skip
    /// redundant AppGroupStore writes when nothing has changed between ticks.
    @ObservationIgnored private var lastSnapshotFingerprint: SnapshotFingerprint? = nil

    private struct SnapshotFingerprint: Equatable {
        let deviceCount: Int
        let offlineCount: Int
        let weakCount: Int
        let brCount: Int
        let routerCount: Int
    }

    private var effectiveGracePeriod: TimeInterval {
        let stored = UserDefaults.standard.double(forKey: "offlineGracePeriod")
        return stored > 0 ? stored : 60
    }

    /// Aggregates computed in a single pass over `devices` each poll tick.
    private struct PollAggregates {
        var offlineCount = 0
        var weakCount = 0
        var brCount = 0
        var routerCount = 0
        var offlineNames: [String] = []
        var deviceStates: [String: Bool] = [:]
        var roomBuckets: [String: (count: Int, offline: Int, weak: Int)] = [:]
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

                // Every 5 seconds: measure latency-based signal quality for all devices.
                self.pollTick += 1
                let rssiJustMeasured = self.pollTick % 5 == 0
                if rssiJustMeasured {
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
                    var graphNeedsRebuild = self.mergeDevices(latest: latest)
                    if self.processTopologyChanges() { graphNeedsRebuild = true }
                    if graphNeedsRebuild {
                        self.applyFilters()
                        SpotlightService.index(self.devices)
                    }
                    self.scanError = self.discovery.discoveryError?.userMessage
                    // Grace-period offline sweep runs every tick so transitions are
                    // detected promptly regardless of whether we recompute aggregates.
                    self.processOfflineTransitions()

                    // Only recompute aggregates and health when something could have
                    // changed: topology shifted or RSSI (and thus isOffline/isWeak) was
                    // just measured. On idle ticks where nothing changed, skip the O(n)
                    // pass, badge write, and all downstream side-effects.
                    guard graphNeedsRebuild || rssiJustMeasured else { return }

                    let agg = self.computeAggregates()
                    NotificationService.shared.updateBadge(agg.offlineCount)
                    let newHealth = NetworkHealthScore.compute(devices: self.devices)
                    // Assign only on change — NetworkHealthScore is Equatable, so an
                    // identical tick no longer invalidates every Dashboard observer (D4).
                    if newHealth != self.health { self.health = newHealth }
                    // Only write the snapshot and trigger side-effects when the aggregate
                    // state actually changed.
                    let fingerprint = SnapshotFingerprint(
                        deviceCount: self.devices.count, offlineCount: agg.offlineCount,
                        weakCount: agg.weakCount, brCount: agg.brCount, routerCount: agg.routerCount
                    )
                    if fingerprint != self.lastSnapshotFingerprint || newHealth != self.health {
                        self.lastSnapshotFingerprint = fingerprint
                        AppGroupStore.writeSnapshot(self.buildWidgetSnapshot(health: newHealth, aggregates: agg))
                        AppGroupStore.writeDeviceStates(agg.deviceStates)
                        HealthHistoryStore.shared.record(score: newHealth.score, grade: newHealth.grade)
                        HealthStreakStore.shared.record(grade: newHealth.grade)
                        if newHealth.grade == "A" { AchievementStore.shared.unlock("firstGradeA") }
                        if agg.brCount >= 2 && agg.routerCount >= 4 { AchievementStore.shared.unlock("resilienceA") }
                    }
                    self.recordHealthDelta(health: newHealth)
                }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    deinit {
        keepAliveTask?.cancel()
    }

    // MARK: - Poll loop phases

    /// Merges the latest HomeKit snapshot into `devices` in-place.
    /// Returns true when the graph needs a rebuild.
    private func mergeDevices(latest: [ThreadDevice]) -> Bool {
        let latestByUID = Dictionary(uniqueKeysWithValues: latest.map { ($0.uniqueIdentifier, $0) })
        let existingByUID = Dictionary(uniqueKeysWithValues: devices.map { ($0.uniqueIdentifier, $0) })
        var graphNeedsRebuild = false

        // Update properties of existing devices
        for device in devices {
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
        if !newDevices.isEmpty { devices.append(contentsOf: newDevices); graphNeedsRebuild = true }

        // Remove devices that disappeared from HomeKit
        let prevCount = devices.count
        devices.removeAll { latestByUID[$0.uniqueIdentifier] == nil }
        if devices.count != prevCount { graphNeedsRebuild = true }

        return graphNeedsRebuild
    }

    /// Detects join/leave events keyed by stable UUID identity, fires notifications
    /// and activity records, and updates membership tracking state.
    /// Returns true when the graph needs a rebuild.
    @MainActor private func processTopologyChanges() -> Bool {
        let currentIDs = Set(devices.map(\.uniqueIdentifier))
        let currentNamesByID = Dictionary(
            devices.map { ($0.uniqueIdentifier, $0.name) },
            uniquingKeysWith: { first, _ in first }
        )
        // Always refresh tracking state, even on the first tick (knownDeviceIDs empty).
        defer {
            knownDeviceIDs = currentIDs
            knownDeviceNamesByID = currentNamesByID
        }
        guard !knownDeviceIDs.isEmpty else { return false }

        let joinedIDs = currentIDs.subtracting(knownDeviceIDs)
        let leftIDs   = knownDeviceIDs.subtracting(currentIDs)
        guard !joinedIDs.isEmpty || !leftIDs.isEmpty else { return false }

        // Resolve display names: joined devices are present now;
        // left devices are gone, so fall back to their last-seen name.
        let joined = joinedIDs.compactMap { currentNamesByID[$0] }.sorted()
        let left   = leftIDs.compactMap { knownDeviceNamesByID[$0] }.sorted()

        let change = TopologyChange(timestamp: Date(), joined: joined, left: left)
        recentTopologyChanges.insert(change, at: 0)
        let cutoff = Date().addingTimeInterval(-300)
        recentTopologyChanges = Array(
            recentTopologyChanges.filter { $0.timestamp > cutoff }.prefix(20)
        )
        NotificationService.shared.notifyTopologyChange(joined: joined, left: left)

        for id in joinedIDs {
            let name = currentNamesByID[id] ?? "Unknown"
            ActivityStore.shared.record(kind: .topologyJoined, deviceID: id, deviceName: name,
                detail: "\(name) joined the Thread network")
        }
        for id in leftIDs {
            let name = knownDeviceNamesByID[id] ?? "Unknown"
            ActivityStore.shared.record(kind: .topologyLeft, deviceID: id, deviceName: name,
                detail: "\(name) left the Thread network")
        }
        return true
    }

    /// Manages grace-period offline/online transitions for all current devices.
    @MainActor private func processOfflineTransitions() {
        for device in devices {
            let uuid = device.uniqueIdentifier
            let name = device.name
            let room = device.room
            if device.isOffline && !offlineDeviceIDs.contains(uuid) {
                offlineDeviceIDs.insert(uuid)
                let gracePeriod = effectiveGracePeriod
                let isBR = device.isBorderRouter
                let t = Task {
                    try? await Task.sleep(for: .seconds(gracePeriod))
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        if self.offlineDeviceIDs.contains(uuid) {
                            NotificationService.shared.notifyDeviceOffline(name, room: room, deviceID: uuid)
                            let kind: ActivityEvent.Kind = isBR ? .borderRouterOffline : .deviceOffline
                            let loc = room.map { " in \($0)" } ?? ""
                            let dur = Int(gracePeriod / 60) > 0 ? "\(Int(gracePeriod / 60))m" : "\(Int(gracePeriod))s"
                            ActivityStore.shared.record(kind: kind, deviceID: uuid, deviceName: name, room: room,
                                detail: "\(name)\(loc) has been unreachable for over \(dur)")
                        }
                        self.pendingOfflineTasks[uuid] = nil
                    }
                }
                pendingOfflineTasks[uuid] = t
            } else if !device.isOffline && offlineDeviceIDs.contains(uuid) {
                pendingOfflineTasks[uuid]?.cancel()
                pendingOfflineTasks[uuid] = nil
                offlineDeviceIDs.remove(uuid)
                NotificationService.shared.clearOfflineNotification(for: uuid)
                let loc = room.map { " in \($0)" } ?? ""
                ActivityStore.shared.record(kind: .deviceOnline, deviceID: uuid, deviceName: name, room: room,
                    detail: "\(name)\(loc) is back online")
            }
        }
    }

    /// Single-pass aggregation over all current devices.
    private func computeAggregates() -> PollAggregates {
        var agg = PollAggregates()
        for d in devices {
            let isOff  = d.isOffline
            let isWeak = d.isWeak
            let room   = d.room ?? "Unknown"
            if isOff  { agg.offlineCount += 1; agg.offlineNames.append(d.name) }
            if isWeak { agg.weakCount += 1 }
            if d.isBorderRouter   { agg.brCount += 1 }
            if d.isRoutingCapable { agg.routerCount += 1 }
            // Keyed by uniqueIdentifier — duplicate names must not collide,
            // and a rename must not orphan state.
            agg.deviceStates[d.uniqueIdentifier.uuidString] = !isOff
            var b = agg.roomBuckets[room, default: (0, 0, 0)]
            b.count += 1
            if isOff  { b.offline += 1 }
            if isWeak { b.weak += 1 }
            agg.roomBuckets[room] = b
        }
        agg.offlineNames.sort()
        return agg
    }

    /// Builds the widget snapshot from pre-computed aggregates.
    private func buildWidgetSnapshot(health: NetworkHealthScore, aggregates agg: PollAggregates) -> WidgetSnapshot {
        let roomSnaps = agg.roomBuckets
            .map { room, b in
                WidgetSnapshot.RoomSnapshot(name: room, deviceCount: b.count,
                                            offlineCount: b.offline, weakCount: b.weak)
            }
            .sorted { $0.name < $1.name }
        let summary = agg.offlineNames.isEmpty
            ? health.summary
            : "\(health.summary) — \(agg.offlineCount) device\(agg.offlineCount == 1 ? "" : "s") offline"
        return WidgetSnapshot(
            grade: health.grade, score: health.score, summary: summary,
            deviceCount: devices.count, offlineCount: agg.offlineCount, weakCount: agg.weakCount,
            offlineDeviceNames: agg.offlineNames, updatedAt: Date(), rooms: roomSnaps
        )
    }

    /// Emits a health activity event when the score shifts by 15+ points.
    @MainActor private func recordHealthDelta(health: NetworkHealthScore) {
        defer { previousHealthScore = health.score }
        guard let prev = previousHealthScore else { return }
        let delta = health.score - prev
        if delta <= -15 {
            ActivityStore.shared.record(kind: .healthDegraded,
                detail: "Network health dropped from \(prev) to \(health.score) — Grade \(health.grade)")
        } else if delta >= 15 {
            ActivityStore.shared.record(kind: .healthImproved,
                detail: "Network health improved from \(prev) to \(health.score) — Grade \(health.grade)")
        }
    }

    // MARK: - Public interface

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
            self.applyFilters()
        }
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

    @MainActor private func applyFilters() {
        let nonThread = DeviceOverrideStore.shared.nonThreadIDs
        let subset = devices.filter { device in
            if nonThread.contains(device.uniqueIdentifier) { return false }
            if let room = selectedRoom, device.room != room { return false }
            if let channel = selectedChannel, device.channel != channel { return false }
            return true
        }
        let graph = MeshTopologyBuilder.buildGraph(from: subset, diagnostics: latestDiagnostics)
        nodes = graph.0
        links = graph.1
    }
}
