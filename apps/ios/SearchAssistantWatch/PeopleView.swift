import SwiftUI

/// Who's where, as distance and compass point from the phone on your hip.
struct PeopleView: View {
    @EnvironmentObject private var link: WatchLink

    /// How long without an update before someone reads as stale. Matches
    /// the phone's marker fade so the two never disagree.
    private static let staleAfter: TimeInterval = 5 * 60

    var body: some View {
        List {
            if rows.isEmpty {
                Text("No one here yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ForEach(rows) { row in
                PersonRow(row: row)
            }
        }
        .listStyle(.carousel)
    }

    /// Me first, then whoever we can locate, nearest first, then everyone
    /// whose position we don't have. On a wrist the top two rows are all
    /// that's visible without scrolling, so the ordering has to earn them.
    private var rows: [PersonRow.Model] {
        let snapshot = link.snapshot
        let now = Date()
        let models = snapshot.people.map { person -> PersonRow.Model in
            var distance: Double?
            var bearing: Double?
            if let originLat = snapshot.myLat, let originLng = snapshot.myLng,
               let lat = person.lat, let lng = person.lng, !person.isMe {
                distance = Geo.distanceMetres(fromLat: originLat, fromLng: originLng,
                                              toLat: lat, toLng: lng)
                bearing = Geo.bearingDegrees(fromLat: originLat, fromLng: originLng,
                                             toLat: lat, toLng: lng)
            }
            return PersonRow.Model(
                id: person.id,
                name: person.name,
                colorHex: person.colorHex,
                isMe: person.isMe,
                hasPosition: person.lat != nil && person.lng != nil,
                distanceMetres: distance,
                bearingDegrees: bearing,
                isStale: now.timeIntervalSince(person.lastSeenAt) > Self.staleAfter)
        }

        return models.sorted { lhs, rhs in
            if lhs.isMe != rhs.isMe { return lhs.isMe }
            switch (lhs.distanceMetres, rhs.distanceMetres) {
            case let (l?, r?): return l < r
            case (_?, nil):    return true
            case (nil, _?):    return false
            case (nil, nil):   return lhs.name < rhs.name
            }
        }
    }
}

struct PersonRow: View {
    struct Model: Identifiable {
        let id: UUID
        let name: String
        let colorHex: String
        let isMe: Bool
        let hasPosition: Bool
        let distanceMetres: Double?
        let bearingDegrees: Double?
        let isStale: Bool
    }

    let row: Model

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color(hex: row.colorHex))
                .frame(width: 10, height: 10)
                .opacity(row.isStale ? 0.4 : 1)
            VStack(alignment: .leading, spacing: 1) {
                Text(row.name)
                    .font(.body)
                    .lineLimit(1)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }

    private var detail: String {
        if row.isMe { return "You" }
        guard let distance = row.distanceMetres,
              let bearing = row.bearingDegrees else {
            return row.hasPosition ? "Position unknown" : "Not sharing"
        }
        let base = "\(Geo.formatDistance(distance)) · \(Geo.compassPoint(bearing))"
        return row.isStale ? "\(base) · stale" : base
    }
}
