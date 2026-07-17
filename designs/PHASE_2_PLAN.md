# Phase 2 Plan — Logging UX (epic `dp-0ms`)

> Handbook for the orchestrating agent (Opus) running implementation subagents (Sonnet).
> Written 2026-07-16 at Phase 1 closeout. Child issues `dp-0ms.1`–`dp-0ms.6` are already
> created in beads with dependencies wired — `bd ready` gives the current wave.

## Mission

DESIGN.md Phase 2: the MVP logging loop. Home screen with today-at-a-glance + reverse-chron
entry timeline; Huckleberry-style add/edit bottom sheet; swipe to edit/delete; FAB long-press
quick-log. **Exit criteria: an entry can be logged in under 5 seconds; full CRUD works on all
platforms.**

Locked UX decisions (user, 2026-07-16 — do not relitigate):
- **Quick-log:** FAB long-press opens a compact popup of the 7 Bristol type icons; tapping one
  instantly saves an entry at `occurredAt = now` (no sheet), with a confirmation SnackBar.
- **Delete:** swipe deletes immediately (soft-delete) + Undo SnackBar. No confirmation dialog.
  Undo = keep the pre-delete entity in memory, call `repository.update(entity)` — its
  `.replace()` writes all columns, clearing `deletedAt`.

## Orchestrator ground rules

1. **Session start:** read `designs/DESIGN.md`, `designs/PHASE_1_HANDOFF.md`, and this file;
   `git pull --rebase`; work on the **`phase_2` branch** (exists, pointed at main).
2. Create `designs/PHASE_2_CURRENT_STATUS.md` from `designs/templates/PHASE_STATUS_TEMPLATE.md`
   at phase start; update it after every closed issue and before any long/risky operation.
3. Beads is the sole tracker: `bd update <id> --claim` before work, `bd close <id>` when its
   acceptance criteria are verified. **Commit + push after every closed issue** — a cutoff must
   never strand more than one issue's work.
4. Phase ships as a **PR from `phase_2` to main** (user rule: unproven work never lands on main
   directly; the verification gate is LOCAL runs, CI is a safety net).
