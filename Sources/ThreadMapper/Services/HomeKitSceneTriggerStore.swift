import HomeKit
import OSLog
import SwiftUI

private let hmLogger = Logger(subsystem: "com.tintronixlab.ThreadMapper", category: "homekit-trigger")

// MARK: - NF-7: HomeKit Scene Trigger Store

@MainActor @Observable
final class HomeKitSceneTriggerStore: NSObject {
    static let shared = HomeKitSceneTriggerStore()

    // Persisted configuration
    @ObservationIgnored @AppStorage("hkTriggerEnabled")        var isEnabled = false
    @ObservationIgnored @AppStorage("hkTriggerGrade")          var triggerGrade = "D"
    @ObservationIgnored @AppStorage("hkTriggerActionSetUUID")  var actionSetUUID = ""
    @ObservationIgnored @AppStorage("hkTriggerActionSetName")  var actionSetName = ""

    // Available action sets loaded from HomeKit
    private(set) var availableActionSets: [ActionSetInfo] = []
    private(set) var isLoadingScenes = false

    struct ActionSetInfo: Identifiable, Hashable {
        let id: String    // UUID string
        let name: String
        let homeName: String
    }

    private let manager = HMHomeManager()

    override init() {
        super.init()
        manager.delegate = self
    }

    func loadScenes() {
        isLoadingScenes = true
        var sets: [ActionSetInfo] = []
        for home in manager.homes {
            for actionSet in home.actionSets {
                sets.append(ActionSetInfo(id: actionSet.uniqueIdentifier.uuidString,
                                          name: actionSet.name,
                                          homeName: home.name))
            }
        }
        availableActionSets = sets.sorted { $0.name < $1.name }
        isLoadingScenes = false
    }

    /// Called from MeshViewModel when grade changes. Fires scene if threshold is crossed.
    func fireIfNeeded(newGrade: String, previousGrade: String) {
        guard isEnabled, !actionSetUUID.isEmpty else { return }
        let rank = ["A": 0, "B": 1, "C": 2, "D": 3, "F": 4]
        let threshold = rank[triggerGrade] ?? 3
        let prev = rank[previousGrade] ?? 0
        let curr = rank[newGrade] ?? 0
        guard curr >= threshold && prev < threshold else { return }
        hmLogger.info("Grade crossed threshold \(self.triggerGrade): \(previousGrade)→\(newGrade). Firing scene '\(self.actionSetName)'.")
        executeScene()
    }

    private func executeScene() {
        for home in manager.homes {
            if let set = home.actionSets.first(where: { $0.uniqueIdentifier.uuidString == actionSetUUID }) {
                home.executeActionSet(set) { error in
                    if let error {
                        hmLogger.error("Scene execution failed: \(error.localizedDescription)")
                    }
                }
                return
            }
        }
        hmLogger.warning("Action set UUID \(self.actionSetUUID) not found in any home.")
    }
}

extension HomeKitSceneTriggerStore: HMHomeManagerDelegate {
    nonisolated func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {
        Task { @MainActor in self.loadScenes() }
    }
}
