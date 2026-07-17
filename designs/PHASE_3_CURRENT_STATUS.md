# Phase 3 Current Status

> Snapshot, not a log. Tasks tracked in beads; reference bd ids.

**Phase:** 3 — Metrics & Reports (bd epic: `dp-85t`)
**Last updated:** 2026-07-17 17:00

## Done (with verification evidence)
- (none yet — phase just started)

## In progress
- `dp-85t.1` Range model + reports providers — Wave 1, subagent dispatched
- `dp-85t.2` fl_chart + Bristol palette + chart widgets — Wave 1, subagent dispatched

## Next steps
1. Verify Wave 1 subagent outputs: `flutter analyze` clean, `flutter test --timeout 30s` green
2. Run `dart run build_runner build --delete-conflicting-outputs` after providers land
3. Start Wave 2: `dp-85t.3` Reports screen assembly (range selector + tabs + Summary tab)
4. Wave 3: `dp-85t.4` List tab with type filters
5. Wave 4: `dp-85t.5` Fixture-verified correctness gate
6. Wave 5: `dp-85t.6` Phase completion (orchestrator-run)

## Known issues & gotchas
- drift pinned at 2.34.0 exactly; fl_chart has no analyzer dep so should resolve safely
- `occurredAt` is local wall time — never `.toUtc()` in UI; group by local calendar day
- Aggregation methods take inclusive first/last days; `watchRange` is half-open `[from, to)`
- Widget tests with drift streams must end with `pumpWidget(SizedBox.shrink()) + pump(1ms)`

## Decisions made this phase
- 2026-07-17 — Phase 3 orchestration plan committed; child issues dp-85t.1–.6 pre-wired in beads
