// Custom CAPBridgeViewController that explicitly registers Capacitor plugins
// via the documented `capacitorDidLoad()` override.
//
// Background: Capacitor 6+ removed automatic plugin registration on iOS for
// SPM-installed packages. capacitor.config.json's `packageClassList` calls
// NSClassFromString(...) which returns nil because the @objc plugin classes
// live in dependent SPM static libraries that the linker dead-strips when
// nothing in the main app module references them. The result is every JS
// call returning UNIMPLEMENTED and listeners (appUrlOpen, etc.) never firing.
//
// Direct `registerPluginInstance` calls force the symbols to be retained
// at link time AND register the plugin with the bridge at runtime.

import UIKit
import Capacitor
// SPM target names (not the library product names)
import AppPlugin
import GeolocationPlugin

@objc(MyViewController)
public class MyViewController: CAPBridgeViewController {

    public override func capacitorDidLoad() {
        guard let bridge = bridge else {
            NSLog("[MyViewController] capacitorDidLoad: bridge is nil")
            return
        }
        bridge.registerPluginInstance(AppPlugin())
        bridge.registerPluginInstance(GeolocationPlugin())
        bridge.registerPluginInstance(BackgroundLocationPlugin())
        NSLog("[MyViewController] registered plugins: App, Geolocation, BackgroundLocation")
    }
}
