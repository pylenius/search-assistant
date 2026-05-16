import SwiftUI

/// Owner-only management sheet. Guarded by the local owner token —
/// callers must have already checked `SessionStore.ownerToken(for:)`
/// before presenting.
struct ManageView: View {
    let slug: String
    let ownerToken: String
    var initialTitle: String
    var initialExpiresAt: Date?
    /// Called once the search has been deleted server-side. Parent
    /// pops back to landing.
    var onDeleted: () -> Void
    var onClose: () -> Void

    @State private var title: String = ""
    @State private var hasExpiry: Bool = false
    @State private var expiresAt: Date = Date().addingTimeInterval(60 * 60 * 24)
    @State private var saving: Bool = false
    @State private var status: String?
    @State private var statusIsError: Bool = false
    @State private var confirmingClear: Bool = false
    @State private var confirmingDelete: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("Search title", text: $title)
                        .submitLabel(.done)
                }

                Section("Expires") {
                    Toggle("Set an expiry", isOn: $hasExpiry.animation())
                    if hasExpiry {
                        DatePicker("Expires at",
                                   selection: $expiresAt,
                                   displayedComponents: [.date, .hourAndMinute])
                        Text(expiryStatus)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Never expires")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button {
                        Task { await save() }
                    } label: {
                        HStack {
                            if saving { ProgressView().padding(.trailing, 6) }
                            Text(saving ? "Saving…" : "Save changes")
                        }
                    }
                    .disabled(saving || title.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                if let status {
                    Section {
                        Text(status)
                            .foregroundStyle(statusIsError ? .red : .secondary)
                    }
                }

                Section("Danger zone") {
                    Button("Clear all recorded paths", role: .destructive) {
                        confirmingClear = true
                    }
                    Button("Delete search", role: .destructive) {
                        confirmingDelete = true
                    }
                }
            }
            .navigationTitle("Manage search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done", action: onClose)
                }
            }
            .confirmationDialog("Clear all recorded paths? This cannot be undone.",
                                isPresented: $confirmingClear,
                                titleVisibility: .visible) {
                Button("Clear paths", role: .destructive) { Task { await clearPaths() } }
                Button("Cancel", role: .cancel) { }
            }
            .confirmationDialog("Delete this entire search? All participants, areas, and paths are removed for everyone.",
                                isPresented: $confirmingDelete,
                                titleVisibility: .visible) {
                Button("Delete search", role: .destructive) { Task { await deleteSearch() } }
                Button("Cancel", role: .cancel) { }
            }
        }
        .onAppear {
            if title.isEmpty { title = initialTitle }
            if let exp = initialExpiresAt {
                hasExpiry = true
                expiresAt = exp
            }
        }
    }

    private var expiryStatus: String {
        let diff = expiresAt.timeIntervalSinceNow
        if diff < 0 { return "Already expired" }
        let hours = Int(diff / 3600)
        if hours < 1 { return "Expires in <1h" }
        let days = hours / 24
        let remH = hours % 24
        return days > 0 ? "Expires in \(days)d \(remH)h" : "Expires in \(hours)h"
    }

    // MARK: - Actions

    private func save() async {
        saving = true; status = nil
        defer { saving = false }
        do {
            _ = try await ApiClient.shared.updateSearch(
                slug: slug,
                title: title.trimmingCharacters(in: .whitespaces),
                expiresAt: hasExpiry ? expiresAt : nil,
                ownerToken: ownerToken)
            statusIsError = false
            status = "Saved."
        } catch let ApiError.status(code, _) {
            statusIsError = true
            status = "Save failed (HTTP \(code))."
        } catch {
            statusIsError = true
            status = error.localizedDescription
        }
    }

    private func clearPaths() async {
        status = nil
        do {
            let resp = try await ApiClient.shared.clearPaths(slug: slug, ownerToken: ownerToken)
            statusIsError = false
            status = "Cleared \(resp.cleared) path\(resp.cleared == 1 ? "" : "s")."
        } catch let ApiError.status(code, _) {
            statusIsError = true
            status = "Clear failed (HTTP \(code))."
        } catch {
            statusIsError = true
            status = error.localizedDescription
        }
    }

    private func deleteSearch() async {
        status = nil
        do {
            try await ApiClient.shared.deleteSearch(slug: slug, ownerToken: ownerToken)
            onDeleted()
        } catch let ApiError.status(code, _) {
            statusIsError = true
            status = "Delete failed (HTTP \(code))."
        } catch {
            statusIsError = true
            status = error.localizedDescription
        }
    }
}

#Preview {
    ManageView(
        slug: "abc12345",
        ownerToken: "owner-token",
        initialTitle: "Saturday hike",
        initialExpiresAt: Date().addingTimeInterval(86400 * 2),
        onDeleted: {},
        onClose: {})
}
