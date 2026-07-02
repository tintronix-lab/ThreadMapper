import SwiftData

@Model
final class MeshLink {
    var id: UUID
    var sourceID: String
    var targetID: String
    var linkQuality: Int
    var inRoute: Bool
    var lastUpdated: Date

    init(id: UUID = UUID(), sourceID: String, targetID: String,
         linkQuality: Int = 1, inRoute: Bool = true) {
        self.id = id
        self.sourceID = sourceID
        self.targetID = targetID
        self.linkQuality = linkQuality
        self.inRoute = inRoute
        self.lastUpdated = Date()
    }
}
