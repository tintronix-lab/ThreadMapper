import Foundation

struct GraphLayout {
    static func fruchtermanReingold(
        nodes: [MeshNode],
        links: [MeshLink],
        size: CGSize,
        iterations: Int = 300
    ) -> [UUID: CGPoint] {
        guard !nodes.isEmpty, size.width > 1, size.height > 1 else { return [:] }

        let safeW = max(size.width, 100)
        let safeH = max(size.height, 100)
        let margin: CGFloat = min(40, safeW * 0.2, safeH * 0.2)

        var positions: [UUID: CGPoint] = [:]
        for node in nodes {
            positions[node.id] = CGPoint(
                x: CGFloat.random(in: margin...(safeW - margin)),
                y: CGFloat.random(in: margin...(safeH - margin))
            )
        }

        let area = safeW * safeH
        let k = sqrt(area / CGFloat(nodes.count))
        var temp: CGFloat = 0.1
        let cooling: CGFloat = 0.995

        for _ in 0..<iterations {
            var displacements: [UUID: CGPoint] = [:]

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
                displacements[node.id] = CGPoint(x: fx, y: fy)
            }

            for link in links {
                guard let a = positions[link.sourceID], let b = positions[link.targetID] else { continue }
                let dx = a.x - b.x; let dy = a.y - b.y
                let dist = max(sqrt(dx*dx + dy*dy), 0.1)
                let force = (dist*dist)/k
                let dirX = dx/dist; let dirY = dy/dist

                displacements[link.sourceID, default: .zero].x -= dirX*force*0.5
                displacements[link.sourceID, default: .zero].y -= dirY*force*0.5
                displacements[link.targetID, default: .zero].x += dirX*force*0.5
                displacements[link.targetID, default: .zero].y += dirY*force*0.5
            }

            for node in nodes {
                guard let pos = positions[node.id], let disp = displacements[node.id] else { continue }
                let mag = sqrt(disp.x*disp.x + disp.y*disp.y)
                if mag > 0 {
                    let limitedX = (disp.x/mag)*min(mag, temp)
                    let limitedY = (disp.y/mag)*min(mag, temp)
                    var newPos = CGPoint(x: pos.x + limitedX, y: pos.y + limitedY)
                    newPos.x = max(margin, min(safeW - margin, newPos.x))
                    newPos.y = max(margin, min(safeH - margin, newPos.y))
                    positions[node.id] = newPos
                }
            }

            temp *= cooling
        }

        return positions
    }
}
