import SwiftUI
import Observation

struct ContentView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage("demoMode") private var demoMode = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var notificationService = NotificationService.shared
    // Tab state lives here so deep links from NotificationService can drive navigation.
    @State private var tabSelection: AppTab = .dashboard
    @State private var sidebarSelection: AppTab? = .dashboard
    @State private var meshVM = MeshViewModel(
        discovery: UserDefaults.standard.bool(forKey: "demoMode")
            ? DemoDiscoveryService()
            : MatterDiscoveryService.shared,
        diagnostics: ContentView.makeDiagnosticsProvider()
    )

    /// Prefer a configured OpenThread Border Router (real data) over the
    /// entitlement-gated ThreadNetwork read; both stay dormant if unavailable.
    static func makeDiagnosticsProvider() -> any DiagnosticsProvider {
        if let raw = UserDefaults.standard.string(forKey: "borderRouterURL"),
           !raw.isEmpty, let url = URL(string: raw) {
            return BorderRouterClient(baseURL: url)
        }
        return ThreadCredentialsService()
    }
    @AppStorage("borderRouterURL") private var borderRouterURL = ""
    @State private var surveyVM = SurveyViewModel()
    @State private var statsStore = DeviceStatsStore.shared
    @State private var notesStore = DeviceNotesStore.shared
    @State private var historyStore = HealthHistoryStore.shared
    @State private var activityStore = ActivityStore.shared
    @State private var proStore = ProStore.shared
    @State private var deviceOverrideStore = DeviceOverrideStore.shared

    var body: some View {
        if !hasSeenOnboarding {
            // OnboardingFlow sets isPresented=false to dismiss; invert so hasSeenOnboarding becomes true
            OnboardingFlow(isPresented: Binding(
                get: { !hasSeenOnboarding },
                set: { hasSeenOnboarding = !$0 }
            ))
        } else {
            MainTabView(tabSelection: $tabSelection, sidebarSelection: $sidebarSelection)
                .environment(meshVM)
                .environment(surveyVM)
                .environment(statsStore)
                .environment(notesStore)
                .environment(historyStore)
                .environment(activityStore)
                .environment(proStore)
                .environment(deviceOverrideStore)
                .task {
                    await NotificationService.shared.requestAuthorization()
                    BackgroundRefreshHandler.schedule()
                    WeeklyReportStore.shared.generateIfNeeded()
                }
                .onChange(of: scenePhase) { _, phase in
                    meshVM.isAppActive = (phase == .active)
                    if phase == .background || phase == .inactive {
                        UserDefaults.standard.synchronize()
                    }
                }
                .onChange(of: borderRouterURL) { _, _ in
                    meshVM.updateDiagnosticsProvider(ContentView.makeDiagnosticsProvider())
                }
                .onChange(of: notificationService.pendingDeepLink) { _, link in
                    guard let link else { return }
                    switch link {
                    case .deviceDetail(let uuid):
                        tabSelection = .dashboard
                        sidebarSelection = .dashboard
                        meshVM.pendingDeviceID = uuid
                    case .dashboard:
                        tabSelection = .dashboard
                        sidebarSelection = .dashboard
                    case .activity:
                        tabSelection = .activity
                        sidebarSelection = .activity
                    }
                    notificationService.pendingDeepLink = nil
                }
                .onOpenURL { url in
                    guard url.scheme == "threadmapper" else { return }
                    switch url.host {
                    case "dashboard":
                        tabSelection = .dashboard
                        sidebarSelection = .dashboard
                    case "mesh":
                        tabSelection = .mesh
                        sidebarSelection = .mesh
                    case "activity":
                        tabSelection = .activity
                        sidebarSelection = .activity
                    case "device":
                        tabSelection = .dashboard
                        sidebarSelection = .dashboard
                        if let uuidStr = url.pathComponents.dropFirst().first,
                           let uuid = UUID(uuidString: uuidStr) {
                            meshVM.pendingDeviceID = uuid
                        }
                    case "dismiss-live-activity":
                        LiveActivityManager.shared.endNow()
                    default: break
                    }
                }
        }
    }
}

struct MainTabView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Binding var tabSelection: AppTab
    @Binding var sidebarSelection: AppTab?

    var body: some View {
        if sizeClass == .regular {
            iPadLayout
        } else {
            iPhoneLayout
        }
    }

    // MARK: - iPad: NavigationSplitView

    private var iPadLayout: some View {
        NavigationSplitView {
            List(AppTab.allCases, id: \.self, selection: $sidebarSelection) { tab in
                Label(tab.title, systemImage: tab.icon)
            }
            .navigationTitle("ThreadMapper")
            .navigationSplitViewColumnWidth(220)
        } detail: {
            (sidebarSelection ?? .dashboard).destination
        }
    }

    // MARK: - iPhone: TabView

    private var iPhoneLayout: some View {
        TabView(selection: $tabSelection) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                tab.destination
                    .tabItem { Label(tab.title, systemImage: tab.icon) }
                    .tag(tab)
            }
        }
    }
}

// MARK: - Tab definition

enum AppTab: CaseIterable, Hashable, Identifiable {
    var id: Self { self }
    case dashboard, mesh, survey, activity, settings

    var title: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .mesh:      return "Mesh"
        case .survey:    return "Survey"
        case .activity:  return "Activity"
        case .settings:  return "Settings"
        }
    }

    var icon: String {
        switch self {
        case .dashboard: return "house.fill"
        case .mesh:      return "network"
        case .survey:    return "figure.walk"
        case .activity:  return "clock.arrow.circlepath"
        case .settings:  return "gearshape"
        }
    }

    @ViewBuilder
    var destination: some View {
        switch self {
        case .dashboard: DashboardView()
        case .mesh:      MeshView()
        case .survey:    SurveyWalkView()
        case .activity:  ActivityFeedView()
        case .settings:  SettingsView()
        }
    }
}
