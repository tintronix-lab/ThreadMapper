import Foundation

struct MeshLink: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    let sourceID: UUID
    let targetID: UUID
    let linkQuality: Int

    init(id: UUID = UUID(), sourceID: UUID, targetID: UUID, linkQuality: Int) {
        self.id = id
        self.sourceID = sourceID
        self.targetID = targetID
        self.linkQuality = linkQuality
    }
}
