import Foundation

struct MeshTopologyBuilder {
    static func buildGraph(from devices: [ThreadDevice]) -> ([MeshNode], [MeshLink]) {
        var nodes: [MeshNode] = []
        var links: [MeshLink] = []

        let borderRouterID = devices.first { $0.isBorderRouter }?.id

        for device in devices {
            let kind: MeshNodeKind = {
                if device.isBorderRouter { return .borderRouter }
                if device.isRouter { return .router }
                return .endDevice
            }()
            nodes.append(MeshNode(
                id: device.id,
                name: device.name,
                kind: kind,
                deviceID: device.id,
                room: device.room,
                channel: device.channel
            ))

            if !device.isBorderRouter, let parentID = borderRouterID {
                links.append(MeshLink(
                    sourceID: parentID,
                    targetID: device.id,
                    linkQuality: device.rssi?.rssiLinkQuality ?? 2
                ))
            }
        }

        return (nodes, links)
    }
}
