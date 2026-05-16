import SwiftUI
import CoreLocation

/// Helsinki — fallback center when neither the snapshot nor the device has a known location.
private let fallbackCenter = CLLocationCoordinate2D(latitude: 60.17, longitude: 24.94)

struct SearchView: View {
    let slug: String

    @StateObject private var store = SearchStore()
    @State private var hub: SignalRService?

    @State private var loadError: String?
    @State private var didLoad: Bool = false
    @State private var needsJoin: Bool = false
    @State private var joining: Bool = false
    @State private var joinError: String?

    var body: some View {
        content
            .navigationBarTitleDisplayMode(.inline)
            .task(id: slug) { await load() }
            .sheet(isPresented: $needsJoin) { joinSheet }
            .onDisappear { Task { await hub?.disconnect() } }
            .onChange(of: store.endedRemotely) { ended in
                if ended { loadError = "The owner ended this search." }
            }
    }

    @ViewBuilder
    private var content: some View {
        if let loadError {
            errorView(loadError)
        } else if didLoad {
            mapStack
        } else {
            ProgressView("Loading search…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var mapStack: some View {
        ZStack(alignment: .topLeading) {
            SearchMapView(
                center: mapCenter,
                zoom: store.defaultZoom,
                positions: store.positions,
                participants: store.participants
            )
            .ignoresSafeArea(edges: [.bottom, .leading, .trailing])

            titleBadge
                .padding(.horizontal, 12)
                .padding(.top, 8)
        }
    }

    private var joinSheet: some View {
        JoinSheet(
            searchTitle: store.title.isEmpty ? "Search" : store.title,
            onJoin: { name in await join(displayName: name) },
            onCancel: { needsJoin = false }
        )
        .presentationDetents([.medium, .large])
    }

    // MARK: - Subviews

    private var titleBadge: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(store.title.isEmpty ? "Search" : store.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            HStack(spacing: 6) {
                Text("/s/\(slug)")
                    .font(.caption2.monospaced())
                Text("·")
                Text("\(store.participants.count) \(store.participants.count == 1 ? "person" : "people")")
                if let me = store.me {
                    Text("·")
                    Circle().fill(Color(hex: me.color)).frame(width: 8, height: 8)
                    Text(me.displayName).lineLimit(1)
                }
                connectionDot
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    @ViewBuilder
    private var connectionDot: some View {
        switch store.connectionState {
        case .connected:
            Image(systemName: "antenna.radiowaves.left.and.right").foregroundStyle(.green)
        case .connecting:
            Image(systemName: "antenna.radiowaves.left.and.right").foregroundStyle(.orange)
        case .failed:
            Image(systemName: "antenna.radiowaves.left.and.right.slash").foregroundStyle(.red)
        case .idle:
            EmptyView()
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            Text("Couldn't load search")
                .font(.headline)
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var mapCenter: CLLocationCoordinate2D {
        guard let p = store.center else { return fallbackCenter }
        return CLLocationCoordinate2D(latitude: p.lat, longitude: p.lng)
    }

    // MARK: - Loading + joining + hub

    private func load() async {
        loadError = nil
        didLoad = false
        do {
            let snap = try await ApiClient.shared.getSearch(slug: slug)
            store.hydrate(snap)
            didLoad = true
            await resolveIdentityAndConnect()
        } catch let ApiError.status(404, _) {
            loadError = "This search doesn't exist. It may have expired."
        } catch let ApiError.status(code, _) {
            loadError = "HTTP \(code) loading search."
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func resolveIdentityAndConnect() async {
        if let token = SessionStore.shared.sessionToken(for: slug) {
            do {
                let dto = try await ApiClient.shared.me(slug: slug, sessionToken: token)
                store.me = Me(id: dto.id,
                              sessionToken: token,
                              color: dto.color,
                              displayName: dto.displayName)
                await connectHub()
                return
            } catch ApiError.status(401, _) {
                SessionStore.shared.clearSessionToken(for: slug)
            } catch {
                // Soft fail — user can pull-to-retry later; for now just prompt.
            }
        }
        needsJoin = true
    }

    private func join(displayName: String) async {
        joining = true
        joinError = nil
        defer { joining = false }

        do {
            let resp = try await ApiClient.shared.joinSearch(slug: slug,
                                                             displayName: displayName)
            SessionStore.shared.setSessionToken(resp.sessionToken, for: slug)
            store.me = Me(id: resp.participantId,
                          sessionToken: resp.sessionToken,
                          color: resp.color,
                          displayName: displayName)
            // Optimistically add ourselves to the participant list pre-snapshot.
            store.upsertParticipant(ParticipantDto(
                id: resp.participantId,
                displayName: displayName,
                color: resp.color,
                joinedAt: Date(),
                lastSeenAt: Date(),
                lastPosition: nil))
            needsJoin = false
            await connectHub()
        } catch let ApiError.status(code, _) {
            joinError = "Couldn't join (HTTP \(code))."
        } catch {
            joinError = error.localizedDescription
        }
    }

    private func connectHub() async {
        guard let token = store.me?.sessionToken else { return }
        let service = SignalRService()
        hub = service
        do {
            try await service.connect(slug: slug, sessionToken: token, store: store)
        } catch {
            // Connection-state set to .failed inside the service.
        }
    }
}

// MARK: - Color helper

extension Color {
    /// Parses "#rrggbb" or "#rrggbbaa". Falls back to gray on bad input.
    init(hex: String) {
        var s = hex
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6 || s.count == 8,
              let value = UInt64(s, radix: 16) else {
            self = .gray; return
        }
        let r, g, b, a: Double
        if s.count == 6 {
            r = Double((value >> 16) & 0xFF) / 255
            g = Double((value >> 8)  & 0xFF) / 255
            b = Double( value        & 0xFF) / 255
            a = 1
        } else {
            r = Double((value >> 24) & 0xFF) / 255
            g = Double((value >> 16) & 0xFF) / 255
            b = Double((value >> 8)  & 0xFF) / 255
            a = Double( value        & 0xFF) / 255
        }
        self = Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

#Preview {
    NavigationStack {
        SearchView(slug: "abc12345")
    }
}
