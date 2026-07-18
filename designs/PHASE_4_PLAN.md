# Phase 4 Implementation Plan — Historical Spreadsheet Import (epic `dp-l8w`)

**Audience:** an Opus orchestrator agent starting with zero conversation context.
**Repo:** `C:\Users\ryan9\AndroidStudioProjects\DejaPoo` · **Branch:** create `phase_4` off `main` (merge `phase_3` first if not yet merged). Unproven work stays on the branch + PR; the verification gate is LOCAL test runs, not CI.

## Context

Phases 0–3 are done (see `designs/PHASE_3_HANDOFF.md`; 139 tests green). Phase 4 (DESIGN.md §Phase 4, bd epic `dp-l8w`) delivers an importer for the user's historical spreadsheet — XLSX and CSV year-sheet layout — expanding daily per-type counts into `dateOnly` events, idempotent on re-import. **Exit criterion:** the real gitignored `Alex Bowels.xlsx` (present in repo root) imports cleanly locally and Reports reproduce its year totals **2024 = 669, 2025 = 791, 2026 YTD = 418**. Phase 4 unblocks Phase 5 (`dp-l4h`, Drive sync/export round-trips through this importer).

## Ground truth: the real spreadsheet layout (verified by opening the xlsx)

- Google Sheets export; 3 sheets named exactly `2024`, `2025`, `2026`; contains a chart + embedded PNG the parser must tolerate.
- Row 1: title (`TYPES OF POOP` in C1). Row 2: headers `MONTH`(A) `DATE`(B) `TYPE 1`…`TYPE 7`(C–I) `TOTAL`(J). Data from row 3.
- Column A: month name only on the 1st of each month — **ignore column A**.
- **Column B: raw Excel serial doubles** (epoch 1899-12-30; e.g. 45292.0 = 2024-01-01). The `excel` package may surface these as `DateCellValue`, `DateTimeCellValue`, `IntCellValue`, or `DoubleCellValue` — handle all four.
- C–I: doubles or blank (blank = 0). J: `SUM(C3:I3)` formula — read the cached value.
- **Side stat table shares data rows in columns L/M/N/P/Q** (year total, avg, per-type sums, KEY legend) — never read past column J. Row gate: "column B parses as a date".
- Sheets include full-year rows with blank trailing days (that's why 2026 = 418 YTD) — empty rows are valid zero-event days.
- Leap-year note: spreadsheet 2024 avg divides by 365; app `averagePerDay` divides by 366. Both display 1.83 — assert app semantics; note discrepancy in handoff.

## Design decisions (settled — do not re-litigate)

1. **No schema change.** `dateOnly = true` is the imported marker (its doc comment already says so). No migration, schemaVersion stays 1.
2. **Deterministic ids** `imp-<yyyy-MM-dd>-t<N>-<k>` (k 1-based occurrence index per date+type). Gives idempotent re-import and clean Phase 5 sync merge. Parser must merge duplicate date rows (sum counts, warn) before expansion so indices never collide.
3. **Dedupe = insert-or-ignore**: new repo method `Future<int> insertAllIfAbsent(List<BowelMovement>)` — probe existing ids (chunked `id IN (...)`, ≤500/chunk, **no** `deletedAt` filter so soft-deleted imports are not resurrected), batch insert with `InsertMode.insertOrIgnore`, return inserted count. Stale rows after a count decrease in the source = accepted limitation → file a backlog bd issue.
4. **Packages:** `excel`, `csv`, `file_picker` (all analyzer-free; cannot disturb the drift 2.34.0/drift_dev 2.34.0 exact pins — NEVER bump those to satisfy the solver).
5. **Architecture:** pure-Dart parsers on bytes/String in `lib/data/import/` (no `dart:io` in lib — web has no file paths), an `ImportService`, and an always-visible Settings "Import" section (NOT behind DEMO_MODE).
6. **Expanded events at noon local** (`day + 12h`), matching `FixtureGenerator`'s documented convention (`lib/data/fixtures/fixture_generator.dart`).
7. **Fixtures generated in-test** via the `excel`/`csv` packages (no committed binaries), writing raw serial doubles in column B to exercise the real code path; plus a real-file gate test that skips when `Alex Bowels.xlsx` is absent (gitignored → skips on CI, runs locally).

## Mandatory reading & rules for the orchestrator

- `CLAUDE.md` (session protocol), `designs/DESIGN.md`, `.claude/skills/drift-flutter/SKILL.md` **before** issue C (repo/drift change).
- bd is the sole tracker. Expand the epic (`bd create --parent dp-l8w`), claim, commit+push after every closed issue. Copy `designs/templates/PHASE_STATUS_TEMPLATE.md` → `designs/PHASE_4_CURRENT_STATUS.md` at start; keep it current.
- Tests: always `flutter test --timeout 30s`; NEVER `flutter test --platform chrome`; web gate is `flutter run -d chrome --dart-define=DB_SMOKE=true` → `DB_SMOKE OK`. Run `flutter build web` from PowerShell, not Git Bash. Widget tests holding drift `watch()` streams must end with `pumpWidget(SizedBox.shrink())` + `pump(1ms)`.
- After provider changes: `dart run build_runner build --delete-conflicting-outputs`.

## bd child issues (dependency order; A/B/C parallelizable, then D→E, F onward serial)

| # | Title | Scope |
|---|-------|-------|
| A | Add import dependencies (excel, csv, file_picker) | `flutter pub add` only; verify pub get resolves without touching drift pins; analyze + full test + `flutter build web` still green before any feature code. |
| B | Import models + deterministic-id event expander | `lib/data/import/import_models.dart` (`DailyCounts`, `ImportIssue`, `SheetParseResult`, `ImportSummary`) + `import_expander.dart` + unit tests. |
| C | Repo: `insertAllIfAbsent` | Read drift skill first. Add to `lib/domain/bowel_movement_repository.dart` + implement in `lib/data/repositories/drift_bowel_movement_repository.dart`; tests: inserted count, dup skipped, soft-deleted not resurrected, >500 chunking. |
| D | XLSX year-sheet parser + synthetic fixture builder | `lib/data/import/xlsx_parser.dart` + `test/helpers/spreadsheet_fixture.dart`; edge-case tests (below). Sheet select: name matches `^\d{4}$` (warn+skip others; date year wins on mismatch). |
| E | CSV year-sheet parser | `lib/data/import/csv_parser.dart`; one file = one year sheet; column-B date fallbacks: ISO, `M/d/yyyy`, `M/d/yy`, Excel serial. Shares fixture helper. |
| F | ImportService + Settings Import UI | `lib/data/import/import_service.dart` (dispatch on extension + magic bytes `PK\x03\x04`; catches parser throws into an error issue — never crashes UI); provider in `lib/data/providers.dart`; `_ImportSection` in `lib/features/settings/settings_screen.dart` cloned from `_DemoDataSection`, using `FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['xlsx','csv'], withData: true)` (`withData: true` mandatory for web); result dialog (inserted/skipped/issues). Widget test drives `ImportService` directly — don't automate the native dialog. |
| G | End-to-end correctness + real-file local gate | Round-trip synthetic fixture → `reportStatsProvider` with `ReportRange.year(anchor:)` (pattern: `test/features/reports/reports_screen_test.dart`); `test/data/import/real_spreadsheet_test.dart` skips if `Alex Bowels.xlsx` absent, else asserts totals 669/791/418. |
| H | Phase wrap-up | README phase table + feature list; `designs/PHASE_4_HANDOFF.md` from template (note leap-year avg + YTD-avg semantics + stale-row limitation w/ backlog issue id); delete status doc; close children + epic; full Session Completion checklist. |

## Parser edge-case checklist (all get tests)

1. Non-date rows (title, headers, KEY legend, blanks) skipped via column-B date gate.
2. Blank count cell = 0; all-blank row = valid zero-event day.
3. J ≠ sum(C–I) → warning (per-type cells authoritative, import proceeds).
4. Non-integral or negative counts → error issue, skip row.
5. All four Excel serial cell-value types (epoch 1899-12-30).
6. Never read past column J (side stats in L–Q).
7. Sheet-name year ≠ date year → warning, dates win.
8. Duplicate dates → merge counts + warning (id stability).
9. Leap year (2024, 366 rows) and partial year (2026).
10. CSV: quoted fields, CRLF, date-format fallbacks; dates without years → error instructing xlsx.
11. Garbage bytes → single error issue, zero inserts, no exception escapes the service.
12. Re-import of identical bytes → inserted 0, skipped N.

## Verification / exit checklist (issue H evidence)

1. `flutter analyze` clean; `flutter test --timeout 30s` all green including real-file gate locally (669/791/418).
2. Manual: Settings → Import → pick `Alex Bowels.xlsx` → ~1878 inserted, re-import → 0 inserted; Reports Year views show 669/791/418. (Spreadsheet's YTD 2.13 avg uses days-elapsed; app year view uses full-year denominator — document, don't chase.)
3. `flutter build web --release --base-href /DejaPoo/` exit 0; DB_SMOKE OK on Chrome; manual web import from bytes works.
4. README + PHASE_4_HANDOFF.md done; children + epic `dp-l8w` closed (unblocks `dp-l4h`); pushed, `git status` clean vs origin.

## Risks

- **`excel` decode quality vs Google-Sheets file** (medium): mitigated by 4-way date-cell fallback, raw-serial fixtures, and the real-file gate catching failures early. Fallback if `excel` chokes: parse `xl/worksheets/*.xml` directly via transitive `archive`+`xml` — the format is simple.
- **Dependency resolution** (medium): isolated in issue A with full gates before feature code; never bump drift pins.
- **Web bytes** (low): `withData: true`; no `dart:io` in lib code (only the skip-gate test uses `File`).
