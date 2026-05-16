import Foundation
import MapKit
import UIKit

/// MKPolygon subclass that remembers which `SearchArea` it represents and the
/// color it should render in. MapKit treats this as a normal MKPolygon for
/// hit-testing / addition, but the renderer pulls our metadata back out.
final class AreaPolygon: MKPolygon {
    var areaId: UUID!
    var color: UIColor = .gray
    /// Hash of the geometry coordinates — used by the diff to decide whether
    /// to replace the overlay when an Area's geometry changes.
    var geometryHash: Int = 0
}

/// Polyline subclass for one path; same pattern as AreaPolygon.
final class PathPolyline: MKPolyline {
    var pathId: UUID!
    var color: UIColor = .gray
    var finalized: Bool = false
    /// Hash of the points + finalized flag — diff trigger.
    var fingerprint: Int = 0
}

// MARK: - Builders

enum OverlayShapes {
    /// Build an AreaPolygon from an AreaDto. Uses the *outer* ring; holes
    /// could be added later via `interiorPolygons:` if we ever support them.
    static func areaPolygon(from area: AreaDto,
                            color: UIColor) -> AreaPolygon {
        // GeoJSON polygons store [lng, lat]; convert to CLLocationCoordinate2D.
        let outerRing = area.geometry.coordinates.first ?? []
        var coords = outerRing.map {
            CLLocationCoordinate2D(latitude: $0[1], longitude: $0[0])
        }
        let polygon = AreaPolygon(coordinates: &coords, count: coords.count)
        polygon.areaId = area.id
        polygon.color = color
        polygon.geometryHash = ringHash(outerRing)
        return polygon
    }

    /// Build a PathPolyline from a PathDto.
    static func pathPolyline(from path: PathDto,
                             color: UIColor) -> PathPolyline {
        let pts = path.geometry.coordinates
        var coords = pts.map {
            CLLocationCoordinate2D(latitude: $0[1], longitude: $0[0])
        }
        let polyline = PathPolyline(coordinates: &coords, count: coords.count)
        polyline.pathId = path.id
        polyline.color = color
        polyline.finalized = path.endedAt != nil
        polyline.fingerprint = pointsFingerprint(pts, finalized: polyline.finalized)
        return polyline
    }

    /// Cheap stable hash of a ring. We only care about whether the ring
    /// changed between updates; exact-vs-near doesn't need geographic awareness.
    static func ringHash(_ ring: [[Double]]) -> Int {
        var hasher = Hasher()
        hasher.combine(ring.count)
        for p in ring {
            for c in p { hasher.combine(c) }
        }
        return hasher.finalize()
    }

    static func pointsFingerprint(_ pts: [[Double]], finalized: Bool) -> Int {
        var hasher = Hasher()
        hasher.combine(finalized)
        hasher.combine(pts.count)
        // First/last points + count are enough to catch every realistic
        // change — paths grow at the end via PathUpdated, finalize sets
        // endedAt. We don't need to fingerprint every interior point.
        if let first = pts.first, first.count >= 2 {
            hasher.combine(first[0]); hasher.combine(first[1])
        }
        if let last = pts.last, last.count >= 2 {
            hasher.combine(last[0]); hasher.combine(last[1])
        }
        return hasher.finalize()
    }
}
