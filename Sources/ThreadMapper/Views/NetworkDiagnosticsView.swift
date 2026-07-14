import SwiftUI
import Charts

struct NetworkDiagnosticsView: View {
    let devices: [ThreadDevice]

    @State private var report: NetworkDiagnosticsEngine.Report?
    @State private var currentSnapshot: TopologySnapshot?
    @State private var baseline: TopologySnapshot? = TopologySnapshot.loadBaseline()
    @State private var otbrInfo: OTBRThreadInfo?
    @State private var isAnalyzing = false
    @State private var baselineSavedFeedback = false
    @State private var runStore = DiagnosticRunStore.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(DeviceStatsStore.self) private var statsStore
    @AppStorage("borderRouterURL") private var borderRouterURL = ""

    private struct OTBRThreadInfo {
        let networkName: String?
        let channel: Int?
        let panID: String?            // "0xDEAD" hex form
        let extPanID: String?
        let meshLocalPrefix: String?
        let keyRotationHours: Int?
        let role: String?             // "leader", "router", "child", "detached"
        let rloc16: String?           // "0x1400" hex form
    }

    var body: some View {
        NavigationStack {
            Group {
                if isAnalyzing {
                    analyzingView
                } else if let report {
                    reportView(report)
                } else {
                    emptyView
                }
            }
            .navigationTitle("Network Diagnostics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        runAnalysis()
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .disabled(isAnalyzing || devices.isEmpty)
                }
                if let snap = currentSnapshot {
                    ToolbarItem(placement: .secondaryAction) {
                        Button {
                            baseline = snap
                            TopologySnapshot.saveBaseline(snap)
                            withAnimation { baselineSavedFeedback = true }
                            Task {
                                try? await Task.sleep(for: .seconds(2))
                                withAnimation { baselineSavedFeedback = false }
                            }
                        } label: {
                            Label(
                                baselineSavedFeedback ? "Baseline Saved" :
                                    (baseline == nil ? "Save as Baseline" : "Update Baseline"),
                                systemImage: baselineSavedFeedback ? "checkmark.circle.fill" : "pin.circle"
                            )
                        }
                    }
                }
                if baseline != nil {
                    ToolbarItem(placement: .secondaryAction) {
                        Button(role: .destructive) {
                            baseline = nil
                            TopologySnapshot.clearBaseline()
                        } label: {
                            Label("Clear Baseline", systemImage: "pin.slash")
                        }
                    }
                }
            }
        }
        .task { runAnalysis() }
    }

    // MARK: - States

    private var analyzingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Analyzing your Thread network…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "stethoscope")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
            Text("No Devices Found")
                .font(.title3.weight(.semibold))
            Text("Return to the dashboard and tap Rescan to discover your Thread network.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Report view

    @ViewBuilder
    private func reportView(_ report: NetworkDiagnosticsEngine.Report) -> some View {
        List {
            summarySection(report)
            if !report.partitions.isEmpty {
                partitionsSection(report.partitions)
            }
            if let snap = currentSnapshot, let base = baseline {
                snapshotComparisonSection(base.diff(against: snap))
            }
            if !report.recommendations.isEmpty {
                recommendationsSection(report.recommendations)
            } else {
                healthySection
            }
            if !report.signalTrendAlerts.isEmpty {
                signalTrendSection(report.signalTrendAlerts)
            }
            if !report.resilienceNodes.isEmpty {
                resilienceSection(report.resilienceNodes)
            }
            if report.totalBorderRouters >= 2 {
                borderRouterComparisonSection(report)
            }
            if !report.roomCoverage.isEmpty {
                roomCoverageSection(report.roomCoverage)
                roomSignalTrendSection(report.roomCoverage)
            }
            meshDepthSection(report.deviceHops)
            if !report.singlePointsOfFailure.isEmpty {
                spofSection(report.singlePointsOfFailure)
            }
            if !report.channelStats.isEmpty {
                channelAnalysisSection(report.channelStats)
            }
            if let info = otbrInfo {
                otbrDatasetSection(info)
            }
            if !runStore.runs.isEmpty {
                diagnosticHistorySection()
            }
            exportSection(report)
        }
    }

    // MARK: - Sections

    private func summarySection(_ report: NetworkDiagnosticsEngine.Report) -> some View {
        Section("Summary") {
            HStack(spacing: 0) {
                summaryStatView(
                    icon: "antenna.radiowaves.left.and.right",
                    value: "\(report.totalBorderRouters)",
                    label: "Border Routers",
                    color: report.totalBorderRouters >= 2 ? .green : (report.totalBorderRouters == 1 ? .orange : .red)
                )
                Divider().frame(height: 48)
                summaryStatView(
                    icon: "point.3.connected.trianglepath.dotted",
                    value: "\(report.totalRouters)",
                    label: "Mesh Routers",
                    color: .blue
                )
                Divider().frame(height: 48)
                summaryStatView(
                    icon: "exclamationmark.triangle.fill",
                    value: "\(report.recommendations.filter { $0.priority == .critical }.count)",
                    label: "Critical Issues",
                    color: report.recommendations.contains { $0.priority == .critical } ? .red : .green
                )
            }
            .padding(.vertical, 6)
        }
    }

    private func summaryStatView(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(color)
            Text(value)
                .font(.title2.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var healthySection: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Network Looks Healthy")
                        .font(.subheadline.weight(.semibold))
                    Text("No issues detected. All routers are redundant, signal strength is good, and no channel conflicts were found.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("Recommendations")
        }
    }

    @ViewBuilder
    private func recommendationsSection(_ recs: [NetworkDiagnosticsEngine.Recommendation]) -> some View {
        Section {
            ForEach(recs) { rec in
                if rec.fixSteps.isEmpty {
                    recRow(rec)
                } else {
                    DisclosureGroup {
                        fixStepsContent(rec.fixSteps)
                    } label: {
                        recRow(rec)
                    }
                }
            }
        } header: {
            Text("Recommendations (\(recs.count))")
        } footer: {
            Text("Tap a recommendation to see step-by-step fix instructions.")
                .font(.caption)
        }
    }

    private func recRow(_ rec: NetworkDiagnosticsEngine.Recommendation) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: rec.icon)
                .font(.title3)
                .foregroundStyle(rec.priority.color)
                .frame(width: 28)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .top) {
                    Text(rec.title)
                        .font(.subheadline.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    Text(rec.priority.label)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(rec.priority.color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(rec.priority.color.opacity(0.12), in: Capsule())
                }
                Text(rec.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
    }

    private func fixStepsContent(_ steps: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(steps.enumerated()), id: \.offset) { i, step in
                HStack(alignment: .top, spacing: 8) {
                    Text("\(i + 1).")
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.tint)
                        .frame(width: 16, alignment: .leading)
                    Text(step)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.top, 6)
        .padding(.bottom, 2)
        .padding(.leading, 40)
    }

    @ViewBuilder
    private func roomCoverageSection(_ coverage: [NetworkDiagnosticsEngine.RoomCoverage]) -> some View {
        Section {
            ForEach(coverage) { room in
                HStack(spacing: 14) {
                    // Grade badge
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(room.gradeColor.opacity(0.15))
                            .frame(width: 44, height: 44)
                        Text(room.grade)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(room.gradeColor)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(room.room)
                            .font(.subheadline.weight(.semibold))
                        HStack(spacing: 12) {
                            Label(
                                "\(room.onlineDevices)/\(room.totalDevices) online",
                                systemImage: room.onlineDevices == room.totalDevices ? "checkmark.circle.fill" : "exclamationmark.circle.fill"
                            )
                            .font(.caption2)
                            .foregroundStyle(room.onlineDevices == room.totalDevices ? .green : .orange)

                            if let rssi = room.avgRSSI {
                                Label("\(rssi) dBm", systemImage: "wifi")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        }
                        if !room.routerNames.isEmpty {
                            Text("Router: \(room.routerNames.joined(separator: ", "))")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        } else {
                            Label("No router in this room", systemImage: "xmark.circle")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        } header: {
            Text("Room Coverage")
        } footer: {
            Text("Grade reflects signal strength and device availability. Rooms without a router rely on hops from another location.")
                .font(.caption)
        }
    }

    // MARK: - Room Signal History

    @ViewBuilder
    private func roomSignalTrendSection(_ coverage: [NetworkDiagnosticsEngine.RoomCoverage]) -> some View {
        let roomData = coverage.compactMap { room -> (room: NetworkDiagnosticsEngine.RoomCoverage, readings: [DeviceStatsStore.Reading])? in
            let readings = aggregatedReadings(for: room.room)
            guard !readings.isEmpty else { return nil }
            return (room: room, readings: readings)
        }
        if !roomData.isEmpty {
            Section {
                ForEach(roomData, id: \.room.id) { entry in
                    let trend = roomSignalTrend(readings: entry.readings)
                    DisclosureGroup {
                        SignalSparklineView(readings: entry.readings)
                            .frame(height: 88)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 4)
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(entry.room.gradeColor.opacity(0.15))
                                    .frame(width: 40, height: 40)
                                Text(entry.room.grade)
                                    .font(.title2.weight(.bold))
                                    .foregroundStyle(entry.room.gradeColor)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text(entry.room.room)
                                    .font(.subheadline.weight(.semibold))
                                HStack(spacing: 6) {
                                    if let latest = entry.readings.last {
                                        Text("\(latest.rssi) dBm")
                                            .font(.caption2.monospacedDigit())
                                            .foregroundStyle(.secondary)
                                    }
                                    Image(systemName: trend.icon)
                                        .imageScale(.small)
                                        .foregroundStyle(trend.color)
                                    Text(trend.label)
                                        .font(.caption2)
                                        .foregroundStyle(trend.color)
                                }
                            }
                            Spacer()
                            Text("\(entry.readings.count) pts")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            } header: {
                Text("Room Signal History")
            } footer: {
                Text("Aggregated RSSI from all devices per room over the last 30 minutes. Tap a room to reveal the sparkline.")
                    .font(.caption)
            }
        }
    }

    private func aggregatedReadings(for room: String) -> [DeviceStatsStore.Reading] {
        devices
            .filter { $0.room == room }
            .flatMap { statsStore.readings[$0.uniqueIdentifier.uuidString] ?? [] }
            .sorted { $0.timestamp < $1.timestamp }
    }

    private func roomSignalTrend(readings: [DeviceStatsStore.Reading]) -> (icon: String, color: Color, label: String) {
        guard readings.count >= 6 else { return ("minus", .secondary, "Stable") }
        let half = readings.count / 2
        let baselineAvg = readings.prefix(half).map(\.rssi).reduce(0, +) / half
        let recentAvg = readings.suffix(half).map(\.rssi).reduce(0, +) / (readings.count - half)
        let delta = recentAvg - baselineAvg
        if delta >= 4 { return ("arrow.up.right", Color.green, "Improving") }
        if delta <= -4 { return ("arrow.down.right", Color.orange, "Degrading") }
        return ("minus", Color.secondary, "Stable")
    }

    private struct BRStats {
        let node: MeshNode
        let directCount: Int
        let totalCount: Int
    }

    private func borderRouterStats(from report: NetworkDiagnosticsEngine.Report) -> [BRStats] {
        let brNodes = report.meshNodes.filter { $0.kind == .borderRouter }
        var childrenOf: [UUID: [UUID]] = [:]
        for link in report.meshLinks { childrenOf[link.sourceID, default: []].append(link.targetID) }

        return brNodes.map { br in
            let direct = childrenOf[br.id]?.count ?? 0
            var total = 0
            var queue = childrenOf[br.id] ?? []
            var seen = Set<UUID>()
            while !queue.isEmpty {
                let next = queue.removeFirst()
                guard seen.insert(next).inserted else { continue }
                total += 1
                queue.append(contentsOf: childrenOf[next] ?? [])
            }
            return BRStats(node: br, directCount: direct, totalCount: total)
        }
    }

    @ViewBuilder
    private func borderRouterComparisonSection(_ report: NetworkDiagnosticsEngine.Report) -> some View {
        let stats = borderRouterStats(from: report)
        Section {
            ForEach(stats, id: \.node.id) { entry in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .foregroundStyle(.blue)
                        Text(entry.node.name)
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        if let ch = entry.node.channel {
                            Text("CH \(ch)")
                                .font(.caption.monospacedDigit())
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(.blue.opacity(0.1), in: Capsule())
                                .foregroundStyle(.blue)
                        }
                    }
                    HStack(spacing: 20) {
                        VStack(spacing: 1) {
                            Text("\(entry.directCount)")
                                .font(.title3.weight(.bold).monospacedDigit())
                            Text("Direct")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        VStack(spacing: 1) {
                            Text("\(entry.totalCount)")
                                .font(.title3.weight(.bold).monospacedDigit())
                            Text("Total Served")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        if let room = entry.node.room {
                            Spacer()
                            Label(room, systemImage: "mappin")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text("Border Router Comparison")
        } footer: {
            Text("Direct = devices routed immediately through this BR. Total = all devices whose traffic passes through it upstream.")
                .font(.caption)
        }
    }

    @ViewBuilder
    private func meshDepthSection(_ hops: [NetworkDiagnosticsEngine.DeviceHopInfo]) -> some View {
        let grouped = Dictionary(grouping: hops) { $0.hopCount }
        let sortedKeys = grouped.keys.sorted()

        Section {
            ForEach(sortedKeys, id: \.self) { hop in
                let group = grouped[hop] ?? []
                DisclosureGroup {
                    ForEach(group) { info in
                        HStack(spacing: 10) {
                            Image(systemName: iconForDevice(info.device))
                                .imageScale(.small)
                                .foregroundStyle(info.device.isOffline ? .red : .secondary)
                                .frame(width: 18)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(info.device.name)
                                    .font(.subheadline)
                                if let parent = info.parentName {
                                    Text("via \(parent)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            if let room = info.device.room {
                                Text(room)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                } label: {
                    HStack {
                        Image(systemName: hopIcon(hop))
                            .foregroundStyle(hopColor(hop))
                            .frame(width: 20)
                        Text(hopLabel(hop))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(hopColor(hop))
                        Spacer()
                        Text("\(group.count)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(.secondary.opacity(0.12), in: Capsule())
                    }
                }
            }
        } header: {
            Text("Mesh Depth")
        } footer: {
            Text("Hop count = routing steps from border router. Each additional hop adds latency. Aim for 3 hops or fewer.")
                .font(.caption)
        }
    }

    @ViewBuilder
    private func spofSection(_ devices: [ThreadDevice]) -> some View {
        Section {
            ForEach(devices) { device in
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.orange)
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(device.name)
                            .font(.subheadline.weight(.semibold))
                        Text("Sole router in \(device.room ?? "its location")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 2)
            }
        } header: {
            Text("Single-Point Routers")
        } footer: {
            Text("These routers have no backup in their area. If one fails, the end devices connected to it lose mesh access.")
                .font(.caption)
        }
    }

    // MARK: - Network Partitions

    @ViewBuilder
    private func partitionsSection(_ partitions: [NetworkDiagnosticsEngine.NetworkPartition]) -> some View {
        let totalIsolated = partitions.reduce(0) { $0 + $1.devices.count }
        Section {
            ForEach(partitions) { partition in
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(partition.devices) { device in
                            HStack(spacing: 10) {
                                Image(systemName: iconForDevice(device))
                                    .imageScale(.small)
                                    .foregroundStyle(.red.opacity(0.7))
                                    .frame(width: 16)
                                Text(device.name)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                if let room = device.room {
                                    Text(room)
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                    }
                    .padding(.top, 4)
                    .padding(.leading, 52)
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.red.opacity(0.12))
                                .frame(width: 42, height: 42)
                            Image(systemName: "wifi.slash")
                                .foregroundStyle(.red)
                                .font(.system(size: 17))
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(partition.devices.count) device\(partition.devices.count == 1 ? "" : "s") isolated")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.red)
                            if let gateway = partition.gatewayDevice {
                                Text("Missing link: \(gateway.name)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("No routing path found")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Text("\(partition.devices.count)")
                            .font(.title3.weight(.bold).monospacedDigit())
                            .foregroundStyle(.red)
                    }
                    .padding(.vertical, 3)
                }
            }
        } header: {
            Label("Isolated Clusters (\(totalIsolated) device\(totalIsolated == 1 ? "" : "s"))", systemImage: "wifi.slash")
                .foregroundStyle(.red)
        } footer: {
            Text("These devices have no path to any border router. They cannot be controlled remotely until the missing routing link is restored.")
                .font(.caption)
        }
    }

    // MARK: - Baseline Comparison

    @ViewBuilder
    private func snapshotComparisonSection(_ diff: SnapshotDiff) -> some View {
        Section {
            if diff.hasChanges {
                ForEach(diff.changes) { change in
                    HStack(spacing: 12) {
                        Image(systemName: change.kind.icon)
                            .foregroundStyle(change.kind.isRegression ? .red : .green)
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(change.name)
                                .font(.subheadline.weight(.semibold))
                            if let room = change.room {
                                Text(room)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        Spacer()
                        Text(change.kind.label)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(change.kind.isRegression ? .red : .green)
                    }
                    .padding(.vertical, 2)
                }
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title3)
                        .foregroundStyle(.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("No Changes Since Baseline")
                            .font(.subheadline.weight(.semibold))
                        Text("Network topology matches the saved snapshot exactly.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        } header: {
            HStack {
                Text("Changes Since Baseline")
                Spacer()
                if diff.regressions.count > 0 {
                    Text("\(diff.regressions.count) regression\(diff.regressions.count == 1 ? "" : "s")")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.red)
                }
            }
        } footer: {
            Text("Baseline captured \(diff.baselineAt, style: .relative) ago — \(diff.changes.count) change\(diff.changes.count == 1 ? "" : "s") detected.")
                .font(.caption)
        }
    }

    // MARK: - Signal Degradation

    @ViewBuilder
    private func signalTrendSection(_ alerts: [NetworkDiagnosticsEngine.SignalTrendAlert]) -> some View {
        Section {
            ForEach(alerts) { alert in
                HStack(spacing: 12) {
                    Image(systemName: "chart.line.downtrend.xyaxis")
                        .foregroundStyle(.orange)
                        .font(.title3)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(alert.device.name)
                            .font(.subheadline.weight(.semibold))
                        HStack(spacing: 6) {
                            Text("\(alert.baselineAvgRSSI) dBm")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                            Image(systemName: "arrow.right")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("\(alert.recentAvgRSSI) dBm")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.red)
                                .monospacedDigit()
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("−\(alert.degradationDB)")
                            .font(.callout.weight(.bold).monospacedDigit())
                            .foregroundStyle(.orange)
                        Text("dBm")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 2)
            }
        } header: {
            Label("Signal Degradation", systemImage: "chart.line.downtrend.xyaxis")
        } footer: {
            Text("Devices whose average signal dropped 8+ dBm over the last 30 minutes. This can indicate new interference, physical obstruction, or a device in need of attention.")
                .font(.caption)
        }
    }

    // MARK: - Failure Impact Analysis

    @ViewBuilder
    private func resilienceSection(_ nodes: [NetworkDiagnosticsEngine.ResilienceNode]) -> some View {
        Section {
            ForEach(nodes) { node in
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.red.opacity(0.1))
                            .frame(width: 38, height: 38)
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(.red.opacity(0.85))
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(node.device.name)
                            .font(.subheadline.weight(.semibold))
                        Text("Failure would isolate \(node.isolatedCount) device\(node.isolatedCount == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if !node.isolatedNames.isEmpty {
                            Text(node.isolatedNames.joined(separator: " · "))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                    Text("\(node.isolatedCount)")
                        .font(.title3.weight(.bold).monospacedDigit())
                        .foregroundStyle(node.isolatedCount >= 3 ? .red : .orange)
                }
                .padding(.vertical, 3)
            }
        } header: {
            Label("Failure Impact", systemImage: "exclamationmark.shield.fill")
        } footer: {
            Text("How many end devices would lose internet access if each routing device were to fail. Add a second router nearby to eliminate single points of failure.")
                .font(.caption)
        }
    }

    // MARK: - Channel Analysis

    @ViewBuilder
    private func channelAnalysisSection(_ channels: [NetworkDiagnosticsEngine.ChannelStats]) -> some View {
        Section {
            ForEach(channels) { stats in
                HStack(spacing: 14) {
                    // Channel badge
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(stats.interferenceRisk.color.opacity(0.12))
                            .frame(width: 48, height: 40)
                        VStack(spacing: 1) {
                            Text("CH")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundStyle(stats.interferenceRisk.color.opacity(0.8))
                            Text("\(stats.channel)")
                                .font(.system(.headline, design: .rounded, weight: .bold))
                                .foregroundStyle(stats.interferenceRisk.color)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text("\(stats.frequencyMHz) MHz")
                                .font(.subheadline.weight(.semibold))
                                .monospacedDigit()
                            Image(systemName: stats.interferenceRisk.icon)
                                .imageScale(.small)
                                .foregroundStyle(stats.interferenceRisk.color)
                            Text(stats.interferenceRisk.label + " interference risk")
                                .font(.caption2)
                                .foregroundStyle(stats.interferenceRisk.color)
                        }
                        Text("\(stats.deviceCount) device\(stats.deviceCount == 1 ? "" : "s"): \(stats.deviceNames.prefix(3).joined(separator: ", "))\(stats.deviceNames.count > 3 ? "…" : "")")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .padding(.vertical, 2)
            }
        } header: {
            Text("Thread Channel Analysis")
        } footer: {
            Text("Thread uses 2.4 GHz channels 11–26. Channels 15, 20, and 25 have the lowest overlap with Wi-Fi 2.4 GHz. Channels 11–14, 17–19, and 22–24 overlap with Wi-Fi non-overlapping channels 1, 6, and 11.")
                .font(.caption)
        }
    }

    // MARK: - OTBR Thread Dataset

    @ViewBuilder
    private func otbrDatasetSection(_ info: OTBRThreadInfo) -> some View {
        Section {
            if let name = info.networkName {
                otbrRow(label: "Network Name", value: name, icon: "network")
            }
            if let ch = info.channel {
                otbrRow(label: "Channel", value: "\(ch)", icon: "waveform")
            }
            if let pan = info.panID {
                otbrRow(label: "PAN ID", value: pan, icon: "number")
            }
            if let ext = info.extPanID {
                otbrRow(label: "Extended PAN ID", value: ext, icon: "key.horizontal")
            }
            if let prefix = info.meshLocalPrefix {
                otbrRow(label: "Mesh Local Prefix", value: prefix, icon: "network.badge.shield.half.filled")
            }
            if let hours = info.keyRotationHours {
                let days = hours / 24
                let detail = days > 0 ? "\(days) day\(days == 1 ? "" : "s") (\(hours) h)" : "\(hours) h"
                otbrRow(label: "Key Rotation", value: detail, icon: "arrow.clockwise.circle")
            }
            if let role = info.role {
                otbrRow(label: "OTBR Role", value: role.capitalized, icon: "antenna.radiowaves.left.and.right",
                        valueColor: role == "leader" ? .green : .primary)
            }
            if let rloc = info.rloc16 {
                otbrRow(label: "RLOC16", value: rloc, icon: "location.circle")
            }
        } header: {
            HStack(spacing: 6) {
                Text("Thread Network Identity")
                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)
                Text("LIVE")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.green)
            }
        } footer: {
            Text("Live data from your OpenThread Border Router. The Extended PAN ID uniquely identifies this Thread network — useful for verifying commissioning targets.")
                .font(.caption)
        }
    }

    private func otbrRow(label: String, value: String, icon: String, valueColor: Color = .secondary) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .imageScale(.small)
                .frame(width: 20)
            Text(label)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.caption.monospacedDigit())
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }

    // MARK: - Helpers

    private func iconForDevice(_ device: ThreadDevice) -> String {
        if device.isBorderRouter { return "antenna.radiowaves.left.and.right" }
        if device.isRoutingCapable { return "point.3.connected.trianglepath.dotted" }
        if device.batteryPercentage != nil { return "battery.50" }
        return "circle.dotted"
    }

    private func hopLabel(_ hop: Int) -> String {
        if hop == 99 { return "Unreachable" }
        if hop == 1  { return "1 Hop (Border Router)" }
        return "\(hop) Hops"
    }

    private func hopIcon(_ hop: Int) -> String {
        switch hop {
        case 99: return "wifi.slash"
        case 1:  return "antenna.radiowaves.left.and.right"
        case 2:  return "2.circle"
        case 3:  return "3.circle"
        default: return "exclamationmark.circle"
        }
    }

    private func hopColor(_ hop: Int) -> Color {
        switch hop {
        case 99:        return .red
        case 1, 2:      return .primary
        case 3:         return .orange
        default:        return .red
        }
    }

    // MARK: - Diagnostic History

    @ViewBuilder
    private func diagnosticHistorySection() -> some View {
        let recent = Array(runStore.runs.prefix(10))
        let chartRuns = Array(runStore.runs.prefix(15).reversed())

        Section {
            if chartRuns.count >= 2 {
                Chart {
                    ForEach(Array(chartRuns.enumerated()), id: \.element.id) { i, run in
                        BarMark(
                            x: .value("Run", i),
                            y: .value("Score", run.score)
                        )
                        .foregroundStyle(scoreColor(run.score))
                        .cornerRadius(3)
                    }
                    RuleMark(y: .value("Target", 80))
                        .foregroundStyle(.green.opacity(0.45))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 2]))
                }
                .chartYScale(domain: 0...100)
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(values: [0, 50, 80, 100]) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                        AxisValueLabel {
                            if let v = value.as(Int.self) {
                                Text("\(v)").font(.system(size: 8))
                            }
                        }
                    }
                }
                .frame(height: 90)
                .padding(.vertical, 4)
            }

            ForEach(recent) { run in
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(scoreColor(run.score).opacity(0.15))
                            .frame(width: 42, height: 42)
                        Text("\(run.score)")
                            .font(.system(.callout, design: .rounded).weight(.bold))
                            .foregroundStyle(scoreColor(run.score))
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 4) {
                            Text(run.timestamp, style: .relative)
                                .font(.subheadline.weight(.medium))
                            Text("ago")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        HStack(spacing: 6) {
                            if run.criticalCount > 0 { runChip("\(run.criticalCount) critical", .red) }
                            if run.highCount > 0     { runChip("\(run.highCount) high", .orange) }
                            if run.isolatedDeviceCount > 0 { runChip("\(run.isolatedDeviceCount) isolated", .red) }
                            if run.criticalCount == 0 && run.highCount == 0 && run.isolatedDeviceCount == 0 {
                                runChip("Healthy", .green)
                            }
                        }
                    }

                    Spacer()

                    if let idx = runStore.runs.firstIndex(where: { $0.id == run.id }),
                       idx + 1 < runStore.runs.count {
                        let delta = run.score - runStore.runs[idx + 1].score
                        if delta != 0 {
                            Label(delta > 0 ? "+\(delta)" : "\(delta)",
                                  systemImage: delta > 0 ? "arrow.up" : "arrow.down")
                                .font(.caption2.monospacedDigit().weight(.semibold))
                                .foregroundStyle(delta > 0 ? .green : .red)
                                .labelStyle(.titleAndIcon)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        } header: {
            HStack {
                Text("Diagnostic History")
                Spacer()
                Text("\(runStore.runs.count) run\(runStore.runs.count == 1 ? "" : "s")")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        } footer: {
            Text("Score = 100 minus issue penalties (−20 per critical, −10 per high, −5 per medium, −15 per isolated device). Green line = 80 target. Saved automatically on each refresh.")
                .font(.caption)
        }
    }

    private func runChip(_ label: String, _ color: Color) -> some View {
        Text(label)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.12), in: Capsule())
    }

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 80...: return .green
        case 60..<80: return .yellow
        case 40..<60: return .orange
        default: return .red
        }
    }

    // MARK: - Export

    @ViewBuilder
    private func exportSection(_ report: NetworkDiagnosticsEngine.Report) -> some View {
        let diff: SnapshotDiff? = currentSnapshot.flatMap { snap in
            baseline.map { base in base.diff(against: snap) }
        }
        Section {
            ShareLink(
                item: generateReportText(report, diff: diff),
                subject: Text("ThreadMapper Diagnostic Report"),
                message: Text("Network diagnostic report from ThreadMapper")
            ) {
                Label("Share Diagnostic Report", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        } footer: {
            Text("Exports a plain-text summary of this diagnostic run — useful for sharing with support forums or keeping a network health snapshot.")
                .font(.caption)
        }
    }

    private func generateReportText(_ report: NetworkDiagnosticsEngine.Report, diff: SnapshotDiff? = nil) -> String {
        let dateStr = Date().formatted(.dateTime.month().day().year().hour().minute())
        var lines: [String] = [
            "ThreadMapper Network Diagnostic Report",
            "Generated: \(dateStr)",
            "─────────────────────────────────────",
            "",
            "NETWORK SUMMARY",
            "  Border Routers : \(report.totalBorderRouters)",
            "  Mesh Routers   : \(report.totalRouters)",
            "  Critical Issues: \(report.recommendations.filter { $0.priority == .critical }.count)",
            "",
        ]

        // Baseline comparison
        if let diff {
            let ago = diff.baselineAt.formatted(.relative(presentation: .numeric))
            lines.append("BASELINE COMPARISON (saved \(ago))")
            if diff.hasChanges {
                for c in diff.changes {
                    let tag = c.kind.isRegression ? "[REGRESSION]" : "[IMPROVEMENT]"
                    lines.append("  \(tag) \(c.name): \(c.kind.label)")
                }
            } else {
                lines.append("  No changes detected since baseline.")
            }
            lines.append("")
        }

        // Recommendations
        lines.append("RECOMMENDATIONS (\(report.recommendations.count))")
        if report.recommendations.isEmpty {
            lines.append("  ✓ No issues detected — network looks healthy.")
        } else {
            for rec in report.recommendations {
                lines.append("  [\(rec.priority.label.uppercased())] \(rec.title)")
                lines.append("    \(rec.detail)")
            }
        }
        lines.append("")

        // Room coverage
        if !report.roomCoverage.isEmpty {
            lines.append("ROOM COVERAGE")
            for room in report.roomCoverage {
                let rssiStr = room.avgRSSI.map { "\($0) dBm" } ?? "no RSSI"
                let routerStr = room.hasRouter ? "has router" : "no router"
                lines.append("  \(room.grade)  \(room.room) — \(room.onlineDevices)/\(room.totalDevices) online, \(rssiStr), \(routerStr)")
            }
            lines.append("")
        }

        // Mesh depth
        let grouped = Dictionary(grouping: report.deviceHops) { $0.hopCount }
        let sortedHops = grouped.keys.sorted()
        lines.append("MESH DEPTH")
        for hop in sortedHops {
            let count = grouped[hop]?.count ?? 0
            let label = hop == 99 ? "Unreachable" : "\(hop) hop\(hop == 1 ? "" : "s")"
            lines.append("  \(label): \(count) device\(count == 1 ? "" : "s")")
        }
        lines.append("")

        // Channel analysis
        if !report.channelStats.isEmpty {
            lines.append("THREAD CHANNEL ANALYSIS")
            for ch in report.channelStats {
                lines.append("  CH \(ch.channel) (\(ch.frequencyMHz) MHz) — \(ch.interferenceRisk.label) interference risk, \(ch.deviceCount) device\(ch.deviceCount == 1 ? "" : "s")")
            }
            lines.append("")
        }

        // SPOFs
        if !report.singlePointsOfFailure.isEmpty {
            lines.append("SINGLE-POINT ROUTERS")
            for d in report.singlePointsOfFailure {
                lines.append("  • \(d.name) (\(d.room ?? "unassigned location"))")
            }
            lines.append("")
        }

        // Failure impact
        if !report.resilienceNodes.isEmpty {
            lines.append("FAILURE IMPACT ANALYSIS")
            for n in report.resilienceNodes {
                lines.append("  \(n.device.name) → \(n.isolatedCount) device\(n.isolatedCount == 1 ? "" : "s") isolated if removed")
                if !n.isolatedNames.isEmpty {
                    lines.append("    (\(n.isolatedNames.joined(separator: ", ")))")
                }
            }
            lines.append("")
        }

        // Signal degradation
        if !report.signalTrendAlerts.isEmpty {
            lines.append("SIGNAL DEGRADATION (last 30 min)")
            for a in report.signalTrendAlerts {
                lines.append("  \(a.device.name): \(a.baselineAvgRSSI) → \(a.recentAvgRSSI) dBm (−\(a.degradationDB) dBm)")
            }
            lines.append("")
        }

        // Isolated partitions
        if !report.partitions.isEmpty {
            let totalIsolated = report.partitions.reduce(0) { $0 + $1.devices.count }
            lines.append("ISOLATED CLUSTERS (\(totalIsolated) devices)")
            for (i, partition) in report.partitions.enumerated() {
                let gateway = partition.gatewayDevice?.name ?? "unknown"
                lines.append("  Cluster \(i + 1): \(partition.devices.count) device\(partition.devices.count == 1 ? "" : "s") — missing link: \(gateway)")
                for d in partition.devices {
                    lines.append("    • \(d.name)\(d.room.map { " (\($0))" } ?? "")")
                }
            }
            lines.append("")
        }

        lines.append("─────────────────────────────────────")
        lines.append("Generated by ThreadMapper")
        return lines.joined(separator: "\n")
    }

    private func runAnalysis() {
        guard !devices.isEmpty else { return }
        isAnalyzing = true
        report = nil
        otbrInfo = nil
        Task {
            let trends = buildTrends()
            async let infoFetch = fetchOTBRInfo()
            let result = NetworkDiagnosticsEngine.analyze(devices: devices, trendsByDeviceID: trends)
            let info = await infoFetch
            report = result
            currentSnapshot = TopologySnapshot.capture(report: result, devices: devices)
            otbrInfo = info
            runStore.record(result)
            isAnalyzing = false
        }
    }

    private func fetchOTBRInfo() async -> OTBRThreadInfo? {
        guard !borderRouterURL.isEmpty, let url = URL(string: borderRouterURL) else { return nil }
        let client = BorderRouterClient(baseURL: url)
        async let nodeResult = client.nodeInfo()
        async let datasetResult = client.activeDataset()
        let (node, dataset) = await (nodeResult, datasetResult)
        guard node != nil || dataset != nil else { return nil }
        let panIDStr = dataset?.panId.map { String(format: "0x%04X", $0) }
        let rloc16Str = node?.rloc16.map { String(format: "0x%04X", $0) }
        return OTBRThreadInfo(
            networkName: dataset?.networkName ?? node?.networkName,
            channel: dataset?.channel,
            panID: panIDStr,
            extPanID: dataset?.extPanId ?? node?.extPanId,
            meshLocalPrefix: dataset?.meshLocalPrefix,
            keyRotationHours: dataset?.securityPolicy?.rotationTime,
            role: node?.state,
            rloc16: rloc16Str
        )
    }

    private func buildTrends() -> [UUID: [Int]] {
        var out: [UUID: [Int]] = [:]
        for device in devices {
            if let s = statsStore.stats(for: device.uniqueIdentifier) {
                out[device.uniqueIdentifier] = s.readings.map(\.rssi)
            }
        }
        return out
    }
}
