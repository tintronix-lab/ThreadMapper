import Foundation
import Observation

struct CommissioningBriefingEntry {
    let deviceID: UUID
    let deviceName: String
    let roleExplanation: String
    let topologyFit: String
    let recommendation: String
    let generatedAt: Date
}

@Observable @MainActor
final class CommissioningBriefingStore {
    static let shared = CommissioningBriefingStore()
    private init() {}

    private(set) var briefings: [UUID: CommissioningBriefingEntry] = [:]

    func store(deviceID: UUID, deviceName: String, roleExplanation: String, topologyFit: String, recommendation: String) {
        briefings[deviceID] = CommissioningBriefingEntry(
            deviceID: deviceID,
            deviceName: deviceName,
            roleExplanation: roleExplanation,
            topologyFit: topologyFit,
            recommendation: recommendation,
            generatedAt: Date()
        )
    }

    func dismiss(_ deviceID: UUID) {
        briefings.removeValue(forKey: deviceID)
    }
}
