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
                // Use minimumDistance: 8 so short taps don't become drags
                .gesture(
                    DragGesture(minimumDistance: 8)
                        .onChanged { value in
                            offset = CGSize(
                                width: value.translation.width + lastDragOffset.width,
                                height: value.translation.height + lastDragOffset.height
                            )
                        }
                        .onEnded { value in
                            lastDragOffset = CGSize(
                                width: value.translation.width + lastDragOffset.width,
                                height: value.translation.height + lastDragOffset.height
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
                // SpatialTapGesture (iOS 17+) gives location and runs simultaneously with drag
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
                if !nodes.isEmpty {
                    applyLayout(size: size)
                }
            }
            // Re-layout whenever node set changes (e.g., scan results arrive after view appears)
            .onChange(of: nodes) { _, _ in
                guard !nodes.isEmpty else { return }
                applyLayout(size: size)
            }
            // Re-layout if size becomes valid after an initial zero-size pass
            .onChange(of: size) { _, newSize in
                guard !nodes.isEmpty, layout.isEmpty else { return }
                applyLayout(size: newSize)
            }
        }
    }

    @ViewBuilder private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "network.slash")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("No Thread devices")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Add Thread accessories in the Home app,\nthen tap Scan.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
    }

    private func makeSelectedHUD() -> AnyView? {
        guard let selectedNodeID,
              let node = nodes.first(where: { $0.id == selectedNodeID }),
              let device = devices.first(where: { $0.id == node.deviceID }) else { return nil }
        return AnyView(
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Circle()
                        .fill(node.kind == .borderRouter ? Color.blue : device.rssi.rssiColor)
                        .frame(width: 12, height: 12)
                    Text(device.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Spacer()
                    Text(node.kind.rawValue)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 16) {
                    if let rssi = device.rssi {
                        Label("\(rssi) dBm", systemImage: rssi.rssiSystemIcon)
                            .foregroundStyle(rssi.rssiColor)
                    } else {
                        Label("No RSSI", systemImage: "wifi.slash")
                            .foregroundStyle(.secondary)
                    }
                    if let room = device.room {
                        Label(room, systemImage: "house")
                    }
                    if let ch = device.channel {
                        Label("CH \(ch)", systemImage: "wave.3.right")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        )
    }

    @ViewBuilder private var legendView: some View {
        VStack(alignment: .leading, spacing: 5) {
            legendItem(color: .blue,   label: "Border Router")
            legendItem(color: .green,  label: "Strong signal")
            legendItem(color: .orange, label: "Fair signal")
            legendItem(color: .red,    label: "Weak signal")
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func fitResetButton(size: CGSize) -> some View {
        Button { fitToView(size: size) } label: {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.caption2)
                .padding(8)
                .background(.ultraThinMaterial, in: Circle())
        }
        .accessibilityLabel("Fit graph to view")
    }

    @ViewBuilder private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 9, height: 9)
            Text(label).font(.caption2).foregroundStyle(.secondary)
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

    private func handleTap(at location: CGPoint) {
        // Invert the canvas transform: canvas draws at (layoutPos + offset), then scaleEffect(scale)
        // scaleEffect scales from view center, but for hit testing SwiftUI reports location in
        // the view's local (pre-scale) coordinate space. Adjust for offset only.
        let canvasX = location.x - offset.width
        let canvasY = location.y - offset.height

        if let hit = nodes.first(where: { node in
            guard let pos = layout[node.id] else { return false }
            let radius: CGFloat = node.kind == .borderRouter ? 18 : 13
            return distance(CGPoint(x: canvasX, y: canvasY), pos) <= (radius + 12) / scale
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
            let baseRadius: CGFloat = node.kind == .borderRouter ? 18 : 13
            let isSelected = node.id == selectedNodeID
            let radius = baseRadius + (isSelected ? 3 : 0)
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
                    Path(ellipseIn: CGRect(x: pos.x - radius - 4, y: pos.y - radius - 4,
                                           width: (radius + 4) * 2, height: (radius + 4) * 2)),
                    with: .color(.accentColor),
                    style: .init(lineWidth: 2.5)
                )
            }

            // Weak device ring (static, no animation to avoid state-update cycles)
            if let rssi = device?.rssi, rssi < -80 {
                let pr = radius + 8
                ctx.stroke(
                    Path(ellipseIn: CGRect(x: pos.x - pr, y: pos.y - pr,
                                           width: pr * 2, height: pr * 2)),
                    with: .color(.red.opacity(0.55)),
                    style: .init(lineWidth: 2)
                )
            }

            // Label
            let label = ctx.resolve(Text(node.name)
                .foregroundStyle(Color(UIColor.label))
                .font(.caption2))
            ctx.draw(label, at: CGPoint(x: pos.x, y: pos.y - radius - 10))
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
