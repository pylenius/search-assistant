import SwiftUI

struct WatchRootView: View {
    @EnvironmentObject private var link: WatchLink

    /// Drives the quiet-phone probe. Nothing publishes when time merely
    /// passes, so without a tick the watch would sit on a search whose
    /// phone died and never notice.
    private let tick = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            // Note the ordering: a search we already know about stays on
            // screen unless the phone is confirmed gone. Backgrounding the
            // phone — the normal case, walking with it in a pocket — must
            // not blank the watch.
            if link.snapshot.hasSearch && !link.phoneLost {
                TabView {
                    ControlsView()
                    PeopleView()
                }
                .tabViewStyle(.page)
            } else {
                IdleView(lostPhone: link.phoneLost)
            }
        }
        .onReceive(tick) { link.pollIfQuiet(asOf: $0) }
    }
}

/// Shown when there's nothing live to display. There is deliberately no
/// "open a search" action — joining needs a link, a display name and a
/// keyboard, none of which belong on a wrist.
struct IdleView: View {
    /// Distinguishes "the phone says no search is open", which we know, from
    /// "the phone stopped talking to us", which we don't. Showing the last
    /// known people and distances after the phone has gone would be a lie
    /// the wearer has no way to check.
    let lostPhone: Bool

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: lostPhone ? "iphone.slash" : "map")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text(lostPhone ? "Lost the iPhone" : "No active search")
                .font(.headline)
                .multilineTextAlignment(.center)
            Text(lostPhone
                 ? "Open Search Assistant on your iPhone."
                 : "Open a search on your iPhone.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}
