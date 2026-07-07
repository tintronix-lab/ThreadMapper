import Foundation

/// Real Thread network-level facts from Apple's Thread credential store
/// (`ThreadNetwork` framework). Unlike per-node routing, these *are* obtainable
/// by a third-party app (with the Thread credentials entitlement), so Feature #2
/// can surface the true channel / PAN ID / network name even when the mesh
/// topology itself stays inferred.
struct ThreadNetworkInfo: Equatable, Identifiable, Codable {
    var id: String { extendedPANID ?? networkName }
    let networkName: String
    let channel: Int?
    let panID: String?
    let extendedPANID: String?
    let borderAgentID: String?
}
