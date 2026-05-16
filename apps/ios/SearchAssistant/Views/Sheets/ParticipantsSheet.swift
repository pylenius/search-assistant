import SwiftUI

/// Bottom-right "people" panel. Lists every participant in the search;
/// tapping a row asks the host view to recenter the map on that
/// participant. Rows whose participant has never shared a location yet
/// are still listed but disabled.
struct ParticipantsSheet: View {
    /// Stable, ordered list of participants. Caller computes this once
    /// per render so we can drive `id:` on the ForEach.
    let rows: [Row]
    var onFocus: (UUID) -> Void
    var onClose: () -> Void

    /// Updates every 15s so the relative-age strings stay fresh while
    /// the sheet is open (matches the web ParticipantList tick).
    @State private var now: Date = Date()
    private let tick = Timer.publish(every: 15, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            List {
                ForEach(rows) { row in
                    Button {
                        onFocus(row.id)
                    } label: {
                        rowView(row)
                    }
                    .buttonStyle(.plain)
                    .disabled(!row.hasPosition)
                    .opacity(row.isStale && !row.isMe ? 0.55 : 1)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Participants")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onClose)
                }
            }
        }
        .onReceive(tick) { now = $0 }
    }

    private func rowView(_ row: Row) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(hex: row.color))
                .frame(width: 14, height: 14)
                .overlay(
                    Circle().stroke(Color.white, lineWidth: 2)
                )
                .shadow(color: Color.black.opacity(0.15), radius: 1, y: 1)

            VStack(alignment: .leading, spacing: 2) {
                Text(row.displayName + (row.isMe ? " (you)" : ""))
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(rowSubtitle(row))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if row.hasPosition {
                Image(systemName: "scope")
                    .font(.callout)
                    .foregroundStyle(.tint)
            } else {
                Image(systemName: "location.slash")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .contentShape(Rectangle())
        .padding(.vertical, 4)
    }

    private func rowSubtitle(_ row: Row) -> String {
        if !row.hasPosition { return "No location yet" }
        return relativeAge(from: row.lastSeenAt)
    }

    private func relativeAge(from date: Date) -> String {
        let s = Int(now.timeIntervalSince(date))
        if s < 30 { return "now" }
        if s < 60 { return "\(s)s ago" }
        let m = s / 60
        if m < 60 { return "\(m)m ago" }
        let h = m / 60
        if h < 24 { return "\(h)h ago" }
        return "\(h / 24)d ago"
    }

    struct Row: Identifiable, Equatable {
        let id: UUID
        let displayName: String
        let color: String
        let lastSeenAt: Date
        let hasPosition: Bool
        let isMe: Bool
        let isStale: Bool
    }
}
