import SwiftUI

// Silence `Color.tertiaryLabel` warning — use UIKit bridge.
extension ShapeStyle where Self == Color {
    static var tertiaryLabel: Color { Color(UIColor.tertiaryLabel) }
}

// MARK: - Filter bar

/// Map/List toggle + room/channel filter chips + scan button.
/// Reads MeshViewModel directly from the environment to avoid threading
/// bindings for every property through MeshView.
struct MeshFilterBar: View {
    @Binding var viewMode: MeshViewMode
    @Binding var showSimulator: Bool
    @Binding var showScanner: Bool
    @Binding var showBRMonitor: Bool
    var onExportMap: () -> Void = {}
    @Environment(MeshViewModel.self) private var viewModel

    var body: some View {
        HStack(spacing: 8) {
            Picker("View", selection: $viewMode) {
                Image(systemName: "map").tag(MeshViewMode.map)
                Image(systemName: "list.bullet").tag(MeshViewMode.list)
            }
            .pickerStyle(.segmented)
            .frame(width: 72)

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

            Menu {
                Button {
                    showSimulator = true
                } label: {
                    Label("Resilience Simulator", systemImage: "shield.lefthalf.filled.trianglebadge.exclamationmark")
                }
                .disabled(viewModel.nodes.filter { $0.kind == .borderRouter || $0.kind == .router }.isEmpty)

                Button {
                    showScanner = true
                } label: {
                    Label("Channel Scanner", systemImage: "waveform.path")
                }

                Button {
                    showBRMonitor = true
                } label: {
                    Label("BR Health Monitor", systemImage: "antenna.radiowaves.left.and.right")
                }

                if viewMode == .map {
                    Divider()
                    Button {
                        onExportMap()
                    } label: {
                        Label("Export Map", systemImage: "square.and.arrow.up")
                    }
                    .disabled(viewModel.nodes.isEmpty)
                }
            } label: {
                Image(systemName: "wrench.and.screwdriver")
                    .font(.caption2)
            }

            Button {
                Task { await viewModel.startScan() }
            } label: {
                if viewModel.isScanning {
                    ProgressView().controlSize(.mini)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption2)
                }
            }
            .disabled(viewModel.isScanning)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
    }

    private var roomBinding: Binding<String?> {
        Binding(get: { viewModel.selectedRoom }, set: { viewModel.selectedRoom = $0 })
    }
    private var channelBinding: Binding<Int?> {
        Binding(get: { viewModel.selectedChannel }, set: { viewModel.selectedChannel = $0 })
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
}

// MARK: - Signal bars

/// Four-bar signal-quality indicator. Reused in border router cards and device rows.
struct SignalBarsView: View {
    let rssi: Int
    enum Size { case small, medium }
    var size: Size = .small

    private var barCount: Int { rssi.rssiLinkQuality }

    var body: some View {
        let w: CGFloat     = size == .small ? 3 : 4
        let baseH: CGFloat = size == .small ? 4 : 5
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<4) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(i < barCount ? rssi.rssiColor : Color.secondary.opacity(0.2))
                    .frame(width: w, height: baseH + CGFloat(i) * (size == .small ? 2.5 : 3))
            }
        }
    }
}

// MARK: - Border router card

/// Fixed-size card for a border router in the backbone strip.
struct BorderRouterCardView: View {
    let node: MeshNode
    let device: ThreadDevice?
    let onSelect: (ThreadDevice) -> Void

    var body: some View {
        Button {
            if let device { onSelect(device) }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.blue)
                    Spacer()
                    if let rssi = device?.rssi {
                        SignalBarsView(rssi: rssi, size: .small)
                    }
                }
                Text(node.name)
                    .font(.footnote.weight(.semibold))
                    .lineLimit(2)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: 0)
                HStack(spacing: 5) {
                    if let room = node.room {
                        Label(room, systemImage: "house").lineLimit(1)
                    }
                    if let ch = node.channel ?? device?.channel {
                        Text("CH \(ch)")
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Color.blue.opacity(0.15), in: Capsule())
                            .foregroundStyle(.blue)
                    }
                }
                .font(.caption2.weight(.medium))
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
}

// MARK: - Device row

/// A single device row inside a room section.
struct MeshDeviceRowView: View {
    let node: MeshNode
    let device: ThreadDevice?
    var hopCount: Int? = nil
    var anomaly: DeviceAnomaly? = nil
    let onSelect: (ThreadDevice) -> Void

