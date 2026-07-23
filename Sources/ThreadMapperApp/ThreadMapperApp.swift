import AppIntents
import Observation
import SwiftUI

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
