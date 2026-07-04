import XCTest
@testable import ThreadMapper

final class ThreadTopologyBuilderTests: XCTestCase {
    func testBuildGraph_withBorderRouter_createsLinks() throws {
        let br = ThreadDevice(
            id: UUID(), name: "BR", manufacturer: "Test", productName: "Bridge", deviceType: "Bridge",
            uniqueIdentifier: UUID(), isBorderRouter: true, isRouter: true, isSleepyEndDevice: false
        )
        let end = ThreadDevice(
            id: UUID(), name: "End", manufacturer: "Test", productName: "End", deviceType: "Sensor",
            uniqueIdentifier: UUID(), isBorderRouter: false, isRouter: false, isSleepyEndDevice: true,
            parentNodeID: br.id.uuidString, rssi: -75
        )
        let (nodes, links) = MeshTopologyBuilder.buildGraph(from: [br, end])
        XCTAssertEqual(nodes.count, 2)
        XCTAssertEqual(links.count, 1)
        XCTAssertEqual(nodes.first(where: { $0.name == "BR" })?.kind, .borderRouter)
    }

    func testBuildGraph_noBorderRouter_returnsNodesOnly() throws {
        let dev = ThreadDevice(
            id: UUID(), name: "Orphan", manufacturer: "Test", productName: "Unknown", deviceType: "Unknown",
            uniqueIdentifier: UUID(), isBorderRouter: false, isRouter: false, isSleepyEndDevice: true
        )
        let (nodes, links) = MeshTopologyBuilder.buildGraph(from: [dev])
        XCTAssertEqual(nodes.count, 1)
        XCTAssertTrue(links.isEmpty)
        XCTAssertEqual(nodes.first?.kind, .endDevice)
    }

    func testBuildGraph_borderRouterIsClassified() throws {
        let br = ThreadDevice(
            id: UUID(), name: "BR", manufacturer: "Test", productName: "Bridge", deviceType: "Bridge",
            uniqueIdentifier: UUID(), isBorderRouter: true, isRouter: false, isSleepyEndDevice: false
        )
        let (nodes, _) = MeshTopologyBuilder.buildGraph(from: [br])
        XCTAssertEqual(nodes.count, 1)
        XCTAssertEqual(nodes.first?.kind, .borderRouter)
    }
}
