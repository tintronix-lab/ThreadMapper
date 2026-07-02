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
            var displacements: [UUID: (dx: CGFloat, dy: CGFloat)] = [:]

            for node in nodes {
                guard let s = positions[node.id] else { continue }
                var fx: CGFloat = 0; var fy: CGFloat = 0
                for other in nodes where other.id != node.id {
                    guard let o = positions[other.id] else { continue }
                    let dx = s.x - o.x; let dy = s.y - o.y
                    let dist = max(sqrt(dx*dx + dy*dy), 0.1)
                    let f = (k*k)/dist
                    fx += (dx/dist)*f
                    fy += (dy/dist)*f
                }
                displacements[node.id] = (fx, fy)
            }

            for link in links {
                guard let a = positions[link.sourceID], let b = positions[link.targetID] else { continue }
                let dx = a.x - b.x; let dy = a.y - b.y
                let dist = max(sqrt(dx*dx + dy*dy), 0.1)
                let force = (dist*dist)/k
                let dirX = dx/dist; let dirY = dy/dist

                let src = displacements[link.sourceID, default: (0,0)]
                let dst = displacements[link.targetID, default: (0,0)]
                displacements[link.sourceID] = (src.dx - dirX*force*0.5, src.dy - dirY*force*0.5)
                displacements[link.targetID] = (dst.dx + dirX*force*0.5, dst.dy + dirY*force*0.5)
            }

            for node in nodes {
                guard let pos = positions[node.id], let disp = displacements[node.id] else { continue }
                let mag = sqrt(disp.dx*disp.dx + disp.dy*disp.dy)
                if mag > 0 {
                    let limitedX = (disp.dx/mag)*min(mag, temp)
                    let limitedY = (disp.dy/mag)*min(mag, temp)
                    var newPos = CGPoint(x: pos.x + limitedX, y: pos.y + limitedY)
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
