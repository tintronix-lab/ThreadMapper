import Foundation
import Observation

enum MeshNodeKind: String, Codable {
    case borderRouter = "Border Router"
    case router = "Router"
    case endDevice = "End Device"
}

struct MeshNode: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    let kind: MeshNodeKind
    var x: CGFloat = 0
    var y: CGFloat = 0
    var deviceID: UUID?
    var room: String?
    var channel: Int?
}
