import Foundation
import Observation
import SwiftUI

/// Explicit device reachability state — replaces the -100 / -92 Int sentinels.
enum Reachability: Equatable {
    case offline
    case quality(Int) // latency-estimated: -55 (excellent) → -92 (marginal)
}

// MARK: - Protocol classification

/// Inferred connectivity protocol for a device, derived from manufacturer + role.
enum DeviceProtocol: String, CaseIterable {
    case threadBorderRouter = "Border Router"
    case threadNative       = "Thread"
    case matterBridge       = "Matter Bridge"
    case zigbeeBridge       = "Zigbee Bridge"
    case homeKitOnly        = "HomeKit"
    case unknown            = "Unknown"

    var icon: String {
        switch self {
        case .threadBorderRouter: return "antenna.radiowaves.left.and.right.circle.fill"
        case .threadNative:       return "antenna.radiowaves.left.and.right"
        case .matterBridge:       return "point.3.connected.trianglepath.dotted"
        case .zigbeeBridge:       return "hexagon"
        case .homeKitOnly:        return "house.fill"
        case .unknown:            return "questionmark.circle"
        }
    }

    var color: Color {
        switch self {
        case .threadBorderRouter: return .purple
        case .threadNative:       return .blue
        case .matterBridge:       return .indigo
        case .zigbeeBridge:       return .orange
        case .homeKitOnly:        return .teal
        case .unknown:            return .gray
        }
    }

    var shortLabel: LocalizedStringResource {
        switch self {
        case .threadBorderRouter: return "Border Router"
        case .threadNative:       return "Thread"
        case .matterBridge:       return "Matter Bridge"
        case .zigbeeBridge:       return "Zigbee"
        case .homeKitOnly:        return "HomeKit"
        case .unknown:            return "Unknown"
        }
    }

    var detail: LocalizedStringResource {
        switch self {
        case .threadBorderRouter: return "Acts as a gateway between Thread mesh and your Wi-Fi network."
        case .threadNative:       return "Communicates natively over the Thread mesh protocol."
        case .matterBridge:       return "Bridges Matter or multiple protocols to your Thread network."
        case .zigbeeBridge:       return "Uses Zigbee, not Thread. Devices behind this hub aren't on your Thread mesh."
        case .homeKitOnly:        return "Connects via Wi-Fi or Bluetooth — not part of the Thread mesh."
        case .unknown:            return "Protocol could not be determined from available data."
        }
    }

    /// True if this device contributes to the Thread mesh topology.
    var isThreadParticipant: Bool {
        switch self {
        case .threadBorderRouter, .threadNative: return true
        default: return false
        }
    }
}

// MARK: - ThreadDevice

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
    var firmwareVersion: String?

    init(id: UUID = UUID(), name: String, manufacturer: String, productName: String, deviceType: String,
         uniqueIdentifier: UUID, isBorderRouter: Bool, isRouter: Bool, isSleepyEndDevice: Bool = false,
         parentNodeID: String? = nil, channel: Int? = nil, rssi: Int? = nil,
         batteryPercentage: Int? = nil, room: String? = nil, firmwareVersion: String? = nil) {
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
        self.firmwareVersion = firmwareVersion
    }

    // MARK: - Derived properties

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

    /// Inferred connectivity protocol from manufacturer name and device role.
    var deviceProtocol: DeviceProtocol {
        let mfr     = manufacturer.lowercased()
        let product = productName.lowercased()

        // Classify known Zigbee bridges first (HomeKit marks them as borderRouters/bridges)
        if mfr.contains("ikea") || product.contains("dirigera") || product.contains("tradfri hub") { return .zigbeeBridge }
        if mfr.contains("philips") || mfr.contains("signify") || product.contains("hue bridge") { return .zigbeeBridge }

        // Apple and Samsung border routers are proper Thread BRs
        if isBorderRouter && mfr.contains("apple") { return .threadBorderRouter }
        if isBorderRouter && (mfr.contains("samsung") || mfr.contains("smartthings")) { return .threadBorderRouter }

        // Matter bridges (hub devices that proxy other protocols)
        if isBorderRouter && (mfr.contains("aqara") || mfr.contains("homey") || mfr.contains("wemo")) { return .matterBridge }
        if isBorderRouter { return .matterBridge }

        // Known Thread-native end-device manufacturers
        if mfr.contains("eve") || mfr.contains("nanoleaf") || mfr.contains("bosch") { return .threadNative }
        if mfr.contains("netatmo") || mfr.contains("elgato") { return .threadNative }

        // Any device actively on a Thread channel is Thread-native
        if channel != nil || isRouter { return .threadNative }

        return .homeKitOnly
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case id, name, manufacturer, productName, deviceType, uniqueIdentifier
        case isBorderRouter, isRouter, isSleepyEndDevice, parentNodeID
        case channel, rssi, batteryPercentage, room, firmwareVersion
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
        firmwareVersion   = try c.decodeIfPresent(String.self, forKey: .firmwareVersion)
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
        try c.encodeIfPresent(firmwareVersion,   forKey: .firmwareVersion)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(uniqueIdentifier)
    }

    static func == (lhs: ThreadDevice, rhs: ThreadDevice) -> Bool {
        lhs.uniqueIdentifier == rhs.uniqueIdentifier
    }
}
