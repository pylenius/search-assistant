import Foundation

/// Per-slug auth tokens. UserDefaults is fine here — these are link-derived
/// session secrets, not high-value credentials; users are on the link-trust
/// model anyway. Keys mirror the web app's localStorage (`sa:session:{slug}`,
/// `sa:owner:{slug}`) so the prefix is easy to grep for if needed.
final class SessionStore {
    static let shared = SessionStore()
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Session token (participant)

    func sessionToken(for slug: String) -> String? {
        defaults.string(forKey: Self.sessionKey(slug))
    }

    func setSessionToken(_ token: String, for slug: String) {
        defaults.set(token, forKey: Self.sessionKey(slug))
    }

    func clearSessionToken(for slug: String) {
        defaults.removeObject(forKey: Self.sessionKey(slug))
    }

    // MARK: - Owner token (creator)

    func ownerToken(for slug: String) -> String? {
        defaults.string(forKey: Self.ownerKey(slug))
    }

    func setOwnerToken(_ token: String, for slug: String) {
        defaults.set(token, forKey: Self.ownerKey(slug))
    }

    // MARK: - Keys

    private static func sessionKey(_ slug: String) -> String { "sa.session.\(slug)" }
    private static func ownerKey(_ slug: String) -> String   { "sa.owner.\(slug)" }
}
