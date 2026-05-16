import SwiftUI

struct LandingView: View {
    /// Called with the slug of the newly-created search.
    var onCreated: (String) -> Void

    @State private var title: String = "Quick search"
    @State private var creating: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "map.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.tint)
                Text("Search Assistant")
                    .font(.largeTitle.weight(.semibold))
                Text("Share a search area and live positions with everyone you're searching with. No account needed.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }

            VStack(spacing: 12) {
                TextField("What are you searching for?", text: $title)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.done)

                Button {
                    Task { await create() }
                } label: {
                    HStack {
                        if creating { ProgressView().controlSize(.small).tint(.white) }
                        Text(creating ? "Creating…" : "Create new search")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(creating || title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 24)

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 24)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .padding()
        .navigationBarTitleDisplayMode(.inline)
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
            onCreated(response.slug)
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
