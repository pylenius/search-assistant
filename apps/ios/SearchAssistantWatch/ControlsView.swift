import SwiftUI

/// The reason this app exists: start and stop recording without digging a
/// phone out of a pocket with wet or gloved hands.
struct ControlsView: View {
    @EnvironmentObject private var link: WatchLink

    private var snapshot: WatchSnapshot { link.snapshot }

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                header

                Button {
                    link.send(.toggleRecording)
                } label: {
                    Label(snapshot.isRecording ? "Recording" : "Record",
                          systemImage: snapshot.isRecording
                            ? "record.circle.fill" : "record.circle")
                        .frame(maxWidth: .infinity)
                }
                .tint(snapshot.isRecording ? .red : .gray)

                Button {
                    link.send(.toggleSharing)
                } label: {
                    Label(snapshot.isSharing ? "Sharing" : "Share location",
                          systemImage: snapshot.isSharing
                            ? "location.fill" : "location")
                        .frame(maxWidth: .infinity)
                }
                .tint(snapshot.isSharing ? .green : .gray)

                if let error = link.commandError {
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private var header: some View {
        VStack(spacing: 2) {
            Text(snapshot.title.isEmpty ? "Search" : snapshot.title)
                .font(.headline)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            HStack(spacing: 4) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 6, height: 6)
                Text(statusLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.bottom, 2)
    }

    /// Reachability beats the phone's own hub state here: if the watch has
    /// lost the phone, nothing on this screen is current, and saying
    /// "connected" because the *phone* was connected two minutes ago would
    /// be a lie the wearer can't check.
    private var statusColor: Color {
        if !link.isReachable { return .orange }
        return snapshot.isConnected ? .green : .yellow
    }

    private var statusLabel: String {
        if !link.isReachable { return "iPhone not reachable" }
        return snapshot.isConnected
            ? "\(snapshot.people.count) in search"
            : "Connecting…"
    }
}
