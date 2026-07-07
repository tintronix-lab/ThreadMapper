import Foundation
import Observation

enum MeshNodeKind: String, Codable {
    case gateway = "Internet / Wi-Fi"
    case borderRouter = "Border Router"
    case router = "Mesh Router"
    case endDevice = "Device"
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

    /// Depth in the inferred hierarchy: 0 = gateway, 1 = border router,
    /// 2 = mesh router, 3 = leaf device. Drives the layered layout.
    var tier: Int = 0

    /// The node this one routes *up* through (its inferred Thread parent).
    /// `nil` for the gateway root. Used to trace the path to the internet.
    var parentID: UUID?

    /// True for a battery / sleepy end device (styled distinctly; never a router).
    var isBattery: Bool = false
}
