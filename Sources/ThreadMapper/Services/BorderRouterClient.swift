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
final class BorderRouterClient: DiagnosticsProvider {

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

    /// Per-device diagnostics keyed by HomeKit `ThreadDevice.id` stay empty —
    /// OTBR nodes have no HomeKit identifier to correlate on. The OTBR's own view
    /// is surfaced via `realTopology()` instead.
    func nodeDiagnostics() async -> [UUID: ThreadNodeDiagnostics] { [:] }

    /// The border router's real routing table → a mesh graph. Parent/child edges
    /// are derived from Thread RLOC16 structure (exact); router interconnect is
    /// approximated. Returns nil (→ inferred graph) if the OTBR is unreachable or
    /// reports nothing.
    ///
    /// NOTE: the `/diagnostics` request body (TLV type list) and response shape
    /// need on-hardware verification; parsing fails soft to nil if they differ.
    func realTopology() async -> ([MeshNode], [MeshLink])? {
        // Diagnostic TLV types: Address16 (0), Route64 (5), Child Table (16).
        let body = Data("[0,5,16]".utf8)
        guard let diags = try? await decode([OTBRDiagnostic].self, path: "diagnostics",
                                            method: "POST", body: body),
              !diags.isEmpty else { return nil }

        let node = try? await decode(OTBRNode.self, path: "node")
        let brRloc = UInt16(truncatingIfNeeded: node?.rloc16 ?? 0)
        let otbrNodes: [(rloc16: UInt16, ext: String?)] = diags.compactMap { diag in
            guard let rloc = diag.rloc16 else { return nil }
            return (rloc, diag.extAddress)
        }
        guard !otbrNodes.isEmpty else { return nil }

        return MeshTopologyBuilder.buildGraph(fromOTBRNodes: otbrNodes,
                                              borderRouterRloc: brRloc,
                                              networkName: node?.networkName)
    }

    /// Lightweight reachability check for the Settings "Test connection" button.
    func testConnection() async -> Bool {
        (try? await decode(OTBRNode.self, path: "node")) != nil
    }

    // MARK: - HTTP

    private func request(path: String, method: String = "GET", body: Data? = nil) -> URLRequest {
        var req = URLRequest(url: baseURL.appendingPathComponent(path))
        req.timeoutInterval = 4
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            req.httpBody = body
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return req
    }

    private func decode<T: Decodable>(_ type: T.Type, path: String,
                                      method: String = "GET", body: Data? = nil) async throws -> T {
        let data = try await fetch(request(path: path, method: method, body: body))
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

/// One node's network-diagnostics entry. RLOC16 may arrive as an int or a hex
/// string depending on OTBR version, so it's decoded flexibly.
struct OTBRDiagnostic: Decodable {
    let extAddress: String?
    let rloc16: UInt16?

    enum CodingKeys: String, CodingKey {
        case extAddress = "ExtAddress"
        case rloc16 = "Rloc16"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        extAddress = try? c.decode(String.self, forKey: .extAddress)
        if let intValue = try? c.decode(Int.self, forKey: .rloc16) {
            rloc16 = UInt16(truncatingIfNeeded: intValue)
        } else if let str = try? c.decode(String.self, forKey: .rloc16),
                  let parsed = UInt16(str.replacingOccurrences(of: "0x", with: ""), radix: 16) {
            rloc16 = parsed
        } else {
            rloc16 = nil
        }
    }
}
