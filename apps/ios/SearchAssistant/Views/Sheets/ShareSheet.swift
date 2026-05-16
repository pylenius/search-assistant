import SwiftUI
import CoreImage.CIFilterBuiltins
import UIKit

struct ShareSheet: View {
    let slug: String
    let participantCount: Int
    var onClose: () -> Void

    @State private var copied: Bool = false
    @State private var qrImage: UIImage?

    /// Direct user-facing URL — matches what the web app renders.
    private var shareURL: URL {
        URL(string: "https://searchassistant.eport.fi/s/\(slug)")!
    }

    /// GPX export served by the API for this search.
    private var gpxURL: URL {
        AppConfig.apiBaseURL.appendingPathComponent("api/searches/\(slug)/export.gpx")
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Text("\(participantCount) \(participantCount == 1 ? "person" : "people") joined so far")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Group {
                    if let qrImage {
                        Image(uiImage: qrImage)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                    } else {
                        Color(.secondarySystemBackground)
                    }
                }
                .frame(width: 220, height: 220)
                .background(Color.white)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.separator)))

                Text(shareURL.absoluteString)
                    .font(.footnote.monospaced())
                    .multilineTextAlignment(.center)
                    .textSelection(.enabled)
                    .padding(.horizontal)

                HStack(spacing: 12) {
                    Button {
                        UIPasteboard.general.string = shareURL.absoluteString
                        copied = true
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 1_800_000_000)
                            copied = false
                        }
                    } label: {
                        Label(copied ? "Copied" : "Copy link",
                              systemImage: copied ? "checkmark" : "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    ShareLink(item: shareURL) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal)

                Link(destination: gpxURL) {
                    Label("Download GPX", systemImage: "arrow.down.doc")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.bordered)
                .padding(.horizontal)

                Spacer(minLength: 0)
            }
            .padding(.top, 16)
            .navigationTitle("Share this search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onClose)
                }
            }
        }
        .onAppear { qrImage = makeQR(for: shareURL.absoluteString) }
    }

    private func makeQR(for string: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        // The native QR is tiny (~25×25); scale up *before* rasterizing so the
        // image is sharp at any frame size.
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        let ctx = CIContext()
        guard let cg = ctx.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}

#Preview {
    ShareSheet(slug: "abc12345", participantCount: 3, onClose: {})
}
