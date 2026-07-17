# Phase 4 Current Status

**Phase:** 4 — Historical Spreadsheet Import (bd epic: `dp-l8w`)
**Last updated:** 2026-07-17 03:00

## Done (with verification evidence)
- `dp-l8w.1` A: Import dependencies (excel ^4.0.6, csv ^8.0.0, file_picker ^11.0.2)
- `dp-l8w.2` B: Import models + ImportExpander (deterministic IDs `imp-yyyy-MM-dd-tN-k`)
- `dp-l8w.3` C: `insertAllIfAbsent` repo method (chunked id probe, insertOrIgnore)
- `dp-l8w.4` D: XLSX parser + SpreadsheetFixture (DST fix: UTC epoch math)
- `dp-l8w.5` E: CSV parser (ISO/US/serial date fallbacks, csv 8.x API)
- `dp-l8w.6` F: ImportService + Settings Import UI (7 tests; 203 total green)
- `dp-l8w.7` G: E2E correctness + real-file gate — `test/data/import/e2e_import_test.dart`
  (4 synthetic round-trip tests: XLSX, CSV, idempotent re-import, multi-year, verified via
  `repo.totalCount`/`typeDistribution`/`averagePerDay`) + `test/data/import/real_spreadsheet_test.dart`
  (skips when `Alex Bowels.xlsx` absent; locally confirmed totals 669/791/418, insertedCount
  1878, idempotent re-import). 209 tests green, analyze clean.
- Wave 1 (ecfac8a) + Wave 2 (ab8c648) + Wave 3 (6affe43) + Wave 4 (this) pushed

## Next steps
1. H (dp-l8w.8): Phase 4 wrap-up — README update, PHASE_4_HANDOFF.md, close epic + children

## Known issues & gotchas
- Excel serial date math must use UTC epoch (DST off-by-one trap — fixed in D)
- `excel` package can't read formula cached values (column J mismatch is best-effort)
- `TextCellValue` constructor is NOT const (creates TextSpan internally)
- csv 8.x API: `Csv().decode()` not `CsvToListConverter`
- drift/drift_dev pinned at 2.34.0; never bump
- file_picker 11.x: `FilePicker.pickFiles()` static, NOT `FilePicker.platform.pickFiles()`

## Decisions made this phase
- 2026-07-17 — Excel serial epoch arithmetic uses UTC to avoid DST trap
- 2026-07-17 — Column J total-mismatch warning is best-effort (formula cells unreadable)
- 2026-07-17 — Magic-bytes dispatch: XLSX content with wrong extension detected via PK\x03\x04
