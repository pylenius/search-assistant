import SwiftUI
import CoreLocation

/// Helsinki — fallback center when neither the snapshot nor the device has a known location.
private let fallbackCenter = CLLocationCoordinate2D(latitude: 60.17, longitude: 24.94)

struct SearchView: View {
    let slug: String

    @State private var snapshot: SearchSnapshotDto?
    @State private var loadError: String?
    @State private var me: Me?
    @State private var needsJoin: Bool = false
    @State private var joinError: String?

    var body: some View {
        Group {
            if let snapshot {
                ZStack(alignment: .topLeading) {
                    MapView(
                        center: mapCenter(snapshot),
                        zoom: snapshot.defaultZoom
                    )
                    .ignoresSafeArea(edges: [.bottom, .leading, .trailing])

                    titleBadge(snapshot: snapshot)
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                }
            } else if let loadError {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundStyle(.orange)
                    Text("Couldn't load search")
                        .font(.headline)
                    Text(loadError)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ProgressView("Loading search…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task(id: slug) {
            await load()
        }
        .sheet(isPresented: $needsJoin) {
            JoinSheet(
                searchTitle: snapshot?.title ?? "Search",
                onJoin: { name in await join(displayName: name) },
                onCancel: { needsJoin = false }
            )
            .presentationDetents([.medium, .large])
        }
    }

    private func titleBadge(snapshot: SearchSnapshotDto) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(snapshot.title.isEmpty ? "Search" : snapshot.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            HStack(spacing: 6) {
                Text("\(snapshot.participants.count) \(snapshot.participants.count == 1 ? "person" : "people")")
                if let me {
                    Text("·")
                    Circle().fill(Color(hex: me.color)).frame(width: 8, height: 8)
                    Text(me.displayName).lineLimit(1)
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func mapCenter(_ snapshot: SearchSnapshotDto) -> CLLocationCoordinate2D {
        guard let p = snapshot.center else { return fallbackCenter }
        return CLLocationCoordinate2D(latitude: p.lat, longitude: p.lng)
    }

    // MARK: - Loading + joining

    private func load() async {
        loadError = nil
        do {
            let snap = try await ApiClient.shared.getSearch(slug: slug)
            snapshot = snap
            await resolveIdentity(in: snap)
        } catch let ApiError.status(404, _) {
            loadError = "This search doesn't exist. It may have expired."
        } catch let ApiError.status(code, _) {
            loadError = "HTTP \(code) loading search."
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func resolveIdentity(in snapshot: SearchSnapshotDto) async {
        if let token = SessionStore.shared.sessionToken(for: slug) {
            do {
                let dto = try await ApiClient.shared.me(slug: slug, sessionToken: token)
                me = Me(id: dto.id,
                        sessionToken: token,
                        color: dto.color,
                        displayName: dto.displayName)
                return
            } catch ApiError.status(401, _) {
                SessionStore.shared.clearSessionToken(for: slug)
            } catch {
                // Network hiccup — leave the user as-is for now; they can
                // re-open the search to retry.
                return
            }
        }
        needsJoin = true
    }

    private func join(displayName: String) async {
        joinError = nil
        do {
            let resp = try await ApiClient.shared.joinSearch(slug: slug,
                                                             displayName: displayName)
            SessionStore.shared.setSessionToken(resp.sessionToken, for: slug)
            me = Me(id: resp.participantId,
                    sessionToken: resp.sessionToken,
                    color: resp.color,
                    displayName: displayName)
            needsJoin = false
            // Refresh the snapshot so participant count + lists include us.
            if let refreshed = try? await ApiClient.shared.getSearch(slug: slug) {
                snapshot = refreshed
            }
        } catch let ApiError.status(code, _) {
            joinError = "Couldn't join (HTTP \(code))."
        } catch {
            joinError = error.localizedDescription
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
