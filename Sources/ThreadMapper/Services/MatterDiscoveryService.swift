import Foundation
import HomeKit
import Observation

enum LiveDiscoveryError: Error {
    case homeKitNotAuthorized
    case homeManagerFailed(Error)
    case noThreadDevicesFound
}

extension LiveDiscoveryError {
    var userMessage: String {
        switch self {
        case .homeKitNotAuthorized:
            return "HomeKit access denied. Enable it in Settings → Privacy & Security → HomeKit."
        case .homeManagerFailed(let err):
            return "HomeKit error: \(err.localizedDescription)"
        case .noThreadDevicesFound:
            return "No devices found. Add Thread accessories in the Home app."
        }
    }
}

protocol LiveDiscoveryService: Observable {
    var devices: [ThreadDevice] { get set }
    var discoveryError: LiveDiscoveryError? { get set }
    func startScanning() async throws
    func stopScanning()
}

@Observable
final class MatterDiscoveryService {
    static let shared = MatterDiscoveryService()

    var devices: [ThreadDevice] = []
    var discoveryError: LiveDiscoveryError?

    @ObservationIgnored private let homeTracker = HomeTracker()
    @ObservationIgnored private var deviceIDCache: [String: UUID] = [:]

    private init() {
        homeTracker.onHomesUpdated = { [weak self] homes in
            guard let self else { return }
            let found = self.extractThreadDevices(from: homes)
            Task { @MainActor in
                self.devices = found
                self.discoveryError = found.isEmpty ? .noThreadDevicesFound : nil
            }
        }
        homeTracker.onNotAuthorized = { [weak self] in
            Task { @MainActor in
                self?.discoveryError = .homeKitNotAuthorized
                self?.devices = []
            }
        }
    }

    func startScanning() async throws {
        await MainActor.run { discoveryError = nil }
        homeTracker.start()
    }

    func stopScanning() {
        homeTracker.stop()
    }

    private func extractThreadDevices(from homes: [HMHome]) -> [ThreadDevice] {
        homes.flatMap { home in
            home.accessories.map { accessory in
                let key = accessory.uniqueIdentifier.uuidString
                let id = cachedID(for: key)
                let isBridge = accessory.category.categoryType == HMAccessoryCategoryTypeBridge
                return ThreadDevice(
                    id: id,
                    name: accessory.name,
                    manufacturer: accessory.manufacturer ?? "Unknown",
                    productName: accessory.model ?? accessory.name,
                    deviceType: accessory.category.localizedDescription,
                    uniqueIdentifier: accessory.uniqueIdentifier,
                    isBorderRouter: isBridge,
                    isRouter: isBridge,
                    isSleepyEndDevice: !isBridge,
                    parentNodeID: nil,
                    channel: nil,
                    rssi: nil,
                    batteryPercentage: batteryLevel(for: accessory),
                    room: accessory.room?.name ?? home.name
                )
            }
        }
    }

    private func cachedID(for key: String) -> UUID {
        if let id = deviceIDCache[key] { return id }
        let id = UUID()
        deviceIDCache[key] = id
        return id
    }

    private func batteryLevel(for accessory: HMAccessory) -> Int? {
        for service in accessory.services where service.serviceType == HMServiceTypeBattery {
            for char in service.characteristics where char.characteristicType == HMCharacteristicTypeBatteryLevel {
                return char.value as? Int
            }
        }
        return nil
    }
}

private final class HomeTracker: NSObject, HMHomeManagerDelegate {
    var onHomesUpdated: (([HMHome]) -> Void)?
    var onNotAuthorized: (() -> Void)?

    private var manager: HMHomeManager?

    func start() {
        guard manager == nil else { return }
        let m = HMHomeManager()
        m.delegate = self
        manager = m
    }

    func stop() {
        manager?.delegate = nil
        manager = nil
    }

    func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {
        if manager.authorizationStatus.contains(.authorized) {
            onHomesUpdated?(manager.homes)
        } else {
            onNotAuthorized?()
        }
    }

    func homeManager(_ manager: HMHomeManager, didAdd home: HMHome) {
        onHomesUpdated?(manager.homes)
    }

    func homeManager(_ manager: HMHomeManager, didRemove home: HMHome) {
        onHomesUpdated?(manager.homes)
    }
}
