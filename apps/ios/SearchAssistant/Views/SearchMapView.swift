import SwiftUI
import MapKit

/// SwiftUI wrapper around MKMapView. Owns initial framing only; live state
/// (positions, areas, paths) is fed in via parameters and diffed onto the
/// underlying map view in `updateUIView`. When `drawing` is true a single
/// finger tap appends a point to the draft polyline; the host view owns
/// the `draftPoints` array.
struct SearchMapView: UIViewRepresentable {
    var center: CLLocationCoordinate2D
    var zoom: Int
    var positions: [UUID: PositionUpdateDto]
    var participants: [UUID: ParticipantDto]
    var areas: [UUID: AreaDto]
    var paths: [UUID: PathDto]
    var drawing: Bool = false
    var draftPoints: [CLLocationCoordinate2D] = []
    var onTapWhileDrawing: ((CLLocationCoordinate2D) -> Void)? = nil
    var basemap: Basemap = .apple

    /// How long without an update before a marker fades.
    static let staleAfter: TimeInterval = 5 * 60

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.pointOfInterestFilter = .excludingAll
        map.showsCompass = true
        map.showsScale = false
        map.isRotateEnabled = true
        map.isPitchEnabled = false
        map.register(MKAnnotationView.self,
                     forAnnotationViewWithReuseIdentifier: Coordinator.participantReuseID)
        map.setRegion(Self.region(center: center, zoom: zoom), animated: false)

        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:)))
        tap.delegate = context.coordinator
        tap.cancelsTouchesInView = false
        map.addGestureRecognizer(tap)
        context.coordinator.tapRecognizer = tap
        context.coordinator.tapRecognizer?.isEnabled = drawing

        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        context.coordinator.onTapWhileDrawing = onTapWhileDrawing
        context.coordinator.tapRecognizer?.isEnabled = drawing
        applyBasemap(map: map)
        recenterIfNeeded(map: map, coord: context.coordinator)
        diffParticipantAnnotations(map: map)
        diffAreas(map: map)
        diffPaths(map: map)
        diffDraft(map: map)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    // MARK: - Basemap

    /// Adds or removes the OSM tile overlay to match the `basemap` prop.
    ///
    /// Level and index both matter, and both were got wrong once:
    ///
    /// - The tiles must be at `.aboveLabels`. `canReplaceMapContent` only
    ///   suppresses Apple's basemap *underneath* the overlay, so tiles at
    ///   `.aboveRoads` come out with Apple's street labels still painted
    ///   on top of OSM's own — every name drawn twice.
    /// - Everything else must therefore be at `.aboveLabels` too (see
    ///   `Self.shapeLevel`), because a whole level renders above a whole
    ///   level: shapes left at the `addOverlay(_:)` default of
    ///   `.aboveRoads` disappear entirely under the tiles.
    ///
    /// Index 0 is what keeps the tiles under the shapes within that
    /// shared level — MapKit draws in insertion order, and the `diff*`
    /// methods always append after this has run.
    private func applyBasemap(map: MKMapView) {
        let existing = map.overlays.compactMap { $0 as? MKTileOverlay }
        switch basemap {
        case .apple:
            if !existing.isEmpty { map.removeOverlays(existing) }
        case .osm:
            if existing.isEmpty {
                map.insertOverlay(OSMTileOverlay(), at: 0, level: Self.shapeLevel)
            }
        }
    }

    /// The one level every overlay lives in. Areas, paths and the draft
    /// line sit here so they stay above the OSM tiles; on Apple's basemap
    /// it also means they draw over street labels rather than under them,
    /// which is what you want from a search area anyway.
    private static let shapeLevel: MKOverlayLevel = .aboveLabels

    // MARK: - Recenter

    /// Snap to the desired center only when the *prop* changes — never on
    /// random update ticks (positions, areas) where we'd otherwise yank the
    /// user back from wherever they panned to. Tracked via the Coordinator
    /// so it survives across SwiftUI re-renders.
    private func recenterIfNeeded(map: MKMapView, coord: Coordinator) {
        let last = coord.lastAppliedCenter
        if let last,
           abs(last.latitude - center.latitude) < 0.000001,
           abs(last.longitude - center.longitude) < 0.000001 {
            return
        }
        coord.lastAppliedCenter = center
        map.setRegion(Self.region(center: center, zoom: zoom), animated: last != nil)
    }

    // MARK: - Participant annotations

    private func diffParticipantAnnotations(map: MKMapView) {
        let now = Date()
        let existing: [UUID: ParticipantAnnotation] = Dictionary(
            uniqueKeysWithValues: map.annotations
                .compactMap { $0 as? ParticipantAnnotation }
                .map { ($0.participantId, $0) }
        )
        var desiredIds: Set<UUID> = []

        for (pid, pos) in positions {
            desiredIds.insert(pid)
            let color = UIColor(hex: participants[pid]?.color ?? "#888888")
            let stale = now.timeIntervalSince(pos.recordedAt) > Self.staleAfter
            let coord = CLLocationCoordinate2D(latitude: pos.lat, longitude: pos.lng)

            if let ann = existing[pid] {
                if ann.coordinate.latitude != coord.latitude
                    || ann.coordinate.longitude != coord.longitude {
                    ann.coordinate = coord
                }
                if ann.color != color || ann.isStale != stale {
                    ann.color = color
                    ann.isStale = stale
                    if let view = map.view(for: ann) {
                        view.image = MarkerImage.circle(color: color, stale: stale)
                    }
                }
            } else {
                let ann = ParticipantAnnotation(participantId: pid,
                                                coordinate: coord,
                                                color: color,
                                                isStale: stale)
                map.addAnnotation(ann)
            }
        }

        let toRemove = existing.filter { !desiredIds.contains($0.key) }.map { $0.value }
        if !toRemove.isEmpty { map.removeAnnotations(toRemove) }
    }

    // MARK: - Areas

    private func diffAreas(map: MKMapView) {
        let existing: [UUID: AreaPolygon] = Dictionary(
            uniqueKeysWithValues: map.overlays
                .compactMap { $0 as? AreaPolygon }
                .map { ($0.areaId, $0) }
        )
        var desiredIds: Set<UUID> = []

        for (aid, area) in areas {
            desiredIds.insert(aid)
            let color = UIColor(hex: area.color ?? participants[area.createdByParticipantId]?.color ?? "#888888")
            let newHash = OverlayShapes.ringHash(area.geometry.coordinates.first ?? [])

            if let prev = existing[aid] {
                if prev.geometryHash == newHash && prev.color == color {
                    continue
                }
                map.removeOverlay(prev)
            }
            map.addOverlay(OverlayShapes.areaPolygon(from: area, color: color),
                           level: Self.shapeLevel)
        }

        let toRemove = existing.filter { !desiredIds.contains($0.key) }.map { $0.value }
        if !toRemove.isEmpty { map.removeOverlays(toRemove) }
    }

    // MARK: - Paths

    private func diffPaths(map: MKMapView) {
        let existing: [UUID: PathPolyline] = Dictionary(
            uniqueKeysWithValues: map.overlays
                .compactMap { $0 as? PathPolyline }
                .map { ($0.pathId, $0) }
        )
        var desiredIds: Set<UUID> = []

        for (pid, path) in paths {
            desiredIds.insert(pid)
            let color = UIColor(hex: participants[path.participantId]?.color ?? "#888888")
            let newFp = OverlayShapes.pointsFingerprint(path.geometry.coordinates,
                                                       finalized: path.endedAt != nil)

            if let prev = existing[pid] {
                if prev.fingerprint == newFp && prev.color == color {
                    continue
                }
                map.removeOverlay(prev)
            }
            map.addOverlay(OverlayShapes.pathPolyline(from: path, color: color),
                           level: Self.shapeLevel)
        }

        let toRemove = existing.filter { !desiredIds.contains($0.key) }.map { $0.value }
        if !toRemove.isEmpty { map.removeOverlays(toRemove) }
    }

    // MARK: - Draft polyline (in-progress drawing)

    private func diffDraft(map: MKMapView) {
        let existing = map.overlays.compactMap { $0 as? DraftPolyline }
        if !existing.isEmpty { map.removeOverlays(existing) }

        guard drawing && draftPoints.count >= 2 else { return }
        // Close the loop visually as soon as we have ≥3 points.
        var coords = draftPoints
        if coords.count >= 3, let first = coords.first {
            coords.append(first)
        }
        let line = DraftPolyline(coordinates: &coords, count: coords.count)
        map.addOverlay(line, level: Self.shapeLevel)
    }

    // MARK: - Region helper

    private static func region(center: CLLocationCoordinate2D, zoom: Int) -> MKCoordinateRegion {
        let span = 360.0 / pow(2.0, Double(max(0, zoom)))
        return MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span))
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
        static let participantReuseID = "participant"

        weak var tapRecognizer: UITapGestureRecognizer?
        var onTapWhileDrawing: ((CLLocationCoordinate2D) -> Void)?
        /// Last `center` we actually applied to the map. Used by
        /// recenterIfNeeded to detect explicit prop changes and ignore
        /// incidental updateUIView calls.
        var lastAppliedCenter: CLLocationCoordinate2D?

        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard recognizer.state == .ended,
                  let map = recognizer.view as? MKMapView else { return }
            let point = recognizer.location(in: map)
            let coord = map.convert(point, toCoordinateFrom: map)
            onTapWhileDrawing?(coord)
        }

        // Let MKMapView keep its own pan/pinch gestures alongside our tap.
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            true
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: any MKAnnotation) -> MKAnnotationView? {
            guard let p = annotation as? ParticipantAnnotation else { return nil }
            let view = mapView.dequeueReusableAnnotationView(
                withIdentifier: Self.participantReuseID,
                for: annotation)
            view.image = MarkerImage.circle(color: p.color, stale: p.isStale)
            view.canShowCallout = false
            view.centerOffset = .zero
            return view
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: any MKOverlay) -> MKOverlayRenderer {
            if let tiles = overlay as? MKTileOverlay {
                return MKTileOverlayRenderer(tileOverlay: tiles)
            }
            if let area = overlay as? AreaPolygon {
                let r = MKPolygonRenderer(polygon: area)
                r.fillColor = area.color.withAlphaComponent(0.18)
                r.strokeColor = area.color
                r.lineWidth = 2
                return r
            }
            if let path = overlay as? PathPolyline {
                let r = MKPolylineRenderer(polyline: path)
                r.strokeColor = path.color
                r.lineWidth = 3
                r.lineCap = .round
                r.lineJoin = .round
                if !path.finalized {
                    r.lineDashPattern = [6, 4]
                }
                return r
            }
            if let draft = overlay as? DraftPolyline {
                let r = MKPolylineRenderer(polyline: draft)
                r.strokeColor = UIColor.systemOrange
                r.lineWidth = 3
                r.lineDashPattern = [4, 4]
                return r
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}
