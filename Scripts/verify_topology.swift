import Foundation

let devices = [
    ThreadDevice(name: "Sensor", manufacturer: "Test", productName: "Sensor", deviceType: "Sensor",
                 uniqueIdentifier: UUID(), parentNodeID: "parent", rssi: -60),
    ThreadDevice(name: "Router", manufacturer: "Test", productName: "Router", deviceType: "Router",
                 uniqueIdentifier: UUID(), isRouter: true),
    ThreadDevice(name: "End", manufacturer: "Test", productName: "End", deviceType: "Sensor",
                 uniqueIdentifier: UUID(), parentNodeID: UUID().uuidString, rssi: -75),
]

let (nodes, links) = MeshTopologyBuilder.buildGraph(from: devices)
print("nodes: \(nodes.count), links: \(links.count)")
assert(nodes.count == 1, "expected 1 router node")
assert(links.count == 1, "expected 1 link")
