import Foundation

/// Everything the watch knows about a search.
///
/// The phone owns every network connection — REST, SignalR and CoreLocation
/// all stay there — and the watch is a display plus a remote control. This
/// flattened snapshot is the entire contract between them, which is why the
/// watch target needs none of `ApiClient`, `SignalRService` or the stores.
///
/// Deliberately *not* the API DTOs: those carry geometry, tokens and expiry
/// the watch has no use for, and pinning the wire format for the watch to
/// the server's would mean a watch update every time the API moves.
struct WatchSnapshot: Codable, Equatable {
    /// `nil` when no search is open on the phone — the watch shows its
    /// idle screen rather than the last search's stale people.
    var slug: String?
    var title: String = ""
    var isRecording: Bool = false
    var isSharing: Bool = false
    var isConnected: Bool = false

    /// The phone's own last known position, and the origin for every
    /// distance and bearing the watch draws. Sending it means the watch
    /// never asks for location permission of its own — the phone is on
    /// the same body, so the difference is centimetres.
    var myLat: Double?
    var myLng: Double?

    var people: [WatchPerson] = []

    var hasSearch: Bool { slug != nil }
}

struct WatchPerson: Codable, Equatable, Identifiable {
    var id: UUID
    var name: String
    var colorHex: String
    var isMe: Bool
    var lat: Double?
    var lng: Double?
    var lastSeenAt: Date
}

/// What the watch can ask the phone to do. Both map onto the same
/// functions the phone's own chips call, so there's one code path.
enum WatchCommand: String, Codable {
    case toggleRecording
    case toggleSharing
}

enum WatchMessage {
    static let commandKey = "command"
    static let snapshotKey = "snapshot"
}

/// Great-circle helpers.
///
/// CoreLocation's `distance(from:)` would do the first one, but keeping the
/// maths here lets this file stay Foundation-only and compile into both
/// targets untouched.
enum Geo {
    private static let earthRadiusMetres = 6_371_000.0

    static func distanceMetres(fromLat: Double, fromLng: Double,
                               toLat: Double, toLng: Double) -> Double {
        let p1 = fromLat * .pi / 180
        let p2 = toLat * .pi / 180
        let dPhi = (toLat - fromLat) * .pi / 180
        let dLambda = (toLng - fromLng) * .pi / 180
        let a = sin(dPhi / 2) * sin(dPhi / 2)
            + cos(p1) * cos(p2) * sin(dLambda / 2) * sin(dLambda / 2)
        return 2 * earthRadiusMetres * atan2(sqrt(a), sqrt(1 - a))
    }

    /// Initial bearing in degrees clockwise from true north.
    static func bearingDegrees(fromLat: Double, fromLng: Double,
                               toLat: Double, toLng: Double) -> Double {
        let p1 = fromLat * .pi / 180
        let p2 = toLat * .pi / 180
        let dLambda = (toLng - fromLng) * .pi / 180
        let y = sin(dLambda) * cos(p2)
        let x = cos(p1) * sin(p2) - sin(p1) * cos(p2) * cos(dLambda)
        let degrees = atan2(y, x) * 180 / .pi
        return (degrees + 360).truncatingRemainder(dividingBy: 360)
    }

    /// Eight-point compass label. The watch shows this rather than a
    /// rotating arrow: an arrow would have to point relative to where the
    /// wearer is facing, and heading needs location permission on the
    /// watch itself, which this design avoids.
    static func compassPoint(_ degrees: Double) -> String {
        let points = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let index = Int((degrees / 45).rounded()) % points.count
        return points[index]
    }

    static func formatDistance(_ metres: Double) -> String {
        metres < 1000
            ? "\(Int(metres.rounded())) m"
            : String(format: "%.1f km", metres / 1000)
    }
}
