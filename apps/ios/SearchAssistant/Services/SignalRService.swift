import Foundation
import SignalRClient

/// Wraps a single SignalR `HubConnection` and pumps hub events into
/// `SearchStore` on the main actor. Lifecycle: `connect(...)` once after
/// the user has a session token; `disconnect()` when the view goes away.
///
/// The connection auto-reconnects on transport-level failures. After a
/// reconnect we re-invoke `JoinSearch` because hub group membership is
/// per-connection.
final class SignalRService: NSObject {

    // SignalR delegate callbacks come in on the library's callbackQueue
    // (default DispatchQueue.main) but the protocol is non-isolated, so
    // we treat this class as non-isolated and hop to MainActor whenever
    // we mutate the store.
    private var connection: HubConnection?
    private weak var store: SearchStore?
    private var slug: String?
    private var sessionToken: String?
    private var openContinuation: CheckedContinuation<Void, Error>?

    // MARK: - Lifecycle

    func connect(slug: String, sessionToken: String, store: SearchStore) async throws {
        if connection != nil { return }  // already connected / connecting
        self.store = store
        self.slug = slug
        self.sessionToken = sessionToken
        await MainActor.run { store.connectionState = .connecting }

        let hubURL = AppConfig.apiBaseURL.appendingPathComponent(AppConfig.hubPath)

        let conn = HubConnectionBuilder(url: hubURL)
            .withHubProtocol(hubProtocolFactory: { logger in
                JSONHubProtocol(
                    logger: logger,
                    encoder: ApiClient.encoder,
                    decoder: ApiClient.decoder
                )
            })
            .withAutoReconnect()
            .withHubConnectionDelegate(delegate: self)
            .withLogging(minLogLevel: .warning)
            .build()
        wireHandlers(on: conn)
        connection = conn

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            openContinuation = cont
            conn.start()
        }
        try await invokeJoin(conn: conn, slug: slug, sessionToken: sessionToken)
        await MainActor.run { store.connectionState = .connected }
    }

    func disconnect() async {
        guard let conn = connection else { return }
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            // SignalR-Client-Swift's stop() is synchronous; just resume.
            conn.stop()
            cont.resume()
        }
        connection = nil
        if let store = store {
            await MainActor.run { store.connectionState = .idle }
        }
    }

    func sendPosition(lng: Double, lat: Double, accuracy: Double, heading: Double?) async {
        guard let conn = connection else { return }
        // Optional<Double> conforms to Encodable; serializes as number or null.
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            conn.invoke(method: "SendPosition", lng, lat, accuracy, heading) { _ in
                cont.resume()
            }
        }
    }

    // MARK: - Wire handlers

    private func wireHandlers(on conn: HubConnection) {
        let weakStore = { [weak store] in store }

        conn.on(method: "ParticipantJoined") { (p: ParticipantDto) in
            Task { @MainActor in weakStore()?.upsertParticipant(p) }
        }
        conn.on(method: "ParticipantLeft") { (_: UUID) in
            // V1: keep participants in the list even after disconnect.
            // The stale-fade in the participants list uses lastSeenAt
            // for the visual cue.
        }
        conn.on(method: "PositionUpdated") { (u: PositionUpdateDto) in
            Task { @MainActor in weakStore()?.applyPosition(u) }
        }
        conn.on(method: "AreaAdded") { (a: AreaDto) in
            Task { @MainActor in weakStore()?.upsertArea(a) }
        }
        conn.on(method: "AreaRemoved") { (id: UUID) in
            Task { @MainActor in weakStore()?.removeArea(id) }
        }
        conn.on(method: "PathStarted") { (p: PathDto) in
            Task { @MainActor in weakStore()?.upsertPath(p) }
        }
        conn.on(method: "PathUpdated") { (p: PathDto) in
            Task { @MainActor in weakStore()?.upsertPath(p) }
        }
        conn.on(method: "PathFinalized") { (id: UUID) in
            Task { @MainActor in weakStore()?.finalizePath(id) }
        }
        conn.on(method: "SearchUpdated") { (u: SearchUpdatedDto) in
            Task { @MainActor in weakStore()?.searchUpdated(u) }
        }
        conn.on(method: "SearchEnded") { (slug: String) in
            Task { @MainActor in weakStore()?.searchEnded(slug: slug) }
        }
    }

    private func invokeJoin(conn: HubConnection, slug: String, sessionToken: String) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            conn.invoke(method: "JoinSearch", slug, sessionToken) { error in
                if let error { cont.resume(throwing: error) } else { cont.resume() }
            }
        }
    }
}

// MARK: - HubConnectionDelegate

extension SignalRService: HubConnectionDelegate {

    func connectionDidOpen(hubConnection: HubConnection) {
        let cont = openContinuation
        openContinuation = nil
        cont?.resume()
    }

    func connectionDidFailToOpen(error: Error) {
        let cont = openContinuation
        openContinuation = nil
        cont?.resume(throwing: error)
        if let store = store {
            Task { @MainActor in store.connectionState = .failed }
        }
    }

    func connectionDidClose(error: Error?) {
        // Auto-reconnect will fire connectionWillReconnect/Reconnect; treat
        // an unsolicited close as a soft "failed" state for the UI.
        if let store = store {
            Task { @MainActor in store.connectionState = .failed }
        }
    }

    func connectionWillReconnect(error: Error) {
        if let store = store {
            Task { @MainActor in store.connectionState = .connecting }
        }
    }

    func connectionDidReconnect() {
        if let store = store {
            Task { @MainActor in store.connectionState = .connected }
        }
        // Re-join the hub group — membership is per-connection.
        if let conn = connection, let slug = slug, let token = sessionToken {
            Task {
                try? await invokeJoin(conn: conn, slug: slug, sessionToken: token)
            }
        }
    }
}
