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

## In progress
- `dp-2ri.3` Repository layer — next up

## Next steps
<!-- Executable by a fresh agent with ZERO conversation context. -->
1. `dp-2ri.3`: `BowelMovementRepository` abstract class in `lib/domain/`; Drift impl in
   `lib/data/repositories/` (uuid v4 ids, injectable clock, soft-delete filter everywhere);
   riverpod providers in `lib/data/providers.dart`; CRUD tests in `test/data/repository_test.dart`
   with `AppDatabase(NativeDatabase.memory())`
2. Then `dp-2ri.4` (fixtures) → `.5` (aggregations) → `.6` (web smoke + CI) → `.7` (handoff).
   Full plan: `~/.claude/plans/lets-come-up-with-gentle-waffle.md`

## Known issues & gotchas
- `*.g.dart` is gitignored; CI runs build_runner before analyze/test, so generated code must never
  be committed
- `occurredAt` is persisted as **local wall time** ISO-8601 text (drift text mode) so SQL
  `date(occurred_at)` groups by the user's calendar day; created/updated/deletedAt stored UTC
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
