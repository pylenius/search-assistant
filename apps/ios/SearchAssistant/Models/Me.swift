import Foundation

/// The local user's identity within a single search. Created when we
/// successfully POST /join (or rehydrate from /me on an auto-rejoin).
struct Me: Equatable {
    var id: UUID
    var sessionToken: String
    var color: String
    var displayName: String
}
