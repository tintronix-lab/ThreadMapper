import SwiftUI

struct MeshGraphView: View {
    let nodes: [MeshNode]
    let links: [MeshLink]
    let devices: [ThreadDevice]
    let onSelectNode: (MeshNode) -> Void
    let onSelectDevice: (ThreadDevice) -> Void

    @State private var layout: [UUID: CGPoint] = [:]
    @State private var selectedNodeID: UUID?

    var body: some View {
        GeometryReader { geo in
            Canvas { ctx, size in
                drawLinks(ctx: &ctx)
                drawNodes(ctx: &ctx)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { value in
                        if let hit = hitTest(location: value.location) {
                            selectedNodeID = hit.id
                            onSelectNode(hit)
                        }
                    }
            )
            .onAppear { applyForceDirectedLayout(size: geo.size) }
        }
    }

    private func drawLinks(ctx: inout GraphicsContext) {
        for link in links {
            guard let from = layout[link.sourceID], let to = layout[link.targetID] else { continue }
            var path = Path()
            path.move(to: from)
            path.addLine(to: to)
            ctx.stroke(path, with: .color(linkColor(for: link)), style: .init(lineWidth: CGFloat(link.linkQuality)))
        }
    }

    private func drawNodes(ctx: inout GraphicsContext) {
        for node in nodes {
            guard let pos = layout[node.id] else { continue }
            let color: Color = node.kind == .borderRouter ? .blue : .gray
            let radius: CGFloat = (node.kind == .borderRouter ? 16 : 12) + (node.id == selectedNodeID ? 3 : 0)
            ctx.fill(Path(ellipseIn: CGRect(x: pos.x - radius, y: pos.y - radius, width: radius*2, height: radius*2)), with: .color(color))
            ctx.draw(Text(node.name).foregroundStyle(.black).font(.caption), at: CGPoint(x: pos.x, y: pos.y - radius - 6))
        }
    }

    private func hitTest(location: CGPoint) -> MeshNode? {
        nodes.first { node in
            guard let pos = layout[node.id] else { return false }
            let radius: CGFloat = node.kind == .borderRouter ? 16 : 12
            return distance(location, pos) <= radius + 6
        }
    }

    private func linkColor(for link: MeshLink) -> Color {
        switch link.linkQuality {
        case 4: return .green
        case 3: return .mint
        case 2: return .orange
        default: return .red
        }
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = a.x - b.x; let dy = a.y - b.y
        return sqrt(dx*dx + dy*dy)
    }

    private func applyForceDirectedLayout(size: CGSize) {
        guard !nodes.isEmpty else { return }
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

        for _ in 0..<300 {
            var displacements: [UUID: CGPoint] = [:]

            for node in nodes {
                var fx: CGFloat = 0; var fy: CGFloat = 0
                for other in nodes where other.id != node.id {
                    guard let o = positions[other.id], let s = positions[node.id] else { continue }
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
                displacements[link.sourceID, default: .zero] = CGPoint(x: displacements[link.sourceID, default: .zero].x - dirX*force*0.5, y: displacements[link.sourceID, default: .zero].y - dirY*force*0.5)
                displacements[link.targetID, default: .zero] = CGPoint(x: displacements[link.targetID, default: .zero].x + dirX*force*0.5, y: displacements[link.targetID, default: .zero].y + dirY*force*0.5)
            }

            for node in nodes {
                guard let pos = positions[node.id], let disp = displacements[node.id] else { continue }
                let mag = sqrt(disp.x*disp.x + disp.y*disp.y)
                if mag > 0 {
                    let limitedX = (disp.x/mag)*min(mag, temp)
                    let limitedY = (disp.y/mag)*min(mag, temp)
                    var newPos = CGPoint(x: pos.x + limitedX, y: pos.y + limitedY)
                    newPos.x = max(20, min(size.width - 20, newPos.x))
                    newPos.y = max(20, min(size.height - 20, newPos.y))
                    positions[node.id] = newPos
                }
            }

            temp *= cooling
        }

        layout = positions
    }
}
