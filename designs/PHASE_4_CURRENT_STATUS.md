# Phase 4 Current Status

**Phase:** 4 — Historical Spreadsheet Import (bd epic: `dp-l8w`)
**Last updated:** 2026-07-17 02:00

## Done (with verification evidence)
- `dp-l8w.1` A: Import dependencies (excel ^4.0.6, csv ^8.0.0, file_picker ^11.0.2)
- `dp-l8w.2` B: Import models + ImportExpander (deterministic IDs `imp-yyyy-MM-dd-tN-k`)
- `dp-l8w.3` C: `insertAllIfAbsent` repo method (chunked id probe, insertOrIgnore)
- `dp-l8w.4` D: XLSX parser + SpreadsheetFixture (DST fix: UTC epoch math)
- `dp-l8w.5` E: CSV parser (ISO/US/serial date fallbacks, csv 8.x API)
- `dp-l8w.6` F: ImportService + Settings Import UI (7 tests; 203 total green)
- Wave 1 (ecfac8a) + Wave 2 (ab8c648) + Wave 3 pushed; 203 tests green, analyze clean

## In progress
- `dp-l8w.7` G: End-to-end correctness + real-file local gate — launching

## Next steps
1. Complete G: Round-trip synthetic fixture → reportStatsProvider; real-file gate (669/791/418)
2. After G: H (dp-l8w.8) wrap-up (README, handoff, close epic)

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
