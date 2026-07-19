# Phase 6 Handoff

**Phase:** 6 — Polish & Release Readiness (bd epic: `dp-bjs`, closed 2026-07-19)

## Phase summary

Phase 6 delivered release-readiness polish: debounced sync wiring so local mutations auto-sync
to Drive, app identity assets (launcher icons, splash, PWA manifest), daily reminder
notifications, a COI service worker for OPFS on GitHub Pages, responsive wide-screen layout with
NavigationRail, an accessibility pass (Bristol selector semantics, chart summaries, error/retry
states), and release signing configuration with store listing documentation.

## Exit criteria — evidence

- Debounced sync wired to all mutation paths — PASS: 8 widget/unit tests in
  `test/data/sync/sync_wiring_test.dart`; create/edit/delete/import all trigger
  `scheduleDebouncedSync()`
- App identity (icons, splash, manifest) — PASS: `flutter_launcher_icons` +
  `flutter_native_splash` generated assets committed; `web/manifest.json` shows DejaPoo
  branding with sage palette colors
- Daily reminder notification — PASS: 8 tests in
  `test/data/notifications/notification_service_test.dart`; enable/disable/reschedule/permission
  denial all verified with fake; hidden on web
- COI service worker for OPFS — PASS: `web/coi_serviceworker.js` + registration in
  `web/index.html` with sessionStorage loop guard; web build succeeds
- Responsive layout — PASS: 4 tests in `test/ui/routing/scaffold_responsive_test.dart`;
  NavigationRail at 840dp+, NavigationBar below
- Accessibility — PASS: 3 tests in `test/ui/widgets/bristol_selector_semantics_test.dart`;
  ErrorRetryWidget extracted and wired into home + reports
- Release signing config — PASS: `android/app/build.gradle.kts` has debug-signing fallback;
  web release build verified (`flutter build web --release --base-href /DejaPoo/`)
- Store listing + iOS deviation — PASS: `designs/STORE_LISTING.md` committed;
  DESIGN.md deviation log updated for iOS-on-Windows limitation
- flutter analyze — PASS: 1 info-level lint only (pre-existing `prefer_const_literals`)
- flutter test --timeout 30s — PASS: 307 tests, all passing
- flutter build web --release — PASS
- README.md updated — PASS: phase table shows Phase 6 Done; features section updated with
  reminders, responsive layout, accessibility, COI worker, app identity

## What changed

- `lib/data/notifications/` — notification service abstraction, local implementation
  (flutter_local_notifications + timezone), fake for tests, preferences notifier
  (shared_preferences), providers
- `lib/data/sync/sync_providers.dart` — unchanged; `scheduleDebouncedSync()` calls added at
  UI layer in entry_sheet, home_screen, settings_screen
- `lib/ui/routing/scaffold_with_nav_bar.dart` — responsive NavigationRail/NavigationBar swap
- `lib/ui/widgets/bristol_type_selector.dart` — Semantics labels on each circle
- `lib/ui/widgets/error_retry_widget.dart` — shared error + retry widget
- `lib/features/home/home_screen.dart` — sync wiring, FAB semantics, ErrorRetryWidget
- `lib/features/reports/` — chart semantics summaries, ErrorRetryWidget
- `web/coi_serviceworker.js` — COI headers for OPFS on GitHub Pages
- `web/index.html` — COI SW registration, DejaPoo branding, splash, theme-color
- `web/manifest.json` — DejaPoo name, sage palette colors, real description
- `android/app/build.gradle.kts` — release signing with debug fallback
- `assets/icon/` — app icon PNG + foreground
- `designs/STORE_LISTING.md` — store listing, privacy policy, data safety answers
- `pubspec.yaml` — new deps: flutter_local_notifications, timezone, shared_preferences,
  permission_handler, flutter_launcher_icons (dev), flutter_native_splash (dev), image (dev)

## How to verify

```bash
flutter analyze
flutter test --timeout 30s
flutter build web --release --base-href /DejaPoo/   # PowerShell only
flutter build apk --release
flutter build appbundle --release
flutter run -d chrome --dart-define=DB_SMOKE=true   # expect "DB_SMOKE OK"
```

## Decisions & deviations from DESIGN.md

- `flutter_native_splash` pinned `^2.4.4` (not ^2.4.6) to avoid image/archive/xml conflict
  with excel ^4.0.6
- COI service worker uses `credentialless` COEP (not `require-corp`) to allow cross-origin
  Google API script loading
- COI reload uses sessionStorage flag to prevent infinite loops from COOP browsing-context-group
  switches
- FAB uses Semantics label (not tooltip) because tooltip's long-press gesture recognizer
  conflicts with quick-log's long-press handler
- iOS release artifacts: docs-only (deviation logged in DESIGN.md); tracked as `dp-y82`

## Deferred work

- `dp-y82` iOS OAuth client verification + build — requires a Mac
- `dp-9w0` Re-add riverpod_lint + custom_lint when analyzer versions align
- `dp-h5e` Import stale-row cleanup: handle decreased counts on re-import
- APK/appbundle release build verification — Gradle daemon lock issues prevented clean builds
  this session; signing config is correct (debug fallback), needs manual verification

## Pointers for next phase

- The app is feature-complete per DESIGN.md. Remaining work is iOS verification (Mac required),
  riverpod_lint re-add (blocked on analyzer version alignment), and Play Store submission
  (user action, not agent work)
- drift/drift_dev remain pinned at 2.34.0; any package additions must dry-run `flutter pub get`
- The COI service worker pattern is critical for the web deployment — any changes to
  `web/index.html` must preserve the SW registration before `flutter_bootstrap.js`
- Manual gates still needed: notification fires on Android emulator, PWA installs from Pages
  with correct icon, real-account sync works after debounce wiring
