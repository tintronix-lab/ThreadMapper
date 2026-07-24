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
///
/// `@MainActor`-isolated on purpose. HomeKit delivers `HMHomeManagerDelegate`
/// callbacks on the main queue and its object graph (`HMAccessory.services`,
/// `readValue`) is not documented thread-safe, so the device source has to live
/// on the main actor to be correct. Previously the conformers carried
/// `@unchecked Sendable`, which silenced the compiler while `measureSignalQualities()`
/// — `nonisolated async`, therefore running on the cooperative pool — read state
/// the delegate callback was concurrently writing on main. The methods are still
/// `async` and suspend at every HomeKit round-trip, so nothing blocks the main
/// thread; only the *ownership* of the state moved.
@MainActor
protocol DiscoveryService: AnyObject, Sendable {
    var devices: [ThreadDevice] { get }
    var discoveryError: DiscoveryError? { get }
    func startScanning() async throws
    func stopScanning()
    func measureSignalQualities() async -> [UUID: Int]
}

@Observable @MainActor
final class MatterDiscoveryService: DiscoveryService {
    static let shared = MatterDiscoveryService()

    var devices: [ThreadDevice] = []
    var discoveryError: DiscoveryError?

    @ObservationIgnored private let homeTracker = HomeTracker()
    @ObservationIgnored private var accessoryCache: [UUID: HMAccessory] = [:]

    private init() {
        // Both callbacks are invoked synchronously from HomeTracker's delegate
        // methods, which are already on the main actor — no Task hop needed, and
        // the update lands in the same turn as the HomeKit notification.
        homeTracker.onHomesUpdated = { [weak self] homes in
            guard let self else { return }
            let found = self.extractThreadDevices(from: homes)
            self.devices = found
            self.discoveryError = found.isEmpty ? .noThreadDevicesFound : nil
        }
        homeTracker.onNotAuthorized = { [weak self] in
            self?.discoveryError = .homeKitNotAuthorized
            self?.devices = []
        }
    }

    func startScanning() async throws {
        discoveryError = nil
        homeTracker.start()
    }

    func stopScanning() {
        homeTracker.stop()
    }

    private func extractThreadDevices(from homes: [HMHome]) -> [ThreadDevice] {
        homes.flatMap { home in
            home.accessories.map { accessory in
                let isBridge = accessory.category.categoryType == HMAccessoryCategoryTypeBridge
                accessoryCache[accessory.uniqueIdentifier] = accessory
                return ThreadDevice(
                    name: accessory.name,
                    manufacturer: accessory.manufacturer ?? "Unknown",
                    productName: accessory.model ?? accessory.name,
                    deviceType: accessory.category.localizedDescription,
                    uniqueIdentifier: accessory.uniqueIdentifier,
                    isBorderRouter: isBridge,
                    isRouter: isBridge,
                    isSleepyEndDevice: batteryLevel(for: accessory) != nil,
                    parentNodeID: nil,
                    channel: nil,
                    rssi: accessory.isReachable ? nil : SignalThresholds.offlineSentinel,
                    batteryPercentage: batteryLevel(for: accessory),
                    room: accessory.room?.name ?? home.name,
                    firmwareVersion: Self.firmwareVersion(for: accessory)
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
        guard accessory.isReachable else { return SignalThresholds.offlineSentinel }
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

    private func batteryLevel(for accessory: HMAccessory) -> Int? {
        for service in accessory.services where service.serviceType == HMServiceTypeBattery {
            for char in service.characteristics where char.characteristicType == HMCharacteristicTypeBatteryLevel {
                return char.value as? Int
            }
        }
        return nil
    }

    /// Returns firmware version from `accessory.firmwareVersion` first, then falls back to
    /// reading the FirmwareRevision characteristic from the accessory information service.
    /// HomeKit caches characteristic values from pairing data, so this works without a readValue call.
    private static func firmwareVersion(for accessory: HMAccessory) -> String? {
        if let v = accessory.firmwareVersion, !v.isEmpty { return v }
        for service in accessory.services where service.serviceType == HMServiceTypeAccessoryInformation {
            // "52" is the HAP UUID for Firmware Revision in the Accessory Information service
            for char in service.characteristics where char.characteristicType == "00000052-0000-1000-8000-0026BB765291" {
                if let v = char.value as? String, !v.isEmpty { return v }
            }
        }
        return nil
    }
}

/// `HMHomeManagerDelegate` predates Swift concurrency and carries no isolation
/// annotation, so its requirements have to be satisfied by `nonisolated` methods.
/// HomeKit documents that it delivers these callbacks on the main queue, which
/// `assumeIsolated` asserts rather than assumes: if HomeKit ever delivered one
/// off-main, this traps loudly instead of corrupting `devices` silently.
@MainActor
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

    nonisolated func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {
        MainActor.assumeIsolated {
            if manager.authorizationStatus.contains(.authorized) {
                onHomesUpdated?(manager.homes)
            } else {
                onNotAuthorized?()
            }
        }
    }

    nonisolated func homeManager(_ manager: HMHomeManager, didAdd home: HMHome) {
        MainActor.assumeIsolated { onHomesUpdated?(manager.homes) }
    }

    nonisolated func homeManager(_ manager: HMHomeManager, didRemove home: HMHome) {
        MainActor.assumeIsolated { onHomesUpdated?(manager.homes) }
    }
}
