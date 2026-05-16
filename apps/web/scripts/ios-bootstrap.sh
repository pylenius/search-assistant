#!/usr/bin/env bash
# Bootstraps the Capacitor iOS project from scratch. Safe to run anytime, including
# after `rm -rf ios/` — the iOS folder is treated as a build artifact and is NOT
# checked in. Every customization (Info.plist, plugins, entitlements, scene
# lifecycle, signing team) must live here so the project is fully reproducible.
#
# Usage:
#   cd apps/web
#   ./scripts/ios-bootstrap.sh
set -euo pipefail

WEB_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$WEB_DIR"

PLIST="ios/App/App/Info.plist"
ENT="ios/App/App/App.entitlements"
SCENE_DELEGATE="ios/App/App/SceneDelegate.swift"
PBXPROJ="ios/App/App.xcodeproj/project.pbxproj"
CAP_CFG_JSON="ios/App/App/capacitor.config.json"
SPM_SRC_DIR="ios/App/CapApp-SPM/Sources/CapApp-SPM"
BG_LOCATION_SRC="native/ios/BackgroundLocationPlugin.swift"
BG_LOCATION_DST="$SPM_SRC_DIR/BackgroundLocationPlugin.swift"

TEAM_ID="HEJK7U967E"
ASSOCIATED_DOMAIN="applinks:searchassistant.eport.fi"
WHEN_IN_USE_DESC="Search Assistant uses your location to share it with your search group."
ALWAYS_DESC="Search Assistant keeps recording your path even when the screen is off, so the group can see where you have been."

echo "==> 1/6 Installing web dependencies"
npm install --silent

echo "==> 2/6 Building web app (writes to dist/)"
npm run build

echo "==> 3/6 Capacitor: ensure iOS platform"
if [ ! -d ios ]; then
  echo "    ios/ missing — running 'cap add ios'"
  npx cap add ios
else
  echo "    ios/ exists — running 'cap sync ios'"
  npx cap sync ios
fi

echo "==> 4/6 Info.plist permissions + scene manifest"

# Location strings + background mode. The custom BackgroundLocationPlugin
# (installed below into CapApp-SPM) needs both descriptions and the
# 'location' background mode to keep CLLocationManager running with screen off.
plutil -replace NSLocationWhenInUseUsageDescription -string "$WHEN_IN_USE_DESC" "$PLIST"
plutil -replace NSLocationAlwaysAndWhenInUseUsageDescription -string "$ALWAYS_DESC" "$PLIST"
plutil -replace UIBackgroundModes -json '["location"]' "$PLIST"

# UIApplicationSceneManifest is required for iOS 26+ — Capacitor's default
# AppDelegate-only lifecycle no longer launches on iOS 26+. See:
# https://github.com/ionic-team/capacitor/issues/7961
plutil -replace UIApplicationSceneManifest -json '{
  "UIApplicationSupportsMultipleScenes": false,
  "UISceneConfigurations": {
    "UIWindowSceneSessionRoleApplication": [{
      "UISceneConfigurationName": "Default Configuration",
      "UISceneDelegateClassName": "$(PRODUCT_MODULE_NAME).SceneDelegate",
      "UISceneStoryboardFile": "Main",
      "UILaunchStoryboardName": "LaunchScreen"
    }]
  }
}' "$PLIST"

echo "==> 5/6 Entitlements + SceneDelegate"

# Associated-domains entitlement. The key contains dots which plutil treats as
# nested, so we just write the file verbatim every run — fully idempotent.
cat > "$ENT" <<PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.associated-domains</key>
    <array>
        <string>${ASSOCIATED_DOMAIN}</string>
    </array>
</dict>
</plist>
PLIST_EOF
plutil -lint "$ENT" >/dev/null

# SceneDelegate.swift — scene lifecycle + Universal Link / URL forwarding.
# Under iOS 13+ scene lifecycle, Capacitor's swizzling on AppDelegate's
# application(_:continue:) doesn't fire, so the SceneDelegate has to post
# the NotificationCenter events AppPlugin listens to (capacitorOpenURL /
# capacitorOpenUniversalLink) itself for the JS-side appUrlOpen event to fire.
cat > "$SCENE_DELEGATE" <<'SWIFT_EOF'
import UIKit
import Capacitor

