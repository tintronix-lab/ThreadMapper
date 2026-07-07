import Foundation

/// Builds an *inferred* Thread/Matter mesh from the limited data HomeKit exposes.
///
/// HomeKit reports which accessories are border routers but not the real Thread
/// parent/child routing table, so paths here are estimated from role, room, and
/// signal — good enough to answer "does this device hop through another Matter
/// device to reach a border router?" while staying honest that it's inferred.
///
/// Hierarchy (top → bottom):
///   gateway (Wi-Fi / Internet)  →  border routers  →  mesh routers  →  end devices
struct MeshTopologyBuilder {

    /// Synthetic root representing the home's Wi-Fi router / internet uplink.
    /// Border routers reach the internet through it; it has no backing device.
    static let gatewayID = UUID(uuidString: "60000000-0000-0000-0000-0000000000FF")!

    static func buildGraph(from devices: [ThreadDevice]) -> ([MeshNode], [MeshLink]) {
        guard !devices.isEmpty else { return ([], []) }

        // Trust explicit router roles when any are present (demo / future Matter
        // diagnostics); otherwise infer routing from power source: mains-powered
        // accessories (no battery reported) relay, battery devices sleep.
        let hasExplicitRoles = devices.contains { !$0.isBorderRouter && $0.isRouter }

        func classify(_ d: ThreadDevice) -> (kind: MeshNodeKind, battery: Bool) {
            if d.isBorderRouter { return (.borderRouter, false) }
            let isRouter = hasExplicitRoles ? d.isRouter : (d.batteryPercentage == nil)
            if isRouter { return (.router, false) }
            return (.endDevice, d.batteryPercentage != nil || d.isSleepyEndDevice)
        }

        let borderRouters = devices.filter { $0.isBorderRouter }
        let routers = devices.filter { !$0.isBorderRouter && classify($0).kind == .router }
        let endDevices = devices.filter { !$0.isBorderRouter && classify($0).kind == .endDevice }

        // Strength proxy: higher rssi (closer to 0) ⇒ more central / better parent.
        func strength(_ d: ThreadDevice) -> Int { d.rssi ?? -100 }

        // Honor a real parent when one is reported (future Matter Thread
        // diagnostics could populate `parentNodeID`); only accept a router/BR.
        let routableIDs = Set((borderRouters + routers).map(\.id))
        func explicitParent(for d: ThreadDevice) -> ThreadDevice? {
            guard let raw = d.parentNodeID,
                  let match = devices.first(where: { $0.id.uuidString == raw }),
                  routableIDs.contains(match.id) else { return nil }
            return match
        }

        var nodes: [MeshNode] = []
        var links: [MeshLink] = []

        // MARK: Gateway (only meaningful when a border router exists)
        if !borderRouters.isEmpty {
            nodes.append(MeshNode(id: gatewayID, name: "Internet", kind: .gateway,
                                  deviceID: nil, tier: 0, parentID: nil))
        }

        // MARK: Border routers — tier 1, uplink to the gateway backbone
        for br in borderRouters {
            nodes.append(MeshNode(id: br.id, name: br.name, kind: .borderRouter,
                                  deviceID: br.id, room: br.room, channel: br.channel,
                                  tier: 1, parentID: borderRouters.isEmpty ? nil : gatewayID))
            links.append(MeshLink(sourceID: gatewayID, targetID: br.id,
                                  linkQuality: 4, kind: .backbone))
        }

        /// Pick the best border router for a device: same room first, then strongest.
        func bestBorderRouter(for d: ThreadDevice) -> ThreadDevice? {
            let sameRoom = borderRouters.filter { $0.room == d.room && d.room != nil }
            let pool = sameRoom.isEmpty ? borderRouters : sameRoom
            return pool.max { strength($0) < strength($1) }
        }

        // MARK: Mesh routers — tier 2, attach to a border router
        for r in routers {
            let parent = explicitParent(for: r) ?? bestBorderRouter(for: r)
            nodes.append(MeshNode(id: r.id, name: r.name, kind: .router,
                                  deviceID: r.id, room: r.room, channel: r.channel,
                                  tier: 2, parentID: parent?.id))
            if let parent {
                links.append(MeshLink(sourceID: parent.id, targetID: r.id,
                                      linkQuality: r.rssi?.rssiLinkQuality ?? 2, kind: .mesh))
            }
        }

        // MARK: End devices — tier 3, prefer hopping through a same-room router
        for e in endDevices {
            let parent = explicitParent(for: e)
                ?? bestParent(for: e, routers: routers,
                              borderRouters: borderRouters, strength: strength)
            nodes.append(MeshNode(id: e.id, name: e.name, kind: .endDevice,
                                  deviceID: e.id, room: e.room, channel: e.channel,
                                  tier: 3, parentID: parent?.id,
                                  isBattery: classify(e).battery))
            if let parent {
                links.append(MeshLink(sourceID: parent.id, targetID: e.id,
                                      linkQuality: e.rssi?.rssiLinkQuality ?? 2, kind: .mesh))
            }
        }

        return (nodes, links)
    }

