import Foundation
import HomeKit
import Observation

enum DiscoveryError: Error {
    case homeKitNotAuthorized
    case homeManagerFailed(Error)
    case noThreadDevicesFound
}

extension DiscoveryError {
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

/// Seam between the poll loop and any device source (HomeKit or Demo).
protocol DiscoveryService: AnyObject {
    var devices: [ThreadDevice] { get }
    var discoveryError: DiscoveryError? { get }
    func startScanning() async throws
    func stopScanning()
    func measureSignalQualities() async -> [UUID: Int]
}

@Observable
final class MatterDiscoveryService: DiscoveryService {
    static let shared = MatterDiscoveryService()

    var devices: [ThreadDevice] = []
    var discoveryError: DiscoveryError?

    @ObservationIgnored private let homeTracker = HomeTracker()
    @ObservationIgnored private var deviceIDCache: [String: UUID] = [:]
    @ObservationIgnored private var accessoryCache: [UUID: HMAccessory] = [:]

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
                accessoryCache[accessory.uniqueIdentifier] = accessory
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
                    rssi: accessory.isReachable ? nil : -100,
                    batteryPercentage: batteryLevel(for: accessory),
                    room: accessory.room?.name ?? home.name
                )
            }
        }
    }

    /// Reads one characteristic per accessory and maps response latency → estimated RSSI.
    /// Returns a dict keyed by accessory uniqueIdentifier.
    func measureSignalQualities() async -> [UUID: Int] {
        let snapshot = accessoryCache
        return await withTaskGroup(of: (UUID, Int).self, returning: [UUID: Int].self) { group in
            for (uuid, accessory) in snapshot {
                group.addTask {
                    let rssi = await Self.latencyRSSI(for: accessory)
                    return (uuid, rssi)
                }
            }
            var out: [UUID: Int] = [:]
            for await (uuid, rssi) in group { out[uuid] = rssi }
            return out
        }
    }

    private static func latencyRSSI(for accessory: HMAccessory) async -> Int {
        guard accessory.isReachable else { return -100 }
        guard let char = accessory.services
            .flatMap(\.characteristics)
            .first(where: { $0.properties.contains(HMCharacteristicPropertyReadable) })
        else { return -65 }

        let start = Date()
        let success = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            char.readValue { err in cont.resume(returning: err == nil) }
        }
        guard success else { return -92 }
        let ms = Date().timeIntervalSince(start) * 1000
        switch ms {
        case ..<60:   return -55
        case 60..<150: return -65
        case 150..<350: return -75
        case 350..<800: return -85
        default:      return -92
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
