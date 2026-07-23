@testable import ThreadMapper
import XCTest

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

    // MARK: byRoom

    func testByRoom_emptyNodes_returnsEmpty() throws {
        let (positions, bounds) = GraphLayout.byRoom(nodes: [], size: CGSize(width: 400, height: 800))
        XCTAssertTrue(positions.isEmpty)
        XCTAssertTrue(bounds.isEmpty)
    }

    func testByRoom_placesEveryNodeAndBuildsRoomCards() throws {
        let nodes = [
            MeshNode(id: UUID(), name: "Internet", kind: .gateway),
            MeshNode(id: UUID(), name: "A", kind: .router, room: "Kitchen"),
            MeshNode(id: UUID(), name: "B", kind: .endDevice, room: "Kitchen"),
            MeshNode(id: UUID(), name: "C", kind: .endDevice, room: "Bedroom"),
        ]
        let (positions, bounds) = GraphLayout.byRoom(nodes: nodes, size: CGSize(width: 400, height: 800))
        XCTAssertEqual(positions.count, nodes.count)   // gateway + 3 devices all placed
        XCTAssertNotNil(bounds["Kitchen"])
        XCTAssertNotNil(bounds["Bedroom"])
    }

    func testByRoom_roomCardsDoNotOverlap() throws {
        let nodes = [
            MeshNode(id: UUID(), name: "A", kind: .endDevice, room: "Kitchen"),
            MeshNode(id: UUID(), name: "B", kind: .endDevice, room: "Bedroom"),
            MeshNode(id: UUID(), name: "C", kind: .endDevice, room: "Garage"),
        ]
        let (_, bounds) = GraphLayout.byRoom(nodes: nodes, size: CGSize(width: 400, height: 800))
        let rects = Array(bounds.values)
        for i in 0..<rects.count {
            for j in (i + 1)..<rects.count {
                XCTAssertFalse(rects[i].intersects(rects[j]), "room cards must never overlap")
            }
        }
    }
}
