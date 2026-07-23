@testable import ThreadMapper
import XCTest

final class BorderRouterClientTests: XCTestCase {

    private let nodeJSON = """
    {"State":"leader","NetworkName":"OpenThread-1234","ExtPanId":"1111111122222222","Rloc16":0}
    """
    private let datasetJSON = """
    {"NetworkName":"OpenThread-1234","Channel":15,"PanId":4660,"ExtPanId":"1111111122222222"}
    """

    private let neighborsJSON = """
    [{"ExtAddress":"aa","Rloc16":1024,"IsChild":true,"Rssi":-60,"LinkQualityIn":18},
     {"ExtAddress":"bb","Rloc16":1025,"IsChild":true,"Rssi":-70,"LinkQualityIn":12}]
    """

    /// Fetcher stub that routes by URL path to the right fixture (or throws).
    private func fetcher(node: String?, dataset: String? = nil,
                         neighbors: String? = nil) -> BorderRouterClient.Fetcher {
        { request in
            let path = request.url?.path ?? ""
            if path.contains("neighbors") {
                guard let neighbors else { throw URLError(.badServerResponse) }
                return Data(neighbors.utf8)
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

    private func client(node: String?, dataset: String? = nil,
                        neighbors: String? = nil) -> BorderRouterClient {
        BorderRouterClient(baseURL: URL(string: "http://192.168.1.50:8081")!,
                           fetch: fetcher(node: node, dataset: dataset, neighbors: neighbors))
    }

    private func device(_ name: String, br: Bool, rssi: Int) -> ThreadDevice {
        ThreadDevice(name: name, manufacturer: "T", productName: name, deviceType: "X",
                     uniqueIdentifier: UUID(), isBorderRouter: br, isRouter: br,
                     isSleepyEndDevice: !br, rssi: rssi, room: "Living Room")
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

    func testNodeDiagnosticsEmptyWithoutNeighbors() async {
        // No /neighbors fixture → correlation yields nothing (inference still applies).
        let diags = await client(node: nodeJSON, dataset: datasetJSON).nodeDiagnostics(for: [])
        XCTAssertTrue(diags.isEmpty)
    }

    func testNodeDiagnosticsCorrelatesChildNeighborsToRoomDevices() async {
        let br = device("HomePod", br: true, rssi: -55)
        let e1 = device("Sensor A", br: false, rssi: -60)   // strongest room device
        let e2 = device("Sensor B", br: false, rssi: -70)

        let diags = await client(node: nodeJSON, neighbors: neighborsJSON)
            .nodeDiagnostics(for: [br, e1, e2])

        XCTAssertEqual(diags.count, 3)
        // Border router anchor carries the neighbor table.
        XCTAssertEqual(diags[br.id]?.role, .leader)
        XCTAssertEqual(diags[br.id]?.neighbors.count, 2)
        // Strongest child neighbor (aa, -60) → strongest room device (e1, -60).
        XCTAssertEqual(diags[e1.id]?.rloc16, 1024)
        XCTAssertEqual(diags[e1.id]?.parentRloc16, 0)
        XCTAssertEqual(diags[e1.id]?.extAddress, "aa")
        XCTAssertEqual(diags[e2.id]?.rloc16, 1025)
    }

    func testTestConnectionReflectsReachability() async {
        let reachable = await client(node: nodeJSON, dataset: datasetJSON).testConnection()
        let unreachable = await client(node: nil, dataset: nil).testConnection()
        XCTAssertTrue(reachable)
        XCTAssertFalse(unreachable)
    }
}