    /// A leaf device's inferred upstream: a same-room mesh router (a real hop
    /// through another Matter device) is preferred over a distant border router,
    /// then any router, then the best border router.
    private static func bestParent(
        for d: ThreadDevice,
        routers: [ThreadDevice],
        borderRouters: [ThreadDevice],
        strength: (ThreadDevice) -> Int
    ) -> ThreadDevice? {
        if let sameRoomRouter = routers
            .filter({ $0.room == d.room && d.room != nil })
            .max(by: { strength($0) < strength($1) }) {
            return sameRoomRouter
        }
        if let sameRoomBR = borderRouters
            .filter({ $0.room == d.room && d.room != nil })
            .max(by: { strength($0) < strength($1) }) {
            return sameRoomBR
        }
        if let strongestRouter = routers.max(by: { strength($0) < strength($1) }) {
            return strongestRouter
        }
        return borderRouters.max { strength($0) < strength($1) }
    }

    // MARK: - Real-data path (Feature #2)

    /// Build the mesh from *actual* Thread diagnostics (roles + parent RLOCs)
    /// when a `DiagnosticsProvider` supplies them. Devices lacking a diagnostics
    /// entry attach to a border router as a fallback; empty diagnostics defers
    /// entirely to the inference path above, so callers can pass through safely.
    static func buildGraph(from devices: [ThreadDevice],
                           diagnostics: [UUID: ThreadNodeDiagnostics]) -> ([MeshNode], [MeshLink]) {
        guard !devices.isEmpty, !diagnostics.isEmpty else { return buildGraph(from: devices) }

        // RLOC16 → deviceID, to resolve parent RLOCs back to real nodes.
        var deviceByRloc: [UInt16: UUID] = [:]
        for d in devices { if let r = diagnostics[d.id]?.rloc16 { deviceByRloc[r] = d.id } }

        let borderRouters = devices.filter { $0.isBorderRouter }
        var nodes: [MeshNode] = []
        var links: [MeshLink] = []

        if !borderRouters.isEmpty {
            nodes.append(MeshNode(id: gatewayID, name: "Internet", kind: .gateway,
                                  deviceID: nil, tier: 0))
        }

        for d in devices {
            let diag = diagnostics[d.id]
            let kind: MeshNodeKind = d.isBorderRouter ? .borderRouter : (diag?.meshKind ?? .endDevice)
            let tier = kind == .borderRouter ? 1 : (kind == .router ? 2 : 3)
            let battery = diag?.isBattery ?? (d.batteryPercentage != nil)

            var parentID: UUID?
            if d.isBorderRouter {
                parentID = borderRouters.isEmpty ? nil : gatewayID
            } else if let pr = diag?.parentRloc16, let pid = deviceByRloc[pr], pid != d.id {
                parentID = pid                       // real parent from the routing table
            } else {
                parentID = borderRouters.first?.id   // fallback for a node without diagnostics
            }

            nodes.append(MeshNode(id: d.id, name: d.name, kind: kind, deviceID: d.id,
                                  room: d.room, channel: d.channel, tier: tier,
                                  parentID: parentID, isBattery: battery))

            if d.isBorderRouter {
                if !borderRouters.isEmpty {
                    links.append(MeshLink(sourceID: gatewayID, targetID: d.id,
                                          linkQuality: 4, kind: .backbone))
                }
            } else if let pid = parentID {
                let quality = diag?.linkQuality ?? (d.rssi?.rssiLinkQuality ?? 2)
                links.append(MeshLink(sourceID: pid, targetID: d.id,
                                      linkQuality: quality, kind: .mesh))
            }
        }

        return (nodes, links)
    }

