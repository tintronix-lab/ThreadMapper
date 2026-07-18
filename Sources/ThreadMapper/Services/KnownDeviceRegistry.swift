import Foundation

/// Persists the set of device UUIDs ever seen by the app so that
/// first-time joins can be distinguished from returning devices.
enum KnownDeviceRegistry {
    private static let key = "tm.knownDeviceIDs"

    static func contains(_ id: UUID) -> Bool {
        persistedIDs.contains(id.uuidString)
    }

    static func markKnown(_ id: UUID) {
        var ids = persistedIDs
        ids.insert(id.uuidString)
        save(ids)
    }

    static func markAllKnown(_ ids: [UUID]) {
        guard !ids.isEmpty else { return }
        var existing = persistedIDs
        ids.forEach { existing.insert($0.uuidString) }
        save(existing)
    }

    static func reset() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    // MARK: - Private

    private static var persistedIDs: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
    }

    private static func save(_ ids: Set<String>) {
        UserDefaults.standard.set(Array(ids), forKey: key)
    }
}
