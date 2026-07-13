import Foundation
import WidgetKit

enum AppGroupStore {
    static let groupID = "group.com.tintronixlab.ThreadMapper"

    private static let snapshotKey = "networkSnapshot"
    // v2: keyed by device uniqueIdentifier (uuidString), not name. The renamed
    // key ensures a legacy name-keyed blob is ignored rather than misread as
    // device-state (which would otherwise fire spurious offline notifications).
    private static let deviceStatesKey = "deviceStatesByID"

    // Widget reload throttling — WidgetKit has a strict daily reload budget,
    // and the caller runs at ~1 Hz. Only reload when meaningful content
    // changed, and never more than once per `minReloadInterval`.
    nonisolated(unsafe) private static var lastReloadAt: Date = .distantPast
    nonisolated(unsafe) private static var lastContentHash: Int?
    private static let minReloadInterval: TimeInterval = 60

    // MARK: - Widget snapshot (written by main app, read by widget)

    static func writeSnapshot(_ snapshot: WidgetSnapshot) {
        guard let defaults = UserDefaults(suiteName: groupID),
              let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: snapshotKey)

        let contentHash = snapshot.contentHash
        let now = Date()
        guard contentHash != lastContentHash,
              now.timeIntervalSince(lastReloadAt) >= minReloadInterval else { return }
        lastContentHash = contentHash
        lastReloadAt = now
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func readSnapshot() -> WidgetSnapshot? {
        guard let defaults = UserDefaults(suiteName: groupID),
              let data = defaults.data(forKey: snapshotKey),
              let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
        else { return nil }
        return snapshot
    }

    // MARK: - Device reachability states (used by BGTask to detect offline changes)
    // Keyed by device name → isReachable

    static func writeDeviceStates(_ states: [String: Bool]) {
        guard let defaults = UserDefaults(suiteName: groupID),
              let data = try? JSONEncoder().encode(states) else { return }
        defaults.set(data, forKey: deviceStatesKey)
    }

    static func readDeviceStates() -> [String: Bool] {
        guard let defaults = UserDefaults(suiteName: groupID),
              let data = defaults.data(forKey: deviceStatesKey),
              let states = try? JSONDecoder().decode([String: Bool].self, from: data)
        else { return [:] }
        return states
    }
}
