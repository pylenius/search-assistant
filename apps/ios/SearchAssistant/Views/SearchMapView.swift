import SwiftUI
import MapKit

/// SwiftUI wrapper around MKMapView. Owns initial framing only; later state
/// (positions, areas, paths) is fed in via parameters and diffed onto the
/// underlying map view in `updateUIView`.
struct SearchMapView: UIViewRepresentable {
    var center: CLLocationCoordinate2D
    var zoom: Int
    var positions: [UUID: PositionUpdateDto]
    var participants: [UUID: ParticipantDto]

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
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        recenterIfNeeded(map: map)
        diffParticipantAnnotations(map: map)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    // MARK: - Diff helpers

    private func recenterIfNeeded(map: MKMapView) {
        let current = map.region.center
        if abs(current.latitude - center.latitude) > 0.01
           || abs(current.longitude - center.longitude) > 0.01 {
            map.setRegion(Self.region(center: center, zoom: zoom), animated: true)
        }
    }

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

    private static func region(center: CLLocationCoordinate2D, zoom: Int) -> MKCoordinateRegion {
        let span = 360.0 / pow(2.0, Double(max(0, zoom)))
        return MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span))
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, MKMapViewDelegate {
        static let participantReuseID = "participant"

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
    }
}
