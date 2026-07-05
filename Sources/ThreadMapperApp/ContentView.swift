import SwiftUI
import Observation

struct ContentView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage("demoMode") private var demoMode = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var meshVM = MeshViewModel(
        discovery: UserDefaults.standard.bool(forKey: "demoMode")
            ? DemoDiscoveryService()
            : MatterDiscoveryService.shared
    )
    @State private var surveyVM = SurveyViewModel()
    @State private var statsStore = DeviceStatsStore.shared
    @State private var notesStore = DeviceNotesStore.shared
    @State private var historyStore = HealthHistoryStore.shared
    @State private var activityStore = ActivityStore.shared

    var body: some View {
        if !hasSeenOnboarding {
            // OnboardingFlow sets isPresented=false to dismiss; invert so hasSeenOnboarding becomes true
            OnboardingFlow(isPresented: Binding(
                get: { !hasSeenOnboarding },
                set: { hasSeenOnboarding = !$0 }
            ))
        } else {
            MainTabView()
                .environment(meshVM)
                .environment(surveyVM)
                .environment(statsStore)
                .environment(notesStore)
                .environment(historyStore)
                .environment(activityStore)
                .task {
                    await NotificationService.shared.requestAuthorization()
                    BackgroundRefreshHandler.schedule()
                }
                .onChange(of: scenePhase) { _, phase in
                    // Pause the poll loop while backgrounded (BGTask covers
                    // offline detection); resume immediately on foreground.
                    meshVM.isAppActive = (phase == .active)
                }
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Dashboard", systemImage: "square.grid.2x2") }

            MeshView()
                .tabItem { Label("Mesh", systemImage: "network") }

            SurveyWalkView()
                .tabItem { Label("Survey", systemImage: "figure.walk") }

            ActivityFeedView()
                .tabItem { Label("Activity", systemImage: "clock.arrow.circlepath") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}
