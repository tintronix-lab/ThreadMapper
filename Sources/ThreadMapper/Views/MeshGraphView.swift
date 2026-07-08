import SwiftUI

struct MeshGraphView: View {
    let nodes: [MeshNode]
    let links: [MeshLink]
    let devices: [ThreadDevice]
    let onSelectNode: (MeshNode) -> Void
    let onSelectDevice: (ThreadDevice?) -> Void

    @State private var layout: [UUID: CGPoint] = [:]
    @State private var selectedNodeID: UUID?
    // pan is in screen/view space; zoom is applied around view center.
    @State private var scale: CGFloat = 1.0
    @State private var baseScale: CGFloat = 1.0   // accumulated zoom between gestures
    @State private var pan: CGSize = .zero
    @State private var lastPan: CGSize = .zero
    @State private var isDragging = false

    private var nodesByID: [UUID: MeshNode] {
        Dictionary(nodes.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()

                // Canvas handles all transforms internally (no scaleEffect).
                // This avoids Canvas clipping content before the visual scale is applied.
                Canvas { ctx, _ in
                    drawRoomZones(ctx: &ctx, size: size)
                    drawLinks(ctx: &ctx, size: size)
                    drawNodes(ctx: &ctx, size: size)
                }
                // Single DragGesture handles both pan (move >= 8pt) and tap (move < 8pt).
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let d = hypot(value.translation.width, value.translation.height)
                            if d >= 8 || isDragging {
                                isDragging = true
                                pan = CGSize(
                                    width:  lastPan.width  + value.translation.width,
                                    height: lastPan.height + value.translation.height
                                )
                            }
                        }
                        .onEnded { value in
                            let d = hypot(value.translation.width, value.translation.height)
                            if !isDragging || d < 8 {
                                handleTap(at: value.startLocation, in: size)
                            } else {
                                lastPan = CGSize(
                                    width:  lastPan.width  + value.translation.width,
                                    height: lastPan.height + value.translation.height
                                )
                            }
                            isDragging = false
                        }
                )
                // Pinch-to-zoom, accumulating scale correctly across multiple gestures.
                .simultaneousGesture(
                    MagnificationGesture()
                        .onChanged { value in
                            scale = max(0.4, min(4.0, baseScale * value))
                        }
                        .onEnded { value in
                            let clamped = max(0.4, min(4.0, baseScale * value))
                            baseScale = clamped
                            scale = clamped
                            if clamped < 0.9 || clamped > 2.6 {
                                withAnimation(.spring(.bouncy)) {
                                    scale = min(max(clamped, 0.9), 2.6)
                                    baseScale = scale
                                }
                            }
                        }
                )
                .overlay(alignment: .center) {
                    if nodes.isEmpty { emptyState }
                }

                // HUD: allowsHitTesting(false) so it never intercepts taps on the canvas.
                if let hud = makeSelectedHUD() {
                    hud
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .allowsHitTesting(false)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .zIndex(10)
                }

                HStack(alignment: .bottom) {
                    legendView.padding(10)
                    Spacer()
                    fitResetButton(size: size).padding(12)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
            .onAppear {
                if !nodes.isEmpty { applyLayout(size: size) }
            }
            .onChange(of: nodes) { _, _ in
                guard !nodes.isEmpty else { return }
                applyLayout(size: size)
            }
            .onChange(of: size) { _, newSize in
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

    // MARK: - Selection HUD

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

// MARK: - Layout & Transform
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
        let newScale = min(scaleX, scaleY, 2.0)

        scale     = newScale
        baseScale = newScale

        // Move the graph center to the view center.
        // screenPos(p) = viewCenter + (p - viewCenter)*scale + pan
        // For screenPos(graphCenter) == viewCenter:  pan = -(graphCenter - viewCenter)*scale
        let cx = size.width / 2, cy = size.height / 2
        let gcx = (minX + maxX) / 2, gcy = (minY + maxY) / 2
        pan = CGSize(
            width:  -(gcx - cx) * newScale,
            height: -(gcy - cy) * newScale
        )
        lastPan = pan
    }

    private func nodeRadius(_ kind: MeshNodeKind) -> CGFloat {
        switch kind {
        case .gateway:      return 17
        case .borderRouter: return 15
        case .router:       return 12
        case .endDevice:    return 10
        }
    }

    /// Layout-space → screen/canvas space.
    private func screenPos(_ p: CGPoint, in size: CGSize) -> CGPoint {
        let cx = size.width / 2, cy = size.height / 2
        return CGPoint(
            x: cx + (p.x - cx) * scale + pan.width,
            y: cy + (p.y - cy) * scale + pan.height
        )
    }

    /// Screen/canvas space → layout space (inverse of screenPos).
    private func toLayout(_ screen: CGPoint, in size: CGSize) -> CGPoint {
        let cx = size.width / 2, cy = size.height / 2
        return CGPoint(
            x: cx + (screen.x - pan.width - cx) / scale,
            y: cy + (screen.y - pan.height - cy) / scale
        )
    }

    private func handleTap(at location: CGPoint, in size: CGSize) {
        let lp = toLayout(location, in: size)
        // Hit radius in layout space: keep ~28pt visual contact area at any zoom level.
        let extraTap: CGFloat = max(14, 28 / scale)
        if let hit = nodes.first(where: { node in
            guard let pos = layout[node.id] else { return false }
            return distance(lp, pos) <= nodeRadius(node.kind) + extraTap
        }) {
            withAnimation(.easeInOut(duration: 0.15)) { selectedNodeID = hit.id }
            onSelectNode(hit)
            onSelectDevice(devices.first { $0.id == hit.deviceID })
        } else {
            withAnimation(.easeInOut(duration: 0.15)) { selectedNodeID = nil }
            onSelectDevice(nil)
        }
    }
}

// MARK: - Drawing
extension MeshGraphView {

