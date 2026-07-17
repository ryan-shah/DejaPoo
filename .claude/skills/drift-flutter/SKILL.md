---
name: drift-flutter
description: Use BEFORE adding or modifying Drift (SQLite) code in this Flutter project — new tables/columns/migrations, datetime fields, repositories, aggregation SQL, web (WASM) support, drift testing, or bumping drift/sqlite3/riverpod versions. Encodes hard-won rules from Phase 1 (2026-07-16); skipping this skill risks re-learning multi-hour failures (UTC datetime shifts, version deadlocks, wedged chrome test runs).
---

# Drift in DejaPoo — the rules and why they exist

Ground truth lives in the repo; this skill tells you where to look and what NOT to redo.

## 1. Version pinning — drift and drift_dev move in lockstep

- `drift: 2.34.0` and `drift_dev: 2.34.0` are pinned **exactly** in pubspec.yaml. Bump them
  **together only**. Learned: drift_dev 2.34.0's schema tool crashes against drift 2.34.2
  (drift3_preview API skew between patch releases), and drift_dev ≥2.34.1+1 requires
  analyzer ^13 while riverpod_generator 4.x requires analyzer ^12 — the solver deadlocks.
- The Riverpod stack is flutter_riverpod 3.x + riverpod_annotation 4.x + riverpod_generator
  4.x specifically for analyzer compatibility with drift_dev. `riverpod_lint`/`custom_lint`
  were dropped until their analyzer constraints catch up (`dp-9w0`).
- After ANY drift/sqlite3 bump: `dart run tool/setup_web.dart` (see §3), then
  `dart run drift_dev schema dump lib/data/db/app_database.dart drift_schemas/`.

## 2. Datetime storage — the UTC-normalization trap

- build.yaml sets `store_date_time_values_as_text: true`, **but drift text mode normalizes
  DateTimes to UTC on write** — it does NOT keep local wall time. A 23:59 event lands on the
  next UTC calendar day and SQL `date()` grouping silently reports the wrong day. This
  shipped as a real bug and was caught only by hand-computed boundary tests.
- Therefore `occurredAt` is a **TEXT column with `LocalDateTimeConverter`**
  (`lib/data/db/bowel_movements_table.dart`) storing local wall-time ISO with no zone
  suffix, so `date(occurred_at)` groups by the user's calendar day. Any future
  calendar-semantic datetime column must use the same converter.
- Sync/audit timestamps (`createdAt`/`updatedAt`/`deletedAt`) stay drift-managed
  (UTC text) — instants, not calendar days.
- Range queries against converter columns compare **strings**:
  `t.occurredAt.isBiggerOrEqualValue(const LocalDateTimeConverter().toSql(from))`.

## 3. Web (WASM) support — never hand-download artifacts

- `dart run tool/setup_web.dart` is the ONLY way to produce `web/sqlite3.wasm` and
  `web/drift_worker.js`: it pins the wasm to the pubspec.lock-resolved sqlite3 version and
  compiles the worker from `web/drift_worker.dart` with the project's own drift. Learned: a
  hand-downloaded worker silently skewed (drift-2.34.2 worker vs pinned drift 2.34.0).
- `AppDatabase.open` logs drift's chosen storage via `onResult`. Without cross-origin
  isolation drift falls back to IndexedDB — currently true everywhere; the COI service
  worker for GitHub Pages is `dp-mih`. Trap (from BinderManager): if the app ever boots
  pre-isolation, drift creates the DB in IndexedDB and keeps it forever.
- Reference implementation for web patterns: github.com/ryan-shah/BinderManager
  (`tool/setup_web.dart`, `web/index.html` COI registration + one-shot reload).

## 4. Testing drift code

- Unit tests: inject `AppDatabase(NativeDatabase.memory())`; repository takes an injectable
  `clock` for deterministic timestamps. See `test/data/repository_test.dart`.
- Aggregation tests MUST include hand-computed boundary cases: events at 00:00 and 23:59:59
  on range edges, `dateOnly` events, soft-deleted exclusion. Boundary tests are what caught
  the UTC bug. See `test/data/aggregation_test.dart`.
- **NEVER `flutter test --platform chrome`** (`dp-0ot`): wedges nondeterministically on this
  Windows machine even for `expect(1+1, 2)` (frontend_server freezes ~28-31 CPUsec at
  "loading"), and on CI the browser harness serves no assets, so wasm loads hang to timeout.
  Two independent failure modes; do not retry this pipeline.
- The web gate is the **runtime probe**: `flutter run -d chrome --dart-define=DB_SMOKE=true`
  → expect `DB_SMOKE OK` on the console (`lib/data/db/db_smoke_probe.dart`; debug-only,
  throwaway DB name). Extend the probe when the schema grows.
- Always `flutter test --timeout 30s`; full test-run discipline (wedge detection, orphan
  cleanup, detached runs with file-redirected output) is in CLAUDE.md "Test-run rules".
- Widget tests holding live drift `watch()` streams (Phase 2+): end them with
  `await tester.pumpWidget(const SizedBox.shrink()); await tester.pump(const
  Duration(milliseconds: 1));` or "A Timer is still pending" wedges flutter_tester.

## 5. Schema & repository conventions

- Tables bind to domain entities via `@UseRowClass(<Entity>, generateInsertable: true)` —
  no duplicate mapping layer; inserts use `entity.toInsertable()`.
- `bristolType` persists as its chart number 1-7 (`BristolTypeConverter`), NOT enum index;
  other enums use `intEnum` (never reorder their values).
- Soft deletes everywhere: reads filter `deleted_at IS NULL`; delete = set `deletedAt` +
  bump `updatedAt` (sync tombstones, Phase 5).
- Aggregations: SQL (`customSelect`) for grouping/counting; Dart over the daily series for
  streaks/gaps (`lib/domain/aggregates.dart`). Weekly/monthly = rollups of daily counts.
- Migrations: bump `schemaVersion`, add a `MigrationStrategy` step, and re-dump the schema
  JSON (`drift_schemas/`) in the same change.
