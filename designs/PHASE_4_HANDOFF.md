# Phase 4 Handoff

**Phase:** 4 — Historical Spreadsheet Import (bd epic: `dp-l8w`, closed 2026-07-17)

## Phase summary

Delivered an importer for the user's historical Google Sheets export (XLSX and CSV year-sheet
layout), expanding daily per-type Bristol counts into `dateOnly` events with deterministic IDs,
idempotent on re-import via insert-or-ignore. Settings screen gained an always-visible Import
section with file picker and result dialog. Real-file gate test locally confirmed exact year
totals (2024 = 669, 2025 = 791, 2026 YTD = 418, total 1878 events).

## Exit criteria — evidence

- Real `Alex Bowels.xlsx` imports cleanly and Reports reproduce year totals 669/791/418 — PASS:
  `test/data/import/real_spreadsheet_test.dart` runs locally (skips on CI), asserts exact totals,
  1878 inserted, idempotent re-import (0 inserted, 1878 skipped)
- `flutter analyze` — PASS: no issues
- `flutter test --timeout 30s` — PASS: 209/209 green (13 new import tests)
- `flutter build web --release --base-href /DejaPoo/` — verified in wave 1 (dependency add)
- README.md updated to reflect this phase — PASS: Phase 4 status → Done, Import feature listed

## What changed

- `lib/data/import/` — new directory:
  - `import_models.dart` — DailyCounts, ImportIssue, SheetParseResult, ImportSummary
  - `import_expander.dart` — deterministic ID generation (`imp-yyyy-MM-dd-tN-k`), duplicate-date
    merging
  - `xlsx_parser.dart` — 4-way Excel serial date handling (DateCellValue, DateTimeCellValue,
    IntCellValue, DoubleCellValue), UTC epoch arithmetic to avoid DST trap
  - `csv_parser.dart` — ISO/US/serial date fallbacks, csv 8.x API
  - `import_service.dart` — dispatch on extension + PK magic bytes, error wrapping
- `lib/domain/bowel_movement_repository.dart` — `insertAllIfAbsent` method (chunked id probe,
  insertOrIgnore, no soft-deleted resurrection)
- `lib/data/repositories/drift_bowel_movement_repository.dart` — insertAllIfAbsent implementation
- `lib/data/providers.dart` — `importServiceProvider` added
- `lib/features/settings/settings_screen.dart` — `_ImportSection` (always visible, not gated by
  DEMO_MODE), FilePicker with `withData: true` for web, result dialog
- `pubspec.yaml` — excel ^4.0.6, csv ^8.0.0, file_picker ^11.0.2
- Tests: import_models_test, import_expander_test, xlsx_parser_test, csv_parser_test,
  import_service_test, e2e_import_test, real_spreadsheet_test — 13 new test files/groups

## How to verify

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test --timeout 30s
# Real-file gate (requires Alex Bowels.xlsx in repo root):
flutter test --timeout 30s test/data/import/real_spreadsheet_test.dart
# Web smoke:
flutter run -d chrome --dart-define=DB_SMOKE=true   # expect DB_SMOKE OK
```

## Decisions & deviations from DESIGN.md

- Excel serial epoch arithmetic uses UTC to avoid DST off-by-one trap (local-time epoch +
  Duration(days: n) doesn't land on midnight when crossing a DST boundary)
- Column J total-mismatch warning is best-effort: `excel` package can't read formula cached
  values, so the check only fires when column J was exported as a literal number
- file_picker 11.x changed API: `FilePicker.pickFiles()` is a static method, not
  `FilePicker.platform.pickFiles()`
- csv 8.x API: `Csv().decode()` replaces `CsvToListConverter`
- Leap-year avg semantics: spreadsheet 2024 divides by 365; app `averagePerDay` divides by 366
  (both display 1.83). App uses correct calendar-day count — no deviation needed
- YTD avg semantics: spreadsheet uses days-elapsed; app year view uses full-year denominator.
  Documented, not chased — the numbers serve different purposes

## Deferred work

- `dp-h5e` — Import stale-row cleanup: handle decreased counts on re-import (P4 backlog)
- `dp-mih` — COI service worker for OPFS on GitHub Pages (independent)
- `dp-9w0` — riverpod_lint/custom_lint re-add (blocked on analyzer version alignment)

## Pointers for next phase

- Phase 5 (Drive sync `dp-l4h`) round-trips through the Phase 4 importer — the deterministic
  IDs (`imp-*`) give stable identity for merge conflict resolution
- `InsertAllIfAbsent` is the idempotent write path; Phase 5 export can generate XLSX via the
  same `excel` package already in deps
- `_ImportSection` in settings is always visible — Phase 5 may want to add an Export section
  alongside it, following the same `ConsumerStatefulWidget` pattern
- `withData: true` on FilePicker is mandatory for web (no file paths available)
- Never bump drift/drift_dev from 2.34.0
