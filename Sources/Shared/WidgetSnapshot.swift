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
}
