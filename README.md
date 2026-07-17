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
| 0 | Scaffold, theme system, navigation shell, Bristol type icons | ✅ Done |
| 1 | Data layer: Drift (SQLite) schema, repositories, aggregation queries, WASM web DB | ✅ Done |
| 2 | Logging UX: home timeline, add/edit bottom sheet, quick-log | ✅ Done |
| 3 | Metrics & reports (stat tiles, charts, range selector) | Planned |
| 4 | Historical spreadsheet import (XLSX/CSV) | Planned |
| 5 | Google Drive sync & export | Planned |
| 6 | Polish & release readiness | Planned |

## Features (so far)

- **Home timeline** — today-at-a-glance header with count + most-recent type, reverse-chron
  entries grouped by calendar day
- **Add/edit entry** — bottom sheet with Bristol type picker, optional size/color/notes;
  swipe right on an entry to edit, tap to view
- **Quick-log** — FAB long-press opens a compact popup of all 7 Bristol type icons; one tap
  saves an entry instantly (< 5 seconds from launch to logged)
- **Delete with undo** — swipe left to soft-delete, SnackBar with Undo restores the entry
- **Persistent local storage** — Drift/SQLite on native, WASM sqlite on web; soft-delete
  tombstones for future sync

## Stack

- **Flutter** (Android / iOS / web) with **Riverpod** for state management
- **Drift** (SQLite) for local storage — native `sqlite3` on mobile, WASM on web
- **go_router** for navigation, **fl_chart** (Phase 3+) for charts
- Custom SVG icon set for Bristol types 1–7

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
flutter build web --release --base-href /DejaPoo/   # GitHub Pages
flutter build apk --release
flutter build appbundle --release
```

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
