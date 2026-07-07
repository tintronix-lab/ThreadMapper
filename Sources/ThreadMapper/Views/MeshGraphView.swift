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

    private var nodesByID: [UUID: MeshNode] { Dictionary(nodes.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a }) }

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

    // MARK: - Selection HUD (device details + inferred route to the internet)

    private func makeSelectedHUD() -> AnyView? {
        guard let selectedNodeID, let node = nodesByID[selectedNodeID] else { return nil }
        let device = devices.first { $0.id == node.deviceID }
        return AnyView(
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(color(for: node, device: device))
                        .frame(width: 8, height: 8)
                    Text(node.name)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    Spacer()
                    Text(node.kind.rawValue)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }

                if let device {
                    HStack(spacing: 12) {
                        if let rssi = device.rssi {
                            // H4: quality label, not raw dBm (values are latency-estimated)
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

                // The whole point of the tab: show the inferred upstream route.
                if let route = routeDescription(from: node) {
                    Label(route, systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        )
    }

    /// Human-readable route from a node up to the internet, naming each hop and
    /// flagging when it relays through another Matter device.
    private func routeDescription(from node: MeshNode) -> String? {
        let path = pathToRoot(from: node.id)
        guard path.count > 1 else {
            return node.kind == .gateway ? "Wi-Fi / internet uplink" : nil
        }
        let names = path.map { hop -> String in
            switch hop.kind {
            case .gateway:      return "Internet"
            case .borderRouter: return "\(hop.name) (border router)"
            case .router:       return "\(hop.name) (relay)"
            case .endDevice:    return hop.name
            }
        }
        let hops = path.filter { $0.kind == .router }.count
        let via = hops > 0 ? " · via \(hops) relay\(hops == 1 ? "" : "s")" : " · direct"
        return "Route: " + names.joined(separator: " → ") + via
    }

    /// Node chain from `id` up through parents to the gateway (bounded).
    private func pathToRoot(from id: UUID) -> [MeshNode] {
        var result: [MeshNode] = []
        var current: UUID? = id
        var guardCount = 0
        while let cur = current, let node = nodesByID[cur], guardCount < 32 {
            result.append(node)
            current = node.parentID
            guardCount += 1
        }
        return result
    }

    private var highlightedNodeIDs: Set<UUID> {
        guard let selectedNodeID, let node = nodesByID[selectedNodeID] else { return [] }
        return Set(pathToRoot(from: node.id).map(\.id))
    }

    // MARK: - Legend

    @ViewBuilder private var legendView: some View {
        VStack(alignment: .leading, spacing: 3) {
            legendItem(symbol: "wifi", color: .secondary, label: "Internet / Wi-Fi")
            legendItem(dotColor: .blue, ring: true, label: "Border router")
            legendItem(dotColor: .indigo, ring: true, label: "Mesh router (relays)")
            legendItem(dotColor: .green, ring: false, label: "Device")
            legendItem(dotColor: .green, ring: false, battery: true, label: "Battery device")
            Divider().padding(.vertical, 1)
            Text("Estimated paths — HomeKit\ndoesn't report Thread routing")
                .font(.system(size: 8))
                .foregroundStyle(.tertiary)
                .italic()
                .fixedSize(horizontal: false, vertical: true)
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

    @ViewBuilder
    private func legendItem(symbol: String? = nil, dotColor: Color? = nil,
                            ring: Bool = false, battery: Bool = false,
                            color: Color = .secondary, label: String) -> some View {
        HStack(spacing: 4) {
            ZStack {
                if let symbol {
                    Image(systemName: symbol).font(.system(size: 8)).foregroundStyle(color)
                } else if let dotColor {
                    if battery {
                        Circle().stroke(Color.green, lineWidth: 1.5).frame(width: 8, height: 8)
                    } else if ring {
                        Circle().stroke(dotColor, lineWidth: 1.5).frame(width: 8, height: 8)
                    } else {
                        Circle().fill(dotColor).frame(width: 7, height: 7)
                    }
                }
            }
            .frame(width: 10)
            Text(label).font(.system(size: 10)).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Layout
extension MeshGraphView {
    private func applyLayout(size: CGSize) {
        guard !nodes.isEmpty, size.width > 80, size.height > 80 else { return }
        layout = GraphLayout.hierarchical(nodes: nodes, size: size)
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

    private func nodeRadius(_ kind: MeshNodeKind) -> CGFloat {
        switch kind {
        case .gateway:      return 15
        case .borderRouter: return 13
        case .router:       return 10
        case .endDevice:    return 8
        }
    }

    // H11: SpatialTapGesture reports location in visual (post-scaleEffect) space.
    // scaleEffect anchors at the view's center, so we must invert that transform
    // to get the canvas-space coordinate for hit testing.
    private func handleTap(at location: CGPoint) {
        guard viewSize.width > 0, viewSize.height > 0 else { return }
        let cx = viewSize.width  / 2
        let cy = viewSize.height / 2
        let canvasX = (location.x - cx) / scale + cx - offset.width
        let canvasY = (location.y - cy) / scale + cy - offset.height

        if let hit = nodes.first(where: { node in
            guard let pos = layout[node.id] else { return false }
            return distance(CGPoint(x: canvasX, y: canvasY), pos) <= nodeRadius(node.kind) + 10
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
        let highlight = highlightedNodeIDs
        let hasSelection = !highlight.isEmpty
        for link in links {
            guard let sourcePos = layout[link.sourceID],
                  let targetPos = layout[link.targetID] else { continue }
            let onPath = highlight.contains(link.sourceID) && highlight.contains(link.targetID)

            var path = Path()
            path.move(to: sourcePos)
            path.addLine(to: targetPos)

            let base = link.kind == .backbone ? Color.secondary : linkColor(for: link)
            let color = hasSelection ? (onPath ? Color.accentColor : base.opacity(0.18)) : base
            let width = onPath ? 3.0 : max(1, CGFloat(link.linkQuality) * 1.1)
            let dash: [CGFloat] = link.kind == .backbone ? [4, 3] : []

            ctx.stroke(path, with: .color(color),
                       style: .init(lineWidth: width, lineCap: .round, dash: dash))
        }
    }

    private func drawNodes(ctx: inout GraphicsContext) {
        let highlight = highlightedNodeIDs
        let hasSelection = !highlight.isEmpty
        for node in nodes {
            guard let pos = layout[node.id] else { continue }
            let device = devices.first { $0.id == node.deviceID }
            let isSelected = node.id == selectedNodeID
            let dimmed = hasSelection && !highlight.contains(node.id)
            let radius = nodeRadius(node.kind) + (isSelected ? 2 : 0)
            let fill = color(for: node, device: device).opacity(dimmed ? 0.3 : 1)

            switch node.kind {
            case .gateway:
                // Rounded square with a Wi-Fi glyph.
                let rect = CGRect(x: pos.x - radius, y: pos.y - radius, width: radius * 2, height: radius * 2)
                ctx.fill(Path(roundedRect: rect, cornerRadius: 5), with: .color(Color(UIColor.systemGray)))
                let icon = ctx.resolve(Text("\(Image(systemName: "wifi"))")
                    .foregroundStyle(.white)
                    .font(.system(size: radius)))
                ctx.draw(icon, at: pos)

            case .borderRouter:
                ctx.fill(circle(pos, radius), with: .color(fill))
                ctx.stroke(circle(pos, radius - 4), with: .color(.white.opacity(dimmed ? 0.3 : 0.9)), lineWidth: 1.5)

            case .router:
                // Ring style signals "relay".
                ctx.fill(circle(pos, radius), with: .color(fill.opacity(dimmed ? 0.15 : 0.25)))
                ctx.stroke(circle(pos, radius), with: .color(fill), lineWidth: 2.5)

            case .endDevice:
                if node.isBattery {
                    ctx.fill(circle(pos, radius - 2), with: .color(fill))
                    ctx.stroke(circle(pos, radius), with: .color(.green.opacity(dimmed ? 0.3 : 0.9)), lineWidth: 1.5)
                } else {
                    ctx.fill(circle(pos, radius), with: .color(fill))
                }
            }

            // Selection ring
            if isSelected {
                ctx.stroke(circle(pos, radius + 3), with: .color(.accentColor), lineWidth: 2)
            }

            // Weak-signal ring
            if let rssi = device?.rssi, rssi < -80, !dimmed {
                ctx.stroke(circle(pos, radius + 5), with: .color(.red.opacity(0.55)), lineWidth: 1.5)
            }

            // Label
            let label = ctx.resolve(Text(node.name)
                .foregroundStyle(Color(UIColor.label).opacity(dimmed ? 0.4 : 1))
                .font(.system(size: 9)))
            ctx.draw(label, at: CGPoint(x: pos.x, y: pos.y - radius - 7))
        }
    }

    private func circle(_ center: CGPoint, _ r: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
    }

    private func color(for node: MeshNode, device: ThreadDevice?) -> Color {
        switch node.kind {
        case .gateway:      return Color(UIColor.systemGray)
        case .borderRouter: return .blue
        case .router:       return device?.rssi.rssiColor ?? .indigo
        case .endDevice:    return device?.rssi.rssiColor ?? .gray
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
