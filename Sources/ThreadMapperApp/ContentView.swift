import SwiftUI
import Observation

struct ContentView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var meshVM = MeshViewModel()
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
