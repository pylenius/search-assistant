# Search Assistant — native iOS app

SwiftUI + MapKit. Replaces the Capacitor-wrapped Vue app at `apps/web/`
on iOS only. Backend (`apps/api`) and web app are unchanged.

## Generate the Xcode project

The `.xcodeproj` is **not checked in** — it's regenerated from `project.yml`
by [xcodegen](https://github.com/yonaskolb/XcodeGen). One-time install:

```sh
brew install xcodegen
```

Then any time `project.yml` changes (e.g. you add a file or a SwiftPM
dependency):

```sh
cd apps/ios
xcodegen
```

## Open and run

```sh
open SearchAssistant.xcodeproj
# In Xcode: pick an iOS Simulator, ⌘R
```

Headless build sanity check from CLI:

```sh
xcodebuild -project SearchAssistant.xcodeproj \
           -scheme SearchAssistant \
           -sdk iphonesimulator \
           -configuration Debug \
           CODE_SIGNING_ALLOWED=NO build
```

## Identifiers

- Team ID: `HEJK7U967E`
- Bundle ID: `fi.eport.searchassistant`
- Associated domain: `applinks:searchassistant.eport.fi`

Same as the Capacitor build — they can't be installed on the same
device simultaneously. Uninstall the Capacitor version before
installing this one.
