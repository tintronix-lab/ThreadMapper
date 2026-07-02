import SwiftUI

struct MeshGraphView: View {
    let nodes: [MeshNode]
    let links: [MeshLink]
    let onSelect: (MeshNode) -> Void

    @State private var layout: [UUID: CGPoint] = [:]

    var body: some View {
        Canvas { ctx, size in
            drawLinks(ctx: &ctx, size: size)
            drawNodes(ctx: &ctx)
        }
        .gesture(
            DragGesture()
                .onChanged { _ in /* manual rearrange future */ }
        )
        .task {
            applyForceDirectedLayout(size: CGSize(width: 400, height: 600))
        }
    }

    private func drawLinks(ctx: inout GraphicsContext, size: CGSize) {
        for link in links {
            guard let from = layout[link.sourceID],
                  let to = layout[link.targetID] else { continue }

            var path = Path()
            path.move(to: from)
            path.addLine(to: to)

            ctx.stroke(
                path,
                with: .color(linkColor(for: link)),
                style: .init(lineWidth: CGFloat(link.linkQuality))
            )
        }
    }

    private func drawNodes(ctx: inout GraphicsContext) {
        for node in nodes {
            guard let pos = layout[node.id] else { continue }
            let color: Color = node.kind == .borderRouter ? .blue : .gray
            let radius: CGFloat = node.kind == .borderRouter ? 14 : 10

            ctx.fill(
                Path(ellipseIn: CGRect(x: pos.x - radius, y: pos.y - radius,
                                       width: radius * 2, height: radius * 2)),
                with: .color(color)
            )

            ctx.draw(
                Text(node.name)
                    .foregroundStyle(.black)
                    .font(.caption),
                at: CGPoint(x: pos.x, y: pos.y - radius - 4)
            )
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

        layout = positions
    }
}
