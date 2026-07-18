# Phase 5 Implementation Plan — Google Drive Sync & Export

**Audience:** Opus orchestrator dispatching Sonnet implementation agents.
**Epic:** `dp-l4h` (children `dp-l4h.1`–`dp-l4h.8`, already created with dependencies wired — run
`bd show dp-l4h.N` for full descriptions/acceptance criteria; do not re-create them).
**Authority:** `designs/DESIGN.md` Phase 5. Carries forward `designs/PHASE_4_HANDOFF.md`.

## Exit criteria (from DESIGN.md / epic acceptance)

1. Two devices converge after concurrent edits (LWW on `updatedAt`, tombstones for deletes).
2. Exported XLSX round-trips through the Phase 4 importer.

## Orchestrator ground rules

- **Branch:** create `phase_5` off `main`; merge via PR after local verification (user rule:
  unproven code never lands on main; local test runs are the gate, CI is a safety net).
- **Every agent prompt must include:** read `CLAUDE.md` (test-run rules!) and, for any agent
  touching drift/schema/repos, `.claude/skills/drift-flutter/SKILL.md`. Always
  `flutter test --timeout 30s`. Never `flutter test --platform chrome`. Never bump
  drift/drift_dev from **2.34.0 exactly**.
- **Beads discipline:** agent claims its issue (`bd update <id> --claim`), closes on completion;
  orchestrator commits + pushes after every completed issue. Keep
  `designs/PHASE_5_CURRENT_STATUS.md` (from `designs/templates/PHASE_STATUS_TEMPLATE.md`)
  updated; delete it at phase end when writing `PHASE_5_HANDOFF.md`.
- **Codegen:** any provider/table change needs
  `dart run build_runner build --delete-conflicting-outputs`; commit generated files.
- **PowerShell for web builds** (`flutter build web --base-href /DejaPoo/`); Git Bash mangles
  the base-href path.
- Personal data (`Alex Bowels.xlsx`, `HuckleberryReference/`) stays gitignored; tests use
  synthetic fixtures.

## Architecture decisions (pre-made — agents implement, don't re-litigate)

- **Snapshot sync, not deltas.** Single JSON file `dejapoo_snapshot.json` in Drive
  **appDataFolder** holding every record incl. tombstones (~2k records — trivially small).
  Versioned envelope: `{version: 1, generatedAt, records: [...]}`. Reject snapshots with
  `version > 1` with a "please update the app" error.
- **Merge = pure function.** `merge(local, remote)` keyed by id; newer `updatedAt` wins; on
  exact tie, tombstone wins, then lexicographically greater id (deterministic on both devices).
  All timestamp comparisons in UTC — verify how `updatedAt`/`createdAt` are stored before
  writing this (see `dejapoo-drift-store-date-time-values-as-text` memory; `occurredAt` uses a
  custom local converter, the audit columns may not).
- **Sync cycle:** pull snapshot (+etag/generation) → merge with `getAllIncludingDeleted()` →
  `applyRemote()` changed rows verbatim (no `updatedAt` bump) → push merged snapshot with a
  conflict guard → on conflict, re-pull and retry once. Single-flight; never blocks logging UX.
- **Triggers:** app open (if signed in + drive scope authorized), ~5 s debounce after any
  entry save/edit/delete, manual "Sync now" in Settings.
- **Auth:** `google_sign_in` 7.x (event-based `authenticate` API; web renders GIS button and
  needs an explicit scope-authorization step) + `extension_google_sign_in_as_googleapis_auth`
  + `googleapis` (Drive v3). Scopes: `drive.appdata` (sync), `drive.file` (optional export
  upload). OAuth clients are user-side setup — code must degrade gracefully when unconfigured,
  and `designs/GOOGLE_OAUTH_SETUP.md` documents Android (SHA-1) + web (client-id meta tag)
  setup. iOS: document only; unverifiable on the Windows dev machine — file a follow-up issue.
- **Export layout = the original spreadsheet:** one sheet per year, date rows, Type 1–7 count
  columns C–I, total J. Timed events collapse to daily counts on export (Phase 4 importer
  re-expands them to `dateOnly` events — round-trip equality is on daily counts, and re-import
  over existing data must insert 0 via `insertAllIfAbsent`).
- **Delivery:** mobile → `share_plus` share sheet; web → browser download via `package:web`
  (not deprecated `dart:html`); Drive upload → fixed "DejaPoo Exports" folder created on demand
  (no folder picker — keep it minimal).

