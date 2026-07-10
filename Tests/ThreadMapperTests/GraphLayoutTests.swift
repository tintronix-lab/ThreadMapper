import XCTest
@testable import ThreadMapper

final class GraphLayoutOnlyTests: XCTestCase {
    func testHierarchical_emptyNodes_returnsEmpty() throws {
        let result = GraphLayout.hierarchical(nodes: [], size: CGSize(width: 100, height: 100))
        XCTAssertTrue(result.isEmpty)
    }

    func testHierarchical_singleNode_placed() throws {
        let node = MeshNode(id: UUID(), name: "Solo", kind: .borderRouter)
        let result = GraphLayout.hierarchical(nodes: [node], size: CGSize(width: 200, height: 200))
        XCTAssertEqual(result.count, 1)
        XCTAssertNotNil(result[node.id])
    }
}
