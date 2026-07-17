# Phase 1 Handoff

**Phase:** 1 — Data layer (bd epic: `dp-2ri`, closed 2026-07-16)

## Phase summary

Built the full data layer: Drift (SQLite) schema v1 with sync-ready columns (soft-delete
tombstones, `updatedAt`), a repository layer behind a domain interface with Riverpod providers,
a deterministic fixture generator modeled on the real spreadsheet distributions, and SQL/Dart
aggregation queries (daily/weekly/monthly type counts, avg/day, streaks, gaps). Works natively
and on web via WASM sqlite, verified end-to-end by a runtime DB_SMOKE probe. Merged via PR #2
(squash `f5b76f6`).

## Exit criteria — evidence

- Repository tests green — PASS: `flutter test --timeout 30s` → **40 tests, all passed**
  (CRUD round-trip, soft-delete invisibility, ranges, watch streams, aggregation boundary
  cases, fixture determinism) on merged main, 2026-07-16
- Web (WASM sqlite) smoke test — PASS: `flutter run -d chrome --dart-define=DB_SMOKE=true` →
  `DB_SMOKE OK: insert/read/aggregate/soft-delete round-tripped` on merged main, 2026-07-16.
  (Runtime probe replaces the originally planned `flutter test --platform chrome` — see
  deviations below.)
- `flutter analyze` — PASS: "No issues found!" on merged main
- Web release build — PASS: `flutter build web --release --base-href /DejaPoo/` exits 0 with
  `sqlite3.wasm` + source-compiled `drift_worker.js` in the output
- README.md updated to reflect this phase (required for every phase) — PASS: rewritten from
  empty stub — product one-liner, phase status table, stack, build/test commands, structure

## What changed

- `lib/domain/` — `BowelMovement` entity (`@UseRowClass`, `copyWith`), `BristolType` moved here
  from UI (re-exported), new `StoolSize`/`StoolColor` enums, `BowelMovementRepository` interface,
  `aggregates.dart` (result types + Dart streak/gap/rollup helpers over SQL daily counts)
- `lib/data/db/` — `bowel_movements_table.dart` (incl. `LocalDateTimeConverter`),
  `app_database.dart` (schema v1, injectable `QueryExecutor`), `db_smoke_probe.dart` (web gate)
- `lib/data/repositories/drift_bowel_movement_repository.dart` — CRUD + soft delete + all
  aggregation queries
- `lib/data/fixtures/fixture_generator.dart` — seeded Poisson daily counts, weighted Bristol types
- `lib/data/providers.dart` — `appDatabaseProvider`, `bowelMovementRepositoryProvider` (keepAlive)
- `drift_schemas/drift_schema_v1.json` — schema baseline for future migration tests
- `web/sqlite3.wasm`, `web/drift_worker.js` (+ `web/drift_worker.dart` source,
  `tool/setup_web.dart` regenerates both after drift/sqlite3 bumps)
- `test/domain/`, `test/data/` — 40 tests
- `.claude/skills/drift-flutter/SKILL.md` — hard-won drift rules; `.github/workflows/test.yml`
  runs build_runner before analyze/test
- `CLAUDE.md` — Test-run rules section (timeouts, wedge detection, orphan cleanup)

## How to verify

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze                                       # No issues found
flutter test --timeout 30s                            # 40 tests pass
flutter run -d chrome --dart-define=DB_SMOKE=true     # console prints "DB_SMOKE OK: ..."
flutter build web --release --base-href /DejaPoo/     # exits 0 (run from PowerShell)
```

## Decisions & deviations from DESIGN.md

- **Local wall-time `occurredAt`:** drift's `store_date_time_values_as_text` normalizes to UTC on
  write, which shifts late-evening events to the next UTC day. `occurredAt` uses a custom
  `LocalDateTimeConverter` (local ISO text, no zone suffix) so SQL `date(occurred_at)` groups by
  the user's calendar day; range queries must compare via `LocalDateTimeConverter().toSql(...)`.
  Sync timestamps (`createdAt`/`updatedAt`/`deletedAt`) stay drift-managed UTC.
- **Web smoke gate is a runtime probe, not a browser unit test** (recorded in DESIGN.md deviation
  log): `flutter test --platform chrome` wedges locally (`dp-0ot`) and its CI harness can't serve
  assets. Gate: `flutter run -d chrome --dart-define=DB_SMOKE=true` → `DB_SMOKE OK`.
- **drift + drift_dev pinned to exactly 2.34.0, bump only in lockstep** — drift_dev 2.34.0's
  schema tool breaks vs drift 2.34.2; drift_dev ≥2.34.1+1 (analyzer ^13) conflicts with
  riverpod_generator 4.x (analyzer ^12)
- **Riverpod 3.x runtime / generator 4.x**; riverpod_lint + custom_lint dropped until analyzer
  versions align (`dp-9w0`)
- Streaks/gaps computed in Dart over the SQL daily-count series (correct for `dateOnly` events)

## Deferred work

- `dp-mih` GitHub Pages COI service worker so drift gets OPFS (today the Pages deploy silently
  falls back to IndexedDB; must land by Phase 6, ideally with Phase 2)
- `dp-9w0` re-add riverpod_lint + custom_lint when analyzer versions align
- `dp-0ot` (in_progress, workaround shipped) local `flutter test --platform chrome` wedge —
  kept open only as a pointer if flutter tooling improves

## Pointers for next phase

- **Phase 2 (Logging UX, epic `dp-0ms`) is fully planned in `designs/PHASE_2_PLAN.md`** —
  read that first; child issues `dp-0ms.1`–`dp-0ms.6` are pre-created with dependencies
- Everything UI needs is behind `bowelMovementRepositoryProvider`
  (`lib/data/providers.dart`) — `create`/`update`/`softDelete`/`watchRange` + aggregations;
  never open the DB directly
- Undo-after-delete works with the existing API: keep the pre-delete entity and call
  `update(entity)` — `.replace()` writes all columns, clearing `deletedAt`
- `BristolTypeSelector` (`lib/ui/widgets/bristol_type_selector.dart`) is the Huckleberry-style
  icon picker, ready to drop into the add/edit sheet
- Widget tests holding live drift `watch()` streams MUST end with
  `await tester.pumpWidget(const SizedBox.shrink()); await tester.pump(const Duration(milliseconds: 1));`
  or flutter_tester wedges ("A Timer is still pending")
- Before touching any drift code, read `.claude/skills/drift-flutter/SKILL.md`
