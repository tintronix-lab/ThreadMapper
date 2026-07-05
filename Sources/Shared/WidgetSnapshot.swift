import Foundation

struct WidgetSnapshot: Codable {
    let grade: String
    let score: Int
    let deviceCount: Int
    let offlineCount: Int
    let weakCount: Int
    let updatedAt: Date
    let rooms: [RoomSnapshot]

    struct RoomSnapshot: Codable {
        let name: String
        let deviceCount: Int
        let offlineCount: Int
        let weakCount: Int
    }

    static let placeholder = WidgetSnapshot(
        grade: "—", score: 0, deviceCount: 0, offlineCount: 0, weakCount: 0,
        updatedAt: Date(), rooms: []
    )

    /// Hash of user-visible content, excluding `updatedAt`. Used to decide
    /// whether a widget timeline reload is actually warranted.
    var contentHash: Int {
        var hasher = Hasher()
        hasher.combine(grade)
        hasher.combine(score)
        hasher.combine(deviceCount)
        hasher.combine(offlineCount)
        hasher.combine(weakCount)
        for room in rooms {
            hasher.combine(room.name)
            hasher.combine(room.deviceCount)
            hasher.combine(room.offlineCount)
            hasher.combine(room.weakCount)
        }
        return hasher.finalize()
    }
}
