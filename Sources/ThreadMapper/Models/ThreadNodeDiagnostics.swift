import Foundation

/// Real per-node Thread routing data — the kind of thing the Thread Network
/// Diagnostics cluster (or an OpenThread Border Router) reports. Present only
/// when a real `DiagnosticsProvider` is connected; absent for HomeKit-only
/// setups, where `MeshTopologyBuilder` falls back to inference.
///
/// This is the seam Feature #2 fills in: once real routing is available, the
/// mesh graph is built from these facts instead of role/room/signal guesses.
struct ThreadNodeDiagnostics: Equatable {

    enum Role: String, Codable, Equatable {
        case leader          // the Thread network leader (usually a border router)
        case router          // full Thread router (relays for others)
        case reed            // router-eligible end device (can become a router)
        case child           // end device attached to a parent router
        case endDevice       // mains end device
        case sleepyEndDevice // battery / sleepy end device
        case unknown
    }

    /// Neighbor / child table entry with real link quality.
    struct Neighbor: Equatable {
        let rloc16: UInt16
        let linkMarginDB: Int?   // dB above the noise floor; higher is better
        let averageRSSI: Int?    // dBm, if reported
        let isChild: Bool
    }

    let deviceID: UUID           // maps to ThreadDevice.id
    let role: Role
    let rloc16: UInt16?          // 16-bit routing locator
    let parentRloc16: UInt16?    // parent's RLOC16 (child → parent edge)
    let extAddress: String?      // 64-bit extended address, hex
    var neighbors: [Neighbor]

    init(deviceID: UUID, role: Role, rloc16: UInt16? = nil, parentRloc16: UInt16? = nil,
         extAddress: String? = nil, neighbors: [Neighbor] = []) {
        self.deviceID = deviceID
        self.role = role
        self.rloc16 = rloc16
        self.parentRloc16 = parentRloc16
        self.extAddress = extAddress
        self.neighbors = neighbors
    }

    /// Mesh link-quality (1…4) from the best real neighbor reading, matching the
    /// scale used by inferred links so the renderer treats both the same.
    var linkQuality: Int {
        let margins = neighbors.compactMap(\.linkMarginDB)
        if let best = margins.max() {
            switch best {
            case 20...: return 4
            case 10..<20: return 3
            case 5..<10: return 2
            default: return 1
            }
        }
        if let rssi = neighbors.compactMap(\.averageRSSI).max() {
            return rssi.rssiLinkQuality
        }
        return 2
    }

    /// Map the Thread role onto the mesh node kind used by the graph.
    var meshKind: MeshNodeKind {
        switch role {
        case .leader, .router, .reed: return .router
        case .child, .endDevice, .sleepyEndDevice, .unknown: return .endDevice
        }
    }

    var isBattery: Bool { role == .sleepyEndDevice }
}
