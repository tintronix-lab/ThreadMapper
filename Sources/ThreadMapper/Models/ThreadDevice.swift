import Foundation
import Observation

final class ThreadDevice: Identifiable, Codable, Hashable, Equatable {
    let id: UUID
    var name: String
    var manufacturer: String
    var productName: String
    var deviceType: String
    var uniqueIdentifier: UUID
    var isBorderRouter: Bool
    var isRouter: Bool
    var isSleepyEndDevice: Bool
    var parentNodeID: String?
    var channel: Int?
    var rssi: Int?
    var batteryPercentage: Int?
    var room: String?

    init(id: UUID = UUID(), name: String, manufacturer: String, productName: String, deviceType: String,
         uniqueIdentifier: UUID, isBorderRouter: Bool, isRouter: Bool, isSleepyEndDevice: Bool = false,
         parentNodeID: String? = nil, channel: Int? = nil, rssi: Int? = nil, batteryPercentage: Int? = nil, room: String? = nil) {
        self.id = id
        self.name = name
        self.manufacturer = manufacturer
        self.productName = productName
        self.deviceType = deviceType
        self.uniqueIdentifier = uniqueIdentifier
        self.isBorderRouter = isBorderRouter
        self.isRouter = isRouter
        self.isSleepyEndDevice = isSleepyEndDevice
        self.parentNodeID = parentNodeID
        self.channel = channel
        self.rssi = rssi
        self.batteryPercentage = batteryPercentage
        self.room = room
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(uniqueIdentifier)
    }

    static func == (lhs: ThreadDevice, rhs: ThreadDevice) -> Bool {
        lhs.uniqueIdentifier == rhs.uniqueIdentifier
    }
}
