import Foundation

enum MeshLinkKind: String, Codable {
    case backbone   // gateway ↔ border router (IP / Wi-Fi / Ethernet)
    case mesh       // Thread mesh hop (router ↔ router, or device ↔ router)
}

struct MeshLink: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    let sourceID: UUID   // parent (upstream, toward the gateway)
    let targetID: UUID   // child (downstream)
    let linkQuality: Int // 1 (weak) … 4 (strong)
    var kind: MeshLinkKind

    init(id: UUID = UUID(), sourceID: UUID, targetID: UUID, linkQuality: Int, kind: MeshLinkKind = .mesh) {
        self.id = id
        self.sourceID = sourceID
        self.targetID = targetID
        self.linkQuality = linkQuality
        self.kind = kind
    }
}
