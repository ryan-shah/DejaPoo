# Phase 2 Current Status

> Snapshot, not a log. Tasks tracked in beads; reference bd ids.

**Phase:** 2 — Logging UX (bd epic: `dp-0ms`)
**Last updated:** 2026-07-17 09:00

## Done (with verification evidence)
- (none yet)

## In progress
- `dp-0ms.1` Home data providers — starting Wave 1
- `dp-0ms.3` Add/Edit entry bottom sheet — starting Wave 1

## Next steps
1. Implement `dp-0ms.1` providers in `lib/features/home/providers/` with unit tests
2. Implement `dp-0ms.3` entry sheet in `lib/features/home/widgets/entry_sheet.dart` with widget tests
3. Run `flutter analyze` + `flutter test --timeout 30s` after Wave 1
4. Wave 2: `dp-0ms.2` Timeline UI (depends on .1)
5. Wave 3: `dp-0ms.4` swipe actions + `dp-0ms.5` FAB quick-log
6. Wave 4: `dp-0ms.6` phase completion

## Known issues & gotchas
- occurredAt is local wall time; group by local calendar day, never `.toUtc()`
- drift widget tests must end with `pumpWidget(SizedBox.shrink())` + `pump(1ms)` to avoid wedge
- drift + drift_dev pinned at 2.34.0 exactly

## Decisions made this phase
- (none yet)
