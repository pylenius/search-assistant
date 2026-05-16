import SwiftUI

struct ContentView: View {
    /// Navigation stack of slugs. Pushing a slug brings up SearchView.
    @State private var path: [String] = []

    var body: some View {
        NavigationStack(path: $path) {
            LandingView { slug in
                path.append(slug)
            }
            .navigationDestination(for: String.self) { slug in
                SearchView(slug: slug)
            }
        }
        // Cold-launch + warm Universal Links (https://searchassistant.eport.fi/s/{slug}).
        // SwiftUI delivers them via NSUserActivityTypeBrowsingWeb.
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
            if let url = activity.webpageURL { route(url) }
        }
        // Custom-scheme deep links (and a fallback some iOS versions take for
        // https:// links the system bridges through openURL: instead).
        .onOpenURL { url in route(url) }
    }

    /// Parse `/s/{slug}` out of any URL we get handed and surface it on the
    /// navigation stack. If the user is already viewing a different slug we
    /// replace the top of the stack instead of pushing — the system intent
    /// is "open this search," not "open another search on top."
    private func route(_ url: URL) {
        guard let slug = parseSlug(url) else { return }
        if path.last == slug { return }
        if path.isEmpty {
            path = [slug]
        } else {
            path[path.count - 1] = slug
        }
    }

    private func parseSlug(_ url: URL) -> String? {
        // Accept any host — the AASA on searchassistant.eport.fi is the only
        // one that will reach us via Universal Links anyway, and being lax
        // here keeps tests + future custom schemes simple.
        let parts = url.path.split(separator: "/").map(String.init)
        guard parts.count >= 2, parts[0] == "s" else { return nil }
        let slug = parts[1]
        guard !slug.isEmpty else { return nil }
        return slug
    }
}

#Preview {
    ContentView()
}
