import SwiftUI
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
    @State private var bannerDismissTask: Task<Void, Never>?
    @State private var roomCoverageExpanded = true
    @State private var allDevicesExpanded = true

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
                DashboardTopologyBanner(changes: viewModel.recentTopologyChanges)
                DashboardHealthSection(
                    health: health,
                    devices: viewModel.devices,
                    onSelectFilter: { navPath.append($0) },
                    showPaywall: $showPaywall
                )
                DashboardIssuesSection(health: health, navPath: $navPath)
                if !health.tips.isEmpty { DashboardTipsSection(tips: health.tips) }
                if !viewModel.devices.isEmpty {
                    DashboardResilienceSection(devices: viewModel.devices, showPaywall: $showPaywall)
                }
                DashboardAchievementsSection(
                    achievementStore: achievementStore,
                    showAchievements: $showAchievements
                )
                DashboardTrendSection()
                DashboardHealthHistorySection(entries: historyStore.entries, healthColor: health.color)
                if !roomGroups.isEmpty {
                    DashboardRoomCoverageSection(
                        roomGroups: roomGroups,
                        selectedRoom: $selectedRoom,
                        isExpanded: $roomCoverageExpanded
                    )
                }
                DashboardPlacementSection(suggestions: buildPlacementSuggestions())
                DashboardDeviceSection(
                    filteredDevices: filteredDevices,
                    selectedRoom: $selectedRoom,
                    isExpanded: $allDevicesExpanded,
                    isScanning: viewModel.isScanning,
                    onSelectDevice: { selectedDevice = $0 }
                )
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
                        bannerDismissTask?.cancel()
                        bannerDismissTask = Task {
                            withAnimation { bannerVisible = false }
                            try? await Task.sleep(for: .seconds(0.4))
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
                bannerDismissTask?.cancel()
                withAnimation(.spring(response: 0.4)) { bannerVisible = true }
                bannerDismissTask = Task {
                    try? await Task.sleep(for: .seconds(4))
                    guard !Task.isCancelled else { return }
                    withAnimation { bannerVisible = false }
                    try? await Task.sleep(for: .seconds(0.4))
                    guard !Task.isCancelled else { return }
                    achievementStore.clearRecentlyUnlocked()
                }
            }
            .onAppear {
                if !viewModel.isScanning { Task { await viewModel.startScan() } }
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
