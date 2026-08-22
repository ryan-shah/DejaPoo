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
  branding with sage palette colors. **Icon redesigned 2026-08-22 (`dp-0rw`)** — the original
  mark read as a hamburger menu; see "Icon redesign" below
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
- `assets/icon/` — icon SVG masters (artwork of record) + rendered PNGs; see "Icon redesign" below
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
- APK release build — VERIFIED (`flutter build apk --release` produces 65.5MB APK). Required
  three Gradle fixes: core library desugaring for flutter_local_notifications, force-apply KGP
  to library subprojects (file_picker/share_plus skip KGP on AGP 9 but builtInKotlin=false),
  and compileSdk override for plugins stuck on SDK 31 (flutter_native_splash). Gradle JVM heap
  reduced from 8G to 4G to prevent daemon OOM crashes on Windows

## Pointers for next phase

- The app is feature-complete per DESIGN.md. Remaining work is iOS verification (Mac required),
  riverpod_lint re-add (blocked on analyzer version alignment), and Play Store submission
  (user action, not agent work)
- drift/drift_dev remain pinned at 2.34.0; any package additions must dry-run `flutter pub get`
- The COI service worker pattern is critical for the web deployment — any changes to
  `web/index.html` must preserve the SW registration before `flutter_bootstrap.js`
- Manual gates still needed: notification fires on Android emulator, PWA installs from Pages
  with correct icon, real-account sync works after debounce wiring

## Icon redesign (2026-08-22, `dp-0rw`)

The Phase 6 launcher icon — three horizontal rounded bars on a flat sage square — read as a
hamburger menu. Two causes: the mark used no rotation, while every `assets/icons/bristol_type_*.svg`
tilts its shapes; and `tool/generate_icon.dart` drew procedurally with `package:image`'s
`fillRect`/`fillCircle`, which has no anti-aliasing and cannot rotate a shape, so the design space
was limited to axis-aligned bars.

**New mark:** a Bristol type-4 capsule in forest `#3E6B48`, tilted −25°, ringed by seven off-white
`#FAFAF7` dots on a sage `#6FAE8D` field. Seven dots read as the seven Bristol types or a week of
entries; the enlarged top dot marks today. Chosen by the user from a rendered candidate sheet
(eight marks, then six colour treatments).

**Pipeline change — SVG is now the artwork of record.** `tool/generate_icon.dart` is deleted and
replaced by `tool/render_icons.dart`, which rasterises the SVG masters through `flutter_svg`
(already a dependency) to a `ui.Picture` drawn offscreen — real anti-aliasing, real transforms. It
lives in `tool/` so `flutter test` (which globs `test/` only) never rewrites committed artwork, but
runs under `flutter test` because rasterising SVG needs a Flutter engine.

Regenerate with, in order:

```bash
flutter test tool/render_icons.dart      # SVG masters -> assets/icon/*.png
dart run flutter_launcher_icons
dart run flutter_native_splash:create
flutter test tool/render_icons.dart      # restores web/favicon.png at 64px
```

The final step is required: `flutter_launcher_icons` has no favicon size option and always emits
16x16.

**Geometry constraints baked into the SVGs** (change these and re-check the numbers):

- Ring radius is 16.0 on the 48-unit grid. The widest point is the enlarged today-dot at 79.5% of
  the icon width — inside the 80% PWA maskable safe circle. This is why `Icon-maskable-*.png` may
  be byte-identical to the plain icons and that is now correct, not a bug: the mark already fits
  the maskable safe zone, so no extra padding is needed.
- `app_icon_foreground.svg` scales the mark 1.1x and fills its own canvas as the 72dp viewport.
  `mipmap-anydpi-v26/ic_launcher.xml` insets it 16%, landing the mark at ~59% of the 108dp canvas,
  inside the 61% guaranteed-safe circle. The old generator pre-scaled to 0.62 **and** took that
  inset, which is why the adaptive mark was tiny.

**Also fixed in the same pass:** `<monochrome>` layer added for Android 13+ themed icons
(`adaptive_icon_monochrome`); `web/favicon.png` 16x16 -> 64x64; splash now uses `app_splash.png`
(the icon on a rounded sage field with transparent surroundings) instead of the full-bleed square
that rendered as a floating green tile; dark splash given its own background `#1A1F1A` instead of
being byte-identical to the light one.

**iOS:** `flutter_launcher_icons` and `flutter_native_splash` both regenerated the iOS asset
catalogs from Windows without a Mac, so `AppIcon.appiconset` and the launch imagesets are current.
Only *building/signing* the iOS app still needs macOS (`dp-y82`).

**Note:** `image: ^4.3.0` stays in `dev_dependencies` even though nothing imports it directly now.
It is load-bearing for resolution — `flutter_native_splash` is pinned `^2.4.4` to avoid an
image/archive/xml conflict with `excel ^4.0.6` (above), and dropping the explicit constraint risks
resurfacing it.

**Verification:** `flutter analyze` (1 pre-existing info lint), `flutter test --timeout 30s`
(305 passed, 1 skipped), `flutter build web --release --base-href /DejaPoo/`,
`flutter build apk --release` (66.6MB), `flutter run -d chrome --dart-define=DB_SMOKE=true`
-> `DB_SMOKE OK`. Still requires a human: launcher icon + themed-icon variant on an Android
emulator, and OPFS on the deployed Pages build.
