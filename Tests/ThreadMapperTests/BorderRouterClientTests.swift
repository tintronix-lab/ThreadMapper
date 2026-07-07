import XCTest
@testable import ThreadMapper

final class BorderRouterClientTests: XCTestCase {

    private let nodeJSON = """
    {"State":"leader","NetworkName":"OpenThread-1234","ExtPanId":"1111111122222222","Rloc16":0}
    """
    private let datasetJSON = """
    {"NetworkName":"OpenThread-1234","Channel":15,"PanId":4660,"ExtPanId":"1111111122222222"}
    """

    private let diagnosticsJSON = """
    [{"ExtAddress":"aa","Rloc16":0},{"ExtAddress":"bb","Rloc16":1024},{"ExtAddress":"cc","Rloc16":1025}]
    """

    /// Fetcher stub that routes by URL path to the right fixture (or throws).
    private func fetcher(node: String?, dataset: String?, diagnostics: String? = nil) -> BorderRouterClient.Fetcher {
        { request in
            let path = request.url?.path ?? ""
            if path.contains("diagnostics") {
                guard let diagnostics else { throw URLError(.badServerResponse) }
                return Data(diagnostics.utf8)
            }
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

    private func client(node: String?, dataset: String?, diagnostics: String? = nil) -> BorderRouterClient {
        BorderRouterClient(baseURL: URL(string: "http://192.168.1.50:8081")!,
                           fetch: fetcher(node: node, dataset: dataset, diagnostics: diagnostics))
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

    func testNodeDiagnosticsAlwaysEmptyForOTBR() async {
        // OTBR nodes have no HomeKit id to key on; the graph comes via realTopology.
        let diags = await client(node: nodeJSON, dataset: datasetJSON).nodeDiagnostics()
        XCTAssertTrue(diags.isEmpty)
    }

    func testRealTopologyBuildsGraphFromDiagnostics() async {
        let client = client(node: nodeJSON, dataset: datasetJSON, diagnostics: diagnosticsJSON)
        guard let (nodes, links) = await client.realTopology() else {
            return XCTFail("expected a real topology")
        }
        XCTAssertNotNil(nodes.first { $0.kind == .gateway })
        // 1025 == 0x0401, parent 0x0400 (== 1024) by RLOC masking.
        let child = nodes.first { $0.id == MeshTopologyBuilder.otbrNodeID(0x0401) }
        XCTAssertEqual(child?.parentID, MeshTopologyBuilder.otbrNodeID(0x0400))
        XCTAssertEqual(links.count, 3)
    }

    func testRealTopologyNilWhenDiagnosticsUnavailable() async {
        let result = await client(node: nodeJSON, dataset: datasetJSON, diagnostics: nil).realTopology()
        XCTAssertNil(result)
    }

    func testTestConnectionReflectsReachability() async {
        let reachable = await client(node: nodeJSON, dataset: datasetJSON).testConnection()
        let unreachable = await client(node: nil, dataset: nil).testConnection()
        XCTAssertTrue(reachable)
        XCTAssertFalse(unreachable)
    }
}
