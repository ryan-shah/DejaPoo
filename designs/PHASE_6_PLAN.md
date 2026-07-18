# Phase 6 Implementation Plan — Polish & Release Readiness

**Audience:** Opus orchestrator dispatching Sonnet implementation agents.
**Epic:** `dp-bjs` (children `dp-bjs.1`–`dp-bjs.7`, already created with dependencies wired — run
`bd show dp-bjs.N` for full descriptions/acceptance criteria; do not re-create them). The backlog
item `dp-mih` (COI service worker) is pulled into this phase as Wave 1 work — claim it directly,
do not duplicate it.
**Authority:** `designs/DESIGN.md` Phase 6. Carries forward `designs/PHASE_5_HANDOFF.md`.

## Exit criteria (from DESIGN.md / epic acceptance)

Installable release artifacts for all three platforms — **with one pre-declared deviation**: iOS
artifacts cannot be built on the Windows dev machine. iOS ships as complete documentation
(icons/splash config, OAuth, build checklist) and the deviation gets a dated entry in
`DESIGN.md`'s deviation log at closeout (`dp-bjs.6`). Android (apk + appbundle) and web
(GitHub Pages) artifacts are the verifiable gates.

## Orchestrator ground rules

- **Branch:** create `phase_6` off `main`; merge via PR after local verification (user rule:
  unproven code never lands on main; local test runs are the gate, CI is a safety net).
- **Every agent prompt must include:** read `CLAUDE.md` (test-run rules!) and, for any agent
  touching drift/schema/repos, `.claude/skills/drift-flutter/SKILL.md`. Always
  `flutter test --timeout 30s`. Never `flutter test --platform chrome`. Never bump
  drift/drift_dev from **2.34.0 exactly**.
- **Beads discipline:** agent claims its issue (`bd update <id> --claim`), closes on completion;
  orchestrator commits + pushes after every completed issue. Keep
  `designs/PHASE_6_CURRENT_STATUS.md` (from `designs/templates/PHASE_STATUS_TEMPLATE.md`)
  updated; delete it at phase end when writing `PHASE_6_HANDOFF.md`.
- **Codegen:** any provider change needs
  `dart run build_runner build --delete-conflicting-outputs`; commit generated files.
- **PowerShell for web builds** (`flutter build web --base-href /DejaPoo/`); Git Bash mangles
  the base-href path.
- **New-dependency protocol** (applies to `dp-bjs.2`/.3): dry-run `flutter pub get` before
  committing pubspec. drift/drift_dev are pinned 2.34.0 and riverpod_generator 4.x needs
  analyzer ^12 — if a new package forces a conflict, report to the orchestrator; never
  force-resolve or bump drift.
- Personal data (`Alex Bowels.xlsx`, `HuckleberryReference/`) stays gitignored.
- Widget tests holding drift `watch()` streams must end with
  `pumpWidget(const SizedBox.shrink())` + `pump(Duration(milliseconds: 1))`.

## Architecture decisions (pre-made — agents implement, don't re-litigate)

- **Debounced sync wiring (`dp-bjs.1`):** hook the existing `scheduleDebouncedSync()`
  (`lib/data/sync/sync_providers.dart`, 5 s debounce, built in Phase 5) into the entry
  create/edit/delete paths at the provider/notifier layer — not inside the repository (the repo
  stays sync-agnostic; import bulk-inserts must NOT each schedule a sync — one schedule after a
  completed import is fine). Silent no-op when not signed in / not drive-authorized.
- **Notifications (`dp-bjs.3`):** `flutter_local_notifications` + `timezone` for a daily zoned
  schedule. Inexact scheduling only (no `SCHEDULE_EXACT_ALARM`); Android 13+
  `POST_NOTIFICATIONS` runtime permission requested when the user enables the toggle, toggle
  reverts on denial. Preference persisted in `shared_preferences` — it is **device-local and
  must never enter the Drive snapshot** (snapshot schema stays version 1, records only).
  Web: hide the section entirely (`kIsWeb`). Wrap the plugin behind a small abstraction so
  schedule/cancel logic is unit-testable with a fake.
