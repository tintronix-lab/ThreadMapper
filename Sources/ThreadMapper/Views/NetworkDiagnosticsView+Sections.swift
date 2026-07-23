import Charts
import SwiftUI

extension NetworkDiagnosticsView {
    // MARK: - Scorecard

    @ViewBuilder
    func scorecardSection(_ dimensions: [NetworkDiagnosticsEngine.ScoreDimension]) -> some View {
        let overall = dimensions.reduce(0) { $0 + $1.score } / max(1, dimensions.count)
        let overallColor: Color = overall >= 80 ? .green : overall >= 60 ? .mint : overall >= 40 ? .orange : .red

        Section {
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: overall >= 80 ? "checkmark.seal.fill" : overall >= 60 ? "exclamationmark.circle.fill" : "xmark.octagon.fill")
                        .foregroundStyle(overallColor)
                    Text("Overall mesh fitness: ")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    + Text("\(overall)/100")
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(overallColor)
                    Spacer()
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(dimensions) { dim in
                        dimensionTile(dim)
                    }
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("Mesh Quality Scorecard")
        } footer: {
            Text("Each dimension is scored independently. Tap a finding below for remediation steps.")
                .font(.caption)
        }
    }

    private func dimensionTile(_ dim: NetworkDiagnosticsEngine.ScoreDimension) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: dim.icon)
                    .foregroundStyle(dim.color)
                    .imageScale(.small)
                Spacer()
                Text(dim.grade)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(dim.color)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(dim.color.opacity(0.15), in: Capsule())
            }
            HStack(alignment: .bottom, spacing: 2) {
                Text("\(dim.score)")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(dim.color)
                    .monospacedDigit()
                Text("/100")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.tertiary)
                    .padding(.bottom, 3)
            }
            Text(dim.name)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(dim.color)
                        .frame(width: geo.size.width * CGFloat(dim.score) / 100, height: 4)
                }
            }
            .frame(height: 4)
        }
        .padding(12)
        .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    var healthySection: some View {
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
    func recommendationsSection(_ recs: [NetworkDiagnosticsEngine.Recommendation]) -> some View {
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
    func roomCoverageSection(_ coverage: [NetworkDiagnosticsEngine.RoomCoverage]) -> some View {
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
    func roomSignalTrendSection(_ coverage: [NetworkDiagnosticsEngine.RoomCoverage]) -> some View {
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
    func borderRouterComparisonSection(_ report: NetworkDiagnosticsEngine.Report) -> some View {
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
    func meshDepthSection(_ hops: [NetworkDiagnosticsEngine.DeviceHopInfo]) -> some View {
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
    func spofSection(_ devices: [ThreadDevice]) -> some View {
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
    func partitionsSection(_ partitions: [NetworkDiagnosticsEngine.NetworkPartition]) -> some View {
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
                                .font(.body)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text("^[\(partition.devices.count) device](inflect: true) isolated")
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
            Label("Isolated Clusters — ^[\(totalIsolated) device](inflect: true)", systemImage: "wifi.slash")
                .foregroundStyle(.red)
        } footer: {
            Text("These devices have no path to any border router. They cannot be controlled remotely until the missing routing link is restored.")
                .font(.caption)
        }
    }

    // MARK: - Baseline Comparison

    @ViewBuilder
    func snapshotComparisonSection(_ diff: SnapshotDiff) -> some View {
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
                    Text("^[\(diff.regressions.count) regression](inflect: true)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.red)
                }
            }
        } footer: {
            Text("Baseline captured \(diff.baselineAt, style: .relative) ago — ^[\(diff.changes.count) change](inflect: true) detected.")
                .font(.caption)
        }
    }

    // MARK: - Signal Degradation

    @ViewBuilder
    func signalTrendSection(_ alerts: [NetworkDiagnosticsEngine.SignalTrendAlert]) -> some View {
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
                            .font(.system(size: microLabelSize))
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
    func resilienceSection(_ nodes: [NetworkDiagnosticsEngine.ResilienceNode]) -> some View {
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
                        Text("Failure would isolate ^[\(node.isolatedCount) device](inflect: true)")
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
    func channelAnalysisSection(_ channels: [NetworkDiagnosticsEngine.ChannelStats]) -> some View {
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
                                .font(.system(size: microLabelSize, weight: .semibold))
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
                            (Text(stats.interferenceRisk.label) + Text(" interference risk"))
                                .font(.caption2)
                                .foregroundStyle(stats.interferenceRisk.color)
                        }
                        Text("^[\(stats.deviceCount) device](inflect: true): \(stats.deviceNames.prefix(3).joined(separator: ", "))\(stats.deviceNames.count > 3 ? "…" : "")")
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

    // MARK: - Helpers

    private func iconForDevice(_ device: ThreadDevice) -> String {
        if device.isBorderRouter { return "antenna.radiowaves.left.and.right" }
        if device.isRoutingCapable { return "point.3.connected.trianglepath.dotted" }
        if device.batteryPercentage != nil { return "battery.50" }
        return "circle.dotted"
    }

    private func hopLabel(_ hop: Int) -> String {
        if hop == 99 { return "Unreachable" }
        if hop == 1 { return "1 Hop (Border Router)" }
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

}
