# App Store Connect submission — Search Assistant (iOS)

Copy-paste source for the App Store listing. Character limits are noted;
counts in parentheses are the current draft's length. Facts here are taken
from `apps/ios/project.yml`, `Info.plist` usage strings, and the live privacy
policy at <https://searchassistant.eport.fi/privacy>.

## App information

| Field | Value |
|---|---|
| Bundle ID | `fi.eport.searchassistant` |
| SKU | `searchassistant-ios` |
| Primary language | English (U.S.) |
| App name (≤30) | `Search Assistant` (16) |
| Subtitle (≤30) | `Shared map for group searches` (29) |
| Primary category | Navigation |
| Secondary category | Travel |
| Age rating | 4+ — no objectionable content; answer "None" to every questionnaire item |
| Copyright | `2026 ePort` |
| Content rights | Contains no third-party content (map tiles are Apple Maps via MapKit) |

## URLs

| Field | Value |
|---|---|
| Privacy Policy URL | `https://searchassistant.eport.fi/privacy` |
| Support URL | `https://searchassistant.eport.fi/` |
| Marketing URL | *(optional — leave blank or reuse the support URL)* |

## Promotional text (≤170, editable without a new build)

```
Share a link, and everyone sees the same search area, each other's live positions, and the ground already covered. No accounts, no signup, no app required for guests.
```
(165)

## Description (≤4000)

```
Search Assistant keeps a group together on one map.

Picking mushrooms, walking a forest line, hiking with friends, or looking for
something someone dropped — everyone taps the same link, picks a name, and
immediately sees the same picture: the area you agreed to cover, where each
person is right now, and which ground has already been walked.

NO ACCOUNTS
There is no signup, no email, and no password. Creating a search gives you a
link. Anyone you send it to can join in seconds — from this app, or straight
from a phone browser if they'd rather not install anything.

DRAW THE AREA
Sketch a polygon on the map and it appears for everyone in the search within
a second. Name it, colour it, remove it when the group moves on.

SEE EACH OTHER LIVE
Turn on location sharing and your position streams to the rest of the group,
and theirs to you. Tap someone in the list to centre the map on them.

RECORD WHAT YOU'VE COVERED
Start recording and your walked track is drawn on the shared map, so the
group can see which ground is done and which is not — the single most useful
thing when several people sweep the same forest. Tracks keep recording with
the screen off, and can be exported as GPX.

SHARE HOWEVER YOU LIKE
Send the link in any messaging app, or show the QR code for someone to scan.

SEARCHES DON'T LINGER
A search expires on its own — by default a week after it's created — and the
person who started it can rename it, clear the recorded tracks, or delete the
whole thing at any time. Deleting removes every position, path, and area in
it.

PRIVACY
No ads, no analytics SDKs, no trackers, and nothing sold or shared with
anyone. Your location goes to the people in your search and nowhere else, and
only while you have sharing or recording switched on. Full policy:
https://searchassistant.eport.fi/privacy
```

## Keywords (≤100 characters total, comma-separated, no spaces after commas)

```
mushroom,foraging,berry,hiking,group,gps,tracker,live location,map,trail,walk,friends,share
```
(91)

Deliberately **not** included: "search and rescue", "SAR", "emergency",
"safety". Those invite review scrutiny as a safety-critical app and imply a
reliability guarantee this app doesn't make.

## What's New in This Version (first release)

```
First release.
```

## App Review Information

- **Sign-in required:** No. Leave the demo-account fields empty.
- **Contact:** Pekka — techteam@ogoship.com

**Notes to reviewer:**

```
No account, login, or demo credentials are needed — the app is anonymous and
link-based.

To exercise every feature on a single device:
1. Launch the app and tap "Create new search".
2. Type a display name and join.
3. Tap "Draw area" and tap points on the map to sketch a polygon, then save
   it — it appears on the map and in the Areas list.
4. Tap "Share my location" to broadcast your position; your marker appears on
   the map and in the Participants list.
5. Tap "Record path" to record a walked track. Moving the device (or using
   the simulator's location simulation) draws the track on the map.
6. Tap "Share" for the join link and QR code; opening that link on a second
   device shows both participants on the same map in real time.

BACKGROUND LOCATION: the app requests "Always" only to keep recording a
walked path while the screen is off, which is the core feature — the group
needs to see which ground has been covered. Background collection happens
only while the user has explicitly started path recording, and stops when
they stop it. iOS shows the standard blue location indicator throughout.
Location is never collected for advertising, analytics, or profiling.

The backend is https://searchassistant.eport.fi (operated by us, in
Finland). The same service also serves the web version of this app.
```

## App Privacy (the nutrition label)

Answer **"Yes, we collect data from this app"**, then declare exactly these:

| Data type | Category | Purpose | Linked to identity? | Used for tracking? |
|---|---|---|---|---|
| Precise Location | Location | App Functionality | No | No |
| Name (self-chosen display name) | Contact Info | App Functionality | No | No |
| Other User Content (drawn areas, recorded paths) | User Content | App Functionality | No | No |
| User ID (per-search session token) | Identifiers | App Functionality | No | No |

Everything else — coarse location, email, phone, contacts, photos, health,
financial, browsing history, search history, diagnostics, crash data,
advertising data, usage data — is **not collected**.

"Not linked to identity" is accurate because there are no accounts: the
session token identifies a participant inside one search and is not tied to a
person, email, or device advertising identifier. Tracking is "No" across the
board, so **no App Tracking Transparency prompt is required**.

## Export compliance

`ITSAppUsesNonExemptEncryption` is already set to `false` in `Info.plist`, so
App Store Connect will not ask. This is correct: the app only uses HTTPS/TLS
provided by the OS.

## Before you upload

1. ~~Bump the version.~~ Done — `MARKETING_VERSION` is now `1.0.0`. Bump
   `CURRENT_PROJECT_VERSION` (currently `1`) on every subsequent upload and
   re-run `xcodegen`.
2. ~~Decide iPhone-only vs universal.~~ Done — `TARGETED_DEVICE_FAMILY` is
   now `"1"` (iPhone only), so **no iPad screenshots are required** and the
   app isn't reviewed on iPad. Adding iPad later is a normal update.
3. **Screenshots.** Required size is 6.9" iPhone, 1320 × 2868. Three are
   ready in `docs/app-store/ios-6.9/`, captured on an iPhone 17 Pro Max
   simulator against a local backend:
   - `1-landing.png` — landing screen with a recent search
   - `2-live-map.png` — the search area, three walked tracks, four participants
   - `3-participants.png` — the participants sheet
   Optional additions if you want five: the share sheet (QR code) and the
   active "Recording" state.
4. **Archive and upload:** Xcode → Product → Archive → Distribute App → App
   Store Connect, signing with team `HEJK7U967E`.
5. **Check the associated domain** still verifies so `/s/{slug}` links open
   the app: `curl https://searchassistant.eport.fi/.well-known/apple-app-site-association`
