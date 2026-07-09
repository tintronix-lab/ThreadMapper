import SwiftUI

struct MeshGraphView: View {
    let nodes: [MeshNode]
    let links: [MeshLink]
    let devices: [ThreadDevice]
    let onSelectNode: (MeshNode) -> Void
    let onSelectDevice: (ThreadDevice?) -> Void

    @State private var layout: [UUID: CGPoint] = [:]
    // Explicit room-card bounds (layout-space) produced by GraphLayout.byRoom.
    // Used by drawRoomZones so zones are positioned by the layout algorithm,
    // not inferred from node positions — this guarantees they never overlap.
    @State private var roomBounds: [String: CGRect] = [:]
    @State private var selectedNodeID: UUID?
    // pan is in screen/view space; zoom is applied around view center.
    @State private var scale: CGFloat = 1.0
    @State private var baseScale: CGFloat = 1.0   // accumulated zoom between gestures
    @State private var pan: CGSize = .zero
    @State private var lastPan: CGSize = .zero
    @State private var isDragging = false
    // Tracked via onGeometryChange — reliable inside NavigationStack/sheet contexts
    // where onAppear may fire before the final size is settled.
    @State private var viewSize: CGSize = .zero

    private var nodesByID: [UUID: MeshNode] {
        Dictionary(nodes.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    }

    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()

            // Canvas handles all transforms internally (no scaleEffect).
            Canvas { ctx, _ in
                drawRoomZones(ctx: &ctx, size: viewSize)
                drawLinks(ctx: &ctx, size: viewSize)
                drawNodes(ctx: &ctx, size: viewSize)
            }
            // VoiceOver cannot navigate a Canvas directly. Provide a virtual
            // accessibility tree that mirrors each node as a button so users can
            // navigate the mesh with assistive technology even when the visual
            // canvas is opaque to the accessibility engine.
            .accessibilityLabel("Mesh network map")
            .accessibilityChildren {
                ForEach(nodes) { node in
                    let device = devices.first { $0.id == node.deviceID }
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) { selectedNodeID = node.id }
                        onSelectNode(node)
                        onSelectDevice(device)
                    } label: {
                        Text(node.name)
                    }
                    .accessibilityValue(accessibilityValue(for: node, device: device))
                    .accessibilityHint(accessibilityHint(for: node))
                }
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
                            handleTap(at: value.startLocation, in: viewSize)
                        } else {
                            lastPan = CGSize(
                                width:  lastPan.width  + value.translation.width,
                                height: lastPan.height + value.translation.height
                            )
                        }
                        isDragging = false
                    }
            )
            // Pinch-to-zoom up to 6×. No spring snap-back at the high end so users
            // can hold any zoom level they choose. Only snap back if they over-zoom-out.
            .simultaneousGesture(
                MagnificationGesture()
                    .onChanged { value in
                        scale = max(0.3, min(6.0, baseScale * value))
                    }
                    .onEnded { value in
                        let clamped = max(0.3, min(6.0, baseScale * value))
                        baseScale = clamped
                        scale = clamped
                        if clamped < 0.4 {
                            withAnimation(.spring(.bouncy)) {
                                scale = 0.4; baseScale = 0.4
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
                fitResetButton.padding(12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .allowsHitTesting(true)

            // Hint fades away once the user zooms in enough to see labels
            if scale < 1.2, !nodes.isEmpty {
                Text("Pinch to zoom — labels appear at 1.2×")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.ultraThinMaterial, in: Capsule())
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 52)
                    .allowsHitTesting(false)
            }
        }
        // onGeometryChange (iOS 17+) fires reliably after every layout pass —
        // even inside NavigationStack sheets where onAppear fires before the
        // nav bar has been measured, making geo.size transiently incorrect.
        .onGeometryChange(for: CGSize.self) { $0.size } action: { newSize in
            let wasEmpty = viewSize == .zero
            viewSize = newSize
            guard !nodes.isEmpty, newSize.width > 80, newSize.height > 80 else { return }
            // Always re-layout on first valid size; re-fit on subsequent size changes
            // (e.g. rotation) but don't discard pan/zoom if the user has explored.
            if wasEmpty || layout.isEmpty {
                applyLayout(size: newSize)
            } else {
                fitToView(size: newSize)
            }
        }
        .onChange(of: nodes) { _, _ in
            guard !nodes.isEmpty, viewSize.width > 80, viewSize.height > 80 else { return }
            applyLayout(size: viewSize)
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

    private var fitResetButton: some View {
        Button { fitToView(size: viewSize) } label: {
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
        let (newLayout, newRoomBounds) = GraphLayout.byRoom(nodes: nodes, size: size)
        layout     = newLayout
        roomBounds = newRoomBounds
        selectedNodeID = nil
        fitToView(size: size)
    }

    private func fitToView(size: CGSize) {
        guard !layout.isEmpty,
              let minX = layout.values.map(\.x).min(),
              let maxX = layout.values.map(\.x).max(),
              let minY = layout.values.map(\.y).min(),
              let maxY = layout.values.map(\.y).max() else { return }

        let graphWidth  = max(maxX - minX, 1)
        let graphHeight = max(maxY - minY, 1)
        let padding: CGFloat = 36
        let scaleX = (size.width  - padding * 2) / graphWidth
        let scaleY = (size.height - padding * 2) / graphHeight
        let newScale = min(scaleX, scaleY, 2.0)

        scale     = newScale
        baseScale = newScale

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
        case .gateway:      return 13
        case .borderRouter: return 11
        case .router:       return 9
        case .endDevice:    return 7
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
        // Hit radius in layout space: generous contact area so small nodes are tappable.
        let extraTap: CGFloat = max(12, 28 / scale)
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

    private func drawRoomZones(ctx: inout GraphicsContext, size: CGSize) {
        guard size.width > 0, size.height > 0, !roomBounds.isEmpty else { return }

        for (room, cellRect) in roomBounds {
            // Transform layout-space room rectangle into screen space.
            // screenPos scales each corner around the view centre, so width = cellRect.width * scale.
            let tl = screenPos(cellRect.origin, in: size)
            let br = screenPos(CGPoint(x: cellRect.maxX, y: cellRect.maxY), in: size)
            let screenRect = CGRect(x: tl.x, y: tl.y, width: br.x - tl.x, height: br.y - tl.y)
            guard screenRect.width > 4, screenRect.height > 4 else { continue }

            let zoneColor = roomZoneColor(for: room)
            let path = Path(roundedRect: screenRect, cornerRadius: 12, style: .continuous)

            ctx.fill(path, with: .color(zoneColor.opacity(0.10)))
            ctx.stroke(path, with: .color(zoneColor.opacity(0.50)), lineWidth: 1)

            // Room label always visible — it lives in the header band at the top of each card
            let deviceCount = nodes.filter {
                $0.room == room || (room == "Unassigned" && $0.room == nil)
            }.filter { $0.kind != .gateway }.count
            let labelText = "\(room)  ·  \(deviceCount) device\(deviceCount == 1 ? "" : "s")"
            let label = ctx.resolve(
                Text(labelText)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(zoneColor)
            )
            ctx.draw(label, at: CGPoint(x: screenRect.midX, y: screenRect.minY + 13))
        }
    }

    private func roomZoneColor(for room: String) -> Color {
        let bucket = abs(room.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }) % 12
        let hue = Double(bucket) / 12.0
        return Color(hue: hue, saturation: 0.55, brightness: 0.72)
    }

    private func drawLinks(ctx: inout GraphicsContext, size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        let highlight = highlightedNodeIDs
        let hasSelection = !highlight.isEmpty
        let nodeMap = nodesByID

        for link in links {
            guard let srcLayout = layout[link.sourceID],
                  let dstLayout = layout[link.targetID] else { continue }
            let sourcePos = screenPos(srcLayout, in: size)
            let targetPos = screenPos(dstLayout, in: size)
            let onPath = highlight.contains(link.sourceID) && highlight.contains(link.targetID)

            // Cross-room mesh links arc as quadratic beziers to avoid piercing room cards.
            // Backbone links (gateway → border router) stay straight — they already travel
            // above the card grid and straight lines read clearly.
            let srcRoom = nodeMap[link.sourceID]?.room
            let dstRoom = nodeMap[link.targetID]?.room
            let isCrossRoom = link.kind == .mesh && srcRoom != dstRoom

            var path = Path()
            if isCrossRoom {
                let mid = CGPoint(x: (sourcePos.x + targetPos.x) / 2,
                                  y: (sourcePos.y + targetPos.y) / 2)
                let dx = targetPos.x - sourcePos.x
                let dy = targetPos.y - sourcePos.y
                let len = max(sqrt(dx * dx + dy * dy), 1)
                // Arc height: 35% of chord length, capped so very long links stay readable.
                let arcHeight = min(len * 0.35, 72)
                // Perpendicular unit vector (90° CCW rotation of the chord direction).
                let perpX = -dy / len
                let perpY =  dx / len
                // Choose the side that faces away from the canvas centre so the curve
                // arcs outward and doesn't cut further through adjacent room cards.
                let cx = size.width / 2, cy = size.height / 2
                let dot = perpX * (mid.x - cx) + perpY * (mid.y - cy)
                let sign: CGFloat = dot >= 0 ? 1 : -1
                let ctrl = CGPoint(x: mid.x + perpX * arcHeight * sign,
                                   y: mid.y + perpY * arcHeight * sign)
                path.move(to: sourcePos)
                path.addQuadCurve(to: targetPos, control: ctrl)
            } else {
                path.move(to: sourcePos)
                path.addLine(to: targetPos)
            }

            let base = link.kind == .backbone ? Color.secondary : linkColor(for: link)
            let color = hasSelection ? (onPath ? Color.accentColor : base.opacity(0.18)) : base
            let width = onPath ? 2.0 : max(0.8, CGFloat(link.linkQuality) * 0.5)
            let dash: [CGFloat] = link.kind == .backbone ? [3, 2] : []

            ctx.stroke(path, with: .color(color),
                       style: .init(lineWidth: width, lineCap: .round, dash: dash))
        }
    }

    private func drawNodes(ctx: inout GraphicsContext, size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
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
                ctx.stroke(circle(pos, radius - 3),
                           with: .color(.white.opacity(dimmed ? 0.3 : 0.85)), lineWidth: 1.5)

            case .router:
                ctx.fill(circle(pos, radius), with: .color(fill.opacity(dimmed ? 0.15 : 0.25)))
                ctx.stroke(circle(pos, radius), with: .color(fill), lineWidth: 2)

            case .endDevice:
                if node.isBattery {
                    ctx.fill(circle(pos, max(2, radius - 2)), with: .color(fill))
                    ctx.stroke(circle(pos, radius),
                               with: .color(.green.opacity(dimmed ? 0.3 : 0.85)), lineWidth: 1.5)
                } else {
                    ctx.fill(circle(pos, radius), with: .color(fill))
                }
            }

            if isSelected {
                ctx.stroke(circle(pos, radius + 3), with: .color(.accentColor), lineWidth: 1.5)
            }

            if let rssi = device?.rssi, rssi < -80, !dimmed {
                ctx.stroke(circle(pos, radius + 3),
                           with: .color(.red.opacity(0.55)), lineWidth: 1)
            }

            // Labels visible only when zoomed in enough that they don't crowd each other.
            // At overview scale (<1.2×) the hint overlay tells users to pinch to zoom.
            let showLabel = scale >= 1.2 || isSelected || (hasSelection && highlight.contains(node.id))
            if showLabel {
                let maxChars: Int
                if isSelected        { maxChars = 18 }
                else if scale >= 2.5 { maxChars = 16 }
                else if scale >= 1.8 { maxChars = 11 }
                else                 { maxChars = 7  }

                let displayName = node.name.count > maxChars
                    ? String(node.name.prefix(maxChars - 1)) + "…"
                    : node.name

                let labelSize: CGFloat = isSelected ? 10 : (scale >= 2.0 ? 9 : 8)
                let label = ctx.resolve(Text(displayName)
                    .foregroundStyle(Color(UIColor.label).opacity(dimmed ? 0.35 : 1))
                    .font(.system(size: labelSize, weight: isSelected ? .semibold : .regular)))
                ctx.draw(label, at: CGPoint(x: pos.x, y: pos.y - radius - 6))
            }
        }
    }

    private func circle(_ center: CGPoint, _ r: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
    }

    private func color(for node: MeshNode, device: ThreadDevice?) -> Color {
        switch node.kind {
        case .gateway:      return Color(UIColor.systemGray)
        case .borderRouter: return .blue
        case .router:
            guard let device else { return .indigo }
            return device.rssi?.rssiColor ?? .indigo
        case .endDevice:
            guard let device else { return .teal }
            return device.rssi?.rssiColor ?? .teal
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

    private func accessibilityValue(for node: MeshNode, device: ThreadDevice?) -> String {
        var parts: [String] = [node.kind.rawValue]
        if let room = node.room { parts.append(room) }
        if let rssi = device?.rssi {
            parts.append(rssi.rssiQualityLabel + " signal")
        } else if device?.isOffline == true {
            parts.append("offline")
        }
        if let ch = node.channel { parts.append("Channel \(ch)") }
        return parts.joined(separator: ", ")
    }

    private func accessibilityHint(for node: MeshNode) -> String {
        switch node.kind {
        case .gateway:      return "Internet uplink — not a physical device"
        case .borderRouter: return "Connects Thread mesh to the internet. Double-tap to view details."
        case .router:       return "Relays traffic for nearby devices. Double-tap to view details."
        case .endDevice:    return "End device. Double-tap to view details."
        }
    }
}
