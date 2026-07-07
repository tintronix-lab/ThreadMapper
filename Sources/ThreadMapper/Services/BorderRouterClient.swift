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

    /// Real routing table parsing is Phase 3b (needs `POST /diagnostics` + OTBR↔
    /// HomeKit device correlation, verified on hardware).
    func nodeDiagnostics() async -> [UUID: ThreadNodeDiagnostics] { [:] }

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
