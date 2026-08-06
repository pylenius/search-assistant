import SwiftUI

struct WatchRootView: View {
    @EnvironmentObject private var link: WatchLink

    var body: some View {
        if link.snapshot.hasSearch {
            TabView {
                ControlsView()
                PeopleView()
            }
            .tabViewStyle(.page)
        } else {
            IdleView()
        }
    }
}

/// Shown until the phone reports an open search. There is deliberately no
/// "open a search" action here — joining needs a link, a display name and a
/// keyboard, none of which belong on a wrist.
struct IdleView: View {
    @EnvironmentObject private var link: WatchLink

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "map")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("No active search")
                .font(.headline)
            Text(link.isReachable
                 ? "Open a search on your iPhone."
                 : "iPhone not reachable.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}
