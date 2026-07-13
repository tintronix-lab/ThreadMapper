import Foundation

/// Talks to an OpenThread Border Router's REST API (ot-br-posix, default port
/// 8081) to read **real** Thread data — the one path to genuine routing that
/// doesn't depend on Apple exposing diagnostics.
///
/// Phase 3a (here): real **network facts** from `/node` + `/node/dataset/active`
/// (network name, channel, PAN ID, ext PAN ID) — mappable with no device
/// correlation, so it flows straight into the Mesh tab's network bar.
///
/// Phase 3b (next, needs on-hardware verification): parse `POST /diagnostics`
/// (child/route tables) into `ThreadNodeDiagnostics` and correlate OTBR nodes
/// (by ext-address) to HomeKit accessories — hence `nodeDiagnostics()` is empty
/// for now.
final class BorderRouterClient: DiagnosticsProvider, @unchecked Sendable {

    typealias Fetcher = (URLRequest) async throws -> Data

    let baseURL: URL
    private let fetch: Fetcher

    init(baseURL: URL, fetch: @escaping Fetcher = BorderRouterClient.defaultFetch) {
        self.baseURL = baseURL
        self.fetch = fetch
    }

    static func defaultFetch(_ request: URLRequest) async throws -> Data {
        let (data, _) = try await URLSession.shared.data(for: request)
        return data
    }

    // MARK: - DiagnosticsProvider

    func threadNetworks() async -> [ThreadNetworkInfo] {
        let node = try? await decode(OTBRNode.self, path: "node")
        let dataset = try? await decode(OTBRActiveDataset.self, path: "node/dataset/active")

        guard let name = dataset?.networkName ?? node?.networkName else { return [] }
        return [ThreadNetworkInfo(
            networkName: name,
            channel: dataset?.channel,
            panID: dataset?.panId.map { String(format: "0x%04X", $0) },
            extendedPANID: dataset?.extPanId ?? node?.extPanId,
            borderAgentID: nil
        )]
    }

    /// Phase 3b: parse `/neighbors` to get real link-quality data for nodes
    /// directly attached to this border router.
    ///
    /// **Correlation strategy**: OTBR nodes are identified by RLOC16 + ext-address,
    /// while HomeKit devices use opaque UUIDs. Without a shared key (HomeKit doesn't
    /// expose Thread addresses), exact matching is not possible. This implementation
    /// uses a best-effort heuristic:
    ///   • The OTBR itself → matched to the HomeKit border router with the strongest
    ///     signal (most likely to be the same physical device).
    ///   • Neighbors with `IsChild = true` → matched to HomeKit end devices in the
    ///     same room as the matched border router, ordered by signal strength.
    ///   • Unmatched nodes → skipped (inference path still applies for those).
    ///
    /// Real matching requires on-hardware verification with a known mapping
    /// (e.g., user labels the OTBR or a future Thread Diagnostics cluster read).
    func nodeDiagnostics(for devices: [ThreadDevice]) async -> [UUID: ThreadNodeDiagnostics] {
        guard let neighbors = try? await decode([OTBRNeighbor].self, path: "neighbors"),
              !neighbors.isEmpty else { return [:] }

        var result: [UUID: ThreadNodeDiagnostics] = [:]

        // Match the OTBR border router itself: pick the HomeKit border router with
        // the strongest estimated signal (best proxy without explicit configuration).
        let borderRouters = devices.filter { $0.isBorderRouter }
        guard let anchorBR = borderRouters.max(by: { ($0.rssi ?? -100) < ($1.rssi ?? -100) }) else {
            return [:]
        }

        // Build the OTBR's own diagnostics entry from its `/node` response.
        let otbrNode = try? await decode(OTBRNode.self, path: "node")
        let otbrRloc = otbrNode?.rloc16.map { UInt16($0 & 0xFFFF) }
        result[anchorBR.id] = ThreadNodeDiagnostics(
            deviceID: anchorBR.id,
            role: .leader,
            rloc16: otbrRloc,
            neighbors: neighbors.map {
                ThreadNodeDiagnostics.Neighbor(
                    rloc16: UInt16($0.rloc16 & 0xFFFF),
                    linkMarginDB: $0.linkMarginDB,
                    averageRSSI: $0.rssi,
                    isChild: $0.isChild
                )
            }
        )

        // Match child neighbors to HomeKit end devices in the anchor border router's room.
        // Sorted weakest-first so we assign the best match to the most likely candidate.
        let childNeighbors = neighbors.filter(\.isChild)
            .sorted { ($0.rssi ?? -100) > ($1.rssi ?? -100) }

        let brRoom = anchorBR.room
        let candidateDevices = devices
            .filter { !$0.isBorderRouter && $0.room == brRoom }
            .sorted { ($0.rssi ?? -100) > ($1.rssi ?? -100) }

        for (neighbor, device) in zip(childNeighbors, candidateDevices) {
            result[device.id] = ThreadNodeDiagnostics(
                deviceID: device.id,
                role: device.isSleepyEndDevice ? .sleepyEndDevice : .child,
                rloc16: UInt16(neighbor.rloc16 & 0xFFFF),
                parentRloc16: otbrRloc,
                extAddress: neighbor.extAddress,
                neighbors: [ThreadNodeDiagnostics.Neighbor(
                    rloc16: otbrRloc ?? 0,
                    linkMarginDB: neighbor.linkMarginDB,
                    averageRSSI: neighbor.rssi,
                    isChild: false
                )]
            )
        }

        return result
    }

    /// Lightweight reachability check for the Settings "Test connection" button.
    func testConnection() async -> Bool {
        (try? await decode(OTBRNode.self, path: "node")) != nil
    }

    // MARK: - HTTP

    private func request(path: String) -> URLRequest {
        var req = URLRequest(url: baseURL.appendingPathComponent(path))
        req.timeoutInterval = 4
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        return req
    }

    private func decode<T: Decodable>(_ type: T.Type, path: String) async throws -> T {
        let data = try await fetch(request(path: path))
        return try JSONDecoder().decode(T.self, from: data)
    }
}

// MARK: - OTBR REST response models (subset of ot-br-posix)

struct OTBRNode: Decodable {
    let networkName: String?
    let extPanId: String?
    let rloc16: Int?
    let state: String?

    enum CodingKeys: String, CodingKey {
        case networkName = "NetworkName"
        case extPanId = "ExtPanId"
        case rloc16 = "Rloc16"
        case state = "State"
    }
}

struct OTBRActiveDataset: Decodable {
    let networkName: String?
    let channel: Int?
    let panId: Int?
    let extPanId: String?

    enum CodingKeys: String, CodingKey {
        case networkName = "NetworkName"
        case channel = "Channel"
        case panId = "PanId"
        case extPanId = "ExtPanId"
    }
}

struct OTBRNeighbor: Decodable {
    let extAddress: String?
    let rloc16: Int
    let isChild: Bool
    let rssi: Int?
    let linkMarginDB: Int?
    let rxOnWhenIdle: Bool?

    enum CodingKeys: String, CodingKey {
        case extAddress    = "ExtAddress"
        case rloc16        = "Rloc16"
        case isChild       = "IsChild"
        case rssi          = "Rssi"
        case linkMarginDB  = "LinkQualityIn"
        case rxOnWhenIdle  = "RxOnWhenIdle"
    }
}