// Use Capacitor's own typed Notification.Name extension. The rawValue
// strings are "CapacitorOpenURLNotification" / "CapacitorOpenUniversalLinkNotification"
// — easy to get wrong if hand-written, so always go through the extension.

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        NSLog("[SceneDelegate] willConnectTo userActivities=%d urlContexts=%d",
              connectionOptions.userActivities.count,
              connectionOptions.urlContexts.count)

        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        window.rootViewController = storyboard.instantiateInitialViewController()
        self.window = window
        window.makeKeyAndVisible()

        for activity in connectionOptions.userActivities {
            handleUserActivity(activity, source: "launch")
        }
        for ctx in connectionOptions.urlContexts {
            handleOpenURL(ctx.url, source: "launch")
        }
    }

    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        handleUserActivity(userActivity, source: "continue")
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        NSLog("[SceneDelegate] openURLContexts count=%d", URLContexts.count)
        for ctx in URLContexts {
            handleOpenURL(ctx.url, source: "openURLContexts")
        }
    }

    private func handleUserActivity(_ activity: NSUserActivity, source: String) {
        NSLog("[SceneDelegate] %@ activity type=%@ webpageURL=%@",
              source, activity.activityType, activity.webpageURL?.absoluteString ?? "nil")

        _ = ApplicationDelegateProxy.shared.application(
            UIApplication.shared,
            continue: activity,
            restorationHandler: { _ in }
        )

        if activity.activityType == NSUserActivityTypeBrowsingWeb,
           let url = activity.webpageURL {
            NSLog("[SceneDelegate] posting capacitorOpenUniversalLink %@", url.absoluteString)
            // AppPlugin casts the object as [String: Any?] — must match exactly
            // or the cast fails silently. Pass NSURL (bridged) to satisfy its
            // `object["url"] as? NSURL` check inside makeUrlOpenObject.
            let payload: [String: Any?] = ["url": url as NSURL]
            NotificationCenter.default.post(
                name: Notification.Name.capacitorOpenUniversalLink,
                object: payload
            )
        }
    }

    private func handleOpenURL(_ url: URL, source: String) {
        NSLog("[SceneDelegate] %@ URL %@", source, url.absoluteString)

        _ = ApplicationDelegateProxy.shared.application(
            UIApplication.shared,
            open: url,
            options: [:]
        )

        NSLog("[SceneDelegate] posting capacitorOpenURL %@", url.absoluteString)
        let payload: [String: Any?] = ["url": url as NSURL, "options": [String: Any?]()]
        NotificationCenter.default.post(
            name: Notification.Name.capacitorOpenURL,
            object: payload
        )
    }
}
SWIFT_EOF

echo "==> 5b/6 Installing BackgroundLocationPlugin into CapApp-SPM"
mkdir -p "$SPM_SRC_DIR"
cp "$BG_LOCATION_SRC" "$BG_LOCATION_DST"

# Register the plugin so Capacitor instantiates it on startup. Stored in
# capacitor.config.json (runtime) — Capacitor reads packageClassList here.
python3 - <<PYEOF
import json
from pathlib import Path

cfg_path = Path("$CAP_CFG_JSON")
cfg = json.loads(cfg_path.read_text())
pkgs = cfg.setdefault("packageClassList", [])
if "BackgroundLocationPlugin" not in pkgs:
    pkgs.append("BackgroundLocationPlugin")
    cfg_path.write_text(json.dumps(cfg, indent=2))
    print("    registered BackgroundLocationPlugin in capacitor.config.json")
else:
    print("    BackgroundLocationPlugin already registered")
PYEOF

echo "==> 6/6 pbxproj: team, entitlements, SceneDelegate (Python)"

# All pbxproj edits in one Python pass. We use str.replace() instead of sed
# because pbxproj is an OpenStep plist and sed mangles it for non-trivial edits.
# Each edit guards itself so the script is idempotent.
python3 <<PYEOF
import sys
from pathlib import Path

pbx = Path("$PBXPROJ")
c = pbx.read_text()

