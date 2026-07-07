import SwiftUI
import Charts
import Observation

struct DashboardView: View {
    @Environment(MeshViewModel.self)       private var viewModel
    @Environment(DeviceStatsStore.self)    private var statsStore
    @Environment(HealthHistoryStore.self)  private var historyStore

    @State private var navPath = NavigationPath()
    @State private var selectedDevice: ThreadDevice?
    @State private var selectedRoom: String? = nil
    @State private var showWeeklyReport = false
    @State private var showPaywall = false
    @State private var showAchievements = false
    @State private var achievementStore = AchievementStore.shared
    @State private var bannerVisible = false
    @State private var roomCoverageExpanded = true
    @State private var allDevicesExpanded = true

    // Fixed hero font sizes backed by @ScaledMetric so they honor Dynamic Type
    // (identical at the default text size, scale up at accessibility sizes) — D8.
    @ScaledMetric(relativeTo: .largeTitle) private var gradeLetterSize: CGFloat = 36
    @ScaledMetric(relativeTo: .caption2) private var gradeScoreSize: CGFloat = 11
    @ScaledMetric(relativeTo: .caption2) private var statLabelSize: CGFloat = 9

    private var health: NetworkHealthScore { viewModel.health }

    private var roomGroups: [(room: String, devices: [ThreadDevice])] {
        Dictionary(grouping: viewModel.devices) { $0.room ?? "Unknown" }
            .map { (room: $0.key, devices: $0.value) }
            .sorted { $0.room < $1.room }
    }

    private var filteredDevices: [ThreadDevice] {
        guard let room = selectedRoom else { return viewModel.devices }
        return viewModel.devices.filter { $0.room == room }
    }

