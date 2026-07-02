import Foundation
import HomeKit
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

    private var homeManager: HMHomeManager?

    func startScanning() async throws {
        let status = await HMHomeManager.authorizationStatus()
        guard status == .authorized else {
            throw DiscoveryError.homeKitNotAuthorized
        }

        let accessories = try await collectAccessories()
        let found = extractThreadTopology(from: accessories)
        await MainActor.run { self.devices = found }
    }

    private func collectAccessories() async throws -> [HMAccessory] {
        try await withCheckedThrowingContinuation { cont in
            let manager = HMHomeManager()
            homeManager = manager

            // HMHomeManager loads homes asynchronously; delegate reports completion.
            manager.delegate = HomeManagerDelegate {
                let result = manager.homes.flatMap { $0.accessories }
                cont.resume(returning: result)
            }

            // Deliver initial cached results if available immediately.
            if !manager.homes.isEmpty {
                let result = manager.homes.flatMap { $0.accessories }
                cont.resume(returning: result)
            }
        }
    }

    func extractThreadTopology(from accessories: [HMAccessory]) -> [ThreadDevice] {
        var results: [ThreadDevice] = []

        for accessory in accessories {
            let matterInfo = accessory.matterDeviceInfo
            let device = ThreadDevice(
                name: accessory.name,
                manufacturer: matterInfo?.manufacturerName ?? "Unknown",
                productName: matterInfo?.productName ?? "Unknown",
                deviceType: inferDeviceType(accessory),
                uniqueIdentifier: accessory.uniqueIdentifier.uuidString,
                isBorderRouter: matterInfo?.supportsThreadBorderRouter ?? false,
                isRouter: matterInfo?.threadNodeType == .router,
                isSleepyEndDevice: matterInfo?.threadNodeType == .sleepyEndDevice,
                parentNodeID: matterInfo?.parentNodeID,
                channel: matterInfo?.threadChannel,
                rssi: nil,
                batteryPercentage: accessory.batteryLevel?.intValue,
                room: accessory.room?.name
            )
            results.append(device)
        }

        return results
    }

    private func inferDeviceType(_ accessory: HMAccessory) -> String {
        for service in accessory.services {
            switch service.serviceType {
            case HMServiceTypeLightbulb: return "Lightbulb"
            case HMServiceTypeSwitch: return "Switch"
            case HMServiceTypeOutlet: return "Outlet"
            case HMServiceTypeContactSensor: return "Sensor"
            default: break
            }
        }
        return "Unknown"
    }
}

// Delegate wrapper to bridge HomeKit delegate to async callback.
private final class HomeManagerDelegate: NSObject, HMHomeManagerDelegate {
    private let completion: ([HMAccessory]) -> Void
    private var finished = false

    init(completion: @escaping ([HMAccessory]) -> Void) {
        self.completion = completion
    }

    func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {
        guard !finished else { return }
        finished = true
        let result = manager.homes.flatMap { $0.accessories }
        completion(result)
    }

    func homeManager(_ manager: HMHomeManager, didAdd home: HMHome) {
        homeManagerDidUpdateHomes(manager)
    }

    func homeManager(_ manager: HMHomeManager, didRemove home: HMHome) {
        homeManagerDidUpdateHomes(manager)
    }
}
