# DejaPoo

An adult [Huckleberry](https://huckleberrycare.com/) for bowel tracking: one-tap logging of
events classified by [Bristol Stool Chart](https://en.wikipedia.org/wiki/Bristol_stool_scale)
type via representative icons, with rich time-range analytics and Google Drive sync/export.

**Targets:** Android · iOS · Web ([live build](https://ryan-shah.github.io/DejaPoo/))

## Status

Under active development. See [`designs/DESIGN.md`](designs/DESIGN.md) for the authoritative
design document and phase breakdown.

| Phase | Scope | Status |
|---|---|---|
| 0 | Scaffold, theme system, navigation shell, Bristol type icons | Done |
| 1 | Data layer: Drift (SQLite) schema, repositories, aggregation queries, WASM web DB | Done |
| 2 | Logging UX: home timeline, add/edit bottom sheet, quick-log | Done |
| 3 | Metrics & reports (stat tiles, charts, range selector) | Done |
| 4 | Historical spreadsheet import (XLSX/CSV) | Done |
| 5 | Google Drive sync & export | Done |
| 6 | Polish & release readiness | Done |

## Features

- **Home timeline** — today-at-a-glance header with count + most-recent type, reverse-chron
  entries grouped by calendar day
- **Add/edit entry** — bottom sheet with Bristol type picker, optional size/color/notes;
  swipe right on an entry to edit, tap to view
- **Quick-log** — FAB long-press opens a compact popup of all 7 Bristol type icons; one tap
  saves an entry instantly (< 5 seconds from launch to logged)
- **Delete with undo** — swipe left to soft-delete, SnackBar with Undo restores the entry
- **Reports & analytics** — Day / Week / Month / Year / Custom range selector with prev/next
  stepping; Summary tab with stat tiles (total, avg/day, most common type, % healthy, longest
  gap), stacked bar chart by Bristol type, and type-distribution donut; List tab with
  multi-select Bristol type filter chips; all stats update live when entries are logged/edited
- **Historical import** — import from XLSX or CSV spreadsheets (Google Sheets year-sheet layout);
  expands daily per-type counts into individual events, idempotent on re-import; accessible from
  Settings on all platforms including web
- **Google Drive sync** — sign in with Google, authorize Drive scope, then sync via a JSON
  snapshot in Drive's appDataFolder; LWW merge on `updatedAt` handles concurrent edits across
  devices; manual "Sync now" plus auto-sync on app open and debounced sync after every local
  mutation when authorized
- **Export** — export all entries as XLSX (year-based sheets matching the import layout) or CSV;
  web uses browser download, mobile uses the native share sheet
- **Daily reminders** — optional local notification at a user-chosen time ("Log today's movements"),
  with Android 13+ permission handling; hidden on web
- **Responsive layout** — NavigationRail at 840dp+ for tablets/desktop, NavigationBar on phone
- **Accessibility** — Bristol type icons announce type + description + selection state; charts
  provide text summaries for screen readers; all screens have designed error/retry and empty states
- **App identity** — launcher icon drawn in the Bristol visual language: a tilted type-4 capsule
  ringed by seven dots (the seven Bristol types, or a week), two-tone sage. The SVGs in
  `assets/icon/` are the artwork of record; `flutter test tool/render_icons.dart` rasterises them.
  Android adaptive + themed (monochrome) icons, native splash with a dark variant, PWA manifest
- **Cross-origin isolation** — COI service worker enables OPFS storage for the web build on
  GitHub Pages (without it drift falls back to IndexedDB permanently)
- **Persistent local storage** — Drift/SQLite on native, WASM sqlite on web; soft-delete
  tombstones for sync

## Stack

- **google_sign_in** + **googleapis** for Google Drive sync/export
- **Flutter** (Android / iOS / web) with **Riverpod** for state management
- **Drift** (SQLite) for local storage — native `sqlite3` on mobile, WASM on web
- **go_router** for navigation, **fl_chart** (Phase 3+) for charts
- **flutter_local_notifications** + **timezone** for daily reminders
- Custom SVG icon set for Bristol types 1-7

## Getting started

Requires the Flutter SDK (Dart ^3.12).

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # code generation

flutter run -d chrome     # web
flutter run -d android    # Android device/emulator
```

### Tests & checks

```bash
flutter analyze
flutter test --timeout 30s

# Web (WASM sqlite) smoke gate: run the app with the DB_SMOKE probe and
# expect a "DB_SMOKE OK" line on the console
flutter run -d chrome --dart-define=DB_SMOKE=true
```

### Release builds

```bash
flutter build web --release --base-href /DejaPoo/   # GitHub Pages (PowerShell only)
flutter build apk --release
flutter build appbundle --release

# Print the version CI will stamp on this commit (name=0.1.<n>, code=<n>)
bash tool/ci_version.sh
```

### Downloading a build

Every merge to `main` publishes a GitHub Release with the Android artifacts attached:
**<https://github.com/ryan-shah/DejaPoo/releases/latest>**. The web build is deployed to
GitHub Pages. Open **Settings → About → Version** in the app to see which build you are on
(`dev` for local builds).

Each pull request additionally gets a `pr-<N>` prerelease with that PR's test APK, plus a
web preview at `/DejaPoo/pr-<N>/`; both are deleted automatically when the PR closes.

### Versioning

Versions are derived by [`tool/ci_version.sh`](tool/ci_version.sh) — the single source of
truth shared by all three build workflows — so no manual bump is needed per release:

| | Value | Source |
| --- | --- | --- |
| `versionName` | `0.1.<n>` | `MAJOR.MINOR` from `pubspec.yaml` + git commit count |
| `versionCode` | `<n>` | git commit count (`git rev-list --count HEAD`) |

The commit count increases on every merge, so **the version changes on every merge**, and
the release tag `v0.1.N` and build number `N` are always the same number. Release artifacts
are named `dejapoo-v<version>.apk` / `.aab` (PR builds: `dejapoo-pr<N>-v<version>.apk`).

To start a new series (e.g. `0.2.x`), change the `MAJOR.MINOR` part of `version:` in
`pubspec.yaml`; the patch and `+build` suffix there are ignored by CI.

Because the version comes from the commit count, all build workflows check out with
`fetch-depth: 0` — a shallow clone would collapse it to `1`.

### Google OAuth setup

Google Drive sync requires a Google Cloud OAuth client configured per platform. See
[`designs/GOOGLE_OAUTH_SETUP.md`](designs/GOOGLE_OAUTH_SETUP.md) for step-by-step instructions
for Android, Web, and iOS.

## Project structure

```
lib/
  data/       # Drift database, repositories, fixtures, Riverpod providers
  domain/     # Entities, enums, repository interface, aggregation helpers
  features/   # Feature modules (home, reports, settings)
  ui/         # Theme tokens, routing, shared widgets (Bristol icons)
designs/      # DESIGN.md (authoritative), phase status & handoff docs
```

## Development notes

- Issue tracking uses [beads](https://github.com/gastownhall/beads) (`bd ready`, `bd show <id>`);
  `CLAUDE.md` documents the full agent workflow, build commands, and test-run rules.
- Generated `*.g.dart` files are gitignored; CI runs `build_runner` before analyze/test.
- Personal reference data (spreadsheets, app screenshots) is local-only and gitignored — tests
  use synthetic fixtures.
