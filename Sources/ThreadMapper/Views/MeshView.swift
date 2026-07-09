import SwiftUI
import Observation

struct MeshView: View {
    @Environment(MeshViewModel.self) private var viewModel
    @State private var showingMap = false

    private var selectedDeviceBinding: Binding<ThreadDevice?> {
        Binding(get: { viewModel.selectedDevice }, set: { viewModel.selectedDevice = $0 })
    }

    private var devicesByID: [UUID: ThreadDevice] {
        Dictionary(viewModel.devices.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    }

    // Border routers sorted best-signal-first for the backbone strip.
    private var borderRouters: [MeshNode] {
        let devMap = devicesByID
        return viewModel.nodes
            .filter { $0.kind == .borderRouter }
            .sorted { nodeA, nodeB in
                let rssiA = nodeA.deviceID.flatMap { devMap[$0] }?.rssi ?? -100
                let rssiB = nodeB.deviceID.flatMap { devMap[$0] }?.rssi ?? -100
                return rssiA > rssiB
            }
    }

    // Nodes grouped by room; gateway excluded; sorted border router → relay → device within each room.
    private var roomGroups: [(room: String, nodes: [MeshNode])] {
        let visible = viewModel.nodes.filter { $0.kind != .gateway }
        let grouped = Dictionary(grouping: visible) { $0.room ?? "Unassigned" }
        return grouped
            .sorted { $0.key < $1.key }
            .map { key, val in
                (room: key, nodes: val.sorted { roleOrder($0) < roleOrder($1) })
            }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if viewModel.isScanning && viewModel.nodes.isEmpty {
                    scanningPlaceholder
                } else if viewModel.nodes.isEmpty {
                    emptyPlaceholder
                } else {
                    meshContent
                }
            }
            .padding(.bottom, 24)
        }
        .background(Color(UIColor.systemGroupedBackground))
        .sheet(item: selectedDeviceBinding) { device in
            DeviceDetailView(device: device)
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showingMap) {
            // Always show the complete topology — not the room/channel-filtered view.
            MeshMapSheet(devices: viewModel.devices)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            topBar
        }
        .onAppear {
            if !viewModel.isScanning {
                Task { await viewModel.startScan() }
            }
        }
    }

    // MARK: - Main content

    @ViewBuilder
    private var meshContent: some View {
        // Stats summary
        statsBanner
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

        // Backbone strip — border routers are the network's spine
        if !borderRouters.isEmpty {
            backboneStrip
                .padding(.bottom, 16)
        }

        // Room sections
        ForEach(roomGroups, id: \.room) { group in
            roomSection(room: group.room, nodes: group.nodes)
        }
    }

    // MARK: - Stats banner

    private var statsBanner: some View {
        HStack(spacing: 0) {
            statCell(
                value: "\(viewModel.visibleDeviceCount)",
                label: "Devices",
                color: .primary
            )
            Divider().frame(height: 28)
            statCell(
                value: "\(borderRouters.count)",
                label: "Border Routers",
                color: .blue
            )
            Divider().frame(height: 28)
            statCell(
                value: "\(viewModel.nodes.filter { $0.kind == .router }.count)",
                label: "Relays",
                color: .indigo
            )
            Divider().frame(height: 28)
            statCell(
                value: "\(viewModel.devices.filter(\.isOffline).count)",
                label: "Offline",
                color: viewModel.devices.contains(where: \.isOffline) ? .red : .secondary
            )
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color(UIColor.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func statCell(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Backbone strip (border routers)

    private var backboneStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Thread Backbone", systemImage: "point.3.filled.connected.trianglepath.dotted")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(borderRouters.count) border router\(borderRouters.count == 1 ? "" : "s")")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                let devMap = devicesByID
                HStack(spacing: 10) {
                    ForEach(borderRouters) { node in
                        let device = node.deviceID.flatMap { devMap[$0] }
                        borderRouterCard(node: node, device: device)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private func borderRouterCard(node: MeshNode, device: ThreadDevice?) -> some View {
        Button {
            if let device { viewModel.selectedDevice = device }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.blue)
                    Spacer()
                    if let rssi = device?.rssi {
                        signalBars(rssi, size: .small)
                    }
                }

                Text(node.name)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(2)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 0)

                HStack(spacing: 5) {
                    if let room = node.room {
                        Label(room, systemImage: "house")
                            .lineLimit(1)
                    }
                    if let ch = node.channel ?? device?.channel {
                        Text("CH \(ch)")
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.15), in: Capsule())
                            .foregroundStyle(.blue)
                    }
                }
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
            }
            .padding(12)
            .frame(width: 148, height: 98)
            .background(Color(UIColor.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.blue.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Room section

    private func roomSection(room: String, nodes: [MeshNode]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Room header
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "house")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(room)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(nodes.count) device\(nodes.count == 1 ? "" : "s")")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 8)

            // Device rows card
            let devMap = devicesByID
            VStack(spacing: 0) {
                ForEach(Array(nodes.enumerated()), id: \.element.id) { index, node in
                    let device = node.deviceID.flatMap { devMap[$0] }
                    deviceRow(node: node, device: device)

                    if index < nodes.count - 1 {
                        Divider()
                            .padding(.leading, 54)
                    }
                }
            }
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Device row

    private func deviceRow(node: MeshNode, device: ThreadDevice?) -> some View {
        Button {
            if let device { viewModel.selectedDevice = device }
        } label: {
            HStack(spacing: 12) {
                // Role icon
                ZStack {
                    Circle()
                        .fill(roleColor(node.kind).opacity(0.12))
                        .frame(width: 38, height: 38)
                    Image(systemName: roleIcon(node.kind))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(roleColor(node.kind))
                }

                // Name + role + signal
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(node.name)
                            .font(.system(size: 14, weight: .medium))
                            .lineLimit(1)
                            .foregroundStyle(device?.isOffline == true ? .secondary : .primary)

                        roleBadge(node.kind)
                    }

                    HStack(spacing: 6) {
                        if let rssi = device?.rssi {
                            signalBars(rssi, size: .small)
                            Text(rssi.rssiQualityLabel)
                                .font(.system(size: 11))
                                .foregroundStyle(rssi.rssiColor)
                        } else if device?.isOffline == true {
                            Label("Offline", systemImage: "wifi.slash")
                                .font(.system(size: 11))
                                .foregroundStyle(.red)
                        } else {
                            Text("No signal data")
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                        }

                        if let ch = device?.channel {
                            Text("·")
                                .foregroundStyle(.tertiary)
                            Text("CH \(ch)")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer(minLength: 0)

                // Battery + chevron
                VStack(alignment: .trailing, spacing: 2) {
                    if let pct = device?.batteryPercentage {
                        HStack(spacing: 3) {
                            Image(systemName: batteryIcon(pct))
                                .font(.system(size: 12))
                                .foregroundStyle(pct < 20 ? .red : .secondary)
                            Text("\(pct)%")
                                .font(.system(size: 11))
                                .foregroundStyle(pct < 20 ? .red : .secondary)
                        }
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tertiaryLabel)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Signal bars

    private enum BarSize { case small, medium }

    @ViewBuilder
    private func signalBars(_ rssi: Int, size: BarSize) -> some View {
        let count = barCount(rssi)
        let w: CGFloat = size == .small ? 3 : 4
        let baseH: CGFloat = size == .small ? 4 : 5
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<4) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(i < count ? rssi.rssiColor : Color.secondary.opacity(0.2))
                    .frame(width: w, height: baseH + CGFloat(i) * (size == .small ? 2.5 : 3))
            }
        }
    }

    private func barCount(_ rssi: Int) -> Int {
        if rssi > -50 { return 4 }
        if rssi > -65 { return 3 }
        if rssi > -80 { return 2 }
        return 1
    }

    // MARK: - Role helpers

    private func roleColor(_ kind: MeshNodeKind) -> Color {
        switch kind {
        case .gateway:      return .gray
        case .borderRouter: return .blue
        case .router:       return .indigo
        case .endDevice:    return .green
        }
    }

    private func roleIcon(_ kind: MeshNodeKind) -> String {
        switch kind {
        case .gateway:      return "globe"
        case .borderRouter: return "antenna.radiowaves.left.and.right"
        case .router:       return "dot.radiowaves.right"
        case .endDevice:    return "sensor.tag.radiowaves.forward"
        }
    }

    @ViewBuilder
    private func roleBadge(_ kind: MeshNodeKind) -> some View {
        switch kind {
        case .endDevice:
            EmptyView()
        case .gateway:
            badgeCapsule("Gateway", color: roleColor(kind))
        case .borderRouter:
            badgeCapsule("Border Router", color: roleColor(kind))
        case .router:
            badgeCapsule("Relay", color: roleColor(kind))
        }
    }

    private func badgeCapsule(_ label: String, color: Color) -> some View {
        Text(label)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color.opacity(0.1), in: Capsule())
    }

    private func roleOrder(_ node: MeshNode) -> Int {
        switch node.kind {
        case .gateway: return 0
        case .borderRouter: return 1
        case .router: return 2
        case .endDevice: return 3
        }
    }

    // MARK: - Battery

    private func batteryIcon(_ p: Int) -> String {
        if p < 10 { return "battery.0percent" }
        if p < 35 { return "battery.25percent" }
        if p < 60 { return "battery.50percent" }
        if p < 80 { return "battery.75percent" }
        return "battery.100percent"
    }

    // MARK: - Placeholders

    @ViewBuilder private var scanningPlaceholder: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.regular)
            Text("Scanning Thread network…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(60)
    }

    @ViewBuilder private var emptyPlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "network.slash")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
                .padding(.bottom, 4)
            Text("No Thread devices found")
                .font(.subheadline.weight(.medium))
            Text("Add Thread accessories in the Home app,\nthen tap Scan.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(60)
    }

    // MARK: - Top bar

    private var topBar: some View {
        VStack(spacing: 0) {
            filterBar
            if !viewModel.threadNetworks.isEmpty { threadNetworkBar }
            if let error = viewModel.scanError { errorBanner(message: error) }
        }
    }

    // MARK: - Filter bar

    private var roomBinding: Binding<String?> {
        Binding(get: { viewModel.selectedRoom }, set: { viewModel.selectedRoom = $0 })
    }
    private var channelBinding: Binding<Int?> {
        Binding(get: { viewModel.selectedChannel }, set: { viewModel.selectedChannel = $0 })
    }

    @ViewBuilder
    private var filterBar: some View {
        HStack(spacing: 6) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    Menu {
                        Picker("Room", selection: roomBinding) {
                            Text("All Rooms").tag(String?.none)
                            ForEach(viewModel.rooms, id: \.self) { room in
                                Text(room).tag(String?(room))
                            }
                        }
                        .pickerStyle(.inline)
                    } label: {
                        filterChip(
                            label: viewModel.selectedRoom ?? "All Rooms",
                            icon: "house",
                            active: viewModel.selectedRoom != nil
                        )
                    }

                    Menu {
                        Picker("Channel", selection: channelBinding) {
                            Text("All Channels").tag(Int?.none)
                            ForEach(viewModel.channels, id: \.self) { ch in
                                Text("CH \(ch)").tag(Int?(ch))
                            }
                        }
                        .pickerStyle(.inline)
                    } label: {
                        filterChip(
                            label: viewModel.selectedChannel.map { "CH \($0)" } ?? "All Channels",
                            icon: "wifi",
                            active: viewModel.selectedChannel != nil
                        )
                    }

                    if viewModel.selectedRoom != nil || viewModel.selectedChannel != nil {
                        Button {
                            withAnimation {
                                viewModel.selectedRoom = nil
                                viewModel.selectedChannel = nil
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                                .font(.caption2)
                        }
                    }
                }
            }

            Spacer(minLength: 4)

            Text("\(viewModel.visibleDeviceCount)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)

            Button {
                showingMap = true
            } label: {
                Image(systemName: "point.3.filled.connected.trianglepath.dotted")
                    .font(.caption2)
            }
            .accessibilityLabel("View mesh map")

            Button {
                Task { await viewModel.startScan() }
            } label: {
                if viewModel.isScanning {
                    ProgressView().controlSize(.mini)
                } else {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.caption2)
                }
            }
            .disabled(viewModel.isScanning)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private func filterChip(label: String, icon: String, active: Bool) -> some View {
        Label(label, systemImage: icon)
            .font(.caption2.weight(.medium))
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(active ? Color.accentColor : Color.secondary.opacity(0.15), in: Capsule())
            .foregroundStyle(active ? .white : .primary)
    }

    // MARK: - Thread network bar

    @ViewBuilder
    private var threadNetworkBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.threadNetworks) { net in
                    HStack(spacing: 5) {
                        Image(systemName: "point.3.filled.connected.trianglepath.dotted")
                            .font(.system(size: 9))
                            .foregroundStyle(.green)
                        Text(net.networkName)
                            .font(.caption2.weight(.semibold))
                        if let ch = net.channel {
                            Text("· CH \(ch)")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        if let pan = net.panID {
                            Text("· PAN \(pan)")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.green.opacity(0.12), in: Capsule())
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
        }
        .background(.ultraThinMaterial)
    }

    // MARK: - Error banner

    @ViewBuilder
    private func errorBanner(message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.octagon.fill")
                .foregroundStyle(.white)
                .imageScale(.small)
            Text(message)
                .font(.caption2)
                .foregroundStyle(.white)
                .lineLimit(2)
            Spacer(minLength: 0)
            Button("Retry") {
                Task { await viewModel.startScan() }
            }
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.white.opacity(0.2), in: Capsule())
            .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.red)
    }
}

