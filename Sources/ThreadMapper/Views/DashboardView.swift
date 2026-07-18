import SwiftUI
import Observation
import StoreKit

struct DashboardView: View {
    @Environment(MeshViewModel.self)       private var viewModel
    @Environment(\.requestReview)          private var requestReview
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
    @State private var showConfetti = false
    @State private var hasCompletedFirstScan = false
    @AppStorage("gradeImprovementCount") private var gradeImprovementCount = 0
    @AppStorage("dash.allDevicesExpanded") private var allDevicesExpanded = true
    @AppStorage("dash.roomCoverageExpanded") private var roomCoverageExpanded = true
    @State private var showDiagnostics = false
    @State private var showCommissioningCheck = false
    @State private var showSmartAdvisor = false
    @State private var showAIInsights = false
    @State private var showHealthCard = false
    @State private var healthCardImage: UIImage? = nil

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
                DashboardAnomalyBanner(anomalies: viewModel.anomalies, devices: viewModel.devices)
                DashboardHealthSection(
                    health: health,
                    devices: viewModel.devices,
                    onSelectFilter: { navPath.append($0) },
                    showPaywall: $showPaywall
                )
                DashboardIssuesSection(health: health, navPath: $navPath)
                DashboardDeviceSection(
                    filteredDevices: filteredDevices,
                    selectedRoom: $selectedRoom,
                    isExpanded: allDevicesExpanded,
                    onToggle: {
                        allDevicesExpanded.toggle()
                        UserDefaults.standard.synchronize()
                    },
                    isScanning: viewModel.isScanning,
                    onSelectDevice: { selectedDevice = $0 }
                )
                if !roomGroups.isEmpty {
                    DashboardRoomCoverageSection(
                        roomGroups: roomGroups,
                        selectedRoom: $selectedRoom,
                        isExpanded: roomCoverageExpanded,
                        onToggle: {
                            roomCoverageExpanded.toggle()
                            UserDefaults.standard.synchronize()
                        }
                    )
                }
                if !health.tips.isEmpty { DashboardTipsSection(tips: health.tips) }
                DashboardPlacementSection(suggestions: buildPlacementSuggestions())
                if !viewModel.devices.isEmpty {
                    DashboardResilienceSection(devices: viewModel.devices, showPaywall: $showPaywall)
                }
                DashboardTrendSection()
                DashboardHealthHistorySection(entries: historyStore.entries, healthColor: health.color)
                DashboardAchievementsSection(
                    achievementStore: achievementStore,
                    showAchievements: $showAchievements
                )
            }
            .refreshable {
                await viewModel.startScan()
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.large)
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
                ToolbarItem(placement: .secondaryAction) {
                    Button { showDiagnostics = true } label: {
                        Label("Network Diagnostics", systemImage: "stethoscope")
                    }
                }
                if !viewModel.devices.isEmpty {
                    ToolbarItem(placement: .secondaryAction) {
                        Button { showCommissioningCheck = true } label: {
                            Label("Commissioning Readiness", systemImage: "checkmark.shield")
                        }
                    }
                    ToolbarItem(placement: .secondaryAction) {
                        Button { showSmartAdvisor = true } label: {
                            Label("Smart Home Advisor", systemImage: "wand.and.stars")
                        }
                    }
                    ToolbarItem(placement: .secondaryAction) {
                        Button { showAIInsights = true } label: {
                            Label("AI Insights", systemImage: "apple.intelligence")
                        }
                    }
                    ToolbarItem(placement: .secondaryAction) {
                        Button { exportHealthCard() } label: {
                            Label("Share Health Card", systemImage: "square.and.arrow.up")
                        }
                    }
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
            .sheet(isPresented: $showDiagnostics) {
                NetworkDiagnosticsView(devices: viewModel.devices)
            }
            .sheet(isPresented: $showCommissioningCheck) {
                CommissioningReadinessView(devices: viewModel.devices)
            }
            .sheet(isPresented: $showSmartAdvisor) {
                NavigationStack { SmartHomeAdvisorView() }
            }
            .sheet(isPresented: $showAIInsights) {
                NavigationStack { AIInsightsWrapperView() }
            }
            .sheet(isPresented: $showWeeklyReport) {
                if let report = WeeklyReportStore.shared.latestReport {
                    WeeklyReportView(report: report)
                }
            }
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .sheet(isPresented: $showAchievements) {
                NavigationStack { AchievementsView() }
            }
            .sheet(isPresented: $showHealthCard) {
                if let img = healthCardImage {
                    HealthCardShareSheet(image: img)
                }
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
            .onChange(of: viewModel.pendingDeviceID) { _, uuid in
                guard let uuid else { return }
                selectedDevice = viewModel.devices.first { $0.id == uuid }
                viewModel.pendingDeviceID = nil
            }
        }
        .overlay {
            ConfettiView(isShowing: $showConfetti)
        }
        .onChange(of: viewModel.isScanning) { old, new in
            if old && !new { hasCompletedFirstScan = true }
        }
        .onChange(of: health.grade) { old, new in
            guard hasCompletedFirstScan else { return }
            let oldRank = gradeRank(old)
            let newRank = gradeRank(new)
            if newRank > oldRank {
                showConfetti = true
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                gradeImprovementCount += 1
                if gradeImprovementCount >= 2 { requestReview() }
                NotificationService.shared.notifyGradeImproved(from: old, to: new)
            } else if newRank < oldRank {
                NotificationService.shared.notifyHealthDrop(from: old, to: new)
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
            }
        }
    }

    private func gradeRank(_ g: String) -> Int {
        switch g {
        case "A": return 5
        case "B": return 4
        case "C": return 3
        case "D": return 2
        case "F": return 1
        default:  return 0
        }
    }

    @MainActor private func exportHealthCard() {
        let offlineCount = viewModel.devices.filter(\.isOffline).count
        let card = NetworkHealthCardView(
            health: health,
            deviceCount: viewModel.devices.count,
            offlineCount: offlineCount,
            generatedAt: Date()
        )
        let renderer = ImageRenderer(content: card)
        renderer.scale = 2.0
        guard let image = renderer.uiImage else { return }
        healthCardImage = image
        showHealthCard = true
    }

    private func buildPlacementSuggestions() -> [String] {
        var suggestions: [String] = []
        for group in roomGroups {
            let avgRSSIs = group.devices.compactMap { statsStore.stats(for: $0.uniqueIdentifier)?.avgRSSI }
            guard !avgRSSIs.isEmpty else { continue }
            let roomAvg = avgRSSIs.reduce(0, +) / avgRSSIs.count
            guard roomAvg < -75 else { continue }
            let quality = roomAvg < -85
                ? String(localized: "very weak")
                : String(localized: "weak")
            suggestions.append(String(localized: "Response quality in \(group.room) is \(quality) (\(roomAvg.rssiQualityLabel)) — consider adding a Thread router nearby"))
        }
        return suggestions
    }
}
