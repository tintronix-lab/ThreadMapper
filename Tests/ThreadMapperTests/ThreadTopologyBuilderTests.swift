import XCTest
@testable import ThreadMapper

final class ThreadTopologyBuilderTests: XCTestCase {
    func testBuildGraph_withParentNode_buildsLink() throws {
        let dev = ThreadDevice(
            name: "Sensor",
            manufacturer: "Test",
            productName: "Sensor",
            deviceType: "Sensor",
            uniqueIdentifier: "child",
            parentNodeID: "parent",
            rssi: -60
        )
        let (nodes, links) = MeshTopologyBuilder.buildGraph(from: [dev])
        XCTAssertTrue(nodes.isEmpty, "child-only should not create router node when no router exists")
        XCTAssertEqual(links.count, 1)
        XCTAssertEqual(links.first?.sourceID, "parent")
        XCTAssertEqual(links.first?.targetID, "child")
        XCTAssertEqual(links.first?.linkQuality, 3)
    }

    func testBuildGraph_withRouter_addsNodes() throws {
        let router = ThreadDevice(
            name: "Router",
            manufacturer: "Test",
            productName: "Router",
            deviceType: "Router",
            uniqueIdentifier: "router1",
            isRouter: true
        )
        let end = ThreadDevice(
            name: "End",
            manufacturer: "Test",
            productName: "End",
            deviceType: "Sensor",
            uniqueIdentifier: "end1",
            parentNodeID: "router1",
            rssi: -75
        )
        let (nodes, links) = MeshTopologyBuilder.buildGraph(from: [router, end])
        XCTAssertEqual(nodes.count, 1)
        XCTAssertEqual(nodes.first?.name, "Router")
        XCTAssertEqual(links.count, 1)
        XCTAssertEqual(links.first?.linkQuality, 2)
    }

    func testBuildGraph_noParents_returnsEmptyLinks() throws {
        let dev = ThreadDevice(
            name: "Orphan",
            manufacturer: "Test",
            productName: "Unknown",
            deviceType: "Unknown",
            uniqueIdentifier: "orphan"
        )
        let (_, links) = MeshTopologyBuilder.buildGraph(from: [dev])
        XCTAssertTrue(links.isEmpty)
    }
}
