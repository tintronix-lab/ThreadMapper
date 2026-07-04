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

    init() {
        keepAliveTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { break }

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
                    if latest != self.devices {
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
                            }
                        }
                        self.knownDeviceNames = Set(latest.map(\.name))
                        self.devices = latest
                    }
                    self.scanError = errorMsg

                    // Offline / online transitions
                    for device in self.devices {
                        let isOffline = device.rssi == -100
                        if isOffline && !self.offlineDeviceNames.contains(device.name) {
                            self.offlineDeviceNames.insert(device.name)
                            NotificationService.shared.notifyDeviceOffline(device.name, room: device.room)
                        } else if !isOffline && self.offlineDeviceNames.contains(device.name) {
                            self.offlineDeviceNames.remove(device.name)
                            NotificationService.shared.clearOfflineNotification(for: device.name)
                        }
                    }
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
