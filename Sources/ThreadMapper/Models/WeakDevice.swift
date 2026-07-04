import Foundation

struct WeakDevice: Identifiable, Codable, Equatable, Hashable {
    var id: UUID = UUID()
    let name: String
    let rssi: Int
}