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
    @Environment(DeviceStatsStore.self) var statsStore
    @AppStorage("borderRouterURL") private var borderRouterURL = ""
    @ScaledMetric(relativeTo: .largeTitle) var heroIconSize: CGFloat = 48
    @ScaledMetric(relativeTo: .caption2) var microLabelSize: CGFloat = 9

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
                .font(.system(size: heroIconSize))
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
            scorecardSection(NetworkDiagnosticsEngine.scoreDimensions(from: report))
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
            compatibilityOverviewSection(devices)
            firmwareOverviewSection(devices)
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
                let detail = days > 0 ? "\(days) \(days == 1 ? "day" : "days") (\(hours) h)" : "\(hours) h"
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
                    .font(.system(size: microLabelSize, weight: .bold))
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
                                Text(verbatim: "\(v)").font(.system(size: microLabelSize))
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
                Text("^[\(runStore.runs.count) run](inflect: true)")
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
                lines.append("  [\(String(localized: rec.priority.label).uppercased())] \(rec.title)")
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
            let label = hop == 99 ? String(localized: "Unreachable") : String(localized: "^[\(hop) hop](inflect: true)")
            lines.append(String(localized: "  \(label): ^[\(count) device](inflect: true)"))
        }
        lines.append("")

        // Channel analysis
        if !report.channelStats.isEmpty {
            lines.append("THREAD CHANNEL ANALYSIS")
            for ch in report.channelStats {
                lines.append(String(localized: "  CH \(ch.channel) (\(ch.frequencyMHz) MHz) — \(ch.interferenceRisk.label) interference risk, ^[\(ch.deviceCount) device](inflect: true)"))
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
                lines.append(String(localized: "  \(n.device.name) → ^[\(n.isolatedCount) device](inflect: true) isolated if removed"))
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
                lines.append(String(localized: "  Cluster \(i + 1): ^[\(partition.devices.count) device](inflect: true) — missing link: \(gateway)"))
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
            UINotificationFeedbackGenerator().notificationOccurred(.success)
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
