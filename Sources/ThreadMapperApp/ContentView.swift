import SwiftUI
import Observation

struct ContentView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var meshVM = MeshViewModel()
    @State private var surveyVM = SurveyViewModel()

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

            AppChecklistView()
                .tabItem { Label("Checklist", systemImage: "checklist") }
        }
    }
}
