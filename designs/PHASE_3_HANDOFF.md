# Phase 3 Handoff

**Phase:** 3 — Metrics & Reports (bd epic: `dp-85t`, closed 2026-07-17)

## Phase summary

Delivered the Reports screen with a Day/Week/Month/Year/Custom range selector, Summary tab
(stat tiles, stacked bar chart, type-distribution donut), and List tab (multi-select Bristol
type filter chips). All stats update live via Riverpod providers watching drift streams. Phase
exit criterion verified: 12 fixture-backed correctness tests cover every range kind and boundary
case (month-straddling weeks, 23:59 local-time events, dateOnly entries, tie-breaking, empty
ranges, healthy-percentage edge cases). 139 total tests green, analyze clean.

## Exit criteria — evidence

- "every range renders correct numbers against fixture data verified by tests" — PASS:
  `test/features/reports/reports_correctness_test.dart` (12 tests) covers Day, Week, Month,
  Year, Custom with exact expected numbers + boundary cases; `flutter test --timeout 30s` →
  139/139 green
- `flutter analyze` — PASS: no issues
- `flutter build web --release --base-href /DejaPoo/` — PASS: exit 0
- `flutter run -d chrome --dart-define=DB_SMOKE=true` — PASS: DB_SMOKE OK printed
- README.md updated to reflect this phase — PASS: Phase 3 status → ✅ Done, Reports & analytics
  feature listed

## What changed

- `lib/domain/report_range.dart` — ReportRange model (Day/Week/Month/Year/Custom with
  prev/next stepping)
- `lib/features/reports/providers/` — report_providers.dart (Riverpod providers for range,
  entries stream, stats, distribution, daily counts), report_stats.dart (ReportStats value class)
- `lib/features/reports/reports_screen.dart` — assembled screen with range selector, Summary/List
  tabs, bar chart bucketing logic
- `lib/features/reports/widgets/` — range_selector.dart, stat_tiles.dart, reports_list_tab.dart,
  charts/stacked_type_bar_chart.dart, charts/type_donut_chart.dart
- `lib/ui/theme/bristol_palette.dart` — 7-color Bristol palette (light + dark), exported via
  theme barrel
- `pubspec.yaml` — fl_chart dependency added
- Tests: report_range_test.dart (32), report_providers_test.dart (9),
  reports_screen_test.dart (6), reports_list_tab_test.dart (8),
  stacked_type_bar_chart_test.dart (3), type_donut_chart_test.dart (2),
  reports_correctness_test.dart (12) — subtotal 72 new tests; 139 total

## How to verify

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test --timeout 30s
flutter build web --release --base-href /DejaPoo/
flutter run -d chrome --dart-define=DB_SMOKE=true   # expect DB_SMOKE OK
```

## Decisions & deviations from DESIGN.md

- Bar chart bucketing: Week/Month → day bars, Year → month bars, Custom → day bars if span ≤ 62
  days else month bars. No bar chart for Day range (stat tiles + donut only).
- Most-common-type ties resolved by lowest Bristol type number (SQL ORDER BY bristol_type →
  insertion-order iteration in the provider loop).
- `dp-mih` (COI service worker for OPFS on GitHub Pages) did not ship with this phase — it is
  an independent parallel issue, still open.

## Deferred work

- `dp-mih` — COI service worker for OPFS on GitHub Pages (independent, not blocked by Phase 3)
- `dp-9w0` — riverpod_lint/custom_lint re-add (blocked on analyzer version alignment)

## Pointers for next phase

- Phase 4 (Historical import `dp-l8w`) verifies year totals against the calendar-year Reports
  numbers this phase produces — use `ReportRange.year(anchor:)` and `reportStatsProvider` to
  cross-check imported data.
- `repo.insertAll(List<BowelMovement>)` is the bulk-insert path for imported data.
- The provider pattern in `lib/features/reports/providers/` is the model for any new feature
  providers: `@riverpod` codegen, watch the repo + range, run `build_runner` after adding.
- `occurredAt` is local wall time — never `.toUtc()` in UI code. Aggregation methods take
  inclusive calendar days; `watchRange` is half-open `[from, to)`.
- fl_chart resolved with the drift 2.34.0 pin (no analyzer dependency conflict).
