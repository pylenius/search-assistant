import SwiftUI

struct LandingView: View {
    /// Called when a slug is ready to navigate to — either freshly created
    /// or picked from the recents list.
    var onOpen: (String) -> Void

    @ObservedObject private var recents = RecentSearchesStore.shared

    @State private var title: String = "Quick search"
    @State private var creating: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section {
                hero
            }
            .listRowBackground(Color.clear)
            .listRowInsets(.init())

            Section("New search") {
                TextField("What are you searching for?", text: $title)
                    .submitLabel(.done)

                Button {
                    Task { await create() }
                } label: {
                    HStack {
                        if creating { ProgressView().controlSize(.small) }
                        Text(creating ? "Creating…" : "Create new search")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(creating || title.trimmingCharacters(in: .whitespaces).isEmpty)
                .listRowInsets(.init(top: 6, leading: 16, bottom: 8, trailing: 16))
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            }

            if !recents.items.isEmpty {
                Section("Recent searches") {
                    ForEach(recents.items) { item in
                        Button {
                            onOpen(item.slug)
                        } label: {
                            recentRow(item)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { offsets in
                        recents.remove(atOffsets: offsets)
                    }
                }
            }

            Section {
                Link("Privacy policy",
                     destination: URL(string: "https://searchassistant.eport.fi/privacy")!)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .listRowBackground(Color.clear)
        }
        .listStyle(.insetGrouped)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var hero: some View {
        VStack(spacing: 10) {
            Image(systemName: "map.fill")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
            Text("Search Assistant")
                .font(.title.weight(.semibold))
            Text("Share a search area and live positions with everyone you're searching with. No account needed.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private func recentRow(_ item: RecentSearch) -> some View {
        HStack(spacing: 12) {
            Image(systemName: item.isOwner ? "crown.fill" : "person.2.fill")
                .font(.callout)
                .foregroundStyle(item.isOwner ? Color.orange : Color.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title.isEmpty ? "Search" : item.title)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text("/s/\(item.slug)")
                        .font(.caption2.monospaced())
                    Text("·")
                    Text(relativeAge(from: item.visitedAt))
                    if item.isOwner {
                        Text("·")
                        Text("owner")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color(.tertiaryLabel))
        }
        .contentShape(Rectangle())
        .padding(.vertical, 2)
    }

    private func relativeAge(from date: Date) -> String {
        let s = Int(Date().timeIntervalSince(date))
        if s < 60 { return "just now" }
        let m = s / 60
        if m < 60 { return "\(m)m ago" }
        let h = m / 60
        if h < 24 { return "\(h)h ago" }
        let d = h / 24
        if d < 7 { return "\(d)d ago" }
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: date)
    }

    private func create() async {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        creating = true
        errorMessage = nil
        defer { creating = false }

        do {
            let response = try await ApiClient.shared.createSearch(
                CreateSearchRequest(title: trimmed,
                                    centerLng: nil,
                                    centerLat: nil,
                                    zoom: 14)
            )
            SessionStore.shared.setOwnerToken(response.ownerToken, for: response.slug)
            // SearchView's load() will upsert into recents on its own — no
            // need to do it here too.
            onOpen(response.slug)
        } catch let ApiError.status(code, _) {
            errorMessage = "Couldn't create search (HTTP \(code))."
        } catch {
            errorMessage = "Network error — \(error.localizedDescription)"
        }
    }
}

#Preview {
    NavigationStack {
        LandingView { _ in }
    }
}
