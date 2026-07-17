# Phase 4 Current Status

**Phase:** 4 — Historical Spreadsheet Import (bd epic: `dp-l8w`)
**Last updated:** 2026-07-17 00:15

## Done (with verification evidence)
- Branch `phase_4` created off main; plan committed (b1b3470)
- Baseline: 139 tests green, `flutter analyze` clean
- Epic children created: dp-l8w.1 through dp-l8w.8 with dependency chain
- Dependencies: A/B/C parallelizable → D+E (need A+B) → F (needs C+D+E) → G → H

## In progress
- `dp-l8w.1` A: Add import dependencies (excel, csv, file_picker) — Sonnet subagent running in isolated worktree
- `dp-l8w.2` B: Import models + deterministic-id event expander — Sonnet subagent running in isolated worktree
  - Creates `lib/data/import/import_models.dart` (DailyCounts, ImportIssue, SheetParseResult, ImportSummary)
  - Creates `lib/data/import/import_expander.dart` (deterministic IDs: `imp-<yyyy-MM-dd>-t<N>-<k>`)
  - Creates tests in `test/data/import/`
- `dp-l8w.3` C: Repo insertAllIfAbsent — Sonnet subagent running in isolated worktree
  - Adds `insertAllIfAbsent` to `lib/domain/bowel_movement_repository.dart`
  - Implements in `lib/data/repositories/drift_bowel_movement_repository.dart`
  - Chunked id probe (<=500/chunk), no deletedAt filter, InsertMode.insertOrIgnore
  - Tests: insert count, dup skip, soft-deleted not resurrected, >500 chunking

## Next steps
1. When A/B/C agents complete: merge their worktree changes into phase_4, resolve any conflicts, run full test suite
2. Close dp-l8w.1, dp-l8w.2, dp-l8w.3; commit + push
3. Launch D (dp-l8w.4, XLSX parser + fixture builder) and E (dp-l8w.5, CSV parser) in parallel
4. After D+E: F (dp-l8w.6, ImportService + Settings UI)
5. After F: G (dp-l8w.7, end-to-end + real-file gate)
6. After G: H (dp-l8w.8, wrap-up)

## Known issues & gotchas
- drift/drift_dev must stay pinned at exactly 2.34.0 — never bump
- Never `flutter test --platform chrome` — wedges; web gate is DB_SMOKE probe
- `occurredAt` uses LocalDateTimeConverter (local wall time, no zone suffix)
- Expanded events at noon local (day + 12h), matching FixtureGenerator convention
- Run `flutter build web` from PowerShell, not Git Bash (MSYS path mangling)
- After provider changes: `dart run build_runner build --delete-conflicting-outputs`

## Decisions made this phase
- 2026-07-17 — Using all settled design decisions from PHASE_4_PLAN.md without changes
- 2026-07-17 — Orchestrating via Opus with Sonnet subagents in isolated worktrees for parallelism
