# Store Listing Prep

This document collects the copy, metadata, and release-signing steps needed to publish
DejaPoo to the Google Play Store (and, once buildable on macOS, the Apple App Store). It
is the reference for `dp-bjs.6` (Phase 6: release builds, signing docs, store listing prep).

## App identity

- **App name:** DejaPoo
- **Package / Application ID (Android):** `com.dejapoo.dejapoo`
- **Bundle ID (iOS, planned):** `com.dejapoo.dejapoo`
- **Category:** Health & Fitness (Medical subcategory)
- **Content rating:** Everyone

## Short description (80 characters max)

```
Track bowel movements with the Bristol Stool Chart. Private, local-first.
```

(75 characters)

## Full description

```
DejaPoo is a private, local-first bowel movement tracker built around the
Bristol Stool Chart.

Log entries in seconds with the quick-log shortcut, or capture full detail —
Bristol type, time, notes, and more — with the detailed entry form. Review
trends over time with built-in reports and charts, and set daily reminders so
nothing gets missed.

Your data stays on your device. DejaPoo does not run any analytics, does not
talk to third-party servers, and shows no ads. If you want a backup or want to
sync across your own devices, you can optionally turn on Google Drive sync —
your data is written only to a hidden, app-specific folder in your own Drive
(appDataFolder) that only you can access; DejaPoo's developer cannot see it.

You can also import historical data from a spreadsheet (CSV/XLSX) and export
your full history at any time in the same formats.

Features:
- Quick-log popup for fast entries
- Detailed entry form (Bristol type, time, notes)
- Reports and charts to spot trends
- CSV/XLSX import and export
- Daily reminders
- Optional, user-controlled Google Drive sync (appDataFolder only)
- No analytics, no tracking, no ads, no third-party servers
```

## Privacy policy text

```
DejaPoo stores your health data (bowel movement records) locally on your
device. If you choose to enable Google Drive sync, your data is written to a
hidden, app-specific folder in your own Google Drive account (the
"appDataFolder", which is not visible in your regular Drive file list and is
accessible only to you and this app). No data is ever sent to any
third-party server, and DejaPoo's developer has no access to your Drive data.

DejaPoo does not use analytics or tracking of any kind, and displays no
advertisements.

You can export all of your data (CSV/XLSX) at any time from within the app,
and you can delete your data — locally and from your Drive appDataFolder —
at any time from the app's settings.
```

## Play Store Data Safety form

| Question | Answer |
|---|---|
| Does your app collect or share any of the required user data types? | Yes |
| Data type collected | Health info (bowel movement records: Bristol type, timestamps, notes) |
| Where is data stored? | On device; optionally in the user's own Google Drive (appDataFolder), under the user's control |
| Is data shared with third parties? | No |
| Is data collection optional? | Sync is optional and user-initiated; local logging is required for the app to function |
| Data encrypted in transit? | Yes — HTTPS to Google Drive APIs when sync is enabled |
| Can users request data deletion? | Yes — in-app deletion of local data and, when synced, the Drive appDataFolder contents |
| Does the app contain ads? | No |
| Does the app use analytics/tracking SDKs? | No |

## Screenshot checklist (manual capture required)

The following screenshots must be captured manually (device/emulator or Chrome) before
submission — none of this is automatable from this environment:

- [ ] Home screen with entries
- [ ] Quick-log popup
- [ ] Entry detail form
- [ ] Reports / charts screen
- [ ] Settings / sync status screen

## Android release signing

### 1. Generate a release keystore (one-time, outside the repo)

```bash
keytool -genkeypair -v -storetype PKCS12 \
  -keystore dejapoo-release.keystore \
  -alias dejapoo \
  -keyalg RSA -keysize 2048 -validity 10000
```

Store the resulting `.keystore`/`.jks` file **outside the repository** (e.g. a password
manager or a secure local folder). It must never be committed — `android/.gitignore`
already excludes `key.properties`, `*.jks`, and `*.keystore`.

### 2. Create `android/key.properties`

```properties
storePassword=<your store password>
keyPassword=<your key password>
keyAlias=dejapoo
storeFile=/absolute/path/to/dejapoo-release.keystore
```

This file is gitignored and never checked in. `android/app/build.gradle.kts` reads it at
build time: if `key.properties` exists, release builds are signed with the real keystore;
if it does not exist (e.g. CI, or a fresh checkout without the secret), release builds
fall back to debug signing so `flutter build apk --release` / `flutter build appbundle
--release` still succeed for local verification.

### 3. Register the release SHA-1 with Google OAuth

After creating the keystore, its SHA-1 fingerprint must be added as a new Android OAuth
client ID in Google Cloud Console, or Google Sign-In (and Drive sync) will silently fail
on release builds. See the "Release builds" note in `designs/GOOGLE_OAUTH_SETUP.md` for
the exact `keytool -list` command and where to register it.

### 4. Build

```powershell
flutter build appbundle --release   # for Play Store upload
flutter build apk --release         # for sideloading / manual testing
```

## iOS (documentation only — see deviation log in DESIGN.md)

iOS release artifacts cannot be produced on this Windows development machine (no Xcode /
macOS toolchain). The following is documented so a macOS session can complete signing and
submission without re-deriving context:

- **Bundle ID:** `com.dejapoo.dejapoo` (set in `ios/Runner.xcodeproj/project.pbxproj`)
- **App icon / launch screen:** configured via `flutter_launcher_icons` /
  `flutter_native_splash` assets already present in the repo (see `pubspec.yaml`); running
  `dart run flutter_launcher_icons` and `dart run flutter_native_splash:create` on macOS
  regenerates the iOS asset catalogs if the source images change.
- **OAuth client:** create an iOS OAuth client ID in Google Cloud Console using the Bundle
  ID above, download `GoogleService-Info.plist`, and wire up the reversed client ID URL
  scheme in `ios/Runner/Info.plist` — full steps in `designs/GOOGLE_OAUTH_SETUP.md` §6.
- **Signing:** requires an active Apple Developer Program membership, a distribution
  certificate, and a provisioning profile configured in Xcode's Signing & Capabilities pane
  for the `Runner` target.
- **Build checklist (on macOS):**
  1. `flutter pub get`
  2. `flutter build ios --release`
  3. Open `ios/Runner.xcworkspace` in Xcode, select a distribution signing team/profile
  4. Archive (Product > Archive) and upload via Xcode Organizer or `xcrun altool`
- **Tracking issue:** dp-y82 (iOS release artifact — see `designs/DESIGN.md` deviation log,
  2026-07-18 entry).
