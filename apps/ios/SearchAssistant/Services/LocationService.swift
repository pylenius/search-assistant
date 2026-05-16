import Foundation
import CoreLocation

struct GeoFix {
    let lng: Double
    let lat: Double
    let accuracyMeters: Double
    let headingDegrees: Double?
    let timestamp: Date
}

/// Native wrapper around CLLocationManager. Background updates are enabled
/// (matches the UIBackgroundModes=[location] Info.plist key written by
/// project.yml). Direct replacement for the BackgroundLocationPlugin we
/// shipped through Capacitor.
///
/// Use:
///   @StateObject var location = LocationService()
///   ...
///   location.start { fix in /* send to hub */ }
///   location.stop()
@MainActor
final class LocationService: NSObject, ObservableObject {
    @Published var authorizationStatus: CLAuthorizationStatus
    @Published var isWatching: Bool = false
    @Published var lastError: String?

    private let manager = CLLocationManager()
    private var onFix: ((GeoFix) -> Void)?

    override init() {
        self.authorizationStatus = .notDetermined
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 5                    // metres between fixes
        manager.activityType = .fitness
        manager.pausesLocationUpdatesAutomatically = false
        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = true
        authorizationStatus = manager.authorizationStatus
    }

    var isSupported: Bool { CLLocationManager.locationServicesEnabled() }

    /// Starts streaming fixes. iOS will prompt for permission if the user
    /// hasn't granted it yet; the first fix arrives once auth is granted.
    func start(onFix: @escaping (GeoFix) -> Void) {
        guard !isWatching else { return }
        self.onFix = onFix
        lastError = nil

        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestAlwaysAuthorization()
        case .denied, .restricted:
            lastError = "Location permission is off — enable it in Settings."
            return
        default: break
        }
        manager.startUpdatingLocation()
        isWatching = true
    }

    func stop() {
        guard isWatching else { return }
        manager.stopUpdatingLocation()
        isWatching = false
        onFix = nil
    }
}

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        let fix = GeoFix(
            lng: loc.coordinate.longitude,
            lat: loc.coordinate.latitude,
            accuracyMeters: loc.horizontalAccuracy,
            headingDegrees: loc.course >= 0 ? loc.course : nil,
            timestamp: loc.timestamp
        )
        Task { @MainActor in self.onFix?(fix) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didFailWithError error: Error) {
        let msg = error.localizedDescription
        Task { @MainActor in self.lastError = msg }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorizationStatus = status
            if (status == .authorizedAlways || status == .authorizedWhenInUse)
                && self.isWatching {
                // User granted permission while a start() was already in flight.
                manager.startUpdatingLocation()
            }
        }
    }
}
