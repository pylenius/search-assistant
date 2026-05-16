// Local Capacitor plugin (target: CapApp-SPM/Sources/CapApp-SPM/).
// Wraps CLLocationManager with background-location enabled so the search
// path keeps updating while the screen is off. Notifies the web layer
// via the "location" listener AND buffers in case JS is paused.
//
// JS access via:
//   import { registerPlugin } from '@capacitor/core'
//   const BackgroundLocation = registerPlugin<BackgroundLocation>('BackgroundLocation')

import Capacitor
import CoreLocation
import Foundation

@objc(BackgroundLocationPlugin)
public class BackgroundLocationPlugin: CAPPlugin, CAPBridgedPlugin, CLLocationManagerDelegate {
    public let identifier = "BackgroundLocationPlugin"
    public let jsName = "BackgroundLocation"
    // `requestPermissions` and `checkPermissions` are already registered by
    // CAPPlugin's base implementation — we only override them below.
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "start", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "stop", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "drainBuffer", returnType: CAPPluginReturnPromise),
    ]

    private let manager = CLLocationManager()
    private var buffer: [[String: Any]] = []
    private let bufferLock = NSLock()
    private let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    override public func load() {
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 10                          // meters between fixes
        manager.activityType = .fitness
        manager.pausesLocationUpdatesAutomatically = false
        manager.allowsBackgroundLocationUpdates = true       // requires UIBackgroundModes "location"
        manager.showsBackgroundLocationIndicator = true      // blue pill while in background
    }

    // Override CAPPlugin's standard requestPermissions so JS can call
    // BackgroundLocation.requestPermissions() and get a Promise<{status}>.
    @objc override public func requestPermissions(_ call: CAPPluginCall) {
        // Ask for "always" so background works. iOS first shows whenInUse,
        // then re-prompts for always after a few minutes of use.
        manager.requestAlwaysAuthorization()
        call.resolve(["status": authStatusString()])
    }

    @objc override public func checkPermissions(_ call: CAPPluginCall) {
        call.resolve(["status": authStatusString()])
    }

    @objc func start(_ call: CAPPluginCall) {
        if let filter = call.getDouble("distanceFilter") {
            manager.distanceFilter = filter
        }
        manager.startUpdatingLocation()
        call.resolve(["status": authStatusString()])
    }

    @objc func stop(_ call: CAPPluginCall) {
        manager.stopUpdatingLocation()
        call.resolve()
    }

    @objc func drainBuffer(_ call: CAPPluginCall) {
        bufferLock.lock()
        let drained = buffer
        buffer.removeAll()
        bufferLock.unlock()
        call.resolve(["locations": drained])
    }

    // MARK: - CLLocationManagerDelegate

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        var data: [String: Any] = [
            "lng": loc.coordinate.longitude,
            "lat": loc.coordinate.latitude,
            "accuracyMeters": loc.horizontalAccuracy,
            "recordedAt": isoFormatter.string(from: loc.timestamp),
        ]
        if loc.course >= 0 {
            data["headingDegrees"] = loc.course
        }
        bufferLock.lock()
        buffer.append(data)
        bufferLock.unlock()
        notifyListeners("location", data: data)
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        notifyListeners("error", data: ["message": error.localizedDescription])
    }

    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        notifyListeners("authorizationChanged", data: ["status": authStatusString()])
    }

    private func authStatusString() -> String {
        switch manager.authorizationStatus {
        case .notDetermined: return "notDetermined"
        case .restricted:    return "restricted"
        case .denied:        return "denied"
        case .authorizedWhenInUse: return "whenInUse"
        case .authorizedAlways:    return "always"
        @unknown default:    return "unknown"
        }
    }
}
