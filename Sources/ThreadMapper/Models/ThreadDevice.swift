import SwiftData

@Model
final class ThreadDevice {
    var id: UUID
    var name: String
    var manufacturer: String
    var productName: String
    var deviceType: String
    var uniqueIdentifier: String
    var isBorderRouter: Bool
    var isRouter: Bool
    var isSleepyEndDevice: Bool
    var parentNodeID: String?
    var channel: Int?
    var lastSeen: Date
    var rssi: Int?
    var batteryPercentage: Int?
    var room: String?
    var assignedAccessory: String?

    init(id: UUID = UUID(), name: String, manufacturer: String, productName: String,
         deviceType: String, uniqueIdentifier: String,
         isBorderRouter: Bool = false, isRouter: Bool = false,
         isSleepyEndDevice: Bool = false, parentNodeID: String? = nil,
         channel: Int? = nil, rssi: Int? = nil, batteryPercentage: Int? = nil,
         room: String? = nil, assignedAccessory: String? = nil) {
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
        self.lastSeen = Date()
        self.rssi = rssi
        self.batteryPercentage = batteryPercentage
        self.room = room
        self.assignedAccessory = assignedAccessory
    }
}
