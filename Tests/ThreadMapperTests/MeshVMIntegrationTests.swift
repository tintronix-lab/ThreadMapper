import XCTest
@testable import ThreadMapper

final class MeshTopologyBuilderRouterTests: XCTestCase {
    func testBuildGraph_routerWithTwoChildren_createsNodesAndLinks() throws {
        let router = ThreadDevice(
            name: "Router", manufacturer: "Test", productName: "R", deviceType: "Router",
            uniqueIdentifier: "r1", isRouter: true)
        let child1 = ThreadDevice(name: "C1", manufacturer: "Test", productName: "C", deviceType: "Sensor", uniqueIdentifier: "c1", parentNodeID: "r1", rssi: -55)
        let child2 = ThreadDevice(name: "C2", manufacturer: "Test", productName: "C", deviceType: "Sensor", uniqueIdentifier: "c2", parentNodeID: "r1", rssi: -70)
        let (nodes, links) = MeshTopologyBuilder.buildGraph(from: [router, child1, child2])
        XCTAssertEqual(nodes.count, 1)
        XCTAssertEqual(links.count, 2)
        XCTAssertTrue(links.contains { $0.targetID == "c1" && $0.linkQuality == 4 })
        XCTAssertTrue(links.contains { $0.targetID == "c2" && $0.linkQuality == 3 })
    }

    func testBuildGraph_borderRouterIsClassified() throws {
        let br = ThreadDevice(name: "BR", manufacturer: "Test", productName: "BR", deviceType: "Bridge", uniqueIdentifier: "br1", isBorderRouter: true)
        let (nodes, _) = MeshTopologyBuilder.buildGraph(from: [br])
        XCTAssertEqual(nodes.count, 1)
        XCTAssertEqual(nodes.first?.kind, .borderRouter)
    }

    func testBuildGraph_linkQualityBoundaries() throws {
        XCTAssertEqual(SignalExtrapolator.coverageScore(for: []), 0.0)
        let good = ThreadDevice(name: "G", manufacturer: "Test", productName: "G", deviceType: "Sensor", uniqueIdentifier: "g", rssi: -40)
        let mid = ThreadDevice(name: "M", manufacturer: "Test", productName: "M", deviceType: "Sensor", uniqueIdentifier: "m", rssi: -70)
        let bad = ThreadDevice(name: "B", manufacturer: "Test", productName: "B", deviceType: "Sensor", uniqueIdentifier: "b", rssi: -90)
        XCTAssertGreaterThan(SignalExtrapolator.coverageScore(for: [good]), SignalExtrapolator.coverageScore(for: [mid]))
        XCTAssertGreaterThan(SignalExtrapolator.coverageScore(for: [mid]), SignalExtrapolator.coverageScore(for: [bad]))
    }
}

import XCTest
@testable import ThreadMapper

final class MeshViewModelTests: XCTestTest {
    func testWarnings_noRouters_reportsBorderRouter() throws {
        let devices = [
            ThreadDevice(name: "B", manufacturer: "T", productName: "B", deviceType: "Lightbulb", uniqueIdentifier: "b1", isRouter: false, isBorderRouter: false)
        ]
        let vm = MeshViewModel(context: makeContext(devices: devices))
        XCTAssertTrue(vm.warnings().contains { $0.contains("Border router") })
    }

    func testRouterDensity_filtersByRoom() throws {
        let d1 = ThreadDevice(name: "A", manufacturer: "T", productName: "A", deviceType: "Sensor", uniqueIdentifier: "a", room: "Kitchen", isRouter: true)
        let d2 = ThreadDevice(name: "B", manufacturer: "T", productName: "B", deviceType: "Sensor", uniqueIdentifier: "b", room: "Garage", isRouter: true)
        let vm = MeshViewModel(context: makeContext(devices: [d1, d2]))
        XCTAssertEqual(vm.routerDensity(for: "Kitchen"), 1)
        XCTAssertEqual(vm.routerDensity(), 2)
    }
}
