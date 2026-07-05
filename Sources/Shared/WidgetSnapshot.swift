import Foundation

struct WidgetSnapshot: Codable {
    let grade: String
    let score: Int
    let summary: String              // e.g. "Good — minor issues present"
    let deviceCount: Int
    let offlineCount: Int
    let weakCount: Int
    let offlineDeviceNames: [String] // named list for Siri intent
    let updatedAt: Date
    let rooms: [RoomSnapshot]

    struct RoomSnapshot: Codable {
        let name: String
        let deviceCount: Int
        let offlineCount: Int
        let weakCount: Int
    }

    static let placeholder = WidgetSnapshot(
        grade: "—", score: 0, summary: "No data", deviceCount: 0,
        offlineCount: 0, weakCount: 0, offlineDeviceNames: [],
        updatedAt: Date(), rooms: []
    )

    var contentHash: Int {
        var hasher = Hasher()
        hasher.combine(grade)
        hasher.combine(score)
        hasher.combine(summary)
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
