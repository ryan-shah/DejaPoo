# Phase 5 Handoff

**Phase:** 5 — Google Drive Sync & Export (bd epic: `dp-l4h`, closed 2026-07-18)

## Phase summary
Phase 5 delivers Google Drive sync and data export. Users sign in with Google, authorize the
Drive scope, and sync their bowel movement data via a JSON snapshot in Drive's appDataFolder.
A last-write-wins merge engine handles concurrent edits across devices, with tombstones for
deletes. Export supports XLSX (year-based sheets matching the import layout) and CSV, delivered
via browser download on web or the native share sheet on mobile.

## Exit criteria — evidence
- Two devices converge after concurrent edits — PASS: `sync_service_test.dart` "two-device
  convergence" test passes (two in-memory DBs sharing one InMemoryDriveSnapshotStore; interleaved
  creates, edits, and deletes converge after A→B→A sync cycle); 282/282 tests pass
- Exported XLSX round-trips through the Phase 4 importer — PASS: `export_round_trip_test.dart`
  verifies export→import round-trip for both XLSX and CSV formats
- README.md updated to reflect this phase — PASS: Phase 5 marked Done, sync/export features
  listed, Google OAuth setup pointer added, googleapis stack entry added

## What changed
- `lib/data/auth/` — `google_auth_provider.dart`: Riverpod notifier managing Google sign-in
  (google_sign_in 7.x event-based API), Drive scope authorization, auth client provisioning
- `lib/data/sync/` — sync model (`sync_models.dart`), LWW merge engine (`merge_engine.dart`),
  Drive snapshot store interface + real impl + in-memory fake, snapshot exceptions,
  `sync_service.dart` (pull-merge-push orchestrator with single-flight guard and conflict retry),
  `sync_providers.dart` (Riverpod wiring with auto-sync trigger and debounced sync)
- `lib/data/export/` — `export_service.dart` (XLSX/CSV generation), `export_providers.dart`,
  conditional import pattern (`export_download.dart` / `_stub.dart` / `_web.dart`) for
  platform-specific file delivery
- `lib/features/settings/settings_screen.dart` — added _AccountSection (sign-in/out/authorize),
  _SyncSection (status, last sync time, retry, Sync now), _ExportSection (XLSX/CSV buttons)
- `lib/data/db/app_database.dart` — schema v1→v2: added `SyncStates` table
- `lib/domain/bowel_movement_repository.dart` — added `getAllIncludingDeleted()`, `applyRemote()`
- `designs/GOOGLE_OAUTH_SETUP.md` — OAuth setup docs for Android, Web, iOS
- `web/index.html` — google-signin-client_id meta tag placeholder
- `pubspec.yaml` — added google_sign_in, extension_google_sign_in_as_googleapis_auth, googleapis,
  googleapis_auth, share_plus, http

## How to verify
```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze                           # 0 issues
flutter test --timeout 30s                # 282 tests pass
flutter build web --release --base-href /DejaPoo/   # from PowerShell
```

## Decisions & deviations from DESIGN.md
- Drive v3 `File` class has no `etag` field — DriveSnapshotStoreImpl uses the `version` field
  (monotonically increasing string) as the lost-update guard instead
- `extension_google_sign_in_as_googleapis_auth ^3.0.0` required for google_sign_in 7.x compat
  (2.x incompatible)
- MergeEngine tie-breaking uses canonical JSON comparison for deterministic resolution when
  `updatedAt` is identical
- drift/drift_dev stays pinned at 2.34.0 (no bump in this phase)
- Auto-sync fires on driveAuthorized state; debounced sync (5s) available for local writes
  but not yet wired to the entry save flow (can be added in Phase 6)

## Deferred work
- `dp-y82` — iOS OAuth verification (can't verify on Windows dev machine)
- Wiring `scheduleDebouncedSync()` to entry create/edit/delete flows (Phase 6 polish)
- Real-account manual sync check (requires OAuth client IDs configured in Google Cloud Console)

## Pointers for next phase
- The Settings screen's ListView order is: Account → Sync → Import → Export → Demo (if DEMO_MODE)
- Export conditional import pattern (`export_download.dart` with `if (dart.library.js_interop)`)
  is the template for any future web-vs-mobile branching
- `InMemoryDriveSnapshotStore` is a full test fake with injectable failure modes — use it for
  any integration tests touching sync
- google_sign_in 7.x uses `authenticate()` + `authenticationEvents` stream, not the older
  `signIn()` method
