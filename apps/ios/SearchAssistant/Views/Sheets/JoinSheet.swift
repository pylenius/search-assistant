import SwiftUI

struct JoinSheet: View {
    let searchTitle: String
    var initialName: String = ""
    var onJoin: (String) async -> Void
    var onCancel: () -> Void

    @State private var name: String = ""
    @State private var joining: Bool = false
    @State private var errorMessage: String?
    @FocusState private var nameFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("e.g. Alice", text: $name)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.join)
                        .focused($nameFocused)
                        .onSubmit { Task { await submit() } }
                } header: {
                    Text("Your display name")
                } footer: {
                    Text("Other participants in “\(searchTitle)” will see this name and a color we assign to you.")
                }

                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.orange) }
                }
            }
            .navigationTitle("Join search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel).disabled(joining)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Join") {
                        Task { await submit() }
                    }
                    .disabled(joining || name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .interactiveDismissDisabled(joining)
        .onAppear {
            if name.isEmpty { name = initialName }
            nameFocused = true
        }
    }

    private func submit() async {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !joining else { return }
        joining = true
        errorMessage = nil
        await onJoin(trimmed)
        joining = false
    }
}

#Preview {
    JoinSheet(searchTitle: "Mushroom hunt", onJoin: { _ in }, onCancel: {})
}
