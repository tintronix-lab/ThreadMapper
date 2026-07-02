import Foundation

final class MeshLink: Identifiable, ObservableObject {
    var id: UUID
    var sourceID: UUID
    var targetID: UUID
    var linkQuality: Int
    var inRoute: Bool
    var lastUpdated: Date

    init(id: UUID = UUID(), sourceID: UUID, targetID: UUID,
         linkQuality: Int = 1, inRoute: Bool = true) {
        self.id = id
        self.sourceID = sourceID
        self.targetID = targetID
        self.linkQuality = linkQuality
        self.inRoute = inRoute
        self.lastUpdated = Date()
    }
}
