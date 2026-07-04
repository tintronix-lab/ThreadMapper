import Foundation
import WidgetKit

enum AppGroupStore {
    static let groupID = "group.com.tintronixlab.ThreadMapper"

    private static let snapshotKey = "networkSnapshot"
    private static let deviceStatesKey = "deviceStates"

    // MARK: - Widget snapshot (written by main app, read by widget)

    static func writeSnapshot(_ snapshot: WidgetSnapshot) {
        guard let defaults = UserDefaults(suiteName: groupID),
              let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: snapshotKey)
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
