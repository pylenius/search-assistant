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
@MainActor
final class WatchBridge: NSObject {
    static let shared = WatchBridge()

    /// Set by `SearchView` while it's on screen. Invoked on the main actor.
    private var onCommand: ((WatchCommand) -> Void)?

    /// Which `SearchView` currently owns the bridge.
    ///
    /// Opening a link for another search replaces the top of the navigation
    /// stack, and SwiftUI can run the incoming view's `onAppear` before the
    /// outgoing view's `onDisappear`. Without an owner check the departing
    /// view would then tear down the arriving view's handler and blank its
    /// snapshot — the watch would go dead a beat after switching searches.
    private var owner: UUID?

    func takeOver(owner: UUID, onCommand: @escaping (WatchCommand) -> Void) {
        self.owner = owner
        self.onCommand = onCommand
    }

    /// No-op if another view has already taken over.
    func resign(owner: UUID) {
        guard self.owner == owner else { return }
        self.owner = nil
        self.onCommand = nil
        clear()
    }

    /// Last payload actually sent, used to skip no-op updates — `publish`
    /// runs on a timer and most ticks change nothing.
    private var lastSent: WatchSnapshot?
    private var lastSentAt: Date = .distantPast
    private let encoder = JSONEncoder()

    /// How long a *silent* search may go before we resend it unchanged.
    ///
    /// The watch decides the phone is gone when it stops hearing from it
    /// (see `WatchLink.staleAfter`), and it can't distinguish "the app was
    /// killed" from "nobody has moved in a while" — both look like silence.
    /// So a search that isn't changing still has to say so periodically.
    /// Must stay comfortably under the watch's threshold.
    private static let heartbeat: TimeInterval = 10

    private var session: WCSession? {
        WCSession.isSupported() ? .default : nil
    }

    /// Latest state handed to us, republished by the heartbeat. Empty when
    /// no search is open, which is itself worth saying: it's how the watch
    /// tells "the phone is here and idle" from "the phone is gone".
    private var current = WatchSnapshot()
    private var heartbeatTimer: Timer?

    /// Call once at launch. Safe to call again — activation is idempotent.
    func activate() {
        guard let session else { return }
        session.delegate = self
        if session.activationState != .activated {
            session.activate()
        }
        startHeartbeat()
    }

    /// Runs for the life of the process, not just while a search is on
    /// screen. The watch treats silence as "the phone app is gone", so the
    /// phone has to keep saying "still here, nothing open" from the landing
    /// screen too — otherwise relaunching the app would leave the watch
    /// stuck on `Lost the iPhone` until a search happened to be opened.
    private func startHeartbeat() {
        guard heartbeatTimer == nil else { return }
        let timer = Timer(timeInterval: Self.heartbeat, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.publish(self.current)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        heartbeatTimer = timer
    }

    func publish(_ snapshot: WatchSnapshot) {
        current = snapshot
        guard let session, session.activationState == .activated else { return }
        // Nothing on the other end. Without this the calls below fail every
        // tick with WCErrorCodeWatchAppNotInstalled and fill the log.
        guard session.isWatchAppInstalled else { return }
        let due = Date().timeIntervalSince(lastSentAt) >= Self.heartbeat
        guard snapshot != lastSent || due else { return }
        guard let data = try? encoder.encode(snapshot) else { return }

        // `lastSent` is only ever recorded against a delivery that actually
        // succeeded. Recording it optimistically is a trap: the dedupe above
        // would then suppress every retry of that same state, so a single
        // failed send — the watch app not installed yet, the watch out of
        // range — leaves the watch permanently stale on whatever it last
        // managed to receive, until the snapshot happens to change again.
        if session.isReachable {
            // Live path: sendMessage is the transport built for frequent
            // updates, and it's what keeps the numbers moving while someone
            // is actually looking at the watch.
            session.sendMessage(
                [WatchMessage.snapshotKey: data],
                replyHandler: nil,
                errorHandler: { [weak self] _ in
                    Task { @MainActor in self?.lastSent = nil }
                })
            lastSent = snapshot
            lastSentAt = Date()
            return
        }

        // Watch asleep or out of range: application context is the only
        // thing that survives that, being latest-wins and queued.
        do {
            try session.updateApplicationContext([WatchMessage.snapshotKey: data])
            lastSent = snapshot
            lastSentAt = Date()
        } catch {
            lastSent = nil
        }
    }

    /// Tells the watch no search is open, so it drops back to its idle
    /// screen instead of showing people from a search the user has left.
    func clear() {
        publish(WatchSnapshot())
    }
}

extension WatchBridge: WCSessionDelegate {
    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith activationState: WCSessionActivationState,
                             error: Error?) {
        // The watch may have been paired or the app installed since the last
        // publish, both of which change whether a send can succeed at all.
        Task { @MainActor in self.lastSent = nil }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    /// Required on iOS: fires when the user switches to a different watch,
    /// and the session has to be re-activated to talk to the new one.
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // The old session is done; re-activating binds to the new watch.
        // Anything we'd cached about the previous one is now wrong.
        Task { @MainActor in self.lastSent = nil }
        session.activate()
    }

    /// Reachability returning is the moment a previously-failed send can
    /// succeed, so drop the dedupe and let the next tick resend.
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in self.lastSent = nil }
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in self.lastSent = nil }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let raw = message[WatchMessage.commandKey] as? String,
              let command = WatchCommand(rawValue: raw) else { return }
        Task { @MainActor in
            self.onCommand?(command)
        }
    }

    /// The reply half of the probe. Reaching this at all is the answer the
    /// watch wants — the app is alive, or WatchConnectivity just relaunched
    /// it in the background, either of which means "not gone".
    nonisolated func session(_ session: WCSession,
                             didReceiveMessage message: [String: Any],
                             replyHandler: @escaping ([String: Any]) -> Void) {
        Task { @MainActor in
            if let raw = message[WatchMessage.commandKey] as? String,
               let command = WatchCommand(rawValue: raw) {
                self.onCommand?(command)
            }
            guard let data = try? self.encoder.encode(self.current) else {
                replyHandler([:])
                return
            }
            replyHandler([WatchMessage.snapshotKey: data])
        }
    }
}
