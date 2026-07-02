import Foundation
import Observation

enum DiscoveryError: Error {
    case homeKitNotAuthorized
    case noThreadDevicesFound
    case homeManagerFailed(Error)
}

@Observable
final class MatterDiscoveryService {
    static let shared = MatterDiscoveryService()
    private init() {}

    var devices: [ThreadDevice] = []

    func startScanning() async throws {
        try await Task.sleep(nanoseconds: 500_000_000)
        let simulated = makeSimulatedAccessories()
        let found = extractThreadTopology(from: simulated)
        await MainActor.run { self.devices = found }
    }

    private func makeSimulatedAccessories() -> [SimulatedAccessory] {
        [
            .init(name: "Living Room Light", serviceType: .lightbulb, isBorderRouter: false, isRouter: false),
            .init(name: "Kitchen Outlet", serviceType: .outlet, isBorderRouter: false, isRouter: false),
            .init(name: "Hallway Sensor", serviceType: .contactSensor, isBorderRouter: false, isRouter: false),
            .init(name: "Office Bulb", serviceType: .lightbulb, isBorderRouter: false, isRouter: false),
            .init(name: "Bedside Switch", serviceType: .switch_, isBorderRouter: false, isRouter: false),
            .init(name: "Garage Sensor", serviceType: .contactSensor, isBorderRouter: false, isRouter: false),
            .init(name: "Thread Border Router", serviceType: .bridge, isBorderRouter: true, isRouter: true),
            .init(name: "Repeater Hallway", serviceType: .bridge, isBorderRouter: false, isRouter: true),
        ]
    }

    func extractThreadTopology(from accessories: [SimulatedAccessory]) -> [ThreadDevice] {
        accessories.map { acc in
            ThreadDevice(
                name: acc.name,
                manufacturer: "Simulated",
                productName: acc.name,
                deviceType: mapServiceType(acc.serviceType),
                uniqueIdentifier: UUID(),
                isBorderRouter: acc.isBorderRouter,
                isRouter: acc.isRouter,
                isSleepyEndDevice: !acc.isRouter && !acc.isBorderRouter,
                parentNodeID: acc.isBorderRouter ? nil : "border-router-1",
                channel: 15,
                rssi: acc.isRouter ? -50 : -75,
                batteryPercentage: (!acc.isRouter && !acc.isBorderRouter) ? 85 : nil
            )
        }
    }

    private func mapServiceType(_ serviceType: ServiceType) -> String {
        switch serviceType {
        case .lightbulb: return "Lightbulb"
        case .outlet: return "Outlet"
        case .switch_: return "Switch"
        case .contactSensor: return "Sensor"
        default: return "Unknown"
        }
    }
}

struct SimulatedAccessory {
    let name: String
    let serviceType: ServiceType
    let isBorderRouter: Bool
    let isRouter: Bool
    var isSleepyEndDevice: Bool { !isRouter && !isBorderRouter }
}

enum ServiceType {
    case lightbulb, outlet, switch_, contactSensor, bridge
}
