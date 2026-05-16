# Search Assistant — Android

Native Android client. Parity target: the iOS app at `apps/ios/`.

## First-time setup

1. Open this folder in Android Studio (or use the Gradle wrapper from
   the command line — `./gradlew assembleDebug`).
2. Copy `local.properties.sample` → `local.properties` and fill in
   your Google Maps SDK for Android API key:
   ```
   MAPS_API_KEY=AIzaSy...
   ```
   Get one at <https://console.cloud.google.com/google/maps-apis>.
   The Maps API key is **required** for any debug build to render the
   map. The `secrets-gradle-plugin` injects it into the manifest's
   `com.google.android.geo.API_KEY` placeholder at build time.

3. Make sure an Android SDK + NDK is available. `ANDROID_HOME`
   resolves to it (already set if you have Android Studio installed).

## Common commands

```
./gradlew assembleDebug          # build a debug APK
./gradlew installDebug           # install on a connected device/emulator
./gradlew bundleRelease          # signed AAB for Play Console
./gradlew lint                   # static analysis
```

Outputs land in `app/build/outputs/apk/` and `app/build/outputs/bundle/`.

## Layout

Mirrors the iOS app's `Models / Services / Stores / Views` split with
Kotlin equivalents under `app/src/main/java/fi/eport/searchassistant/`:

```
data/api/        → ApiClient.swift counterpart
data/realtime/   → SignalRService.swift
data/session/    → SessionStore.swift
data/recents/    → RecentSearchesStore.swift
domain/          → SearchStore.swift  (as a HiltViewModel)
location/        → LocationService.swift  (as a foreground service)
ui/landing/      → LandingView.swift
ui/search/       → SearchView + SearchMapView + sheets
```
