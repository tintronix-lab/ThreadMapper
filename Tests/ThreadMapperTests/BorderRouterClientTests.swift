import XCTest
@testable import ThreadMapper

final class BorderRouterClientTests: XCTestCase {

    private let nodeJSON = """
    {"State":"leader","NetworkName":"OpenThread-1234","ExtPanId":"1111111122222222","Rloc16":0}
    """
    private let datasetJSON = """
    {"NetworkName":"OpenThread-1234","Channel":15,"PanId":4660,"ExtPanId":"1111111122222222"}
    """

    /// Fetcher stub that routes by URL path to the right fixture (or throws).
    private func fetcher(node: String?, dataset: String?) -> BorderRouterClient.Fetcher {
        { request in
            let path = request.url?.path ?? ""
            if path.contains("dataset") {
                guard let dataset else { throw URLError(.badServerResponse) }
                return Data(dataset.utf8)
            }
            if path.hasSuffix("node") {
                guard let node else { throw URLError(.badServerResponse) }
                return Data(node.utf8)
            }
            throw URLError(.unsupportedURL)
        }
    }

    private func client(node: String?, dataset: String?) -> BorderRouterClient {
        BorderRouterClient(baseURL: URL(string: "http://192.168.1.50:8081")!,
                           fetch: fetcher(node: node, dataset: dataset))
    }

    func testThreadNetworksParsesNodeAndDataset() async {
        let networks = await client(node: nodeJSON, dataset: datasetJSON).threadNetworks()
        XCTAssertEqual(networks.count, 1)
        let net = networks.first
        XCTAssertEqual(net?.networkName, "OpenThread-1234")
        XCTAssertEqual(net?.channel, 15)
        XCTAssertEqual(net?.panID, "0x1234")               // 4660 == 0x1234
        XCTAssertEqual(net?.extendedPANID, "1111111122222222")
    }

    func testUnreachableBorderRouterYieldsNoNetworks() async {
        let networks = await client(node: nil, dataset: nil).threadNetworks()
        XCTAssertTrue(networks.isEmpty)
    }

    func testNodeDiagnosticsEmptyWithoutDevicesToCorrelate() async {
        let diags = await client(node: nodeJSON, dataset: datasetJSON).nodeDiagnostics(for: [])
        XCTAssertTrue(diags.isEmpty)
    }

    func testTestConnectionReflectsReachability() async {
        let reachable = await client(node: nodeJSON, dataset: datasetJSON).testConnection()
        let unreachable = await client(node: nil, dataset: nil).testConnection()
        XCTAssertTrue(reachable)
        XCTAssertFalse(unreachable)
    }
}
