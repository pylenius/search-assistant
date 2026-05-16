import SwiftUI
import CoreLocation

/// Helsinki — fallback center when neither the snapshot nor the device has a known location.
private let fallbackCenter = CLLocationCoordinate2D(latitude: 60.17, longitude: 24.94)
private let fallbackZoom = 12

struct SearchView: View {
    let slug: String

    @State private var snapshot: SearchSnapshotDto?
    @State private var loadError: String?

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
    }

    private func titleBadge(snapshot: SearchSnapshotDto) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(snapshot.title.isEmpty ? "Search" : snapshot.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            Text("\(snapshot.participants.count) \(snapshot.participants.count == 1 ? "person" : "people")")
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

    private func load() async {
        loadError = nil
        do {
            snapshot = try await ApiClient.shared.getSearch(slug: slug)
        } catch let ApiError.status(404, _) {
            loadError = "This search doesn't exist. It may have expired."
        } catch let ApiError.status(code, _) {
            loadError = "HTTP \(code) loading search."
        } catch {
            loadError = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        SearchView(slug: "abc12345")
    }
}
