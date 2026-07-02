import XCTest
@testable import ThreadMapper

final class GraphLayoutTests: XCTestCase {
    func testFruchtermanReingold_emptyNodes_returnsEmpty() throws {
        let result = GraphLayout.fruchtermanReingold(nodes: [], links: [], size: CGSize(width: 100, height: 100))
        XCTAssertTrue(result.isEmpty)
    }

    func testFruchtermanReingold_singleNode_placed() throws {
        let node = MeshNode(name: "Solo", kind: .borderRouter)
        let result = GraphLayout.fruchtermanReingold(nodes: [node], links: [], size: CGSize(width: 200, height: 200))
        XCTAssertEqual(result.count, 1)
        let pos = result[node.id]!
        XCTAssertGreaterThanOrEqual(pos.x, 20)
        XCTAssertLessThanOrEqual(pos.x, 180)
    }

    func testFruchtermanReingold_twoNodes_doNotCollide() throws {
        let a = MeshNode(name: "A", kind: .router)
        let b = MeshNode(name: "B", kind: .router)
        let link = MeshLink(sourceID: a.id.uuidString, targetID: b.id.uuidString)
        let result = GraphLayout.fruchtermanReingold(nodes: [a, b], links: [link], size: CGSize(width: 300, height: 300))
        let posA = result[a.id]!
        let posB = result[b.id]!
        let dx = posA.x - posB.x
        let dy = posA.y - posB.y
        XCTAssertGreaterThan(sqrt(dx*dx + dy*dy), 5)
    }
}
