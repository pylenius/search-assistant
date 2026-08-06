import SwiftUI

@main
struct SearchAssistantApp: App {
    init() {
        // Activated at launch rather than when a search opens: the watch
        // may wake first and ask for the current application context, and
        // an unactivated session has nothing to give it.
        WatchBridge.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
