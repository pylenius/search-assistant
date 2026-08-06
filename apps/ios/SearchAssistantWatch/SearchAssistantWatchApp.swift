import SwiftUI

@main
struct SearchAssistantWatchApp: App {
    @StateObject private var link = WatchLink()

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environmentObject(link)
        }
    }
}