    // MARK: - OTBR-native path (Feature #2, Phase 3b)

    /// Deterministic node UUID for an RLOC16 so selection/layout stay stable
    /// across refreshes (distinct from `gatewayID`).
    static func otbrNodeID(_ rloc16: UInt16) -> UUID {
        let hex = String(format: "%04X", rloc16)   // 4 hex digits (rloc16 ≤ 0xFFFF)
        return UUID(uuidString: "0B000000-0000-0000-0000-00000000\(hex)") ?? UUID()
    }

    /// Build the mesh straight from an OTBR's routing table. A Thread RLOC16
    /// encodes its parent — `parent = rloc16 & 0xFC00`, and a node is a router
    /// when `rloc16 & 0x03FF == 0` — so child→parent edges are *real*, not
    /// inferred. Router↔router interconnect is approximated as a star under the
    /// queried border router (the Route table would refine it; see Phase 3b notes).
    static func buildGraph(fromOTBRNodes nodes: [(rloc16: UInt16, ext: String?)],
                           borderRouterRloc: UInt16,
                           networkName: String?) -> ([MeshNode], [MeshLink]) {
        guard !nodes.isEmpty else { return ([], []) }

        var meshNodes: [MeshNode] = [
            MeshNode(id: gatewayID, name: networkName ?? "Internet", kind: .gateway,
                     deviceID: nil, tier: 0),
        ]
        var links: [MeshLink] = []
        let rlocs = Set(nodes.map(\.rloc16))

        func isRouter(_ r: UInt16) -> Bool { (r & 0x03FF) == 0 }
        func label(_ kind: MeshNodeKind, _ r: UInt16) -> String {
            let hex = String(format: "0x%04X", Int(r))
            switch kind {
            case .borderRouter: return "Border Router \(hex)"
            case .router:       return "Router \(hex)"
            default:            return "Device \(hex)"
            }
        }

        for node in nodes {
            let r = node.rloc16
            let isBR = r == borderRouterRloc
            let router = isRouter(r)
            let kind: MeshNodeKind = isBR ? .borderRouter : (router ? .router : .endDevice)
            let tier = isBR ? 1 : (router ? 2 : 3)

            let parentID: UUID?
            if isBR {
                parentID = gatewayID
            } else if router {
                parentID = otbrNodeID(borderRouterRloc)          // approx: routers under BR
            } else {
                let parentRloc = r & 0xFC00                        // real parent from RLOC
                parentID = otbrNodeID(rlocs.contains(parentRloc) ? parentRloc : borderRouterRloc)
            }

            meshNodes.append(MeshNode(id: otbrNodeID(r), name: label(kind, r), kind: kind,
                                      deviceID: nil, tier: tier, parentID: parentID))

            if isBR {
                links.append(MeshLink(sourceID: gatewayID, targetID: otbrNodeID(r),
                                      linkQuality: 4, kind: .backbone))
            } else if let parentID {
                links.append(MeshLink(sourceID: parentID, targetID: otbrNodeID(r),
                                      linkQuality: 3, kind: .mesh))
            }
        }
        return (meshNodes, links)
    }
}
