import SwiftUI
import CoreLocation

/// Helsinki — fallback center when neither the snapshot nor the device has a known location.
private let fallbackCenter = CLLocationCoordinate2D(latitude: 60.17, longitude: 24.94)

struct SearchView: View {
    let slug: String

    @StateObject private var store = SearchStore()
    @StateObject private var location = LocationService()
    @StateObject private var recorder = PathRecorder()
    @State private var hub: SignalRService?

    @Environment(\.dismiss) private var dismiss

    @State private var loadError: String?
    @State private var didLoad: Bool = false
    @State private var needsJoin: Bool = false
    @State private var joining: Bool = false
    @State private var joinError: String?

    /// Device's last-known location, captured on appearance for initial
    /// map centering. Wins over the search's stored center because what
    /// the user almost always wants to see first is themselves.
    @State private var initialUserCenter: CLLocationCoordinate2D?

    // Draw mode (step 11).
    @State private var drawing: Bool = false
    @State private var draftPoints: [CLLocationCoordinate2D] = []
    @State private var areaSheetShown: Bool = false
    @State private var areaSaveError: String?

    // Share / Manage (step 12).
    @State private var shareSheetShown: Bool = false
    @State private var manageSheetShown: Bool = false

    /// Client-side throttle so we don't spam the hub if the device emits faster.
    /// Server enforces its own ~700ms rate limit, this is just bandwidth manners.
    @State private var lastSentAt: Date = .distantPast
    private static let minSendInterval: TimeInterval = 1.0

    var body: some View {
        content
            .navigationBarTitleDisplayMode(.inline)
            .task(id: slug) { await load() }
            .sheet(isPresented: $needsJoin) { joinSheet }
            .sheet(isPresented: $areaSheetShown) { areaSheet }
            .sheet(isPresented: $shareSheetShown) { shareSheet }
            .sheet(isPresented: $manageSheetShown) { manageSheet }
            .onDisappear {
                if recorder.isRecording { Task { await recorder.stop() } }
                location.stop()
                Task { await hub?.disconnect() }
            }
            .onChange(of: store.endedRemotely) { ended in
                if ended { loadError = "The owner ended this search." }
            }
    }

    private var isOwner: Bool {
        SessionStore.shared.ownerToken(for: slug) != nil
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
                participants: store.participants,
                areas: store.areas,
                paths: store.paths,
                drawing: drawing,
                draftPoints: draftPoints,
                onTapWhileDrawing: { coord in
                    draftPoints.append(coord)
                }
            )
            .ignoresSafeArea(edges: [.bottom, .leading, .trailing])

