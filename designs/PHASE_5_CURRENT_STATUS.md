# Phase 5 Current Status

**Phase:** 5 — Google Drive Sync & Export (bd epic: `dp-l4h`)
**Last updated:** 2026-07-18 01:00

## Done (with verification evidence)
- `dp-l4h.1` Sync model + LWW merge engine — 22 tests pass, commutative merge verified
- `dp-l4h.2` Repo sync surface + sync_state table — schema v1→v2 migration, 12 tests pass
- `dp-l4h.3` Export generators + round-trip test — 16 tests pass, XLSX/CSV round-trip confirmed
- Wave 1 integrated: `flutter analyze` clean, 259/259 tests pass (commit `15eaf1c`, pushed)
- `dp-l4h.4` Google sign-in + auth provider + Settings account section + OAuth docs — `flutter analyze` clean, `flutter pub get` resolves (drift 2.34.0 preserved), builds web+android
- `dp-l4h.5` DriveSnapshotStore interface + real impl + in-memory fake — 13 tests pass
- Wave 2 integrated: `flutter analyze` clean, 272/272 tests pass

## Next steps
1. Commit + push Wave 2
2. Launch Wave 3: `dp-l4h.6` (SyncService + triggers + status + Sync now UI) + `dp-l4h.7` (Export UI)

## Known issues & gotchas
- drift/drift_dev pinned at 2.34.0 — never bump
- `extension_google_sign_in_as_googleapis_auth` bumped to `^3.0.0` (2.x incompatible with google_sign_in 7.x)
- googleapis Drive v3 `File` class has no `etag` field — DriveSnapshotStoreImpl uses `version` (monotonically increasing) as the lost-update guard
- `http` package added as explicit dependency (was transitive, needed for `depend_on_referenced_packages` lint)
- `dp-y82` filed for iOS OAuth verification (can't verify on Windows)

## Decisions made this phase
- 2026-07-17 — Branch is `phase_5` off `main`; merge via PR after local verification
- 2026-07-17 — MergeEngine tie-breaking uses canonical JSON comparison for deterministic resolution
- 2026-07-18 — Drive v3 `version` field used instead of nonexistent `etag` for conflict detection
- 2026-07-18 — `extension_google_sign_in_as_googleapis_auth ^3.0.0` (not ^2.0.12) for google_sign_in 7.x compat
