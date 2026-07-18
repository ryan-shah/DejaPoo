# Phase 5 Current Status

**Phase:** 5 — Google Drive Sync & Export (bd epic: `dp-l4h`)
**Last updated:** 2026-07-18

## Done (with verification evidence)
- `dp-l4h.1` Sync model + LWW merge engine — 22 tests pass
- `dp-l4h.2` Repo sync surface + sync_state table — schema v1→v2 migration, 12 tests pass
- `dp-l4h.3` Export generators + round-trip test — 16 tests pass
- Wave 1 integrated: 259/259 tests pass (commit `15eaf1c`, pushed)
- `dp-l4h.4` Google sign-in + auth provider + Settings account section + OAuth docs
- `dp-l4h.5` DriveSnapshotStore interface + real impl + in-memory fake — 13 tests pass
- Wave 2 integrated: 272/272 tests pass (commit `ce9d637`, pushed)
- `dp-l4h.6` SyncService + triggers + status + _SyncSection UI — 10 tests pass (incl. two-device convergence)
- `dp-l4h.7` Export UI: _ExportSection (XLSX/CSV), conditional import web download, share_plus mobile
- Wave 3 integrated: `flutter analyze` clean, 282/282 tests pass

## Next steps
1. Commit + push Wave 3
2. `dp-l4h.8` — E2E verification + closeout (README, handoff, close epic)

## Known issues & gotchas
- drift/drift_dev pinned at 2.34.0 — never bump
- googleapis Drive v3 `File` class has no `etag` — impl uses `version` field
- `dp-y82` filed for iOS OAuth verification (can't verify on Windows)

## Decisions made this phase
- 2026-07-17 — Branch is `phase_5` off `main`; merge via PR after local verification
- 2026-07-17 — MergeEngine tie-breaking uses canonical JSON comparison
- 2026-07-18 — Drive v3 `version` field used instead of nonexistent `etag`
- 2026-07-18 — `extension_google_sign_in_as_googleapis_auth ^3.0.0` for google_sign_in 7.x compat
