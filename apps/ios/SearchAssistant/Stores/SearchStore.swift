import Foundation
import Combine

enum ConnectionState: Equatable {
    case idle, connecting, connected, failed
}

/// Mirrors apps/web/src/stores/searchStore.ts: holds all live state for one
/// search, hydrated from `GET /api/searches/{slug}` and then mutated by
/// SignalR events. UIView wrappers and SwiftUI views observe via @Published.
@MainActor
final class SearchStore: ObservableObject {
    @Published var slug: String?
    @Published var title: String = ""
    @Published var expiresAt: Date?
    @Published var center: PointGeometry?
    @Published var defaultZoom: Int = 13

    // Dictionary keyed by id for O(1) upsert; views compute sorted arrays
    // via the helpers below.
    @Published var participants: [UUID: ParticipantDto] = [:]
    @Published var areas: [UUID: AreaDto] = [:]
    @Published var paths: [UUID: PathDto] = [:]
    @Published var positions: [UUID: PositionUpdateDto] = [:]

    /// Participants whose trails are hidden from the map. Per-device, not
    /// persisted and not shared: it declutters this screen and nothing more.
    /// Markers are deliberately never hidden — where someone is matters even
    /// when where they've been is in the way.
    @Published var hiddenTrails: Set<UUID> = []

    @Published var me: Me?
    @Published var connectionState: ConnectionState = .idle
    /// Set when the search is deleted by its owner (SearchEnded broadcast).
    @Published var endedRemotely: Bool = false
    /// Set when the owner removed *us* specifically. Distinct from
    /// `endedRemotely` because the search is still running for everyone else.
    @Published var removedRemotely: Bool = false

    // MARK: - Derived

    var participantList: [ParticipantDto] {
        participants.values.sorted { $0.joinedAt < $1.joinedAt }
    }

    var areaList: [AreaDto] {
        areas.values.sorted { $0.createdAt < $1.createdAt }
    }

    // MARK: - Hydration

    func hydrate(_ snapshot: SearchSnapshotDto) {
        slug = snapshot.slug
        title = snapshot.title
        expiresAt = snapshot.expiresAt
        center = snapshot.center
        defaultZoom = snapshot.defaultZoom
        participants = Dictionary(uniqueKeysWithValues:
            snapshot.participants.map { ($0.id, $0) })
        areas = Dictionary(uniqueKeysWithValues:
            snapshot.areas.map { ($0.id, $0) })
        paths = Dictionary(uniqueKeysWithValues:
            snapshot.paths.map { ($0.id, $0) })
        // Seed positions from participants who already have a lastPosition.
        positions = Dictionary(uniqueKeysWithValues:
            snapshot.participants.compactMap { p in
                guard let pos = p.lastPosition else { return nil }
                return (p.id, PositionUpdateDto(
                    participantId: p.id,
                    lng: pos.lng, lat: pos.lat,
                    accuracyMeters: 0,
                    headingDegrees: nil,
                    recordedAt: p.lastSeenAt))
            })
    }

    // MARK: - Mutations (hub event handlers + manual writes)

    func upsertParticipant(_ p: ParticipantDto) { participants[p.id] = p }
    func applyPosition(_ u: PositionUpdateDto) { positions[u.participantId] = u }
    func upsertArea(_ a: AreaDto) { areas[a.id] = a }
    func removeArea(_ id: UUID) { areas.removeValue(forKey: id) }
    func upsertPath(_ p: PathDto) { paths[p.id] = p }
    func removePath(_ id: UUID) { paths.removeValue(forKey: id) }

    func toggleTrail(_ participantId: UUID) {
        if hiddenTrails.contains(participantId) {
            hiddenTrails.remove(participantId)
        } else {
            hiddenTrails.insert(participantId)
        }
    }

    /// Owner removed someone. The server deletes their paths and areas and
    /// announces each one, but sweep up here too: a client that reconnected
    /// mid-removal would otherwise keep drawing shapes owned by nobody.
    func removeParticipant(_ id: UUID) {
        if me?.id == id {
            removedRemotely = true
            return
        }
        participants.removeValue(forKey: id)
        positions.removeValue(forKey: id)
        paths = paths.filter { $0.value.participantId != id }
        areas = areas.filter { $0.value.createdByParticipantId != id }
        hiddenTrails.remove(id)
    }

    func finalizePath(_ id: UUID) {
        guard var p = paths[id] else { return }
        if p.endedAt == nil { p.endedAt = Date() }
        paths[id] = p
    }

    func searchUpdated(_ u: SearchUpdatedDto) {
        title = u.title
        expiresAt = u.expiresAt
    }

    func searchEnded(slug: String) {
        endedRemotely = true
    }

    func reset() {
        slug = nil
        title = ""
        expiresAt = nil
        center = nil
        defaultZoom = 13
        participants = [:]
        areas = [:]
        paths = [:]
        positions = [:]
        hiddenTrails = []
        me = nil
        connectionState = .idle
        endedRemotely = false
        removedRemotely = false
    }
}
