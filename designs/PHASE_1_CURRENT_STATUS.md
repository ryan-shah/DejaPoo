# Phase 1 Current Status

> This is a **snapshot, not a log** — keep it under ~100 lines and overwrite stale content.
> Tasks are tracked in beads, not here; reference bd ids.

**Phase:** 1 — Data layer (bd epic: `dp-2ri`)
**Last updated:** 2026-07-16

## Done (with verification evidence)
- Epic expanded into `dp-2ri.1`–`dp-2ri.7` with dependencies wired (`bd show dp-2ri`)
- `dp-2ri.1` Domain model — analyze clean, 2 tests pass; committed a9d983f
- `dp-2ri.2` Drift database — build_runner clean, analyze clean, tests pass,
  `flutter build web --release` exits 0 with sqlite3.wasm + drift_worker.js in build output;
  schema v1 baseline in `drift_schemas/drift_schema_v1.json`
- `dp-2ri.3` Repository layer — 12 tests green (CRUD, soft-delete, ranges, watch)
- `dp-2ri.4` Fixture generator — 7 tests green (determinism, Poisson rate, weights)
- `dp-2ri.5` Aggregations — 40 tests green total; hand-computed boundary cases caught the drift
  UTC-normalization bug (see gotchas), fixed with LocalDateTimeConverter

## In progress
- `dp-2ri.6` Web WASM smoke verification — DONE pending PR merge. Implemented as runtime
  DB_SMOKE probe (`lib/data/db/db_smoke_probe.dart`), NOT `flutter test --platform chrome`
  (unusable: wedges locally `dp-0ot`; CI harness can't serve assets). Evidence on branch
  `dp-2ri.6-web-wasm-smoke`: "DB_SMOKE OK: insert/read/aggregate/soft-delete round-tripped"
  observed on Chrome; analyze clean; 40 native tests green; `flutter build web --release`
  exits 0 with source-compiled drift_worker.js. Deviation recorded in DESIGN.md.

## Next steps
<!-- Executable by a fresh agent with ZERO conversation context. -->
1. Await user review/merge of the `dp-2ri.6-web-wasm-smoke` PR; after merge:
   `git checkout main && git pull --rebase`, `bd close dp-2ri.6`
2. Then `dp-2ri.7`: verify exit criteria with evidence, write `designs/PHASE_1_HANDOFF.md` from
   template, delete this file, `bd close dp-2ri.7 dp-2ri`, push.
   Full plan: `~/.claude/plans/lets-come-up-with-gentle-waffle.md`
3. Unmerged learnings from BinderManager tracked as `dp-mih` (COI service worker for GitHub
   Pages OPFS; probe confirmed IndexedDB fallback happens today).

## Known issues & gotchas
- `*.g.dart` is gitignored; CI runs build_runner before analyze/test, so generated code must never
  be committed
- **Drift text mode normalizes datetimes to UTC on write** — it does NOT keep local wall time.
  `occurredAt` therefore uses a custom `LocalDateTimeConverter` (TEXT column, local wall-time ISO,
  no zone suffix) in `lib/data/db/bowel_movements_table.dart` so `date(occurred_at)` groups by the
  user's calendar day. Sync timestamps (created/updated/deletedAt) stay drift-managed UTC text.
  Range queries must compare via `LocalDateTimeConverter().toSql(...)` strings.
- **drift and drift_dev are pinned to exactly 2.34.0** — drift_dev 2.34.0's schema tool breaks
  against drift 2.34.2, and drift_dev ≥2.34.1+1 needs analyzer ^13 which conflicts with
  riverpod_generator 4.x (analyzer ^12). Bump both together, in lockstep, when upgrading.
- `--base-href /DejaPoo/` gets mangled by Git Bash path conversion on Windows — run
  `flutter build web` from PowerShell (or `MSYS_NO_PATHCONV=1`)

## Decisions made this phase
- 2026-07-16 — Datetimes stored as ISO-8601 text (`store_date_time_values_as_text: true`);
  occurredAt in local wall time for SQL day-grouping, sync timestamps in UTC
- 2026-07-16 — Domain entity bound to Drift via `@UseRowClass` (no duplicate mapping layer)
- 2026-07-16 — Streaks/gaps computed in Dart over SQL daily-count series
- 2026-07-16 — Riverpod upgraded to 3.x runtime / generator 4.x (needed for drift_dev analyzer
  compat); riverpod_lint + custom_lint dropped until ecosystem aligns (`dp-9w0`)