    var body: some View {
        NavigationStack(path: $navPath) {
            List {
                topologyBanner
                healthSection
                issuesSection
                if !health.tips.isEmpty { tipsSection }
                resilienceSection
                achievementsSection
                trendSection
                healthHistorySection
                if !roomGroups.isEmpty { roomCoverageSection }
                placementSection
                deviceSection
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: DeviceFilterSpec.self) { spec in
                DeviceFilterView(spec: spec)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await viewModel.startScan() }
                    } label: {
                        if viewModel.isScanning {
                            ProgressView().controlSize(.small)
                        } else {
                            Label("Rescan", systemImage: "arrow.clockwise")
                                .font(.caption.weight(.medium))
                        }
                    }
                    .disabled(viewModel.isScanning)
                }
                if WeeklyReportStore.shared.latestReport != nil {
                    ToolbarItem(placement: .secondaryAction) {
                        Button { showWeeklyReport = true } label: {
                            Label("Weekly Report", systemImage: "doc.text.fill")
                        }
                    }
                }
            }
            .sheet(item: $selectedDevice) { device in DeviceDetailView(device: device) }
            .sheet(isPresented: $showWeeklyReport) {
                if let report = WeeklyReportStore.shared.latestReport {
                    WeeklyReportView(report: report)
                }
            }
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .sheet(isPresented: $showAchievements) {
                NavigationStack { AchievementsView() }
            }
            .overlay(alignment: .top) {
                if let unlocked = achievementStore.recentlyUnlocked, bannerVisible {
                    AchievementBanner(achievement: unlocked) {
                        withAnimation { bannerVisible = false }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            achievementStore.clearRecentlyUnlocked()
                        }
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 8)
                    .zIndex(1)
                }
            }
            .onChange(of: achievementStore.recentlyUnlocked) { _, unlocked in
                guard unlocked != nil else { return }
                withAnimation(.spring(response: 0.4)) { bannerVisible = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                    withAnimation { bannerVisible = false }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        achievementStore.clearRecentlyUnlocked()
                    }
                }
            }
            .onAppear {
                if !viewModel.isScanning { Task { await viewModel.startScan() } }
            }
        }
    }

    // MARK: - Topology Change Banner

    @ViewBuilder
    private var topologyBanner: some View {
        let recent = viewModel.recentTopologyChanges.filter {
            Date().timeIntervalSince($0.timestamp) < 300
        }
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

    // MARK: - Health Score Hero

    @ViewBuilder
    private var healthSection: some View {
        Section {
            HStack(alignment: .center, spacing: 20) {
                gradeRingView

                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(health.summary)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(2)
                        Text("\(health.score) / 100 pts")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(health.color)
                    }

                    let offline = viewModel.devices.filter(\.isOffline)
                    let weak    = viewModel.devices.filter(\.isWeak)
                    let routers = viewModel.devices.filter(\.isRoutingCapable)

                    VStack(spacing: 6) {
                        HStack(spacing: 6) {
                            tappableStatCard(
                                icon: "cpu.fill", value: "\(viewModel.devices.count)",
                                label: "Devices", tint: .accentColor,
                                spec: DeviceFilterSpec(title: "All Devices", category: .all)
                            )
                            tappableStatCard(
                                icon: "antenna.radiowaves.left.and.right",
                                value: "\(routers.count)",
                                label: "Routers", tint: .indigo,
                                spec: DeviceFilterSpec(title: "Routers", category: .routers)
                            )
                        }
                        HStack(spacing: 6) {
                            tappableStatCard(
                                icon: offline.count > 0 ? "wifi.slash" : "wifi.circle.fill",
                                value: "\(offline.count)",
                                label: "Offline",
                                tint: offline.count > 0 ? .red : .green,
                                spec: DeviceFilterSpec(title: "Offline Devices", category: .offline)
                            )
                            tappableStatCard(
                                icon: weak.count > 0 ? "wifi.exclamationmark" : "checkmark.circle.fill",
                                value: "\(weak.count)",
                                label: "Weak",
                                tint: weak.count > 0 ? .orange : .green,
                                spec: DeviceFilterSpec(title: "Weak Signal Devices", category: .weak)
                            )
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

    @ViewBuilder
    private var gradeRingView: some View {
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
    }

    /// Stat card backed by a Button that pushes onto `navPath`. Buttons — unlike
    /// NavigationLinks — have no one-per-List-row restriction, so all four tiles
    /// in the shared hero row stay independently tappable (fixes D1).
    @ViewBuilder
    private func tappableStatCard(icon: String, value: String, label: String, tint: Color, spec: DeviceFilterSpec) -> some View {
        Button {
            navPath.append(spec)
        } label: {
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

    // MARK: - Issues

    @ViewBuilder
    private var issuesSection: some View {
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
                ForEach(health.issues) { issue in
                    issueRow(issue)
                }
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
            // Button + navPath rather than an in-row NavigationLink, so it plays
            // nicely with the other tappable rows in the List (fixes D2).
            Button {
                navPath.append(DeviceFilterSpec(
                    title: issue.message,
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
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(.red.opacity(0.1), in: Capsule())
            }
            // Only actionable rows advertise navigation, so the affordance
            // matches behaviour (fixes D2's inconsistent tap targets).
            if actionable {
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .contentShape(Rectangle())
        .padding(.vertical, 3)
    }

    // MARK: - Resilience

    private var borderRouterCount: Int { viewModel.devices.filter(\.isBorderRouter).count }
    private var routerCount: Int { viewModel.devices.filter(\.isRoutingCapable).count }

    private var resilienceGrade: String {
        switch (borderRouterCount, routerCount) {
        case (2..., 4...): return "A"
        case (2..., 2...): return "B"
        case (1..., 3...): return "C"
        case (1..., 1...): return "D"
        default:           return "F"
        }
    }

    private var resilienceColor: Color { TMStyle.gradeColor(resilienceGrade) }

    private var resilienceSummary: String {
        switch resilienceGrade {
        case "A": return "Excellent redundancy — true mesh failover"
        case "B": return "Good resilience — dual border routers"
        case "C": return "Moderate — one border router, some routing"
        case "D": return "Limited — single router, no failover path"
        default:  return "No border router — Thread network at risk"
        }
    }

    private var resilienceCriticalNames: [String] {
        guard resilienceGrade == "D" || resilienceGrade == "F" else { return [] }
        return viewModel.devices.filter(\.isBorderRouter).map(\.name).sorted()
    }

    @ViewBuilder
    private var resilienceSection: some View {
        if !viewModel.devices.isEmpty {
            Section {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .stroke(resilienceColor.opacity(0.12), lineWidth: 6)
                        Text(resilienceGrade)
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundStyle(resilienceColor)
                    }
                    .frame(width: 56, height: 56)
                    .shadow(color: resilienceColor.opacity(0.2), radius: 6, x: 0, y: 2)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(resilienceSummary)
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 12) {
                            Label("\(borderRouterCount) Border Router\(borderRouterCount == 1 ? "" : "s")",
                                  systemImage: "antenna.radiowaves.left.and.right")
                            Label("\(routerCount) Total Router\(routerCount == 1 ? "" : "s")",
                                  systemImage: "point.3.connected.trianglepath.dotted")
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                        if !resilienceCriticalNames.isEmpty {
                            Text("Critical: \(resilienceCriticalNames.joined(separator: ", "))")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.red)
                        }
                    }
                }
                .padding(.vertical, 6)
            } header: {
                HStack {
                    Text("Mesh Resilience")
                    Spacer()
                    if !ProStore.shared.isPro {
                        Button { showPaywall = true } label: {
                            Label("Pro", systemImage: "lock.fill")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Tips

    @ViewBuilder
    private var tipsSection: some View {
        Section {
            ForEach(Array(health.tips.enumerated()), id: \.offset) { index, tip in
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

    // MARK: - Achievements

    @ViewBuilder
    private var achievementsSection: some View {
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

    // MARK: - Trend Sparkline

    @ViewBuilder
    private var trendSection: some View {
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

    // MARK: - Room Coverage (collapsible)

    @ViewBuilder
    private var roomCoverageSection: some View {
        Section {
            if roomCoverageExpanded {
                ForEach(roomGroups, id: \.room) { group in
                    roomRow(group.room, group.devices)
                }
            }
        } header: {
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) { roomCoverageExpanded.toggle() }
                } label: {
                    HStack(spacing: 4) {
                        Text("Room Coverage")
                        Image(systemName: "chevron.down")
                            .font(.caption2.weight(.semibold))
                            .rotationEffect(.degrees(roomCoverageExpanded ? 0 : -90))
                            .animation(.easeInOut(duration: 0.25), value: roomCoverageExpanded)
                    }
                }
                .buttonStyle(.plain)
                Spacer()
                if selectedRoom != nil {
                    Button("Show All") { selectedRoom = nil }
                        .font(.caption)
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
                        Text("\(devices.count) device\(devices.count == 1 ? "" : "s")")
                            .font(.caption2).foregroundStyle(.secondary)
                        if weak > 0 { Text("· \(weak) weak").font(.caption2).foregroundStyle(.orange) }
                        if offline > 0 { Text("· \(offline) offline").font(.caption2).foregroundStyle(.red) }
                    }
                }

                Spacer()

                if let g = worstGrade {
                    Text(g)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
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

    // MARK: - Device List (collapsible)

    @ViewBuilder
    private var deviceSection: some View {
        Section {
            if allDevicesExpanded {
                if filteredDevices.isEmpty {
                    if viewModel.isScanning {
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
                        DeviceListRow(device: device)
                            .onTapGesture { selectedDevice = device }
                    }
                }
            }
        } header: {
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) { allDevicesExpanded.toggle() }
                } label: {
                    HStack(spacing: 4) {
                        Text(selectedRoom ?? "All Devices")
                        Image(systemName: "chevron.down")
                            .font(.caption2.weight(.semibold))
                            .rotationEffect(.degrees(allDevicesExpanded ? 0 : -90))
                            .animation(.easeInOut(duration: 0.25), value: allDevicesExpanded)
                    }
                }
                .buttonStyle(.plain)
                Spacer()
                if selectedRoom != nil {
                    Button("Clear Filter") { selectedRoom = nil }
                        .font(.caption)
                }
            }
        }
    }

    // MARK: - Health History Chart

    @ViewBuilder
    private var healthHistorySection: some View {
        if historyStore.entries.count >= 2 {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Health Score — Last 24h")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if let latest = historyStore.entries.last {
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

                    Chart(historyStore.entries) { entry in
                        LineMark(
                            x: .value("Time", entry.timestamp),
                            y: .value("Score", entry.score)
                        )
                        .foregroundStyle(health.color)
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 2))

                        AreaMark(
                            x: .value("Time", entry.timestamp),
                            y: .value("Score", entry.score)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [health.color.opacity(0.22), health.color.opacity(0.0)],
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
                                    Text("\(v)").font(.system(size: 7))
                                }
                            }
                        }
                    }
                    .frame(height: 90)
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Placement Suggestions

    @ViewBuilder
    private var placementSection: some View {
        let suggestions = buildPlacementSuggestions()
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

    private func buildPlacementSuggestions() -> [String] {
        var suggestions: [String] = []
        for group in roomGroups {
            let avgRSSIs = group.devices.compactMap { statsStore.stats(for: $0.uniqueIdentifier)?.avgRSSI }
            guard !avgRSSIs.isEmpty else { continue }
            let roomAvg = avgRSSIs.reduce(0, +) / avgRSSIs.count
            guard roomAvg < -75 else { continue }
            let quality = roomAvg < -85 ? "very weak" : "weak"
            suggestions.append(
                "Response quality in \(group.room) is \(quality) (\(roomAvg.rssiQualityLabel)) — consider adding a Thread router nearby"
            )
        }
        return suggestions
    }
}
