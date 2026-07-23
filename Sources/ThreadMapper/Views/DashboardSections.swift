import SwiftUI
import Charts
import OSLog

private let log = Logger(subsystem: "com.tintronixlab.ThreadMapper", category: "DashboardSections")

// MARK: - Topology Banner

struct DashboardTopologyBanner: View {
    let changes: [MeshViewModel.TopologyChange]

    var body: some View {
        let recent = changes.filter { Date().timeIntervalSince($0.timestamp) < 300 }
        if let change = recent.first {
            Section {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundStyle(.blue)
                        .imageScale(.medium)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Network topology changed")
                            .font(.subheadline.weight(.semibold))
                        if !change.joined.isEmpty {
                            Text("Joined: \(change.joined.joined(separator: ", "))")
                                .font(.caption2).foregroundStyle(.green)
                        }
                        if !change.left.isEmpty {
                            Text("Left: \(change.left.joined(separator: ", "))")
                                .font(.caption2).foregroundStyle(.red)
                        }
                        Text(change.timestamp, style: .relative)
                            .font(.caption2).foregroundStyle(.secondary)
                            .padding(.top, 1)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}

// MARK: - Anomaly Banner

struct DashboardAnomalyBanner: View {
    let anomalies: [UUID: DeviceAnomaly]
    let devices: [ThreadDevice]

    private var criticalDevices: [ThreadDevice] {
        devices.filter { anomalies[$0.uniqueIdentifier]?.trajectory == .critical }
    }
    private var decliningDevices: [ThreadDevice] {
        devices.filter { anomalies[$0.uniqueIdentifier]?.trajectory == .declining }
    }

    var body: some View {
        let critCount = criticalDevices.count
        let declCount = decliningDevices.count
        guard critCount + declCount > 0 else { return AnyView(EmptyView()) }

        let isCritical = critCount > 0
        let color: Color = isCritical ? .red : .orange
        let icon = isCritical ? "exclamationmark.triangle.fill" : "arrow.down.right.circle.fill"
        let names: [String] = (criticalDevices + decliningDevices).prefix(2).map(\.name)

        return AnyView(
            Section {
                HStack(spacing: 10) {
                    Image(systemName: icon).foregroundStyle(color).imageScale(.medium)
                    VStack(alignment: .leading, spacing: 2) {
                        anomalyLabel(critCount: critCount, declCount: declCount, names: names)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(color)
                        Text("Check the Mesh tab for trajectory details.")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 4)
            }
        )
    }

    private func anomalyLabel(critCount: Int, declCount: Int, names: [String]) -> Text {
        if critCount > 0 && declCount > 0 {
            let total = critCount + declCount
            let tail = total > 2 ? "…" : ""
            return Text("^[\(total) device](inflect: true) degrading — \(names.joined(separator: ", "))\(tail)")
        } else if critCount > 0 {
            if critCount == 1 {
                return Text("\(names[0]) showing critical signal drop")
            } else {
                return Text("^[\(critCount) device](inflect: true) showing critical signal drop")
            }
        } else {
            if declCount == 1 {
                return Text("\(names[0]) signal declining")
            } else {
                return Text("^[\(declCount) device](inflect: true) signal declining")
            }
        }
    }
}

// MARK: - Health Hero

struct DashboardHealthSection: View {
    let health: NetworkHealthScore
    let devices: [ThreadDevice]
    let onSelectFilter: (DeviceFilterSpec) -> Void
    @Binding var showPaywall: Bool

    @ScaledMetric(relativeTo: .caption2) private var statLabelSize: CGFloat = 9

    var body: some View {
        Section {
            HStack(alignment: .center, spacing: 20) {
                GradeRingView(health: health)

                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(health.summary)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(2)
                        Text("\(health.score) / 100 pts")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(health.color)
                    }

                    let offline = devices.filter(\.isOffline)
                    let weak    = devices.filter(\.isWeak)
                    let routers = devices.filter(\.isRoutingCapable)

                    VStack(spacing: 6) {
                        HStack(spacing: 6) {
                            statCard(icon: "cpu.fill", value: "\(devices.count)",
                                label: "Devices", tint: .accentColor,
                                spec: DeviceFilterSpec(title: String(localized: "All Devices"), category: .all))
                            statCard(icon: "antenna.radiowaves.left.and.right",
                                value: "\(routers.count)",
                                label: "Routers", tint: .indigo,
                                spec: DeviceFilterSpec(title: String(localized: "Routers"), category: .routers))
                        }
                        HStack(spacing: 6) {
                            statCard(
                                icon: offline.count > 0 ? "wifi.slash" : "wifi.circle.fill",
                                value: "\(offline.count)",
                                label: "Offline",
                                tint: offline.count > 0 ? .red : .green,
                                spec: DeviceFilterSpec(title: String(localized: "Offline Devices"), category: .offline))
                            statCard(
                                icon: weak.count > 0 ? "wifi.exclamationmark" : "checkmark.circle.fill",
                                value: "\(weak.count)",
                                label: "Weak",
                                tint: weak.count > 0 ? .orange : .green,
                                spec: DeviceFilterSpec(title: String(localized: "Weak Signal Devices"), category: .weak))
                        }
                    }
                }
            }
            .padding(.vertical, 8)
        } header: {
            HStack {
                Text("Network Health")
                Spacer()
                let streak = HealthStreakStore.shared.currentStreak
                if streak >= 2 {
                    if ProStore.shared.isPro {
                        Label("\(streak)-day streak", systemImage: "flame.fill")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.orange)
                    } else {
                        Button { showPaywall = true } label: {
                            Label("Streak", systemImage: "lock.fill")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    /// Buttons — unlike NavigationLinks — have no one-per-List-row restriction, so
    /// all four tiles in the shared hero row stay independently tappable.
    @ViewBuilder
    private func statCard(icon: String, value: String, label: String, tint: Color, spec: DeviceFilterSpec) -> some View {
        Button { onSelectFilter(spec) } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(tint)
                    .frame(width: 14)
                VStack(alignment: .leading, spacing: 0) {
                    Text(value)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.primary)
                    Text(label)
                        .font(.system(size: statLabelSize))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Achievements

struct DashboardAchievementsSection: View {
    let achievementStore: AchievementStore
    @Binding var showAchievements: Bool

    var body: some View {
        let unlocked = achievementStore.unlockedCount
        let total = achievementStore.achievements.count
        if unlocked > 0 {
            Section {
                Button { showAchievements = true } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "trophy.fill")
                            .font(.title3)
                            .foregroundStyle(.yellow)
                            .frame(width: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Achievements")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text("\(unlocked) of \(total) unlocked")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        HStack(spacing: 4) {
                            ForEach(achievementStore.achievements.filter(\.isUnlocked).prefix(3)) { a in
                                Image(systemName: a.icon)
                                    .font(.caption2)
                                    .foregroundStyle(.yellow)
                            }
                        }
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Trend Sparkline

struct DashboardTrendSection: View {
    @Environment(DeviceStatsStore.self) private var statsStore

    var body: some View {
        let buckets = statsStore.networkTrendBuckets()
        if buckets.count >= 3 {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Response Quality (estimated) — Last 30 min")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if let last = buckets.last {
                            Text(last.avgRSSI.rssiQualityLabel)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(last.avgRSSI.rssiColor)
                        }
                    }
                    let readings = buckets.map {
                        DeviceStatsStore.Reading(timestamp: $0.timestamp, rssi: $0.avgRSSI)
                    }
                    SignalSparklineView(readings: readings)
                        .frame(height: 56)
                }
                .padding(.vertical, 4)
            }
        }
    }
}

// MARK: - Room Health Grid (NF-2)

struct DashboardRoomHealthGrid: View {
    let devices: [ThreadDevice]
    let anomalies: [UUID: DeviceAnomaly]
    @Binding var selectedRoom: String?

    struct RoomSummary: Identifiable {
        let id: String
        let room: String
        let total: Int
        let offline: Int
        let weak: Int
        let declining: Int
        let grade: String
        let color: Color

        static func compute(room: String, devices: [ThreadDevice], anomalies: [UUID: DeviceAnomaly]) -> RoomSummary {
            let offline  = devices.filter(\.isOffline).count
            let weak     = devices.filter(\.isWeak).count
            let declining = devices.filter { anomalies[$0.uniqueIdentifier]?.trajectory != .stable && anomalies[$0.uniqueIdentifier] != nil }.count
            var score = 100
            score -= min(40, offline  * 20)
            score -= min(20, weak     * 7)
            score -= min(10, declining * 5)
            score = max(0, score)
            let (grade, color): (String, Color)
            switch score {
            case 90...: (grade, color) = ("A", .green)
            case 75..<90: (grade, color) = ("B", .mint)
            case 60..<75: (grade, color) = ("C", .yellow)
            case 40..<60: (grade, color) = ("D", .orange)
            default: (grade, color) = ("F", .red)
            }
            return RoomSummary(id: room, room: room, total: devices.count,
                               offline: offline, weak: weak, declining: declining,
                               grade: grade, color: color)
        }
    }

    private var rooms: [RoomSummary] {
        Dictionary(grouping: devices) { $0.room ?? "Unknown" }
            .map { RoomSummary.compute(room: $0.key, devices: $0.value, anomalies: anomalies) }
            .sorted { $0.room < $1.room }
    }

    var body: some View {
        let summaries = rooms
        guard summaries.count > 1 else { return AnyView(EmptyView()) }
        return AnyView(
            Section {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
                    ForEach(summaries) { summary in
                        RoomHealthCard(summary: summary, isSelected: selectedRoom == summary.room)
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    selectedRoom = selectedRoom == summary.room ? nil : summary.room
                                }
                            }
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Label("Room Health", systemImage: "house.and.flag")
            }
        )
    }
}

private struct RoomHealthCard: View {
    let summary: DashboardRoomHealthGrid.RoomSummary
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                Text(summary.room)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .foregroundStyle(isSelected ? .white : .primary)
                Spacer()
                Text(summary.grade)
                    .font(.title2.weight(.black))
                    .foregroundStyle(isSelected ? .white : summary.color)
            }
            HStack(spacing: 8) {
                Label("\(summary.total)", systemImage: "sensor.tag.radiowaves.forward")
                    .font(.caption2)
                    .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                if summary.offline > 0 {
                    Label("\(summary.offline)", systemImage: "network.slash")
                        .font(.caption2)
                        .foregroundStyle(isSelected ? .white : .red)
                }
            }
        }
        .padding(10)
        .background(
            isSelected
                ? RoundedRectangle(cornerRadius: 10).fill(summary.color)
                : RoundedRectangle(cornerRadius: 10).fill(summary.color.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(summary.color.opacity(isSelected ? 0 : 0.25), lineWidth: 1)
        )
    }
}

// MARK: - Room Coverage

struct DashboardRoomCoverageSection: View {
    // Grouping lives here (not in DashboardView) so the parent's frequent
    // presentation-state churn doesn't redo it — SwiftUI skips this body
    // entirely while `devices` is unchanged.
    let devices: [ThreadDevice]
    @Binding var selectedRoom: String?
    let isExpanded: Bool
    let onToggle: () -> Void
    @Environment(DeviceStatsStore.self) private var statsStore

    private var roomGroups: [(room: String, devices: [ThreadDevice])] {
        Dictionary(grouping: devices) { $0.room ?? "Unknown" }
            .map { (room: $0.key, devices: $0.value) }
            .sorted { $0.room < $1.room }
    }

    var body: some View {
        Section {
            Button {
                onToggle()
                log.debug("roomCoverage toggled → \(isExpanded)")
            } label: {
                HStack {
                    Text("Room Coverage")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                        .animation(.easeInOut(duration: 0.2), value: isExpanded)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                if selectedRoom != nil {
                    Button("Show All") { selectedRoom = nil }
                        .foregroundStyle(.tint)
                }
                ForEach(roomGroups, id: \.room) { group in
                    roomRow(group.room, group.devices)
                }
            }
        }
    }

    @ViewBuilder
    private func roomRow(_ room: String, _ devices: [ThreadDevice]) -> some View {
        let offline = devices.filter(\.isOffline).count
        let weak = devices.filter(\.isWeak).count
        let grades = devices.compactMap { statsStore.stats(for: $0.uniqueIdentifier)?.healthGrade }
        let worstGrade = ["F", "D", "C", "B", "A"].first { grades.contains($0) }

        Button {
            selectedRoom = selectedRoom == room ? nil : room
        } label: {
            HStack(spacing: 10) {
                Image(systemName: TMStyle.roomIcon(room))
                    .foregroundStyle(selectedRoom == room ? Color.accentColor : Color.secondary)
                    .imageScale(.small)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(room)
                        .font(.subheadline.weight(selectedRoom == room ? .semibold : .regular))
                        .foregroundStyle(.primary)
                    HStack(spacing: 6) {
                        Text("^[\(devices.count) device](inflect: true)")
                            .font(.caption2).foregroundStyle(.secondary)
                        if weak > 0 { Text("· \(weak) weak").font(.caption2).foregroundStyle(.orange) }
                        if offline > 0 { Text("· \(offline) offline").font(.caption2).foregroundStyle(.red) }
                    }
                }

                Spacer()

                if let g = worstGrade {
                    Text(g)
                        .font(.system(.callout, design: .rounded, weight: .bold))
                        .foregroundStyle(TMStyle.gradeColor(g))
                }

                Image(systemName: selectedRoom == room ? "chevron.down" : "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
        .padding(.vertical, 2)
    }
}

// MARK: - Device List

struct DashboardDeviceSection: View {
    let filteredDevices: [ThreadDevice]
    @Binding var selectedRoom: String?
    let isExpanded: Bool
    let onToggle: () -> Void
    let isScanning: Bool
    let onSelectDevice: (ThreadDevice) -> Void

    var body: some View {
        Section {
            Button {
                onToggle()
                log.debug("allDevices toggled → \(isExpanded)")
            } label: {
                HStack {
                    Text(selectedRoom ?? "All Devices")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                    if selectedRoom != nil {
                        Text("Clear Filter")
                            .font(.caption)
                            .foregroundStyle(.tint)
                            .padding(.trailing, 4)
                    }
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                        .animation(.easeInOut(duration: 0.2), value: isExpanded)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                if filteredDevices.isEmpty {
                    if isScanning {
                        HStack {
                            Spacer()
                            VStack(spacing: 8) {
                                ProgressView()
                                Text("Contacting HomeKit…")
                                    .foregroundStyle(.secondary)
                                    .font(.subheadline)
                            }
                            .padding()
                            Spacer()
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("No Thread devices found", systemImage: "network.slash")
                                .font(.subheadline).foregroundStyle(.secondary)
                            Text("Open the Home app and add your Thread border router and accessories, then tap Rescan.")
                                .font(.caption).foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 6)
                    }
                } else {
                    ForEach(filteredDevices) { device in
                        Button { onSelectDevice(device) } label: {
                            DeviceListRow(device: device)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button { onSelectDevice(device) } label: {
                                Label("View Details", systemImage: "info.circle")
                            }
                            Button {
                                UIPasteboard.general.string = device.name
                            } label: {
                                Label("Copy Name", systemImage: "doc.on.doc")
                            }
                            if let room = device.room {
                                Button {
                                    UIPasteboard.general.string = "\(device.name) · \(room)"
                                } label: {
                                    Label("Copy Name & Room", systemImage: "doc.on.clipboard")
                                }
                            }
                            Divider()
                            if device.isOffline {
                                Label("Offline", systemImage: "wifi.slash")
                                    .foregroundStyle(.red)
                            } else {
                                Label("Online", systemImage: "wifi")
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Tips

struct DashboardTipsSection: View {
    let tips: [LocalizedStringResource]
    var body: some View {
        Section {
            ForEach(Array(tips.enumerated()), id: \.offset) { index, tip in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(index + 1)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 20, height: 20)
                        .background(.blue.opacity(0.85), in: Circle())
                    Text(tip)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 3)
            }
        } header: {
            Label("Recommendations", systemImage: "lightbulb.fill")
                .foregroundStyle(.primary)
                .symbolRenderingMode(.multicolor)
        }
    }
}

// MARK: - Issues

struct DashboardIssuesSection: View {
    let health: NetworkHealthScore
    @Binding var navPath: NavigationPath

    var body: some View {
        Section {
            if health.issues.isEmpty {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.12))
                            .frame(width: 36, height: 36)
                        Image(systemName: "checkmark.shield.fill")
                            .foregroundStyle(.green)
                            .imageScale(.medium)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("All Clear")
                            .font(.subheadline.weight(.semibold))
                        Text("No network issues detected")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 6)
            } else {
                ForEach(health.issues) { issue in issueRow(issue) }
            }
        } header: {
            HStack {
                Text("Issues")
                Spacer()
                let critCount = health.issues.filter(\.isCritical).count
                if critCount > 0 {
                    Label("\(critCount) Critical", systemImage: "exclamationmark.circle.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.red)
                } else if !health.issues.isEmpty {
                    Label("\(health.issues.count)", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    @ViewBuilder
    private func issueRow(_ issue: NetworkHealthScore.Issue) -> some View {
        if !issue.affectedDevices.isEmpty {
            Button {
                navPath.append(DeviceFilterSpec(
                    title: String(localized: issue.message),
                    category: .ids(issue.affectedDevices.map(\.uniqueIdentifier))
                ))
            } label: {
                issueRowContent(issue, actionable: true)
            }
            .buttonStyle(.plain)
        } else {
            issueRowContent(issue, actionable: false)
        }
    }

    private func issueRowContent(_ issue: NetworkHealthScore.Issue, actionable: Bool) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(issue.isCritical ? Color.red.opacity(0.12) : Color.orange.opacity(0.12))
                    .frame(width: 34, height: 34)
                Image(systemName: issue.icon)
                    .font(.caption)
                    .foregroundStyle(issue.isCritical ? .red : .orange)
            }
            Text(issue.message)
                .font(.subheadline)
                .foregroundStyle(.primary)
            Spacer()
            if issue.isCritical {
                Text("Critical")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(.red.opacity(0.1), in: Capsule())
            }
            if actionable {
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .contentShape(Rectangle())
        .padding(.vertical, 3)
    }
}

// MARK: - Health History Chart

struct DashboardHealthHistorySection: View {
    let entries: [HealthHistoryStore.Entry]
    let healthColor: Color
    @ScaledMetric(relativeTo: .caption2) private var chartAxisFont: CGFloat = 7

    var body: some View {
        if entries.count >= 2 {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Health Score — Last 24h")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if let latest = entries.last {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(TMStyle.gradeColor(latest.grade))
                                    .frame(width: 6, height: 6)
                                Text("\(latest.score) / 100")
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(TMStyle.gradeColor(latest.grade))
                            }
                        }
                    }
                    Chart(entries) { entry in
                        LineMark(
                            x: .value("Time", entry.timestamp),
                            y: .value("Score", entry.score)
                        )
                        .foregroundStyle(healthColor)
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 2))

                        AreaMark(
                            x: .value("Time", entry.timestamp),
                            y: .value("Score", entry.score)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [healthColor.opacity(0.22), healthColor.opacity(0.0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                    }
                    .chartYScale(domain: 0...100)
                    .chartXAxis(.hidden)
                    .chartYAxis {
                        AxisMarks(values: [0, 40, 60, 75, 90, 100]) { value in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                            AxisValueLabel {
                                if let v = value.as(Int.self) {
                                    Text(verbatim: "\(v)").font(.system(size: chartAxisFont))
                                }
                            }
                        }
                    }
                    .frame(height: 90)
                    .accessibilityLabel(Text("Health score chart, last 24 hours"))
                    .accessibilityValue(Text(entries.last.map {
                        String(localized: "Latest score \($0.score) of 100, grade \($0.grade)")
                    } ?? String(localized: "No score history")))
                }
                .padding(.vertical, 4)
            }
        }
    }
}

// MARK: - Placement Suggestions

struct DashboardPlacementSection: View {
    let suggestions: [String]
    var body: some View {
        if !suggestions.isEmpty {
            Section("Placement Suggestions") {
                ForEach(suggestions, id: \.self) { suggestion in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "arrow.up.forward.circle.fill")
                            .foregroundStyle(.blue)
                            .imageScale(.small)
                            .frame(width: 18)
                        Text(suggestion)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - Grade Ring

/// Animated grade ring isolated so Dynamic Type metric changes don't re-render parents.
struct GradeRingView: View {
    let health: NetworkHealthScore
    @ScaledMetric(relativeTo: .largeTitle) private var gradeLetterSize: CGFloat = 36
    @ScaledMetric(relativeTo: .caption2)  private var gradeScoreSize: CGFloat = 11

    var body: some View {
        ZStack {
            Circle()
                .stroke(health.color.opacity(0.12), lineWidth: 8)
            Circle()
                .trim(from: 0, to: CGFloat(health.score) / 100)
                .stroke(health.color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.8, dampingFraction: 0.75), value: health.score)
            VStack(spacing: 0) {
                Text(health.grade)
                    .font(.system(size: gradeLetterSize, weight: .black, design: .rounded))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .foregroundStyle(health.color)
                Text("\(health.score)")
                    .font(.system(size: gradeScoreSize, weight: .bold, design: .monospaced))
                    .foregroundStyle(health.color.opacity(0.7))
            }
        }
        .frame(width: 92, height: 92)
        .shadow(color: health.color.opacity(0.25), radius: 8, x: 0, y: 3)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Network health grade \(health.grade), score \(health.score) out of 100"))
    }
}

// MARK: - Resilience

/// Isolated so it only re-renders when `devices` or the paywall binding changes.
struct DashboardResilienceSection: View {
    let devices: [ThreadDevice]
    @Binding var showPaywall: Bool

    private struct ResilienceInfo {
        let borderRouterCount: Int
        let routerCount: Int
        let grade: String
        let summary: LocalizedStringResource
        let color: Color
        let criticalNames: [String]
    }

    private var resilience: ResilienceInfo {
        var brCount = 0, routerCount = 0
        var brNames: [String] = []
        for device in devices {
            if device.isBorderRouter { brCount += 1; brNames.append(device.name) }
            if device.isRoutingCapable { routerCount += 1 }
        }
        let grade: String
        switch (brCount, routerCount) {
        case (2..., 4...): grade = "A"
        case (2..., 2...): grade = "B"
        case (1..., 3...): grade = "C"
        case (1..., 1...): grade = "D"
        default:           grade = "F"
        }
        let summary: LocalizedStringResource
        switch grade {
        case "A": summary = "Excellent redundancy — true mesh failover"
        case "B": summary = "Good resilience — dual border routers"
        case "C": summary = "Moderate — one border router, some routing"
        case "D": summary = "Limited — single router, no failover path"
        default:  summary = "No border router — Thread network at risk"
        }
        return ResilienceInfo(
            borderRouterCount: brCount, routerCount: routerCount,
            grade: grade, summary: summary, color: TMStyle.gradeColor(grade),
            criticalNames: (grade == "D" || grade == "F") ? brNames.sorted() : []
        )
    }

    var body: some View {
        let r = resilience
        let isPro = ProStore.shared.isPro
        Section {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(r.color.opacity(0.12), lineWidth: 6)
                    Text(r.grade)
                        .font(.system(.title2, design: .rounded, weight: .black))
                        .foregroundStyle(r.color)
                }
                .frame(width: 56, height: 56)
                .shadow(color: r.color.opacity(0.2), radius: 6, x: 0, y: 2)

                VStack(alignment: .leading, spacing: 6) {
                    Text(r.summary)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 12) {
                        Label("^[\(r.borderRouterCount) Border Router](inflect: true)",
                              systemImage: "antenna.radiowaves.left.and.right")
                        Label("^[\(r.routerCount) Total Router](inflect: true)",
                              systemImage: "point.3.connected.trianglepath.dotted")
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    if !r.criticalNames.isEmpty {
                        Text("Critical: \(r.criticalNames.joined(separator: ", "))")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.red)
                    }
                }
            }
            .padding(.vertical, 6)
            .blur(radius: isPro ? 0 : 4)
            .overlay {
                if !isPro {
                    Button { showPaywall = true } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "lock.fill")
                                .font(.title3)
                            Text("Pro Feature")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        } header: {
            HStack {
                Text("Mesh Resilience")
                Spacer()
                if !isPro {
                    Label("Pro", systemImage: "lock.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
