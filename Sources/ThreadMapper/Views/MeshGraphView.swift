import SwiftUI

struct MeshGraphView: View {
    let nodes: [MeshNode]
    let links: [MeshLink]
    let devices: [ThreadDevice]
    let onSelectNode: (MeshNode) -> Void
    let onSelectDevice: (ThreadDevice?) -> Void

    @State private var layout: [UUID: CGPoint] = [:]
    @State private var selectedNodeID: UUID?
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastDragOffset: CGSize = .zero
    @State private var viewSize: CGSize = .zero   // needed to invert scaleEffect in hit-testing

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()

                if let hud = makeSelectedHUD() {
                    hud
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .zIndex(10)
                }

                Canvas { ctx, _ in
                    ctx.translateBy(x: offset.width, y: offset.height)
                    drawLinks(ctx: &ctx)
                    drawNodes(ctx: &ctx)
                }
                .scaleEffect(scale)
                // Divide translation by scale so pan speed is constant at any zoom level.
                .gesture(
                    DragGesture(minimumDistance: 8)
                        .onChanged { value in
                            offset = CGSize(
                                width:  value.translation.width  / scale + lastDragOffset.width,
                                height: value.translation.height / scale + lastDragOffset.height
                            )
                        }
                        .onEnded { value in
                            lastDragOffset = CGSize(
                                width:  value.translation.width  / scale + lastDragOffset.width,
                                height: value.translation.height / scale + lastDragOffset.height
                            )
                        }
                )
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in scale = max(0.4, min(4.0, value)) }
                        .onEnded { _ in
                            if scale < 0.9 || scale > 2.6 {
                                withAnimation(.spring(.bouncy)) {
                                    scale = min(max(scale, 0.9), 2.6)
                                }
                            }
                        }
                )
                // SpatialTapGesture (iOS 17+) gives location in visual (post-scaleEffect) space.
                .simultaneousGesture(
                    SpatialTapGesture()
                        .onEnded { value in
                            handleTap(at: value.location)
                        }
                )
                .overlay(alignment: .center) {
                    if nodes.isEmpty { emptyState }
                }

                HStack(alignment: .bottom) {
                    legendView.padding(10)
                    Spacer()
                    fitResetButton(size: size).padding(12)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
            .onAppear {
                viewSize = size
                if !nodes.isEmpty {
                    applyLayout(size: size)
                }
            }
            .onChange(of: nodes) { _, _ in
                guard !nodes.isEmpty else { return }
                applyLayout(size: size)
            }
            .onChange(of: size) { _, newSize in
                viewSize = newSize
                guard !nodes.isEmpty, layout.isEmpty else { return }
                applyLayout(size: newSize)
            }
        }
    }

    @ViewBuilder private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "network.slash")
                .font(.system(size: 26))
                .foregroundStyle(.secondary)
            Text("No Thread devices")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Add Thread accessories in the Home app,\nthen tap Scan.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(16)
    }

    private func makeSelectedHUD() -> AnyView? {
        guard let selectedNodeID,
              let node = nodes.first(where: { $0.id == selectedNodeID }),
              let device = devices.first(where: { $0.id == node.deviceID }) else { return nil }
        return AnyView(
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(node.kind == .borderRouter ? Color.blue : device.rssi.rssiColor)
                        .frame(width: 8, height: 8)
                    Text(device.name)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    Spacer()
                    Text(node.kind.rawValue)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 12) {
                    if let rssi = device.rssi {
                        // H4: show quality label, not raw dBm (values are latency-estimated)
                        Label("\(rssi.rssiQualityLabel) (est.)", systemImage: rssi.rssiSystemIcon)
                            .foregroundStyle(rssi.rssiColor)
                    } else {
                        Label("No Signal", systemImage: "wifi.slash")
                            .foregroundStyle(.secondary)
                    }
                    if let room = device.room {
                        Label(room, systemImage: "house")
                    }
                    if let ch = device.channel {
                        Label("CH \(ch)", systemImage: "wave.3.right")
                    }
                }
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        )
    }

    @ViewBuilder private var legendView: some View {
        VStack(alignment: .leading, spacing: 3) {
            legendItem(color: .blue,   label: "Border Router")
            legendItem(color: .green,  label: "Strong")
            legendItem(color: .orange, label: "Fair")
            legendItem(color: .red,    label: "Weak")
            Divider().padding(.vertical, 1)
            // H5: make clear this is an estimated star topology, not real mesh links
            Text("Estimated topology")
                .font(.system(size: 8))
                .foregroundStyle(.tertiary)
                .italic()
        }
        .padding(7)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func fitResetButton(size: CGSize) -> some View {
        Button { fitToView(size: size) } label: {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 10))
                .padding(6)
                .background(.ultraThinMaterial, in: Circle())
        }
        .accessibilityLabel("Fit graph to view")
    }

    @ViewBuilder private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label).font(.system(size: 10)).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Layout
