import Foundation
import Observation

/// A single firmware version transition for one device.
struct FirmwareChange: Codable, Identifiable {
    let id: UUID
    let deviceID: UUID
    let deviceName: String
    let fromVersion: String?   // nil on the very first recorded version
    let toVersion: String
    let detectedAt: Date
}

/// Tracks firmware version changes per device across app launches.
/// Records a new entry only when a version string differs from the last known version.
@Observable
final class FirmwareHistoryStore {
    static let shared = FirmwareHistoryStore()

    private(set) var changes: [FirmwareChange] = []

    @ObservationIgnored private let storeURL: URL
    @ObservationIgnored private var lastKnownVersions: [UUID: String] = [:]

    init(storeURL: URL? = nil) {
        self.storeURL = storeURL ?? Self.defaultURL
        restore()
    }

    // MARK: - Recording

    /// Call each time a device is observed with a (possibly new) firmware version.
    /// Silently ignores nil versions. Logs a change only when the version string differs.
    func record(deviceID: UUID, deviceName: String, version: String) {
        let previous = lastKnownVersions[deviceID]
        guard previous != version else { return }
        let isFirstTime = (previous == nil)
        lastKnownVersions[deviceID] = version
        guard !isFirstTime else { return }  // first observation: just track, don't log a "change"
        let change = FirmwareChange(
            id: UUID(),
            deviceID: deviceID,
            deviceName: deviceName,
            fromVersion: previous,
            toVersion: version,
            detectedAt: Date()
        )
        changes.insert(change, at: 0)
        if changes.count > 500 { changes = Array(changes.prefix(500)) }
        persist()
    }

    // MARK: - Queries

    func changes(for deviceID: UUID) -> [FirmwareChange] {
        changes.filter { $0.deviceID == deviceID }
    }

    func latestVersion(for deviceID: UUID) -> String? {
        lastKnownVersions[deviceID]
    }

    func allTrackedVersions() -> [(deviceID: UUID, version: String)] {
        lastKnownVersions.map { ($0.key, $0.value) }
    }

    // MARK: - Persistence

    private static var defaultURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("firmware_history.json")
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(changes) else { return }
        try? data.write(to: storeURL, options: [.atomic, .completeFileProtection])
    }

    private func restore() {
        guard let data = try? Data(contentsOf: storeURL),
              let decoded = try? JSONDecoder().decode([FirmwareChange].self, from: data) else { return }
        changes = decoded
        // Rebuild last-known from the most recent change per device (array is newest-first).
        for change in decoded.reversed() {
            lastKnownVersions[change.deviceID] = change.toVersion
        }
    }

    // MARK: - Testing support

    static func makeTestInstance() -> FirmwareHistoryStore {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("firmware_test_\(UUID().uuidString).json")
        return FirmwareHistoryStore(storeURL: url)
    }
}
