import SwiftUI
import Observation
import AppIntents

@main
struct ThreadMapperApp: App {
    init() {
        // Must be registered before app finishes launching
        BackgroundRefreshHandler.register()
        ThreadMapperShortcuts.updateAppShortcutParameters()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
