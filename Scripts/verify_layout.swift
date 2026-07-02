import Foundation

let nodeA = MeshNode(name: "A", kind: .router)
let nodeB = MeshNode(name: "B", kind: .router)
let link = MeshLink(sourceID: nodeA.id, targetID: nodeB.id)
let layout = GraphLayout.fruchtermanReingold(nodes: [nodeA, nodeB], links: [link], size: CGSize(width: 300, height: 300))
let posA = layout[nodeA.id]!
let posB = layout[nodeB.id]!
let dist = sqrt(pow(posA.x - posB.x, 2) + pow(posA.y - posB.y, 2))
print("distance: \(dist)")
assert(dist > 5, "nodes should not collide")