    /// Draws a labeled, colored background zone for each room, behind links and nodes.
    private func drawRoomZones(ctx: inout GraphicsContext, size: CGSize) {
        let hPad: CGFloat  = 20   // horizontal padding around the room's nodes
        let vPad: CGFloat  = 18   // bottom / sides padding
        let topPad: CGFloat = 28  // extra top padding to fit the room label above top nodes

        let roomGroups = Dictionary(
            grouping: nodes.filter { $0.room != nil },
            by: { $0.room! }
        )

        for (room, roomNodes) in roomGroups {
            let layoutPositions = roomNodes.compactMap { layout[$0.id] }
            guard !layoutPositions.isEmpty else { continue }

            let sps = layoutPositions.map { screenPos($0, in: size) }
            let minX = sps.map(\.x).min()! - hPad
            let maxX = sps.map(\.x).max()! + hPad
            let minY = sps.map(\.y).min()! - topPad
            let maxY = sps.map(\.y).max()! + vPad

            guard maxX > minX, maxY > minY else { continue }

            let rect = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
            let zoneColor = roomZoneColor(for: room)

            ctx.fill(Path(roundedRect: rect, cornerRadius: 14, style: .continuous),
                     with: .color(zoneColor.opacity(0.07)))
            ctx.stroke(Path(roundedRect: rect, cornerRadius: 14, style: .continuous),
                       with: .color(zoneColor.opacity(0.3)), lineWidth: 1)

            // Room name + device count label centred at the top of the zone.
            let count = roomNodes.count
            let labelText = "\(room)  \(count) device\(count == 1 ? "" : "s")"
            let label = ctx.resolve(
                Text(labelText)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(zoneColor.opacity(0.75))
            )
            ctx.draw(label, at: CGPoint(x: (minX + maxX) / 2, y: minY + 11))
        }
    }

    /// Deterministic per-room colour derived from the room name, spread across 12 hues.
    private func roomZoneColor(for room: String) -> Color {
        let bucket = abs(room.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }) % 12
        let hue = Double(bucket) / 12.0
        return Color(hue: hue, saturation: 0.55, brightness: 0.72)
    }

    private func drawLinks(ctx: inout GraphicsContext, size: CGSize) {
        let highlight = highlightedNodeIDs
        let hasSelection = !highlight.isEmpty
        for link in links {
            guard let srcLayout = layout[link.sourceID],
                  let dstLayout = layout[link.targetID] else { continue }
            let sourcePos = screenPos(srcLayout, in: size)
            let targetPos = screenPos(dstLayout, in: size)
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

    private func drawNodes(ctx: inout GraphicsContext, size: CGSize) {
        let highlight = highlightedNodeIDs
        let hasSelection = !highlight.isEmpty
        for node in nodes {
            guard let layoutP = layout[node.id] else { continue }
            let pos = screenPos(layoutP, in: size)
            let device = devices.first { $0.id == node.deviceID }
            let isSelected = node.id == selectedNodeID
            let dimmed = hasSelection && !highlight.contains(node.id)
            let radius = nodeRadius(node.kind) + (isSelected ? 2 : 0)
            let fill = color(for: node, device: device).opacity(dimmed ? 0.3 : 1)

            switch node.kind {
            case .gateway:
                let rect = CGRect(x: pos.x - radius, y: pos.y - radius,
                                  width: radius * 2, height: radius * 2)
                ctx.fill(Path(roundedRect: rect, cornerRadius: 5),
                         with: .color(Color(UIColor.systemGray)))
                let icon = ctx.resolve(Text("\(Image(systemName: "wifi"))")
                    .foregroundStyle(.white)
                    .font(.system(size: radius)))
                ctx.draw(icon, at: pos)

            case .borderRouter:
                ctx.fill(circle(pos, radius), with: .color(fill))
                ctx.stroke(circle(pos, radius - 4),
                           with: .color(.white.opacity(dimmed ? 0.3 : 0.9)), lineWidth: 1.5)

            case .router:
                ctx.fill(circle(pos, radius), with: .color(fill.opacity(dimmed ? 0.15 : 0.25)))
                ctx.stroke(circle(pos, radius), with: .color(fill), lineWidth: 2.5)

            case .endDevice:
                if node.isBattery {
                    ctx.fill(circle(pos, radius - 2), with: .color(fill))
                    ctx.stroke(circle(pos, radius),
                               with: .color(.green.opacity(dimmed ? 0.3 : 0.9)), lineWidth: 1.5)
                } else {
                    ctx.fill(circle(pos, radius), with: .color(fill))
                }
            }

            if isSelected {
                ctx.stroke(circle(pos, radius + 3), with: .color(.accentColor), lineWidth: 2)
            }

            if let rssi = device?.rssi, rssi < -80, !dimmed {
                ctx.stroke(circle(pos, radius + 5),
                           with: .color(.red.opacity(0.55)), lineWidth: 1.5)
            }

            let displayName = node.name.count > 14 ? String(node.name.prefix(13)) + "…" : node.name
            let label = ctx.resolve(Text(displayName)
                .foregroundStyle(Color(UIColor.label).opacity(dimmed ? 0.35 : 1))
                .font(.system(size: 10, weight: isSelected ? .semibold : .regular)))
            ctx.draw(label, at: CGPoint(x: pos.x, y: pos.y - radius - 8))
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