            titleBadge
                .padding(.horizontal, 12)
                .padding(.top, 8)
        }
        .overlay(alignment: .topTrailing) {
            HStack(spacing: 8) {
                drawButton
                recordPathButton
                shareLocationButton
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
        }
        .overlay(alignment: .bottom) {
            VStack(spacing: 10) {
                if let msg = recorder.error ?? location.lastError ?? areaSaveError {
                    Text(msg)
                        .font(.footnote)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(.regularMaterial, in: Capsule())
                        .transition(.opacity)
                }
                if drawing { drawingToolbar }
            }
            .padding(.bottom, 20)
        }
    }

    private var recordPathButton: some View {
        Button {
            toggleRecording()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: recorder.isRecording
                      ? "record.circle.fill"
                      : "record.circle")
                Text(recorder.isRecording ? "Recording" : "Record")
            }
            .font(.caption.weight(.medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.regularMaterial, in: Capsule())
            .foregroundStyle(recorder.isRecording ? Color.red : Color.primary)
        }
        .buttonStyle(.plain)
        .disabled(store.me == nil)
        .opacity(store.me == nil ? 0.5 : 1)
    }

    private var shareLocationButton: some View {
        Button {
            toggleShareLocation()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: location.isWatching
                      ? "location.fill"
                      : "location")
                Text(location.isWatching ? "Sharing" : "Share location")
            }
            .font(.caption.weight(.medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.regularMaterial, in: Capsule())
            .foregroundStyle(location.isWatching ? Color.green : Color.primary)
        }
        .buttonStyle(.plain)
        .disabled(store.me == nil)
        .opacity(store.me == nil ? 0.5 : 1)
    }

    private var joinSheet: some View {
        JoinSheet(
            searchTitle: store.title.isEmpty ? "Search" : store.title,
            onJoin: { name in await join(displayName: name) },
            onCancel: { needsJoin = false }
        )
        .presentationDetents([.medium, .large])
    }

    private var areaSheet: some View {
        AreaSheet(
            defaultColor: store.me?.color ?? "#3b82f6",
            onSave: { title, color in
                await commitArea(title: title, color: color)
            },
            onCancel: {
                areaSheetShown = false
                // Discarding the draft on cancel matches the web flow.
                draftPoints = []
            }
        )
        .presentationDetents([.medium, .large])
    }

    private var shareSheet: some View {
        ShareSheet(
            slug: slug,
            participantCount: store.participants.count,
            onClose: { shareSheetShown = false }
        )
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder
    private var manageSheet: some View {
        if let token = SessionStore.shared.ownerToken(for: slug) {
            ManageView(
                slug: slug,
                ownerToken: token,
                initialTitle: store.title,
                initialExpiresAt: store.expiresAt,
                onDeleted: {
                    manageSheetShown = false
                    dismiss()
                },
                onClose: { manageSheetShown = false }
            )
        }
    }

    private var drawButton: some View {
        Button {
            toggleDrawing()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: drawing
                      ? "pencil.tip.crop.circle.fill"
                      : "pencil.tip.crop.circle")
                Text(drawing ? "Drawing" : "Draw")
            }
            .font(.caption.weight(.medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.regularMaterial, in: Capsule())
            .foregroundStyle(drawing ? Color.orange : Color.primary)
        }
        .buttonStyle(.plain)
        .disabled(store.me == nil)
        .opacity(store.me == nil ? 0.5 : 1)
    }

    private var drawingToolbar: some View {
        HStack(spacing: 10) {
            Button(role: .cancel) {
                cancelDrawing()
            } label: {
                Label("Cancel", systemImage: "xmark")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.bordered)

            Button {
                if !draftPoints.isEmpty { draftPoints.removeLast() }
            } label: {
                Label("Undo", systemImage: "arrow.uturn.backward")
            }
            .buttonStyle(.bordered)
            .disabled(draftPoints.isEmpty)

            Button {
                areaSaveError = nil
                areaSheetShown = true
            } label: {
                Label("Finish", systemImage: "checkmark")
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .disabled(draftPoints.count < 3)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: Capsule())
    }

    // MARK: - Subviews

    private var titleBadge: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(store.title.isEmpty ? "Search" : store.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Button {
                    shareSheetShown = true
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .labelStyle(.iconOnly)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.15), in: Capsule())
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Share")
                if isOwner {
                    Button {
                        manageSheetShown = true
                    } label: {
                        Label("Manage", systemImage: "slider.horizontal.3")
                            .labelStyle(.iconOnly)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.15), in: Capsule())
                            .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Manage")
                }
            }
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
        if let me = initialUserCenter { return me }
        if let p = store.center {
            return CLLocationCoordinate2D(latitude: p.lat, longitude: p.lng)
        }
        return fallbackCenter
    }

    // MARK: - Loading + joining + hub

    private func load() async {
        loadError = nil
        didLoad = false
        do {
            let snap = try await ApiClient.shared.getSearch(slug: slug)
            store.hydrate(snap)
            didLoad = true
            // Remember this search on the device so the landing screen can
            // offer it as a quick re-entry next time.
            RecentSearchesStore.shared.upsert(
                slug: slug,
                title: snap.title,
                isOwner: SessionStore.shared.ownerToken(for: slug) != nil)
            // Fire-and-forget one-shot location request to recenter the map.
            // No-op if permission is denied; uses the cached fix if one is
            // already on hand.
            location.requestSingleFix { coord in
                initialUserCenter = coord
            }
            await resolveIdentityAndConnect()
        } catch let ApiError.status(404, _) {
            loadError = "This search doesn't exist. It may have expired."
            // Drop it from recents — there's nothing to come back to.
            RecentSearchesStore.shared.remove(slug: slug)
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

    // MARK: - Share location

    private func toggleShareLocation() {
        if location.isWatching {
            location.stop()
        } else {
            location.start { fix in
                handleFix(fix)
            }
        }
    }

    private func handleFix(_ fix: GeoFix) {
        // Client-side 1/s throttle on top of the server's 700ms rate limit.
        let now = Date()
        if now.timeIntervalSince(lastSentAt) < Self.minSendInterval { return }
        lastSentAt = now

        if let hub {
            Task {
                await hub.sendPosition(lng: fix.lng,
                                       lat: fix.lat,
                                       accuracy: fix.accuracyMeters,
                                       heading: fix.headingDegrees)
            }
        }

        // Tee fixes into the path recorder; it's a no-op when not recording.
        recorder.append([fix.lng, fix.lat])
    }

    // MARK: - Drawing

    private func toggleDrawing() {
        if drawing {
            cancelDrawing()
        } else {
            areaSaveError = nil
            draftPoints = []
            drawing = true
        }
    }

    private func cancelDrawing() {
        drawing = false
        draftPoints = []
        areaSheetShown = false
        areaSaveError = nil
    }

    private func commitArea(title: String?, color: String) async {
        guard draftPoints.count >= 3,
              let token = store.me?.sessionToken else {
            areaSaveError = "You need to be joined to add areas."
            areaSheetShown = false
            return
        }
        // GeoJSON ring is [lng, lat] and must close (first == last).
        var ring: [[Double]] = draftPoints.map { [$0.longitude, $0.latitude] }
        if let first = ring.first { ring.append(first) }
        let geometry = PolygonGeometry(ring: ring)
        do {
            _ = try await ApiClient.shared.addArea(
                slug: slug,
                geometry: geometry,
                title: title,
                color: color,
                sessionToken: token)
            // Server broadcasts AreaAdded — store will reflect it.
            areaSheetShown = false
            drawing = false
            draftPoints = []
            areaSaveError = nil
        } catch let ApiError.status(code, _) {
            areaSaveError = "Couldn't save area (HTTP \(code))."
            areaSheetShown = false
        } catch {
            areaSaveError = error.localizedDescription
            areaSheetShown = false
        }
    }

    // MARK: - Path recording

    private func toggleRecording() {
        if recorder.isRecording {
            Task { await recorder.stop() }
        } else {
            guard let me = store.me else { return }
            recorder.configure(slug: slug, sessionToken: me.sessionToken)
            // Auto-enable location sharing so the recorder gets fixes.
            if !location.isWatching {
                location.start { fix in handleFix(fix) }
            }
            recorder.start()
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
