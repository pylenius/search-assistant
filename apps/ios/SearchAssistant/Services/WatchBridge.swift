import Foundation
import WatchConnectivity

/// Phone half of the watch companion link.
///
/// Two directions, two transports, chosen deliberately:
///
/// - **State out** goes over `updateApplicationContext`, which is
///   latest-wins and is delivered even when the watch app is asleep. That's
///   exactly the semantics a "here is the current state" payload wants —
///   a queue of stale positions would be worse than useless.
/// - **Commands in** come over `sendMessage`, which needs the watch
///   reachable. That's acceptable because commands are only sent from a
///   screen the user is actively looking at, and the watch surfaces the
///   failure instead of silently dropping them.
///
/// A singleton because `WCSession.default` is one per process and its
/// delegate can only be set once.
final class WatchBridge: NSObject {
    static let shared = WatchBridge()

    /// Set by `SearchView` while it's on screen; cleared when it leaves.
    /// Invoked on the main actor.
    var onCommand: ((WatchCommand) -> Void)?

    /// Last payload actually sent, used to skip no-op updates — `publish`
    /// runs on a timer and most ticks change nothing.
    private var lastSent: WatchSnapshot?
    private let encoder = JSONEncoder()

    private var session: WCSession? {
        WCSession.isSupported() ? .default : nil
    }

    /// Call once at launch. Safe to call again — activation is idempotent.
    func activate() {
        guard let session else { return }
        session.delegate = self
        if session.activationState != .activated {
            session.activate()
        }
    }

    func publish(_ snapshot: WatchSnapshot) {
        guard let session, session.activationState == .activated else { return }
        guard snapshot != lastSent else { return }
        guard let data = try? encoder.encode(snapshot) else { return }
        // Throws only if the session isn't activated or the payload isn't
        // property-list-safe; `data` always is, and activation is checked
        // above, so there's nothing actionable to do with the error.
        try? session.updateApplicationContext([WatchMessage.snapshotKey: data])
        lastSent = snapshot
    }

    /// Tells the watch no search is open, so it drops back to its idle
    /// screen instead of showing people from a search the user has left.
    func clear() {
        publish(WatchSnapshot())
    }
}

extension WatchBridge: WCSessionDelegate {
    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {}

    func sessionDidBecomeInactive(_ session: WCSession) {}

    /// Required on iOS: fires when the user switches to a different watch,
    /// and the session has to be re-activated to talk to the new one.
    func sessionDidDeactivate(_ session: WCSession) {
        // The old session is done; re-activating binds to the new watch.
        // Anything we'd cached about the previous one is now wrong.
        lastSent = nil
        session.activate()
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let raw = message[WatchMessage.commandKey] as? String,
              let command = WatchCommand(rawValue: raw) else { return }
        Task { @MainActor in
            self.onCommand?(command)
        }
    }
}
