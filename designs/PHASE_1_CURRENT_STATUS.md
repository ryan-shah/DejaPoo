# Phase 1 Current Status

> This is a **snapshot, not a log** — keep it under ~100 lines and overwrite stale content.
> Tasks are tracked in beads, not here; reference bd ids.

**Phase:** 1 — Data layer (bd epic: `dp-2ri`)
**Last updated:** 2026-07-16

## Done (with verification evidence)
- Epic expanded into `dp-2ri.1`–`dp-2ri.7` with dependencies wired (`bd show dp-2ri`)

## In progress
- `dp-2ri.1` Domain model — creating `lib/domain/` (BowelMovement entity, StoolSize/StoolColor
  enums, BristolType moved from `lib/ui/widgets/bristol_icon.dart` with re-export)

## Next steps
<!-- Executable by a fresh agent with ZERO conversation context. -->
1. Finish `dp-2ri.1`: `lib/domain/{bristol_type,stool_size,stool_color,bowel_movement,domain}.dart`;
   re-export BristolType from `lib/ui/widgets/bristol_icon.dart`; `flutter analyze && flutter test`;
   commit, push, `bd close dp-2ri.1`
2. `dp-2ri.2`: `flutter pub add drift drift_flutter uuid && flutter pub add --dev drift_dev`;
   build.yaml (`store_date_time_values_as_text: true`); table + AppDatabase in `lib/data/db/`;
   pinned `web/sqlite3.wasm` + `web/drift_worker.js`; schema dump to `drift_schemas/`
3. Then `dp-2ri.3` (repository) → `.4` (fixtures) → `.5` (aggregations) → `.6` (web smoke + CI)
   → `.7` (handoff). Full plan: `~/.claude/plans/lets-come-up-with-gentle-waffle.md`

## Known issues & gotchas
- `*.g.dart` is gitignored; CI runs build_runner before analyze/test, so generated code must never
  be committed
- `occurredAt` is persisted as **local wall time** ISO-8601 text (drift text mode) so SQL
  `date(occurred_at)` groups by the user's calendar day; created/updated/deletedAt stored UTC

## Decisions made this phase
- 2026-07-16 — Datetimes stored as ISO-8601 text (`store_date_time_values_as_text: true`);
  occurredAt in local wall time for SQL day-grouping, sync timestamps in UTC
- 2026-07-16 — Domain entity bound to Drift via `@UseRowClass` (no duplicate mapping layer)
- 2026-07-16 — Streaks/gaps computed in Dart over SQL daily-count series
