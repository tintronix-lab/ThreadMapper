import SwiftUI

@main
struct ThreadMapperWatchApp: App {
    @StateObject private var store = WatchConnectivityStore()

    var body: some Scene {
        WindowGroup {
            TabView {
                NavigationStack { WatchDashboardView() }
                NavigationStack { GuidedSurveyControlView() }
            }
            .environmentObject(store)
        }
    }
}
