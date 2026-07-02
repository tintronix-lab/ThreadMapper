import Foundation

enum MeshNodeKind: String, Codable {
    case borderRouter = "Border Router"
    case router = "Router"
    case endDevice = "End Device"
}

struct MeshNode: Identifiable, Codable {
    let id: UUID
    let name: String
    let kind: MeshNodeKind
    var x: CGFloat
    var y: CGFloat

    init(id: UUID = UUID(), name: String, kind: MeshNodeKind,
         x: CGFloat = 0, y: CGFloat = 0) {
        self.id = id
        self.name = name
        self.kind = kind
        self.x = x
        self.y = y
    }
}
