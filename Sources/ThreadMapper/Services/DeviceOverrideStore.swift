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
    @ObservationIgnored private let defaults: UserDefaults

    private(set) var nonThreadIDs: Set<UUID> {
        didSet { persist() }
    }

    /// `defaults` is injectable so tests can use an isolated suite; the shared
    /// instance uses `.standard`.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.stringArray(forKey: key) ?? []
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
        defaults.set(Array(nonThreadIDs.map(\.uuidString)), forKey: key)
    }
}
