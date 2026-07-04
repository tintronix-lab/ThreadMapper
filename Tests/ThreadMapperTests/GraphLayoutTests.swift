import XCTest
@testable import ThreadMapper

final class GraphLayoutOnlyTests: XCTestCase {
    func testFruchtermanReingold_emptyNodes_returnsEmpty() throws {
        let result = GraphLayout.fruchtermanReingold(nodes: [], links: [], size: CGSize(width: 100, height: 100))
        XCTAssertTrue(result.isEmpty)
    }

    func testFruchtermanReingold_singleNode_placed() throws {
        let node = MeshNode(id: UUID(), name: "Solo", kind: .borderRouter)
        let result = GraphLayout.fruchtermanReingold(nodes: [node], links: [], size: CGSize(width: 200, height: 200))
        XCTAssertEqual(result.count, 1)
        let pos = result[node.id]!
        XCTAssertGreaterThanOrEqual(pos.x, 20)
        XCTAssertLessThanOrEqual(pos.x, 180)
    }
}
