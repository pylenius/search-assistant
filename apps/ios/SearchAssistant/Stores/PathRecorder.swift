import Foundation

/// Owns the lifecycle of one path-recording session for the local user.
///
/// Flow mirrors apps/web/src/views/SearchView.vue:
///   start() → reset buffer; fix updates land via append(); every 5 s a
///   flush task POSTs /paths the first time it has ≥2 points and PATCHes
///   thereafter; stop() drains + PATCH finalize:true on the server.
@MainActor
final class PathRecorder: ObservableObject {
    @Published var isRecording: Bool = false
    @Published var error: String?

    private var pathId: UUID?
    private var buffer: [[Double]] = []
    private var flushTask: Task<Void, Never>?

    /// Set once we know the slug + session token (typically in SearchView's
    /// `.onChange(of: me)`).
    var slug: String?
    var sessionToken: String?

    static let flushInterval: Duration = .seconds(5)

    func configure(slug: String, sessionToken: String) {
        self.slug = slug
        self.sessionToken = sessionToken
    }

    func append(_ point: [Double]) {
        guard isRecording else { return }
        buffer.append(point)
    }

    func start() {
        guard !isRecording else { return }
        buffer.removeAll()
        pathId = nil
        error = nil
        isRecording = true

        flushTask = Task { [weak self] in
            while await self?.isRecording == true {
                try? await Task.sleep(for: Self.flushInterval)
                await self?.flush()
            }
        }
    }

    func stop() async {
        flushTask?.cancel()
        flushTask = nil
        isRecording = false
        await flush()
        await finalize()
        pathId = nil
        buffer.removeAll()
    }

    private func flush() async {
        guard !buffer.isEmpty,
              let slug,
              let token = sessionToken else { return }
        let points = buffer
        buffer.removeAll()

        do {
            if let pid = pathId {
                _ = try await ApiClient.shared.appendToPath(
                    slug: slug, pathId: pid, points: points, sessionToken: token)
            } else if points.count >= 2 {
                let path = try await ApiClient.shared.startPath(
                    slug: slug, points: points, sessionToken: token)
                pathId = path.id
            } else {
                // Need at least 2 points to start a path; hold for the next flush.
                buffer.insert(contentsOf: points, at: 0)
            }
        } catch {
            self.error = "Couldn't save path."
            // Put the points back so we retry on the next tick.
            buffer.insert(contentsOf: points, at: 0)
        }
    }

    private func finalize() async {
        guard let pid = pathId,
              let slug,
              let token = sessionToken else { return }
        do {
            _ = try await ApiClient.shared.finalizePath(
                slug: slug, pathId: pid, sessionToken: token)
        } catch {
            // Soft fail — the server will still simplify on next snapshot.
        }
    }
}
