# Phase 3 Plan — Metrics & Reports (epic `dp-85t`)

> Handbook for the orchestrating agent (Opus) running implementation subagents (Sonnet).
> Written 2026-07-17 at Phase 2 closeout. Child issues `dp-85t.1`–`dp-85t.6` are already
> created in beads with dependencies wired — `bd ready` gives the current wave.

## Mission

DESIGN.md Phase 3: Reports screen with **Day / Week / Month / Year / Custom** range selector.
Per range: stat tiles (total, avg/day, most common type, % in healthy range 3–5, longest gap),
stacked bar chart of counts by type over time (day bars for week/month, month bars for year),
type-distribution donut, and a List view with filters. All computations via the Phase 1
aggregation queries — **the aggregation layer is already built and fully tested; this phase is
UI/consumption work.** **Exit criteria: every range renders correct numbers against fixture
data, verified by tests.**

Locked UX decisions (user, 2026-07-17 — do not relitigate):
- **Range model: calendar periods with prev/next stepping.** Day = a calendar day, Week =
  Mon–Sun (use existing `weekStart()`), Month/Year = calendar month/year. ◀ ▶ arrows step the
  anchor; a label shows the period (e.g. "July 2026"). Custom opens `showDateRangePicker`.
  (Calendar years must match the spreadsheet's year totals — Phase 4 verifies against them.)
- **Reports layout: Summary | List tabs** under the range selector. Summary = stat tiles +
  stacked bar + donut; List = filterable entries for the same range.
- **`dp-mih` (COI service worker → OPFS on GitHub Pages) ships alongside this phase** as an
  independent parallel task. It is its own bd issue, not an epic child — don't duplicate it.

## Orchestrator ground rules

1. **Session start:** read `designs/DESIGN.md`, `designs/PHASE_2_HANDOFF.md`, and this file;
   `git pull --rebase`; work on the **`phase_3` branch** (exists, pointed at main).
2. Create `designs/PHASE_3_CURRENT_STATUS.md` from `designs/templates/PHASE_STATUS_TEMPLATE.md`
   at phase start; update it after every closed issue and before any long/risky operation.
3. Beads is the sole tracker: `bd update <id> --claim` before work, `bd close <id>` when its
   acceptance criteria are verified. **Commit + push after every closed issue** — a cutoff must
   never strand more than one issue's work.
4. Phase ships as a **PR from `phase_3` to main** (user rule: unproven work never lands on main
   directly; the verification gate is LOCAL runs, CI is a safety net).
5. Verification gate after every wave (run it yourself, don't trust subagent claims):
   `flutter analyze` (clean) and `flutter test --timeout 30s` (all green, detached → file → poll).
6. **Every Sonnet subagent prompt MUST include:**
   - The issue's `bd show <id>` content (scope + acceptance criteria)
   - Pointer to CLAUDE.md "Test-run rules" — always `--timeout 30s`; NEVER
     `flutter test --platform chrome`; kill stalled runs
   - Pointer to `.claude/skills/drift-flutter/SKILL.md` before touching any drift code
     (relevant to `.1`'s stream-watching providers and any test seeding)
   - The drift widget-test teardown rule: any widget test whose tree held live drift `watch()`
     streams must end with
     `await tester.pumpWidget(const SizedBox.shrink()); await tester.pump(const Duration(milliseconds: 1));`
     or flutter_tester wedges with "A Timer is still pending"
   - The exact files it owns (keep parallel agents' file sets disjoint)
   - Style: this repo uses explicit types (see `analysis_options.yaml` + existing code)

## Existing building blocks (reuse, do not reinvent)

| What | Where |
|---|---|
| Aggregations (all inclusive calendar-day ranges) | `lib/domain/bowel_movement_repository.dart`: `dailyTypeCounts(firstDay, lastDay)`, `typeDistribution(...)` → `Map<BristolType,int>`, `totalCount(...)`, `averagePerDay(...)`, `longestGapDays(...)`, `longestStreakDays(...)`, `currentStreakDays(today)` — via `bowelMovementRepositoryProvider` in `lib/data/providers.dart`; UI never opens the DB directly |
| Pure rollup/streak helpers | `lib/domain/aggregates.dart`: `weekStart()` (ISO Monday), `rollUpByWeek`, `rollUpByMonth`, `DailyTypeCount`/`PeriodTypeCount` value types, streak/gap functions — all unit-tested |
| Live entries stream | `watchRange(from, to)` — **half-open `[from, to)`**, newest first |
| Enums/labels for legends & filters | `BristolType` (`.number`, `.label`, `.fromNumber`) in `lib/domain/bristol_type.dart`; `BristolIcon` in `lib/ui/widgets/bristol_icon.dart` |
| Theme tokens | `package:dejapoo/ui/theme/theme.dart` barrel — `Spacing`, `Radii`, `IconSizes.statTileIcon` (already anticipates stat tiles), color schemes |
| Stat-tile visual precedent | `TodayHeader` in `lib/features/home/widgets/today_header.dart` |
| Entry tile display pattern | `lib/features/home/widgets/timeline_entry_tile.dart` (List tab adapts, doesn't import-and-hack) |
| Provider pattern to mirror | `lib/features/home/providers/timeline_providers.dart` (codegen `@riverpod`; run build_runner after adding providers) |
| Test DB recipe | `AppDatabase(NativeDatabase.memory())` + `ProviderScope(overrides: [appDatabaseProvider, bowelMovementRepositoryProvider])` — see `test/features/home/home_screen_test.dart` |
| Fixtures | `lib/data/fixtures/fixture_generator.dart` (seeded, deterministic) |

**Datetime traps** (Phase 1, see `PHASE_1_HANDOFF.md` + bd memories):
- `occurredAt` is **local wall time** by design — never `.toUtc()` it in UI code; group by local
  calendar day.
- Aggregation methods take **inclusive** first/last calendar days; `watchRange` is **half-open
  instants** `[from, to)`. When one `ReportRange` feeds both (e.g. providers invalidating on the
  stream), convert deliberately: `to = lastDay + 1 day at 00:00`. Off-by-one here is the most
  likely correctness bug of the phase.

## Issues & wave map

Waves run in dependency order; parallelize within a wave only because file sets are disjoint.
Re-derive the actual frontier with `bd ready` — do not blindly trust this table if scope shifts.

| Wave | Issues (parallel ∥) | Owned files (keep disjoint) |
|---|---|---|
| 1 | `dp-85t.1` (range model + providers) ∥ `dp-85t.2` (fl_chart + palette + chart widgets) ∥ `dp-mih` (COI worker) | .1: `lib/domain/report_range.dart`, `lib/features/reports/providers/*`, their tests · .2: `pubspec.yaml`, `lib/ui/theme/*` (palette additions), `lib/features/reports/widgets/charts/*`, their tests · dp-mih: `web/*` + Pages deploy workflow only |
| 2 | `dp-85t.3` (reports screen assembly: selector + tabs + Summary) | `lib/features/reports/reports_screen.dart`, `lib/features/reports/widgets/` (selector, stat tiles), widget tests |
| 3 | `dp-85t.4` (List tab with filters) | new list-tab widget file(s) + tests only |
| 4 | `dp-85t.5` (fixture-verified correctness gate) | `test/features/reports/reports_correctness_test.dart` |
| 5 | `dp-85t.6` (phase completion) | docs, README, handoff — run by the orchestrator itself, not a subagent |

Issue details live in beads (`bd show dp-85t.N`) — scope and acceptance criteria are recorded
there.

## Design notes for implementers

- **Chart bucketing by range kind:** Week/Month → day bars (`dailyTypeCounts` directly);
  Year → month bars (`rollUpByMonth`); Day → stat tiles + donut only, no bar chart;
  Custom → day bars when span ≤ 62 days, else month bars.
- **Chart widgets stay presentational:** they take plain pre-bucketed data (no providers, no DB)
  so `dp-85t.2` can land in wave 1 and be tested with static fixtures.
- **Bristol palette:** 7 distinguishable colors (light + dark schemes) added to theme tokens —
  the single source for bar segments, donut sections, legend chips, and filter chips.
- **fl_chart dependency:** before adding, re-check the analyzer/version-pin trap
  (drift + drift_dev pinned 2.34.0 exactly; riverpod_generator 4.x). fl_chart has no analyzer
  dependency so it should resolve — but verify `flutter pub get` still solves.
- **Provider refresh:** Reports must update live when an entry is logged/edited/deleted while
  the screen is open. Simplest: aggregation providers `ref.watch` the range's `watchRange`
  stream and recompute on emission (mind the inclusive-vs-half-open conversion above).
- **`dateOnly` entries** count toward all stats and appear in the List tab as "all day" (no
  time), consistent with the home timeline.
- **Semantics now, not in Phase 6:** labels on the range selector controls, stat tiles, chart
  legend entries, and filter chips.
- **No new deps beyond fl_chart.** Date formatting via `MaterialLocalizations`, as in Phase 2.

## Final verification gate (dp-85t.6, orchestrator-run)

1. `flutter analyze` clean; `flutter test --timeout 30s` all green
2. Web: `flutter run -d chrome --dart-define=DB_SMOKE=true` → `DB_SMOKE OK` still prints, then
   manual Reports spot-check in the running app: switch through every range kind, step prev/next,
   set a Custom range, then **log an entry and confirm the open Reports screen updates live**;
   kill the process stack per skill cleanup rules
3. Android: `flutter run -d android` → Reports renders and updates after logging an entry
4. iOS: project still compiles (no Mac available — same gate as Phases 0–2)
5. `flutter build web --release --base-href /DejaPoo/` exit 0 (PowerShell, not Git Bash)
6. If `dp-mih` landed: deployed Pages build selects **OPFS**, not the IndexedDB fallback
7. **README.md updated** (required exit step per CLAUDE.md), `PHASE_3_HANDOFF.md` written,
   status doc deleted, `bd close` children + epic, PR opened from `phase_3`

## Deferred/adjacent (do not scope-creep into this phase)

- Phase 4 import (`dp-l8w`) — runs after this phase (it verifies year totals against the
  calendar-year Reports numbers this phase produces)
- Phase 5 sync/export (`dp-l4h`), Phase 6 polish/a11y pass (`dp-bjs`)
- `dp-9w0` riverpod_lint/custom_lint re-add — separate, blocked on analyzer alignment
- Timeline pagination, insights/trends views, per-time-of-day charts — file bd issues if the
  temptation arises; do not build
