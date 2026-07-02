import Foundation

struct MeshTopologyBuilder {
    static func buildGraph(from devices: [ThreadDevice]) -> ([MeshNode], [MeshLink]) {
        var nodes: [MeshNode] = []
        var links: [MeshLink] = []

        let routers = devices.filter { $0.isRouter || $0.isBorderRouter }
        let ends = devices.filter { !$0.isRouter && !$0.isBorderRouter }

        for device in routers {
            let kind: MeshNodeKind = device.isBorderRouter ? .borderRouter : .router
            nodes.append(MeshNode(name: device.name, kind: kind))
        }

        for device in devices {
            guard let parentID = device.parentNodeID else { continue }
            links.append(MeshLink(
                sourceID: parentID,
                targetID: device.uniqueIdentifier,
                linkQuality: estimateLinkQuality(device)
            ))
        }

        return (nodes, links)
    }

    private static func estimateLinkQuality(_ device: ThreadDevice) -> Int {
        guard let rssi = device.rssi else { return 2 }
        if rssi > -50 { return 4 }
        if rssi > -65 { return 3 }
        if rssi > -80 { return 2 }
        return 1
    }
}
