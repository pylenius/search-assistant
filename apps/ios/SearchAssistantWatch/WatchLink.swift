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

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        Task { @MainActor in self.isReachable = reachable }
    }
}