// Silence `Color.tertiaryLabel` warning — use UIKit bridge.
private extension ShapeStyle where Self == Color {
    static var tertiaryLabel: Color { Color(UIColor.tertiaryLabel) }
}

// MARK: - Mesh Map Sheet

/// Full-screen canvas graph presented as a sheet from MeshView.
/// Always shows the COMPLETE topology (all devices, ignoring any room/channel
/// filter that may be active in the list), so the mesh structure is legible.
/// Manages its own device-selection state so tapping a node inside the sheet
/// opens DeviceDetailView within the same sheet context.
private struct MeshMapSheet: View {
    let devices: [ThreadDevice]

    @Environment(\.dismiss) private var dismiss
    @State private var selectedDevice: ThreadDevice?
    @State private var graphNodes: [MeshNode] = []
    @State private var graphLinks: [MeshLink] = []

    var body: some View {
        NavigationStack {
            MeshGraphView(
                nodes: graphNodes,
                links: graphLinks,
                devices: devices,
                onSelectNode: { _ in },
                onSelectDevice: { device in selectedDevice = device }
            )
            .navigationTitle("Mesh Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("Pinch to zoom · drag to pan · tap a node")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .sheet(item: $selectedDevice) { device in
                DeviceDetailView(device: device)
                    .presentationDetents([.large])
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .task {
            let (n, l) = MeshTopologyBuilder.buildGraph(from: devices, diagnostics: [:])
            graphNodes = n
            graphLinks = l
        }
    }
}
