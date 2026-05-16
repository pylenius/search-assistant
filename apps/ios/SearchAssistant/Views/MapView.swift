import SwiftUI
import MapKit

/// Lightweight MKMapView wrapper. Later steps will pass in arrays of
/// participants / areas / paths and diff overlays in `updateUIView`.
struct MapView: UIViewRepresentable {
    var center: CLLocationCoordinate2D
    var zoom: Int

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.pointOfInterestFilter = .excludingAll
        map.showsCompass = true
        map.showsScale = false
        map.isRotateEnabled = true
        map.isPitchEnabled = false
        map.setRegion(Self.region(center: center, zoom: zoom), animated: false)
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        // Only recenter if the SwiftUI-level center moved meaningfully — avoid
        // fighting the user's manual pans/zooms each render.
        let current = map.region.center
        if abs(current.latitude - center.latitude) > 0.01
           || abs(current.longitude - center.longitude) > 0.01 {
            map.setRegion(Self.region(center: center, zoom: zoom), animated: true)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, MKMapViewDelegate {
        // Overlays and annotations come in later steps.
    }

    /// Web-Mercator-ish zoom-to-region conversion. Good enough for our use:
    /// each integer step roughly halves the visible degree span.
    private static func region(center: CLLocationCoordinate2D, zoom: Int) -> MKCoordinateRegion {
        let span = 360.0 / pow(2.0, Double(max(0, zoom)))
        return MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span)
        )
    }
}
