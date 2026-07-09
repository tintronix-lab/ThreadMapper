import Foundation
import Observation

/// Persists per-device overrides that correct HomeKit's classification of
/// bridge devices. HomeKit marks all bridges as border routers regardless of
/// radio protocol (Thread, Zigbee, Z-Wave, etc.). This store lets users mark
/// individual devices as "not a Thread device" to hide them from the mesh
/// topology while keeping them visible in list and dashboard views.
@Observable
final class DeviceOverrideStore {
    static let shared = DeviceOverrideStore()

    private let key = "nonThreadDeviceIDs"

    private(set) var nonThreadIDs: Set<UUID> {
        didSet { persist() }
    }

    private init() {
        let stored = UserDefaults.standard.stringArray(forKey: "nonThreadDeviceIDs") ?? []
        nonThreadIDs = Set(stored.compactMap(UUID.init))
    }

    func isNonThread(_ id: UUID) -> Bool {
        nonThreadIDs.contains(id)
    }

    func setNonThread(_ id: UUID, _ exclude: Bool) {
        if exclude {
            nonThreadIDs.insert(id)
        } else {
            nonThreadIDs.remove(id)
        }
    }

    private func persist() {
        UserDefaults.standard.set(
            Array(nonThreadIDs.map(\.uuidString)),
            forKey: key
        )
    }
}