# 1) DEVELOPMENT_TEAM next to CODE_SIGN_STYLE.
if "DEVELOPMENT_TEAM = $TEAM_ID" not in c:
    c = c.replace(
        "CODE_SIGN_STYLE = Automatic;",
        "CODE_SIGN_STYLE = Automatic;\n\t\t\t\tDEVELOPMENT_TEAM = $TEAM_ID;"
    )

# 2) CODE_SIGN_ENTITLEMENTS next to CODE_SIGN_IDENTITY (both build configs).
if "CODE_SIGN_ENTITLEMENTS = App/App.entitlements;" not in c:
    c = c.replace(
        "CODE_SIGN_IDENTITY",
        "CODE_SIGN_ENTITLEMENTS = App/App.entitlements;\n\t\t\t\tCODE_SIGN_IDENTITY"
    )

# 3) Add SceneDelegate.swift as a Swift source. Capacitor's default project
#    has AppDelegate.swift in the same group / Sources phase; we mirror that.
SCENE_FILE_REF = "5C3E0E0A2A0B0001000A0001"
SCENE_BUILD_FILE = "5C3E0E0A2A0B0001000A0002"

if "SceneDelegate.swift" not in c:
    # PBXBuildFile entry
    c = c.replace(
        "/* End PBXBuildFile section */",
        f"\t\t{SCENE_BUILD_FILE} /* SceneDelegate.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {SCENE_FILE_REF} /* SceneDelegate.swift */; }};\n/* End PBXBuildFile section */"
    )
    # PBXFileReference entry
    c = c.replace(
        "/* End PBXFileReference section */",
        f"\t\t{SCENE_FILE_REF} /* SceneDelegate.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = SceneDelegate.swift; sourceTree = \"<group>\"; }};\n/* End PBXFileReference section */"
    )
    # Add to the App group's children (alongside AppDelegate.swift)
    c = c.replace(
        "504EC3071FED79650016851F /* AppDelegate.swift */,\n",
        f"504EC3071FED79650016851F /* AppDelegate.swift */,\n\t\t\t\t{SCENE_FILE_REF} /* SceneDelegate.swift */,\n"
    )
    # Add to Sources build phase
    c = c.replace(
        "504EC3081FED79650016851F /* AppDelegate.swift in Sources */,\n",
        f"504EC3081FED79650016851F /* AppDelegate.swift in Sources */,\n\t\t\t\t{SCENE_BUILD_FILE} /* SceneDelegate.swift in Sources */,\n"
    )

pbx.write_text(c)
print(f"  team set: DEVELOPMENT_TEAM = $TEAM_ID")
print(f"  entitlements: CODE_SIGN_ENTITLEMENTS = App/App.entitlements")
print(f"  SceneDelegate.swift: added (id {SCENE_FILE_REF})")
PYEOF

echo ""
echo "==> Verification"
plutil -extract NSLocationWhenInUseUsageDescription raw -o - "$PLIST"
plutil -extract NSLocationAlwaysAndWhenInUseUsageDescription raw -o - "$PLIST"
echo "  UIBackgroundModes: $(plutil -extract UIBackgroundModes json -o - "$PLIST")"
echo "  Scene manifest: $(plutil -extract UIApplicationSceneManifest.UISceneConfigurations.UIWindowSceneSessionRoleApplication.0.UISceneDelegateClassName raw -o - "$PLIST")"
echo "  BackgroundLocationPlugin.swift: $(test -f "$BG_LOCATION_DST" && echo "present" || echo "MISSING")"
echo "  Entitlements:"
plutil -p "$ENT" | sed 's/^/    /'
echo "  DEVELOPMENT_TEAM lines in pbxproj: $(grep -c "DEVELOPMENT_TEAM = $TEAM_ID" "$PBXPROJ")"
echo "  CODE_SIGN_ENTITLEMENTS lines in pbxproj: $(grep -c "CODE_SIGN_ENTITLEMENTS = App/App.entitlements;" "$PBXPROJ")"
echo "  SceneDelegate referenced: $(grep -c "SceneDelegate.swift" "$PBXPROJ") line(s)"

cat <<EOF

iOS scaffold ready.
  Next: open ios/App/App.xcworkspace in Xcode, set signing team if prompted,
        then Product → Archive → upload to TestFlight.
  Re-run this script anytime — it's idempotent.
EOF