extension MeshGraphView {
    private func applyLayout(size: CGSize) {
        guard !nodes.isEmpty, size.width > 80, size.height > 80 else { return }
        layout = GraphLayout.fruchtermanReingold(nodes: nodes, links: links, size: size)
        selectedNodeID = nil
        fitToView(size: size)
    }

    private func fitToView(size: CGSize) {
        guard let minX = layout.values.map(\.x).min(),
              let maxX = layout.values.map(\.x).max(),
              let minY = layout.values.map(\.y).min(),
              let maxY = layout.values.map(\.y).max() else { return }

        let graphWidth  = max(maxX - minX, 1)
        let graphHeight = max(maxY - minY, 1)
        let padding: CGFloat = 48
        let scaleX = (size.width  - padding * 2) / graphWidth
        let scaleY = (size.height - padding * 2) / graphHeight
        let fitScale = min(scaleX, scaleY, 2.0)
        scale = fitScale
        offset = CGSize(
            width:  size.width  / 2 - ((minX + maxX) / 2) * fitScale,
            height: size.height / 2 - ((minY + maxY) / 2) * fitScale
        )
        lastDragOffset = offset
    }

    // H11: SpatialTapGesture reports location in visual (post-scaleEffect) space.
    // scaleEffect anchors at the view's center, so we must invert that transform
    // to get the canvas-space coordinate for hit testing.
    private func handleTap(at location: CGPoint) {
        guard viewSize.width > 0, viewSize.height > 0 else { return }
        let cx = viewSize.width  / 2
        let cy = viewSize.height / 2
        // Invert scaleEffect: visual → canvas pre-offset → layout position
        let canvasX = (location.x - cx) / scale + cx - offset.width
        let canvasY = (location.y - cy) / scale + cy - offset.height

        if let hit = nodes.first(where: { node in
            guard let pos = layout[node.id] else { return false }
            let radius: CGFloat = node.kind == .borderRouter ? 13 : 9
            return distance(CGPoint(x: canvasX, y: canvasY), pos) <= radius + 10
        }) {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedNodeID = hit.id
            }
            onSelectNode(hit)
            onSelectDevice(devices.first { $0.id == hit.deviceID })
        } else {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedNodeID = nil
            }
            onSelectDevice(nil)
        }
    }
}

// MARK: - Drawing
extension MeshGraphView {
    private func drawLinks(ctx: inout GraphicsContext) {
        for link in links {
            guard let sourcePos = layout[link.sourceID],
                  let targetPos = layout[link.targetID] else { continue }
            var path = Path()
            path.move(to: sourcePos)
            path.addLine(to: targetPos)
            ctx.stroke(
                path,
                with: .color(linkColor(for: link)),
                style: .init(lineWidth: max(1, CGFloat(link.linkQuality) * 1.2), lineCap: .round)
            )
        }
    }

    private func drawNodes(ctx: inout GraphicsContext) {
        for node in nodes {
            guard let pos = layout[node.id] else { continue }
            let baseRadius: CGFloat = node.kind == .borderRouter ? 13 : 9
            let isSelected = node.id == selectedNodeID
            let radius = baseRadius + (isSelected ? 2 : 0)
            let device = devices.first { $0.id == node.deviceID }
            let color: Color = node.kind == .borderRouter ? .blue : (device?.rssi.rssiColor ?? .gray)

            // Node body
            ctx.fill(
                Path(ellipseIn: CGRect(x: pos.x - radius, y: pos.y - radius,
                                       width: radius * 2, height: radius * 2)),
                with: .color(color)
            )

            // Selection ring
            if isSelected {
                ctx.stroke(
                    Path(ellipseIn: CGRect(x: pos.x - radius - 3, y: pos.y - radius - 3,
                                           width: (radius + 3) * 2, height: (radius + 3) * 2)),
                    with: .color(.accentColor),
                    style: .init(lineWidth: 2)
                )
            }

            // Weak device ring
            if let rssi = device?.rssi, rssi < -80 {
                let pr = radius + 5
                ctx.stroke(
                    Path(ellipseIn: CGRect(x: pos.x - pr, y: pos.y - pr,
                                           width: pr * 2, height: pr * 2)),
                    with: .color(.red.opacity(0.55)),
                    style: .init(lineWidth: 1.5)
                )
            }

            // Label
            let label = ctx.resolve(Text(node.name)
                .foregroundStyle(Color(UIColor.label))
                .font(.system(size: 9)))
            ctx.draw(label, at: CGPoint(x: pos.x, y: pos.y - radius - 7))
        }
    }

    private func linkColor(for link: MeshLink) -> Color {
        switch link.linkQuality {
        case 4:  return .green
        case 3:  return .mint
        case 2:  return .orange
        default: return .red
        }
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = a.x - b.x, dy = a.y - b.y
        return sqrt(dx * dx + dy * dy)
    }
}