## Waves

**Wave 1 — parallel, no cross-deps (3 Sonnet agents):**
- `dp-l4h.1` Sync model + LWW merge engine (pure Dart, no new deps)
- `dp-l4h.2` Repository sync surface + `sync_state` table (drift skill mandatory; schema
  migration + migration test)
- `dp-l4h.3` Export generators + importer round-trip test

**Wave 2 — parallel (2 agents):**
- `dp-l4h.4` Google sign-in / auth provider / Settings account section / OAuth docs.
  ⚠ Dependency-resolution risk: check analyzer transitive constraints before committing
  pubspec (riverpod_generator 4.x needs analyzer ^12; drift pinned). If google_sign_in 7.x
  forces a conflict, report back to orchestrator rather than force-resolving.
- `dp-l4h.5` DriveSnapshotStore interface + real impl + in-memory fake (blocked only on .1)

**Wave 3 — parallel (2 agents):**
- `dp-l4h.6` SyncService + triggers + status provider + Sync now UI (needs .1/.2/.4/.5)
- `dp-l4h.7` Export UI in Settings (needs .3/.4)

**Wave 4 — single agent or orchestrator:**
- `dp-l4h.8` E2E two-device convergence test (two app stacks, one fake store), full gates,
  README update, `PHASE_5_HANDOFF.md`, close children + epic, push.

## Verification gates (each wave; full set at .8)

```powershell
flutter analyze
flutter test --timeout 30s
flutter build web --release --base-href /DejaPoo/   # PowerShell
flutter build apk --release
flutter run -d chrome --dart-define=DB_SMOKE=true   # expect "DB_SMOKE OK"
```

Manual gates (require the user / real Google account — schedule at .8, surface clearly):
sign-in + sync on Chrome and Android emulator; export→re-import shows 0 inserted.

## Manual user-side OAuth setup (Console steps — cannot be automated)

Required before the real-account gates at `dp-l4h.8`; code work is never blocked on this
(the app degrades gracefully until configured). `dp-l4h.4` writes the detailed
`designs/GOOGLE_OAUTH_SETUP.md`; the short version:

1. Create a Google Cloud project; enable the **Google Drive API**
2. OAuth consent screen: External, add the user's Gmail as a **test user**, scopes
   `drive.appdata` + `drive.file`; stay in **Testing** mode (personal use — no Google
   verification review needed; `drive.appdata` only triggers review if published)
3. **Android client ID**: applicationId + debug-keystore SHA-1 (`gradlew signingReport`);
   add the release-keystore SHA-1 before signed builds. Matched at runtime — nothing in code
4. **Web client ID**: Authorized JavaScript origins `http://localhost:5000` (pin dev runs
   with `flutter run -d chrome --web-port 5000`) and `https://ryan-shah.github.io`
   (origins are host-only, so this covers `/DejaPoo/`); client ID goes in a
   `web/index.html` meta tag
5. **iOS client ID**: bundle ID + reversed-client-ID URL scheme in Info.plist —
   documented only, unverifiable on the Windows dev machine

## Risks & watch-items

| Risk | Mitigation |
|---|---|
| google_sign_in 7.x web: access tokens expire ~1 h, no silent refresh for scopes | Sync triggers re-check authorization; prompt re-auth instead of failing silently |
| pubspec analyzer conflicts (drift 2.34.0 pin vs new deps) | Wave 2 agent must dry-run `flutter pub get` and escalate conflicts, never bump drift |
| Drive write conflict (two devices pushing) | etag/generation guard + one re-pull-and-retry; E2E test injects the conflict |
| `updatedAt` timezone semantics in merge | dp-l4h.1/.2 must assert UTC comparison in tests (boundary test at a DST edge) |
| Widget tests holding drift `watch()` streams wedge flutter_tester | End with `pumpWidget(SizedBox.shrink())` + `pump(1ms)` (CLAUDE.md rule) |
| iOS OAuth unverifiable on Windows | Document in GOOGLE_OAUTH_SETUP.md; file deferred bd issue |

## Deferred / out of scope

Background/periodic sync, multi-account, partial-field merge (record-level LWW only),
Drive folder picker UI, iOS device verification (`dp-*` to be filed at closeout),
existing backlog: `dp-mih` (COI/OPFS), `dp-9w0`, `dp-h5e`.
