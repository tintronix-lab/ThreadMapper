import Observation
import SwiftUI

enum MeshViewMode: Hashable {
    case map, list
}

struct MeshView: View {
    @Environment(MeshViewModel.self) private var viewModel
    @State private var viewMode: MeshViewMode = .map
    @State private var searchText = ""
    @State private var showResilienceSimulator = false
    @State private var showChannelScanner = false
    @State private var showBRMonitor = false
    @State private var showTimeLapse = false
    @State private var isExportingMap = false
    @State private var exportedMapImage: UIImage?
    @State private var nlFilterIDs: [UUID]?
    @State private var nlFilterDescription: String?
    @State private var isRunningNLFilter = false
    @State private var showPaywall = false

    private var selectedDeviceBinding: Binding<ThreadDevice?> {
        Binding(get: { viewModel.selectedDevice }, set: { viewModel.selectedDevice = $0 })
    }

    private var devicesByID: [UUID: ThreadDevice] {
        Dictionary(viewModel.devices.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    }

    // Border routers sorted best-signal-first for the backbone strip.
    private func borderRouters(devMap: [UUID: ThreadDevice]) -> [MeshNode] {
        viewModel.nodes
            .filter { $0.kind == .borderRouter }
            .sorted { nodeA, nodeB in
                let rssiA = nodeA.deviceID.flatMap { devMap[$0] }?.rssi ?? SignalThresholds.offlineSentinel
                let rssiB = nodeB.deviceID.flatMap { devMap[$0] }?.rssi ?? SignalThresholds.offlineSentinel
                return rssiA > rssiB
            }
    }

    // Nodes grouped by room; gateway excluded; sorted border router → relay → device within each room.
    private var roomGroups: [(room: String, nodes: [MeshNode])] {
        let visible = viewModel.nodes.filter { $0.kind != .gateway }
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        let matches: [MeshNode]
        if let ids = nlFilterIDs {
            let idSet = Set(ids)
            matches = visible.filter { node in node.deviceID.map { idSet.contains($0) } ?? false }
        } else {
            matches = q.isEmpty ? visible : visible.filter { $0.name.lowercased().contains(q) }
        }
        let grouped = Dictionary(grouping: matches) { $0.room ?? "Unassigned" }
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
            .sheet(isPresented: $showResilienceSimulator) {
                ResilienceSimulatorView()
            }
            .sheet(isPresented: $showChannelScanner) {
                ChannelScannerView()
            }
            .sheet(isPresented: $showBRMonitor) {
                BRHealthMonitorView()
            }
            .sheet(isPresented: $showTimeLapse) {
                MeshTopologyRewindView()
            }
            .sheet(isPresented: $isExportingMap) {
                if let img = exportedMapImage {
                    MeshMapShareSheet(image: img)
                }
            }
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .safeAreaInset(edge: .top, spacing: 0) {
                topBar
            }
            .onAppear {
                if !viewModel.isScanning {
                    Task { await viewModel.startScan() }
                }
            }
            .onChange(of: viewMode) { _, mode in
                if mode == .map { clearNLFilter() }
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
        // Derive shared collections once per render — statsBanner, the
        // backbone strip, and every room section reuse them.
        let devMap = devicesByID
        let routers = borderRouters(devMap: devMap)
        let groups = roomGroups
        return ScrollView {
            LazyVStack(spacing: 0) {
                statsBanner(borderRouterCount: routers.count)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                if !routers.isEmpty {
                    backboneStrip(borderRouters: routers, devMap: devMap)
                        .padding(.bottom, 16)
                }

                if groups.isEmpty && (!searchText.isEmpty || nlFilterDescription != nil) {
                    VStack(spacing: 12) {
                        Image(systemName: nlFilterDescription != nil ? "sparkles" : "magnifyingglass")
                            .font(.title2)
                            .foregroundStyle(.tertiary)
                        if let desc = nlFilterDescription {
                            Text("No devices matched: \(desc)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("No devices match \"\(searchText)\"")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Button("Clear Search") { clearNLFilter() }
                            .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                } else {
                    ForEach(groups, id: \.room) { group in
                        roomSection(room: group.room, nodes: group.nodes, devMap: devMap)
                    }
                }
            }
            .padding(.bottom, 24)
        }
        .refreshable {
            await viewModel.startScan()
        }
    }

    // MARK: - Stats banner

    private func statsBanner(borderRouterCount: Int) -> some View {
        HStack(spacing: 0) {
            statCell(
                value: "\(viewModel.visibleDeviceCount)",
                label: "Devices",
                color: .primary
            )
            Divider().frame(height: 28)
            statCell(
                value: "\(borderRouterCount)",
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
        .cardBackground()
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

    private func backboneStrip(borderRouters: [MeshNode], devMap: [UUID: ThreadDevice]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Thread Backbone", systemImage: "point.3.filled.connected.trianglepath.dotted")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("^[\(borderRouters.count) border router](inflect: true)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
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

    private func roomSection(room: String, nodes: [MeshNode], devMap: [UUID: ThreadDevice]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Room header
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: TMStyle.roomIcon(room))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(room)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("^[\(nodes.count) device](inflect: true)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 8)

            // Device rows card
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

    // MARK: - Hop counts (BFS from border routers through parentID chain)

    private var hopCountByNodeID: [UUID: Int] {
        var childrenOf: [UUID: [UUID]] = [:]
        for node in viewModel.nodes {
            if let pid = node.parentID { childrenOf[pid, default: []].append(node.id) }
        }
        var hopCounts: [UUID: Int] = [:]
        var queue: [(id: UUID, hop: Int)] = viewModel.nodes
            .filter { $0.kind == .borderRouter }
            .map { ($0.id, 1) }
        while !queue.isEmpty {
            let (id, hop) = queue.removeFirst()
            guard hopCounts[id] == nil else { continue }
            hopCounts[id] = hop
            for childID in childrenOf[id] ?? [] where hopCounts[childID] == nil {
                queue.append((childID, hop + 1))
            }
        }
        return hopCounts
    }

    // MARK: - Device row

    private func deviceRow(node: MeshNode, device: ThreadDevice?) -> some View {
        MeshDeviceRowView(
            node: node,
            device: device,
            hopCount: hopCountByNodeID[node.id],
            anomaly: device.flatMap { viewModel.anomalies[$0.uniqueIdentifier] }
        ) { d in
            viewModel.selectedDevice = d
        }
    }

    // MARK: - NL Filter

    private func runNLFilter() {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }
        guard ProStore.shared.isPro else { showPaywall = true; return }
        guard #available(iOS 26, *) else { return }
        isRunningNLFilter = true
        let rooms = Array(Set(viewModel.devices.compactMap(\.room))).sorted()
        let count = viewModel.devices.count
        Task { @MainActor in
            defer { isRunningNLFilter = false }
            guard let filter = try? await AINetworkAnalyzer.parseNLFilter(
                query: query, rooms: rooms, deviceCount: count
            ) else { return }
            applyNLFilter(filter)
        }
    }

    @available(iOS 26, *)
    private func applyNLFilter(_ filter: NLDeviceFilter) {
        let hops = hopCountByNodeID
        var matched = viewModel.devices.filter { device in
            if let room = filter.roomContains?.lowercased(), !room.isEmpty {
                guard device.room?.lowercased().contains(room) == true else { return false }
            }
            if let role = filter.roleFilter {
                switch role {
                case "border_router": if !device.isBorderRouter { return false }
                case "router":        if !device.isRouter || device.isBorderRouter { return false }
                case "end_device":    if device.isRoutingCapable { return false }
                default: break
                }
            }
            if let status = filter.statusFilter {
                switch status {
                case "offline": if !device.isOffline { return false }
                case "online":  if device.isOffline { return false }
                case "weak":    if !device.isWeak { return false }
                default: break
                }
            }
            if let minH = filter.minHops {
                let nodeID = viewModel.nodes.first(where: { $0.deviceID == device.id })?.id
                if (nodeID.flatMap { hops[$0] } ?? 0) < minH { return false }
            }
            if filter.batteryPoweredOnly == true {
                if !device.isSleepyEndDevice && device.batteryPercentage == nil { return false }
            }
            return true
        }
        if let sort = filter.sortOrder {
            switch sort {
            case "rssi_weakest": matched.sort { ($0.rssi ?? -100) < ($1.rssi ?? -100) }
            case "rssi_best":    matched.sort { ($0.rssi ?? -100) > ($1.rssi ?? -100) }
            case "hops_most":
                matched.sort { a, b in
                    let hA = viewModel.nodes.first(where: { $0.deviceID == a.id }).flatMap { hops[$0.id] } ?? 0
                    let hB = viewModel.nodes.first(where: { $0.deviceID == b.id }).flatMap { hops[$0.id] } ?? 0
                    return hA > hB
                }
            default: break
            }
        }
        nlFilterIDs = matched.map { $0.id }
        nlFilterDescription = filter.filterDescription
    }

    private func clearNLFilter() {
        searchText = ""
        nlFilterIDs = nil
        nlFilterDescription = nil
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
            if viewMode == .list { listSearchBar }
            if !viewModel.threadNetworks.isEmpty { threadNetworkBar }
            if let error = viewModel.scanError { errorBanner(message: error) }
        }
    }

    // MARK: - Filter bar

    @ViewBuilder
    private var filterBar: some View {
        MeshFilterBar(
            viewMode: $viewMode,
            showSimulator: $showResilienceSimulator,
            showScanner: $showChannelScanner,
            showBRMonitor: $showBRMonitor,
            showTimeLapse: $showTimeLapse,
            onExportMap: { exportMap() }
        )
    }

    @MainActor
    private func exportMap() {
        let snapshot = MeshGraphView(
            nodes: viewModel.nodes,
            links: viewModel.links,
            devices: viewModel.devices,
            isLive: !viewModel.latestDiagnostics.isEmpty,
            onSelectNode: { _ in },
            onSelectDevice: { _ in }
        )
        .frame(width: 1024, height: 768)
        .background(Color(UIColor.systemBackground))
        let renderer = ImageRenderer(content: snapshot)
        renderer.scale = 2.0
        guard let image = renderer.uiImage else { return }
        exportedMapImage = image
        isExportingMap = true
    }

    // MARK: - List search bar (with AI NL filter)

    private var listSearchBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: nlFilterDescription != nil ? "sparkles" : "magnifyingglass")
                    .font(.caption)
                    .foregroundStyle(nlFilterDescription != nil ? Color.purple : Color.secondary.opacity(0.5))
                TextField("Search or ask AI…", text: $searchText)
                    .font(.subheadline)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onSubmit { runNLFilter() }
                if isRunningNLFilter {
                    ProgressView().controlSize(.mini)
                } else if !searchText.isEmpty && nlFilterDescription == nil {
                    if #available(iOS 26, *) {
                        Button { runNLFilter() } label: {
                            Image(systemName: "sparkles")
                                .font(.caption)
                                .foregroundStyle(.purple)
                        }
                    }
                }
                if !searchText.isEmpty || nlFilterDescription != nil {
                    Button { clearNLFilter() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                            .font(.caption)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            if let desc = nlFilterDescription {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles").font(.caption2).foregroundStyle(.purple)
                    Text(desc)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.purple)
                    Spacer()
                    if let count = nlFilterIDs?.count {
                        Text("^[\(count) device](inflect: true) matched")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(.purple.opacity(0.08))
            }
        }
        .background(.ultraThinMaterial)
        .overlay(Divider(), alignment: .bottom)
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

// MARK: - Share Sheet

private struct MeshMapShareSheet: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.horizontal)
                    .shadow(color: .black.opacity(0.12), radius: 8, y: 4)

                ShareLink(
                    item: Image(uiImage: image),
                    preview: SharePreview(
                        "Thread Mesh Map",
                        image: Image(uiImage: image)
                    )
                ) {
                    Label("Share Map", systemImage: "square.and.arrow.up")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .foregroundStyle(.white)
                        .padding(.horizontal)
                }
            }
            .padding(.top, 24)
            .navigationTitle("Export Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

