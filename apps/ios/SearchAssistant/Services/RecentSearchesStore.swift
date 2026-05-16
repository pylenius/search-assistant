import Foundation

struct RecentSearch: Codable, Identifiable, Equatable {
    var slug: String
    var title: String
    var visitedAt: Date
    var isOwner: Bool

    var id: String { slug }
}

/// Persistent list of searches the user has opened on this device.
///
/// Backed by UserDefaults (single JSON blob under `sa.recents.v1`) so it
/// matches the existing SessionStore model — slugs and titles aren't
/// secrets, the actual auth tokens live separately in
/// [[user_session_store]]'s keyspace.
///
/// Capped at 20 entries so the landing list stays scannable. Eviction is
/// oldest-first by `visitedAt`.
@MainActor
final class RecentSearchesStore: ObservableObject {
    static let shared = RecentSearchesStore()

    @Published private(set) var items: [RecentSearch] = []

    private let defaults: UserDefaults
    private let key = "sa.recents.v1"
    private let cap = 20

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        items = Self.load(from: defaults, key: key)
    }

    /// Add or refresh an entry. Newest visit goes to the top.
    func upsert(slug: String, title: String, isOwner: Bool) {
        var current = items
        current.removeAll { $0.slug == slug }
        current.insert(
            RecentSearch(slug: slug,
                         title: title,
                         visitedAt: Date(),
                         isOwner: isOwner),
            at: 0)
        if current.count > cap {
            current.removeLast(current.count - cap)
        }
        items = current
        persist()
    }

    func remove(slug: String) {
        items.removeAll { $0.slug == slug }
        persist()
    }

    func remove(atOffsets offsets: IndexSet) {
        // High-to-low so earlier indices stay valid after each removal.
        for i in offsets.sorted(by: >) {
            items.remove(at: i)
        }
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        defaults.set(data, forKey: key)
    }

    private static func load(from defaults: UserDefaults, key: String) -> [RecentSearch] {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([RecentSearch].self, from: data) else {
            return []
        }
        return decoded
    }
}
