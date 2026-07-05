import AppIntents
import Foundation

// MARK: - Get Network Health

struct GetNetworkHealthIntent: AppIntent {
    static let title: LocalizedStringResource = "Check Thread Network Health"
    static let description = IntentDescription(
        "Get the current health grade and score for your Thread network.",
        categoryName: "Network"
    )
    static let openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> {
        guard let snapshot = AppGroupStore.readSnapshot() else {
            let msg = "ThreadMapper hasn't scanned yet. Open the app to see your Thread network health."
            return .result(value: msg, dialog: IntentDialog(stringLiteral: msg))
        }
        let value = "Grade \(snapshot.grade) — \(snapshot.score) out of 100. \(snapshot.summary)."
        return .result(value: value, dialog: IntentDialog(stringLiteral: value))
    }
}

// MARK: - Get Offline Devices

struct GetOfflineDevicesIntent: AppIntent {
    static let title: LocalizedStringResource = "Show Offline Thread Devices"
    static let description = IntentDescription(
        "List any Thread devices that are currently offline.",
        categoryName: "Network"
    )
    static let openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> {
        guard let snapshot = AppGroupStore.readSnapshot() else {
            let msg = "ThreadMapper hasn't scanned yet. Open the app to check your devices."
            return .result(value: msg, dialog: IntentDialog(stringLiteral: msg))
        }
        if snapshot.offlineDeviceNames.isEmpty {
            let msg = "All \(snapshot.deviceCount) Thread devices are online."
            return .result(value: msg, dialog: IntentDialog(stringLiteral: msg))
        }
        let names = snapshot.offlineDeviceNames.joined(separator: ", ")
        let count = snapshot.offlineDeviceNames.count
        let msg = "\(count) Thread device\(count == 1 ? " is" : "s are") offline: \(names)."
        return .result(value: msg, dialog: IntentDialog(stringLiteral: msg))
    }
}

// MARK: - Shortcuts Provider

struct ThreadMapperShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: GetNetworkHealthIntent(),
            phrases: [
                "Check my Thread network in \(.applicationName)",
                "What's my network health in \(.applicationName)",
                "Network health in \(.applicationName)"
            ],
            shortTitle: "Check Thread Health",
            systemImageName: "network"
        )
        AppShortcut(
            intent: GetOfflineDevicesIntent(),
            phrases: [
                "Which devices are offline in \(.applicationName)",
                "Show offline devices in \(.applicationName)",
                "Are any devices offline in \(.applicationName)"
            ],
            shortTitle: "Offline Devices",
            systemImageName: "wifi.slash"
        )
    }
}
