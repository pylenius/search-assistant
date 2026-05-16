import SwiftUI

struct AreaSheet: View {
    /// Default color when the user hasn't chosen one (typically their own).
    let defaultColor: String
    var initialTitle: String = ""
    var onSave: (_ title: String?, _ color: String) async -> Void
    var onCancel: () -> Void

    @State private var title: String = ""
    @State private var selectedColor: String = ""
    @State private var saving: Bool = false
    @State private var errorMessage: String?
    @FocusState private var titleFocused: Bool

    /// Same palette as ColorPalette.cs server-side / web AreaDialog.
    private static let palette: [String] = [
        "#ef4444", "#f97316", "#eab308", "#22c55e", "#14b8a6",
        "#3b82f6", "#6366f1", "#a855f7", "#ec4899", "#0ea5e9",
        "#84cc16", "#f43f5e",
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("e.g. North hillside", text: $title)
                        .focused($titleFocused)
                        .submitLabel(.done)
                } header: {
                    Text("Title")
                } footer: {
                    Text("Optional — shows in the Areas list and on shared GPX exports.")
                }

                Section {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(minimum: 32), spacing: 12), count: 6),
                        spacing: 12
                    ) {
                        ForEach(Self.palette, id: \.self) { hex in
                            colorSwatch(hex)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Color")
                }

                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.orange) }
                }
            }
            .navigationTitle("Save area")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel).disabled(saving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(saving)
                }
            }
        }
        .interactiveDismissDisabled(saving)
        .onAppear {
            if title.isEmpty { title = initialTitle }
            if selectedColor.isEmpty { selectedColor = defaultColor }
            titleFocused = true
        }
    }

    private func colorSwatch(_ hex: String) -> some View {
        let isSelected = hex == selectedColor
        return Button {
            selectedColor = hex
        } label: {
            Circle()
                .fill(Color(hex: hex))
                .frame(width: 34, height: 34)
                .overlay(
                    Circle()
                        .stroke(isSelected ? Color.primary : Color.clear, lineWidth: 3)
                        .padding(-2)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Color \(hex)")
    }

    private func save() async {
        guard !saving else { return }
        saving = true
        errorMessage = nil
        let titleTrimmed = title.trimmingCharacters(in: .whitespaces)
        await onSave(titleTrimmed.isEmpty ? nil : titleTrimmed, selectedColor)
        saving = false
    }
}

#Preview {
    AreaSheet(defaultColor: "#3b82f6", onSave: { _, _ in }, onCancel: {})
}
