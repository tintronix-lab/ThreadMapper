import Foundation
import Observation

/// Explicit device reachability state — replaces the -100 / -92 Int sentinels.
enum Reachability: Equatable {
    case offline
    case quality(Int) // latency-estimated: -55 (excellent) → -92 (marginal)
}

@Observable
final class ThreadDevice: Identifiable, Codable, Hashable, Equatable, @unchecked Sendable {
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

    /// Derived reachability state from the raw rssi field.
    var reachability: Reachability? {
        guard let rssi else { return nil }
        return rssi == -100 ? .offline : .quality(rssi)
    }

    /// True when the device is confirmed unreachable (rssi sentinel -100).
    var isOffline: Bool { rssi == -100 }

    /// True when signal quality is poor but device is reachable.
    var isWeak: Bool {
        if case .quality(let q) = reachability { return q < -80 }
        return false
    }

    /// A border router is also a router. Single source of truth for "counts as a
    /// router" so the Resilience grade and the resilience achievement agree (D6).
    var isRoutingCapable: Bool { isRouter || isBorderRouter }

    // MARK: - Codable
    // Custom implementation required: @Observable rewrites stored vars into
    // macro-generated backing storage that the synthesizer cannot reconcile with Codable.

    private enum CodingKeys: String, CodingKey {
        case id, name, manufacturer, productName, deviceType, uniqueIdentifier
        case isBorderRouter, isRouter, isSleepyEndDevice, parentNodeID
        case channel, rssi, batteryPercentage, room
    }

    required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id                = try c.decode(UUID.self,   forKey: .id)
        name              = try c.decode(String.self, forKey: .name)
        manufacturer      = try c.decode(String.self, forKey: .manufacturer)
        productName       = try c.decode(String.self, forKey: .productName)
        deviceType        = try c.decode(String.self, forKey: .deviceType)
        uniqueIdentifier  = try c.decode(UUID.self,   forKey: .uniqueIdentifier)
        isBorderRouter    = try c.decode(Bool.self,   forKey: .isBorderRouter)
        isRouter          = try c.decode(Bool.self,   forKey: .isRouter)
        isSleepyEndDevice = try c.decode(Bool.self,   forKey: .isSleepyEndDevice)
        parentNodeID      = try c.decodeIfPresent(String.self, forKey: .parentNodeID)
        channel           = try c.decodeIfPresent(Int.self,    forKey: .channel)
        rssi              = try c.decodeIfPresent(Int.self,    forKey: .rssi)
        batteryPercentage = try c.decodeIfPresent(Int.self,    forKey: .batteryPercentage)
        room              = try c.decodeIfPresent(String.self, forKey: .room)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id,                forKey: .id)
        try c.encode(name,              forKey: .name)
        try c.encode(manufacturer,      forKey: .manufacturer)
        try c.encode(productName,       forKey: .productName)
        try c.encode(deviceType,        forKey: .deviceType)
        try c.encode(uniqueIdentifier,  forKey: .uniqueIdentifier)
        try c.encode(isBorderRouter,    forKey: .isBorderRouter)
        try c.encode(isRouter,          forKey: .isRouter)
        try c.encode(isSleepyEndDevice, forKey: .isSleepyEndDevice)
        try c.encodeIfPresent(parentNodeID,      forKey: .parentNodeID)
        try c.encodeIfPresent(channel,           forKey: .channel)
        try c.encodeIfPresent(rssi,              forKey: .rssi)
        try c.encodeIfPresent(batteryPercentage, forKey: .batteryPercentage)
        try c.encodeIfPresent(room,              forKey: .room)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(uniqueIdentifier)
    }

    static func == (lhs: ThreadDevice, rhs: ThreadDevice) -> Bool {
        lhs.uniqueIdentifier == rhs.uniqueIdentifier
    }
}
