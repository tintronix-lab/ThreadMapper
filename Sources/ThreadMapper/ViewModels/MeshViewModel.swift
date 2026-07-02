import SwiftUI
import Observation

@Observable
final class MeshViewModel {
    var devices: [ThreadDevice] = []
    var nodes: [MeshNode] = []
    var links: [MeshLink] = []
    var selectedDevice: ThreadDevice?
    var isScanning = false
    var scanError: String?

    private let discovery = MatterDiscoveryService.shared

    func startScan() async {
        await MainActor.run { isScanning = true; scanError = nil }
        do {
            try await discovery.startScanning()
            let found = discovery.devices
            let graph = MeshTopologyBuilder.buildGraph(from: found)

            await MainActor.run {
                self.devices = found
                self.nodes = graph.0
                self.links = graph.1
            }
        } catch {
            await MainActor.run { scanError = error.localizedDescription }
        }
        await MainActor.run { isScanning = false }
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
}
