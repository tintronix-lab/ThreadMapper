import SwiftUI

struct MeshGraphView: View {
    let nodes: [MeshNode]
    let links: [MeshLink]
    let devices: [ThreadDevice]
    var isLive: Bool = false   // real per-node routing (from a border router) is driving the graph
    let onSelectNode: (MeshNode) -> Void
    let onSelectDevice: (ThreadDevice?) -> Void

    @State var layout: [UUID: CGPoint] = [:]
    // Explicit room-card bounds (layout-space) produced by GraphLayout.byRoom.
    // Used by drawRoomZones so zones are positioned by the layout algorithm,
    // not inferred from node positions — this guarantees they never overlap.
    @State var roomBounds: [String: CGRect] = [:]
    @State var selectedNodeID: UUID?
    // pan is in screen/view space; zoom is applied around view center.
    @State var scale: CGFloat = 1.0
    @State var baseScale: CGFloat = 1.0   // accumulated zoom between gestures
    @State var pan: CGSize = .zero
    @State var lastPan: CGSize = .zero
    @State var isDragging = false
    // Tracked via onGeometryChange — reliable inside NavigationStack/sheet contexts
    // where onAppear may fire before the final size is settled.
    @State var viewSize: CGSize = .zero
    // Gating hash: skip layout re-solve when node membership/rooms/size are unchanged.
    @State var layoutHash: Int? = nil
    @State var legendExpanded = false

    @ScaledMetric(relativeTo: .caption2) var canvasNodeLabel: CGFloat = 8
    @ScaledMetric(relativeTo: .caption2) var canvasRoomLabel: CGFloat = 9

    var nodesByID: [UUID: MeshNode] {
        Dictionary(nodes.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    }

    var devicesByID: [UUID: ThreadDevice] {
        Dictionary(devices.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    }

    var body: some View {
        ZStack {
            Color(UIColor.systemBackground)
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
                let devMap = devicesByID
                ForEach(nodes) { node in
                    let device = node.deviceID.flatMap { devMap[$0] }
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

            // Bottom overlay: info card (when a node is selected) + legend toggle + fit button.
            // The Spacer at the top is transparent — canvas gestures pass through it.
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                selectedHUD
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        if legendExpanded {
                            legendView
                                .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .bottomLeading)))
                        }
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { legendExpanded.toggle() }
                        } label: {
                            Image(systemName: legendExpanded ? "info.circle.fill" : "info.circle")
                                .font(.caption)
                                .padding(6)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        .accessibilityLabel("Toggle legend")
                    }
                    .padding(10)
                    Spacer()
                    fitResetButton.padding(12)
                }
                .padding(.bottom, 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedNodeID)
            .zIndex(10)

            // Hint: only visible when labels are hidden and no node is selected.
            if scale < 0.7, !nodes.isEmpty, selectedNodeID == nil {
                Text("Pinch to zoom for device names")
                    .font(.caption)
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
                .font(.title2)
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

    @ViewBuilder private var selectedHUD: some View {
        if let selectedNodeID, let node = nodesByID[selectedNodeID] {
            let device = node.deviceID.flatMap { devicesByID[$0] }
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
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let d = device {
                        Button("Details →") { onSelectDevice(d) }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                    }
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
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                if let route = routeDescription(from: node) {
                    Label(route, systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: .black.opacity(0.10), radius: 10, x: 0, y: -3)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
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

    var highlightedNodeIDs: Set<UUID> {
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
            if isLive {
                Label("Live routing · Border Router", systemImage: "checkmark.seal.fill")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.green)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Estimated paths — HomeKit\ndoesn't report Thread routing")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .italic()
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(7)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var fitResetButton: some View {
        Button { fitToView(size: viewSize) } label: {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.caption)
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
                    Image(systemName: symbol).font(.caption2).foregroundStyle(color)
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
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }
}