    private func roleColor(_ kind: MeshNodeKind) -> Color {
        switch kind {
        case .gateway: return .gray
        case .borderRouter: return .blue
        case .router: return .indigo
        case .endDevice: return .green
        }
    }

    private func roleIcon(_ kind: MeshNodeKind) -> String {
        switch kind {
        case .gateway: return "globe"
        case .borderRouter: return "antenna.radiowaves.left.and.right"
        case .router: return "dot.radiowaves.right"
        case .endDevice: return "sensor.tag.radiowaves.forward"
        }
    }

    @ViewBuilder private func roleBadge(_ kind: MeshNodeKind) -> some View {
        switch kind {
        case .endDevice: EmptyView()
        case .gateway: badgeCapsule("Gateway", color: roleColor(kind))
        case .borderRouter: badgeCapsule("Border Router", color: roleColor(kind))
        case .router: badgeCapsule("Relay", color: roleColor(kind))
        }
    }

    private func badgeCapsule(_ label: String, color: Color) -> some View {
        Text(label)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(color.opacity(0.1), in: Capsule())
    }

    private func batteryIcon(_ p: Int) -> String {
        if p < 10 { return "battery.0percent" }
        if p < 35 { return "battery.25percent" }
        if p < 60 { return "battery.50percent" }
        if p < 80 { return "battery.75percent" }
        return "battery.100percent"
    }

    var body: some View {
        Button {
            if let device { onSelect(device) }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(roleColor(node.kind).opacity(0.12))
                        .frame(width: 38, height: 38)
                    Image(systemName: roleIcon(node.kind))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(roleColor(node.kind))
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(node.name)
                            .font(.subheadline.weight(.medium))
                            .lineLimit(1)
                            .foregroundStyle(device?.isOffline == true ? .secondary : .primary)
                        roleBadge(node.kind)
                    }
                    HStack(spacing: 6) {
                        if let rssi = device?.rssi {
                            SignalBarsView(rssi: rssi, size: .small)
                            Text(rssi.rssiQualityLabel)
                                .font(.caption2)
                                .foregroundStyle(rssi.rssiColor)
                        } else if device?.isOffline == true {
                            Label("Offline", systemImage: "wifi.slash")
                                .font(.caption2)
                                .foregroundStyle(.red)
                        } else {
                            Text("No signal data")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        if let ch = device?.channel {
                            Text("·").foregroundStyle(.tertiary)
                            Text("CH \(ch)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        if let hop = hopCount, node.kind == .endDevice || node.kind == .router {
                            Text("·").foregroundStyle(.tertiary)
                            Text("^[\(hop) hop](inflect: true)")
                                .font(.caption2.weight(hop >= 4 ? .semibold : .regular))
                                .foregroundStyle(hop <= 2 ? Color.secondary : hop == 3 ? Color.orange : Color.red)
                        }
                        if let anomaly, anomaly.trajectory != .stable {
                            Text("·").foregroundStyle(.tertiary)
                            Image(systemName: anomaly.trajectory.sfSymbol)
                                .font(.caption2)
                                .foregroundStyle(anomaly.trajectory == .critical ? .red : .orange)
                            Text(anomaly.trajectory.label)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(anomaly.trajectory == .critical ? .red : .orange)
                        }
                    }
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 2) {
                    if let pct = device?.batteryPercentage {
                        HStack(spacing: 3) {
                            Image(systemName: batteryIcon(pct))
                                .font(.caption)
                                .foregroundStyle(pct < 20 ? .red : .secondary)
                            Text("\(pct)%")
                                .font(.caption2)
                                .foregroundStyle(pct < 20 ? .red : .secondary)
                        }
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiaryLabel)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
        }
        .buttonStyle(.plain)
        .contextMenu {
            if let device {
                Button { onSelect(device) } label: {
                    Label("View Details", systemImage: "info.circle")
                }
                Button {
                    UIPasteboard.general.string = device.name
                } label: {
                    Label("Copy Name", systemImage: "doc.on.doc")
                }
                if let rssi = device.rssi {
                    Button {
                        UIPasteboard.general.string = "\(device.name): \(rssi.rssiQualityLabel)"
                    } label: {
                        Label("Copy Signal Quality", systemImage: "antenna.radiowaves.left.and.right")
                    }
                }
                Divider()
                if device.isOffline {
                    Label("Offline", systemImage: "wifi.slash").foregroundStyle(.red)
                } else if let hop = hopCount {
                    Label("^[\(hop) hop](inflect: true) from hub", systemImage: "point.3.connected.trianglepath.dotted")
                }
            }
        }
    }
}