5. Verification gate after every wave (run it yourself, don't trust subagent claims):
   `flutter analyze` (clean) and `flutter test --timeout 30s` (all green, detached → file → poll).
6. **Every Sonnet subagent prompt MUST include:**
   - The issue's `bd show <id>` content (scope + acceptance criteria)
   - Pointer to CLAUDE.md "Test-run rules" — always `--timeout 30s`; NEVER
     `flutter test --platform chrome`; kill stalled runs
   - Pointer to `.claude/skills/drift-flutter/SKILL.md` before touching any drift code
   - The drift widget-test teardown rule: any widget test whose tree held live drift `watch()`
     streams must end with
     `await tester.pumpWidget(const SizedBox.shrink()); await tester.pump(const Duration(milliseconds: 1));`
     or flutter_tester wedges with "A Timer is still pending"
   - The exact files it owns (keep parallel agents' file sets disjoint)
   - Style: this repo uses explicit types (see `analysis_options.yaml` + existing code)

## Existing building blocks (reuse, do not reinvent)

| What | Where |
|---|---|
| Repository (CRUD + soft delete + aggregations) | `lib/domain/bowel_movement_repository.dart` (interface), `bowelMovementRepositoryProvider` in `lib/data/providers.dart` — UI never opens the DB directly |
| Live queries | `watchRange(from, to)` (newest first, `[from, to)`); `dailyTypeCounts(firstDay, lastDay)` for per-day/type counts |
| Entity | `lib/domain/bowel_movement.dart` (`copyWith` available); enums `BristolType` (1–7, `.number`, `.fromNumber`), `StoolSize`, `StoolColor` in `lib/domain/` |
| Icon picker | `lib/ui/widgets/bristol_type_selector.dart` — horizontally scrolling tappable circles, exactly the sheet's primary selector |
| Icons | `BristolIcon` in `lib/ui/widgets/bristol_icon.dart` |
| Theme tokens | `package:dejapoo/ui/theme/theme.dart` barrel (`Spacing`, `IconSizes`, color schemes) |
| Test DB | `AppDatabase(NativeDatabase.memory())` — see existing `test/data/*` for the pattern |
| Fixtures | `lib/data/fixtures/fixture_generator.dart` (seeded, deterministic) for realistic test/demo data |

Datetime trap (from Phase 1, see `PHASE_1_HANDOFF.md`): `occurredAt` is **local wall time** by
design. Group timeline entries by local calendar day; never call `.toUtc()` on it in UI code.

## Issues & wave map

Waves run in dependency order; parallelize within a wave only because file sets are disjoint.
Re-derive the actual frontier with `bd ready` — do not blindly trust this table if scope shifts.

| Wave | Issues (parallel ∥) | Owned files (keep disjoint) |
|---|---|---|
| 1 | `dp-0ms.1` (providers) ∥ `dp-0ms.3` (add/edit sheet) | .1: `lib/features/home/providers*`, `test/features/home/providers_test.dart` · .3: `lib/features/home/widgets/entry_sheet*` (new files only), `test/features/home/entry_sheet_test.dart` |
| 2 | `dp-0ms.2` (timeline UI) | `lib/features/home/home_screen.dart`, `lib/features/home/widgets/` (tiles, header, empty state), widget tests |
| 3 | `dp-0ms.4` (swipe actions) ∥ `dp-0ms.5` (FAB + quick-log) | .4: entry tile widget + its tests · .5: `home_screen.dart` FAB + new quick-log popup widget + tests. **Conflict note:** if .4 and .5 both need `home_screen.dart` edits, run .4 first or serialize the touchpoint |
| 4 | `dp-0ms.6` (phase completion) | docs, README, handoff — run by the orchestrator itself, not a subagent |

Issue details live in beads (`bd show dp-0ms.N`) — scope, acceptance criteria, and the locked
UX decisions are all recorded there.

## Design notes for implementers

- **Bottom sheet:** `showModalBottomSheet(isScrollControlled: true, useSafeArea: true)` with a
  `DraggableScrollableSheet`-style scrollable form; one stateful form widget parameterized by
  optional `BowelMovement existing` (null = create, non-null = edit/prefill).
- **Sheet save path:** create → `repository.create(...)`; edit → `existing.copyWith(...)` →
  `repository.update(...)`. Save button disabled until a Bristol type is selected.
- **Timeline stream:** `watchRange(now - 30 days, tomorrow)` is fine for MVP; note a follow-up
  bd issue for pagination/load-more instead of building it now.
- **Date formatting:** prefer `MaterialLocalizations` (`formatTimeOfDay`, `formatMediumDate`);
  add `intl` only if genuinely needed. No other new dependencies are expected this phase
  (fl_chart is Phase 3). If a dep must be added, check the drift/riverpod analyzer pin trap in
  `PHASE_1_HANDOFF.md` first.
- **`dateOnly` entries** (imported history, Phase 4) show as "all day" — no time; excluded from
  time-of-day UI but counted in daily stats.
- **Semantics:** give the type picker circles semantic labels now (Phase 6 does the full a11y
  pass, but retrofitting the core picker later is worse).

## Final verification gate (dp-0ms.6, orchestrator-run)

1. `flutter analyze` clean; `flutter test --timeout 30s` all green
2. Web: `flutter run -d chrome --dart-define=DB_SMOKE=true` → `DB_SMOKE OK` still prints, then
   manual CRUD spot-check in the running app; kill the process stack per skill cleanup rules
3. Android: `flutter run -d android` → create/edit/delete/quick-log an entry
4. iOS: project still compiles (no Mac available — same gate as Phases 0/1)
5. <5s logging: time the quick-log path (FAB long-press → tap type → saved)
6. `flutter build web --release --base-href /DejaPoo/` exit 0 (PowerShell, not Git Bash)
7. **README.md updated** (required exit step per CLAUDE.md), `PHASE_2_HANDOFF.md` written,
   status doc deleted, `bd close` children + epic, PR opened from `phase_2`

## Deferred/adjacent (do not scope-creep into this phase)

- `dp-mih` — COI service worker for GitHub Pages OPFS; ideally lands alongside Phase 2 but is
  its own issue, not part of this epic
- Reports/charts (Phase 3), import (Phase 4), notifications/a11y pass (Phase 6)
