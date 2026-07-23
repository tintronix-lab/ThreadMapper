import SwiftUI

struct BRHealthMonitorView: View {
    @Environment(MeshViewModel.self) private var meshVM
    @Environment(DeviceStatsStore.self) private var statsStore
    @Environment(\.dismiss) private var dismiss

    private var borderRouters: [ThreadDevice] {
        meshVM.devices.filter(\.isBorderRouter).sorted { $0.name < $1.name }
    }

    private var onlineCount: Int { borderRouters.filter { !$0.isOffline }.count }
    private var offlineCount: Int { borderRouters.filter(\.isOffline).count }
    private var isSingleBR: Bool { borderRouters.count == 1 }

    var body: some View {
        NavigationStack {
            Group {
                if borderRouters.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 14) {
                            summaryBanner
                            ForEach(borderRouters) { br in
                                BRCard(device: br,
                                       statsStore: statsStore,
                                       isOnlyBR: isSingleBR,
                                       totalBRs: borderRouters.count)
                            }
                            RouterSaturationSection(nodes: meshVM.nodes)
                        }
                        .padding(16)
                    }
                    .background(Color(UIColor.systemGroupedBackground))
                }
            }
            .navigationTitle("Border Router Health")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Summary banner

    private var summaryBanner: some View {
        HStack(spacing: 0) {
            bannerCell("\(borderRouters.count)", label: "Total", color: .primary)
            Divider().frame(height: 28)
            bannerCell("\(onlineCount)", label: "Online", color: .green)
            Divider().frame(height: 28)
            bannerCell("\(offlineCount)", label: "Offline",
                       color: offlineCount > 0 ? .red : .secondary)
            if isSingleBR {
                Divider().frame(height: 28)
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption2)
                    Text("No redundancy")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.orange)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 10)
        .cardBackground()
    }

    private func bannerCell(_ value: String, label: LocalizedStringKey, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No Border Routers")
                .font(.headline)
            Text("Border routers bridge Thread and Wi-Fi. Add a Thread border router in the Home app to enable monitoring.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Per-BR card

private struct BRCard: View {
    @ScaledMetric(relativeTo: .caption2) private var axisLabelSize: CGFloat = 8
    let device: ThreadDevice
    let statsStore: DeviceStatsStore
    let isOnlyBR: Bool
    let totalBRs: Int

    private var stats: DeviceStats? { statsStore.stats(for: device.uniqueIdentifier) }

    private var lastSeenDate: Date? { stats?.readings.last?.timestamp }

    private var uptimeLabel: LocalizedStringResource {
        guard let date = lastSeenDate else { return "No recent data" }
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "Last seen just now" }
        if interval < 3600 { return "Last seen \(Int(interval / 60))m ago" }
        if interval < 86400 { return "Last seen \(Int(interval / 3600))h ago" }
        return "Last seen \(Int(interval / 86400))d ago"
    }

    private var statusColor: Color {
        if device.isOffline { return .red }
        guard let rssi = device.rssi else { return .secondary }
        return rssi > SignalThresholds.good ? .green : rssi > SignalThresholds.weak ? .orange : .red
    }

    private var statusLabel: LocalizedStringResource {
        device.isOffline ? "Offline" : "Online"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header row
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(statusColor.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(statusColor)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(device.name)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        statusBadge
                        if isOnlyBR {
                            Text("Only BR")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.orange)
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(.orange.opacity(0.12), in: Capsule())
                        }
                    }
                    HStack(spacing: 8) {
                        if let room = device.room {
                            Label(room, systemImage: "house")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        if let ch = device.channel {
                            Text("CH \(ch)")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                if let rssi = device.rssi, !device.isOffline {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(rssi) dBm")
                            .font(.caption.weight(.semibold).monospacedDigit())
                            .foregroundStyle(rssi.rssiColor)
                        Text(rssi.rssiQualityLabel)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Signal sparkline
            if let stats {
                signalSparkline(stats: stats)
            }

            // Footer
            HStack {
                Image(systemName: "clock")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text(uptimeLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                if let count = stats?.readings.count {
                    Text("\(count) samples")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            // Offline warning
            if device.isOffline && isOnlyBR {
                Label("Critical — all Thread devices have lost internet connectivity.", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(8)
                    .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            } else if device.isOffline {
                Label("Offline — devices that routed through this border router may have rerouted.", systemImage: "wifi.slash")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(8)
                    .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(14)
        .cardBackground()
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(device.isOffline ? Color.red.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }

    // MARK: - Status badge

    private var statusBadge: some View {
        HStack(spacing: 3) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
            Text(statusLabel)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(statusColor)
        }
        .padding(.horizontal, 6).padding(.vertical, 2)
        .background(statusColor.opacity(0.12), in: Capsule())
    }

    // MARK: - Signal sparkline

    private func signalSparkline(stats: DeviceStats) -> some View {
        let readings = stats.readings.suffix(40)
        return Canvas { ctx, size in
            guard readings.count > 1 else { return }
            let minRSSI = -100.0
            let maxRSSI = -40.0
            let w = size.width / CGFloat(readings.count - 1)
            var path = Path()
            for (i, r) in readings.enumerated() {
                let fraction = (Double(r.rssi) - minRSSI) / (maxRSSI - minRSSI)
                let x = CGFloat(i) * w
                let y = size.height * (1 - CGFloat(max(0, min(1, fraction))))
                if i == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
            }
            let color: Color = device.isOffline
                ? .red
                : ((device.rssi ?? SignalThresholds.offlineSentinel) > SignalThresholds.good ? .green : .orange)
            ctx.stroke(path, with: .color(color.opacity(0.8)), lineWidth: 1.5)
        }
        .frame(height: 36)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
        .overlay(alignment: .topLeading) {
            Text(verbatim: "−40 dBm")
                .font(.system(size: axisLabelSize))
                .foregroundStyle(.tertiary)
                .padding(.leading, 4).padding(.top, 2)
        }
        .overlay(alignment: .bottomLeading) {
            Text(verbatim: "−100 dBm")
                .font(.system(size: axisLabelSize))
                .foregroundStyle(.tertiary)
                .padding(.leading, 4).padding(.bottom, 2)
        }
        .accessibilityLabel(Text("Signal trend for \(device.name)"))
        .accessibilityValue(Text(device.rssi.map { "Latest \($0) dBm, \($0.rssiQualityLabel)" } ?? String(localized: "No signal data")))
    }
}

// MARK: - Router Saturation (NF-6)

private let saturationSoftLimit = 15
private let saturationWarnThreshold = 0.80

private struct RouterSaturationSection: View {
    let nodes: [MeshNode]

    struct RouterLoad: Identifiable {
        let id: UUID
        let name: String
        let kind: MeshNodeKind
        let directCount: Int
        var saturation: Double { Double(directCount) / Double(saturationSoftLimit) }
        var isOverloaded: Bool { saturation >= saturationWarnThreshold }
    }

    private var loads: [RouterLoad] {
        let routing = nodes.filter { $0.kind == .borderRouter || $0.kind == .router }
        return routing.map { node in
            let children = nodes.filter { $0.parentID == node.id && $0.kind == .endDevice }.count
            return RouterLoad(id: node.id, name: node.name, kind: node.kind, directCount: children)
        }
        .filter { $0.directCount > 0 }
        .sorted { $0.saturation > $1.saturation }
    }

    private var anyOverloaded: Bool { loads.contains(where: \.isOverloaded) }

    var body: some View {
        if !loads.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: anyOverloaded ? "exclamationmark.triangle.fill" : "chart.bar.fill")
                        .foregroundStyle(anyOverloaded ? Color.orange : Color.blue)
                        .font(.subheadline)
                    Text("Router Capacity")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("Limit ~\(saturationSoftLimit)/router")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                if anyOverloaded {
                    Label("One or more routers are near capacity. Consider adding a Thread relay to balance the load.", systemImage: "info.circle")
                        .font(.caption2).foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
                ForEach(loads, id: \.id) { load in
                    RouterLoadRow(load: load)
                }
            }
            .padding(12)
            .cardBackground()
        }
    }
}

private struct RouterLoadRow: View {
    let load: RouterSaturationSection.RouterLoad

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(load.name).font(.caption).lineLimit(1)
                Text(load.kind == .borderRouter ? "BR" : "Relay")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(load.directCount)/\(saturationSoftLimit)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(load.isOverloaded ? Color.orange : Color.primary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(Color.secondary.opacity(0.12))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(load.isOverloaded ? Color.orange : Color.blue)
                        .frame(width: geo.size.width * min(1, load.saturation))
                }
            }
            .frame(height: 6)
        }
    }
}
