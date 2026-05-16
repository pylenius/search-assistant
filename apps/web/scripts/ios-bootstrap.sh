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

# Location strings + background mode.
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

# SceneDelegate.swift — handles the scene lifecycle and forwards Universal Links
# + URL opens to Capacitor's ApplicationDelegateProxy so JS gets the events.
cat > "$SCENE_DELEGATE" <<'SWIFT_EOF'
import UIKit
import Capacitor

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        window.rootViewController = storyboard.instantiateInitialViewController()
        self.window = window
        window.makeKeyAndVisible()

        // Forward any Universal Link that launched the app to Capacitor.
        if let userActivity = connectionOptions.userActivities.first {
            _ = ApplicationDelegateProxy.shared.application(
                UIApplication.shared,
                continue: userActivity,
                restorationHandler: { _ in }
            )
        }
    }

    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        _ = ApplicationDelegateProxy.shared.application(
            UIApplication.shared,
            continue: userActivity,
            restorationHandler: { _ in }
        )
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        for urlContext in URLContexts {
            _ = ApplicationDelegateProxy.shared.application(
                UIApplication.shared,
                open: urlContext.url,
                options: [:]
            )
        }
    }
}
SWIFT_EOF

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