- **App identity (`dp-bjs.2`):** master icon derived from the Bristol SVG visual language +
  sage palette (#6FAE8D primary, #3E6B48, #FAFAF7 background). `flutter_launcher_icons`
  (adaptive Android + iOS set + web icons) and `flutter_native_splash`; fix `web/manifest.json`
  (still says "A new Flutter project", Flutter-blue theme color) and `index.html` title/meta.
  Both are config + generated assets — commit everything generated.
- **COI worker (`dp-mih`):** adopt the BinderManager pattern — `web/coi_serviceworker.js`
  registered in `web/index.html` with a one-time reload **before the app boots**. Critical trap
  (from the issue): if the app boots pre-reload, drift creates the DB in IndexedDB and keeps it
  forever even after OPFS becomes available. Verify with the DB_SMOKE probe that storage
  selection reports OPFS on the Pages-style build.
- **Responsive layout (`dp-bjs.4`):** single breakpoint at 840 dp in the go_router shell
  scaffold — `NavigationRail` wide, `NavigationBar` narrow; content columns constrained to
  ~720–840 dp centered; charts may use full width. No new packages; phone rendering unchanged.
- **Accessibility + states (`dp-bjs.5`):** two sweeps, one agent (they touch the same files —
  do not parallelize with each other). Bristol selector semantics are the DESIGN.md-flagged
  item: each circle announces "Bristol type N: <description>" + selected state. Charts get a
  text semantics summary. Extract a shared error-retry widget only if ≥3 call sites repeat.
  5 files already have some Semantics — extend, don't duplicate.
- **Release/signing (`dp-bjs.6`):** `key.properties` + keystore are user-side secrets
  (gitignored); `build.gradle` signingConfig falls back to debug signing when absent so builds
  never break for agents/CI. Store-listing collateral goes in `designs/STORE_LISTING.md`
  including privacy-policy text (health data: local + user's own Drive appDataFolder, no
  third-party servers, no analytics) and Play data-safety answers.

## Waves

**Wave 1 — parallel, no cross-deps (3 Sonnet agents):**
- `dp-bjs.1` Debounced sync wiring (+ unit tests with fake store/time)
- `dp-bjs.2` + `dp-mih` App identity assets **and** COI service worker (one agent — both live
  in `web/` + platform config; keep them in separate commits)
- `dp-bjs.3` Daily reminder notification (new deps — dependency-resolution risk; escalate
  conflicts)

**Wave 2 — parallel (2 agents):**
- `dp-bjs.4` Responsive wide-screen layout (shell scaffold + screen containers)
- `dp-bjs.5` Accessibility + empty/error/loading audit (widgets + screens' content)

⚠ Wave 2 agents both touch feature screens: .4 owns scaffold/layout containers, .5 owns
widget semantics + state widgets. Instruct each to stay in its lane; orchestrator resolves
any overlap at merge.

**Wave 3 — sequential (1 agent, or orchestrator):**
- `dp-bjs.6` Release builds, signing docs, store listing, DESIGN.md deviation entry (blocked
  on all of the above incl. `dp-mih`)
- `dp-bjs.7` Closeout: full gates, README, `PHASE_6_HANDOFF.md`, close children + epic, push

## Verification gates (each wave; full set at .7)

```powershell
flutter analyze
flutter test --timeout 30s
flutter build web --release --base-href /DejaPoo/   # PowerShell
flutter build apk --release
flutter build appbundle --release                   # Wave 3
flutter run -d chrome --dart-define=DB_SMOKE=true   # expect "DB_SMOKE OK"
```

Manual gates (require the user — schedule at .7, surface clearly):
- Notification fires on Android emulator at chosen time; disable cancels it
- New icon + splash visible on emulator; PWA installs from the Pages deploy with correct
  name/icon; DB_SMOKE on the deployed Pages build reports OPFS (post-COI-worker)
- Real-account sync still works after debounce wiring (create entry → wait ~5 s → check
  Settings sync status); store-listing screenshot capture

## Manual user-side setup (cannot be automated)

1. **Android release keystore:** `keytool -genkey …` + `android/key.properties` (documented by
   `dp-bjs.6`; debug fallback keeps builds green until then). Add the release SHA-1 to the
   Google Cloud Android OAuth client (per `designs/GOOGLE_OAUTH_SETUP.md`) or sync breaks on
   release builds.
2. **Play Console:** listing, data-safety form, privacy policy URL — text supplied by
   `designs/STORE_LISTING.md`; account + upload are user actions.
3. **iOS:** everything (requires a Mac) — docs only this phase; `dp-y82` stays open.

## Risks & watch-items

| Risk | Mitigation |
|---|---|
| flutter_local_notifications / timezone / shared_preferences vs drift 2.34.0 + analyzer pins | Dry-run `flutter pub get`; escalate, never force-resolve (protocol above) |
| COI reload loop or app booting pre-reload → DB stuck in IndexedDB forever | Follow BinderManager pattern exactly; verify storage backend via DB_SMOKE on a Pages-style serve |
| Debounce wiring causing a sync per imported row | Schedule once per completed mutation flow; import triggers at most one |
| Splash/icon codegen touching android/ios build files breaks release build | Wave 1 gate includes `flutter build apk --release` |
| Wave 2 merge conflicts on shared screens | Lane split (.4 layout containers / .5 semantics+states); orchestrator merges |
| Release signing config breaks agent builds when key.properties absent | Mandatory debug-signing fallback in build.gradle |
| "All three platforms" exit criterion vs Windows-only dev machine | Pre-declared deviation: iOS docs-only; record in DESIGN.md deviation log |

## Deferred / out of scope

Background sync, notification actions/smart reminders, per-record import provenance
(`dp-h5e` stays open), `dp-9w0` (riverpod_lint), `dp-y82` (iOS verification), localization,
onboarding flow, widget/home-screen shortcuts. Store *submission* (uploading to Play) is a
user action, not agent work.
