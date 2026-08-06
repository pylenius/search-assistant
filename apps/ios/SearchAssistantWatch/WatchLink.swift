import Foundation
import WatchConnectivity

/// Watch half of the companion link. Holds the last snapshot the phone
/// sent and forwards commands back to it.
///
/// `isReachable` is surfaced separately from the snapshot because it's the
/// honest answer to "is what I'm looking at still live?" — application
/// context persists across a lost connection, so without it the watch would
/// happily show minute-old positions as if they were current.
@MainActor
final class WatchLink: NSObject, ObservableObject {
    @Published private(set) var snapshot = WatchSnapshot()
    @Published private(set) var isReachable = false
    @Published var commandError: String?

    /// When the last snapshot arrived, stamped on receipt rather than sent
    /// in the payload — the two clocks don't need to agree, and only the
    /// watch's own sense of "how long has it been quiet" matters here.
    @Published private(set) var lastUpdate: Date?

    /// Set only when a probe has actually failed. Silence alone never sets
    /// it: a phone in a pocket with the app suspended is silent and is
    /// perfectly fine, which is the whole point of the app.
    @Published private(set) var phoneLost = false

    /// How long the phone may be silent before we probe it. `WatchBridge`
    /// resends even an unchanged search every 10s while it's running, so
    /// this is several missed beats.
    ///
    /// Reachability is no use here: iOS can be woken on demand for
    /// messages, so the watch may consider a suspended — or dead — app
    /// "reachable" either way.
    static let staleAfter: TimeInterval = 25

    private var probing = false

    private let decoder = JSONDecoder()

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    func send(_ command: WatchCommand) {
        let session = WCSession.default
        guard session.isReachable else {
            commandError = "iPhone not reachable"
            return
        }
        commandError = nil
        session.sendMessage(
            [WatchMessage.commandKey: command.rawValue],
            replyHandler: nil,
            errorHandler: { [weak self] error in
                Task { @MainActor in
                    self?.commandError = error.localizedDescription
                }
            })
    }

    fileprivate func apply(_ context: [String: Any]) {
        guard let data = context[WatchMessage.snapshotKey] as? Data,
              let decoded = try? decoder.decode(WatchSnapshot.self, from: data)
        else { return }
        snapshot = decoded
        lastUpdate = Date()
        phoneLost = false
    }

    /// Called from the view's timer. Once the phone has been quiet for
    /// `staleAfter`, ask it directly rather than assuming the worst —
    /// WatchConnectivity relaunches a merely-suspended iOS app to answer,
    /// so a reply means "pocketed, carry on" and a failure means "gone".
    func pollIfQuiet(asOf now: Date) {
        guard !probing else { return }
        if let lastUpdate, now.timeIntervalSince(lastUpdate) <= Self.staleAfter {
            return
        }
        probing = true
        WCSession.default.sendMessage(
            [WatchMessage.stateRequestKey: true],
            replyHandler: { [weak self] reply in
                Task { @MainActor in
                    guard let self else { return }
                    self.probing = false
                    // apply() clears phoneLost and restamps lastUpdate. An
                    // empty reply still counts as contact, so stamp anyway.
                    self.apply(reply)
                    self.lastUpdate = Date()
                    self.phoneLost = false
                }
            },
            errorHandler: { [weak self] _ in
                Task { @MainActor in
                    self?.probing = false
                    self?.phoneLost = true
                }
            })
    }
}

extension WatchLink: WCSessionDelegate {
    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith activationState: WCSessionActivationState,
                             error: Error?) {
        // Whatever the phone last published is waiting here, so the watch
        // opens with real content instead of an empty screen.
        let context = session.receivedApplicationContext
        let reachable = session.isReachable
        Task { @MainActor in
            self.isReachable = reachable
            self.apply(context)
        }
    }

    nonisolated func session(_ session: WCSession,
                             didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in self.apply(applicationContext) }
    }

    /// The live path. Same payload as the application context — the phone
    /// picks whichever transport can actually deliver right now, so both
    /// land here and the watch doesn't care which one it was.
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in self.apply(message) }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        Task { @MainActor in self.isReachable = reachable }
    }
}
