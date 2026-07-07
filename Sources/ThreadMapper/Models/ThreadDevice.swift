import Foundation
import Observation

/// Explicit device reachability state — replaces the -100 / -92 Int sentinels.
enum Reachability: Equatable {
    case offline
    case quality(Int) // latency-estimated: -55 (excellent) → -92 (marginal)
}

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

    /// Signature of user-visible metadata. `==` is identity-only
    /// (uniqueIdentifier), so the poll loop compares signatures to detect
    /// renames, room moves, battery/role/channel changes that would
    /// otherwise never propagate to the UI.
    var metadataSignature: String {
        "\(uniqueIdentifier)|\(name)|\(room ?? "")|\(batteryPercentage.map(String.init) ?? "")|\(isBorderRouter)|\(isRouter)|\(channel.map(String.init) ?? "")"
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(uniqueIdentifier)
    }

    static func == (lhs: ThreadDevice, rhs: ThreadDevice) -> Bool {
        lhs.uniqueIdentifier == rhs.uniqueIdentifier
    }
}
