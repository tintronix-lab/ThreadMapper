import Foundation

struct GraphLayout {
    static func fruchtermanReingold(
        nodes: [MeshNode],
        links: [MeshLink],
        size: CGSize,
        iterations: Int = 300
    ) -> [UUID: CGPoint] {
        guard !nodes.isEmpty else { return [:] }

        var positions: [UUID: CGPoint] = [:]
        for node in nodes {
            positions[node.id] = CGPoint(
                x: CGFloat.random(in: 40...(size.width - 40)),
                y: CGFloat.random(in: 40...(size.height - 40))
            )
        }

        let area = size.width * size.height
        let k = sqrt(area / CGFloat(nodes.count))
        var temp: CGFloat = 0.1
        let cooling: CGFloat = 0.995

        for _ in 0..<iterations {
            var displacements: [UUID: CGPoint] = [:]

            for node in nodes {
                var disp = CGPoint.zero
                for other in nodes where other.id != node.id {
                    let delta = positions[node.id]! - positions[other.id]!
                    let dist = max(sqrt(delta.x * delta.x + delta.y * delta.y), 0.1)
                    disp += (delta / dist) * (k * k / dist)
                }
                displacements[node.id] = disp
            }

            for link in links {
                guard let a = positions[link.sourceID],
                      let b = positions[link.targetID] else { continue }
                let delta = a - b
                let dist = max(sqrt(delta.x * delta.x + delta.y * delta.y), 0.1)
                let force = (dist * dist) / k
                let dir = delta / dist
                displacements[link.sourceID, default: .zero] -= dir * force * 0.5
                displacements[link.targetID, default: .zero] += dir * force * 0.5
            }

            for node in nodes {
                let disp = displacements[node.id, default: .zero]
                let mag = sqrt(disp.x * disp.x + disp.y * disp.y)
                if mag > 0 {
                    let limited = disp / mag * min(mag, temp)
                    var newPos = positions[node.id]! + limited
                    newPos.x = max(20, min(size.width - 20, newPos.x))
                    newPos.y = max(20, min(size.height - 20, newPos.y))
                    positions[node.id] = newPos
                }
            }
            temp *= cooling
        }

        return positions
    }
}
