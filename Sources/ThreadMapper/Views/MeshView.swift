import SwiftUI
import Observation

enum MeshViewMode: Hashable {
    case map, list
}

struct MeshView: View {
    @Environment(MeshViewModel.self) private var viewModel
    @State private var viewMode: MeshViewMode = .map

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
        content
            .background(Color(UIColor.systemGroupedBackground))
            .sheet(item: selectedDeviceBinding) { device in
                DeviceDetailView(device: device)
                    .presentationDetents([.large])
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

    @ViewBuilder
    private var content: some View {
        if viewModel.isScanning && viewModel.nodes.isEmpty {
            scanningPlaceholder
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.nodes.isEmpty {
            emptyPlaceholder
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewMode == .map {
            mapContent
        } else {
            listContent
        }
    }

    // MARK: - Map view

    private var mapContent: some View {
        MeshGraphView(
            nodes: viewModel.nodes,
            links: viewModel.links,
            devices: viewModel.devices,
            isLive: !viewModel.latestDiagnostics.isEmpty,
            onSelectNode: { _ in },
            onSelectDevice: { device in viewModel.selectedDevice = device }
        )
    }

    // MARK: - List view

    private var listContent: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                statsBanner
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                if !borderRouters.isEmpty {
                    backboneStrip
                        .padding(.bottom, 16)
                }

                ForEach(roomGroups, id: \.room) { group in
                    roomSection(room: group.room, nodes: group.nodes)
                }
            }
            .padding(.bottom, 24)
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
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
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
        BorderRouterCardView(node: node, device: device) { d in
            viewModel.selectedDevice = d
        }
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
        MeshDeviceRowView(node: node, device: device) { d in
            viewModel.selectedDevice = d
        }
    }

    // MARK: - Role helpers

    private func roleOrder(_ node: MeshNode) -> Int {
        switch node.kind {
        case .gateway: return 0
        case .borderRouter: return 1
        case .router: return 2
        case .endDevice: return 3
        }
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
                .font(.largeTitle)
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

    @ViewBuilder
    private var filterBar: some View {
        MeshFilterBar(viewMode: $viewMode)
    }

    // MARK: - Thread network bar

    @ViewBuilder
    private var threadNetworkBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.threadNetworks) { net in
                    HStack(spacing: 5) {
                        Image(systemName: "point.3.filled.connected.trianglepath.dotted")
                            .font(.caption2)
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

