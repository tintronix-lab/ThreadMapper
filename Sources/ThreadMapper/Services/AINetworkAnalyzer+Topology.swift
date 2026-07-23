import Foundation
import FoundationModels

// MARK: - Topology Change Digest (NF-3)

@available(iOS 26, *)
@Generable(description: "Plain-English summary of Thread mesh changes since the user last opened the app")
struct TopologyChangeSummary {
    @Guide(description: "1–2 sentences covering what changed: which devices joined, went offline, or had signal issues. Mention room names. Plain English, no jargon.")
    var headline: String

    @Guide(description: "1 sentence on whether the network is better, worse, or about the same overall.")
    var outlook: String
}

@available(iOS 26, *)
extension AINetworkAnalyzer {
    func topologyChangeSummary(diff: SnapshotDiff, deviceCount: Int) async -> (headline: String, outlook: String)? {
        let session = LanguageModelSession()
        let prompt = Self.buildTopologyDigestPrompt(diff: diff, deviceCount: deviceCount)
        guard let result = try? await session.respond(to: prompt, generating: TopologyChangeSummary.self) else { return nil }
        return (result.content.headline, result.content.outlook)
    }
}
