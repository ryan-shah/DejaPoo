# Project Instructions for AI Agents

This file provides instructions and context for AI coding agents working on this project.

<!-- BEGIN BEADS INTEGRATION v:1 profile:minimal hash:7510c1e2 -->
## Beads Issue Tracker

This project uses **bd (beads)** for issue tracking. Run `bd prime` to see full workflow context and commands.

### Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --claim  # Claim work
bd close <id>         # Complete work
```

### Rules

- Use `bd` for ALL task tracking — do NOT use TodoWrite, TaskCreate, or markdown TODO lists
- Run `bd prime` for detailed command reference and session close protocol
- Use `bd remember` for persistent knowledge — do NOT use MEMORY.md files

**Architecture in one line:** issues live in a local Dolt DB; sync uses `refs/dolt/data` on your git remote; `.beads/issues.jsonl` is a passive export. See https://github.com/gastownhall/beads/blob/main/docs/SYNC_CONCEPTS.md for details and anti-patterns.

## Session Completion

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds
<!-- END BEADS INTEGRATION -->


## Build & Test

```bash
# Install dependencies
flutter pub get

# Run code generation (Riverpod, Drift, etc.)
dart run build_runner build --delete-conflicting-outputs

# Static analysis (CI uses --no-fatal-infos)
flutter analyze

# Run all tests (ALWAYS pass --timeout, see Test-run rules below)
flutter test --timeout 30s

# Run a single test file
flutter test --timeout 30s test/path/to/test.dart

# Web (WASM sqlite) smoke test — gate runs in CI; local runs wedge on this
# Windows machine (see Test-run rules)
flutter test --platform chrome test/web

# Run on Chrome (web)
flutter run -d chrome

# Run on connected Android device/emulator
flutter run -d android

# Build web release (for GitHub Pages)
flutter build web --release --base-href /DejaPoo/

# Build Android APK
flutter build apk --release

# Build Android App Bundle
flutter build appbundle --release
```

### Test-run rules (learned the hard way, 2026-07-16)

- **Always pass `--timeout 30s` to `flutter test`.** It bounds plain `test()`s; note it does
  NOT bound `testWidgets` (their 10-minute internal default wins).
- **The suite is small and fast. A run stalled for minutes is wedged — kill it, don't wait.**
  Distinguish: testers idling at 0 CPU right after start is normal kernel compilation; a
  compiler process whose CPU time hasn't moved between two checks minutes apart is a wedge.
- **Local `flutter test --platform chrome` wedges on this Windows machine** (`dp-0ot`):
  the frontend compile freezes at ~31 CPUsec, or the suite hangs after "Running test suite".
  The web smoke gate (`test/web/`) is verified in CI (ubuntu), not locally.
- **Run long suites detached, redirect output to a file, and poll the file.** Never pipe test
  output through buffering commands (`tail`, `head`, `Select-Object`) — you fly blind.
- **Killed `flutter test --platform chrome` runs leak their whole process stack** (dart test
  runner, frontend_server, headless Chrome). Orphans deadlock later runs on shared build locks.
  Clean up: kill dart/dartvm/dartaotruntime processes (sparing the IDE's language-server,
  tooling-daemon, devtools) and chrome.exe processes whose command line contains
  `flutter_tools`.
- **Drift + widget tests (Phase 2+):** drift closes `watch()` streams with zero-duration timers
  at ProviderScope disposal; a `testWidgets` failure like "A Timer is still pending" can wedge
  flutter_tester at 0 CPU right after the `[E]` line. End any widget test whose tree holds live
  drift streams with `await tester.pumpWidget(const SizedBox.shrink()); await
  tester.pump(const Duration(milliseconds: 1));` (the nonzero duration is required).
- **Checkpoint `PHASE_X_CURRENT_STATUS.md` before starting any long run.**

## Project Structure

```
lib/
  main.dart              # App entry point
  app.dart               # MaterialApp.router widget
  data/                  # Repositories, data sources, DTOs
  domain/                # Entities, value objects, enums
  features/              # Feature modules (home/, reports/, settings/)
  ui/
    theme/               # Design tokens, color schemes, ThemeData
    routing/             # go_router configuration, shell scaffold
    widgets/             # Shared widgets (Bristol icons, etc.)
assets/
  icons/                 # Bristol type 1-7 SVG icons
```

## Architecture & Design

**`designs/DESIGN.md` is the authoritative design document** — product scope, stack, data model,
and the Phase 0–6 breakdown with exit criteria. Read it before starting work. If implementation
deviates from it, record the deviation in its dated deviation log.

Current work status lives in `designs/PHASE_X_CURRENT_STATUS.md` (one per active phase);
completed phases have a `designs/PHASE_X_HANDOFF.md`. Templates for both are in `designs/templates/`.

## Agent Workflow: Phases, Status & Handoff

Work is organized into phases, each tracked as a beads epic (`dp-atb` … `dp-bjs`). These rules
exist so any session can end abruptly (usage limits, disconnects) without stranding work, and so
a fresh agent can resume with zero conversation context.

### Session start protocol

1. Read `designs/DESIGN.md` and the current `designs/PHASE_X_CURRENT_STATUS.md`
2. `git pull --rebase`
3. `bd ready` to find unblocked work; `bd show <id>` then `bd update <id> --claim`

### During work

- **Beads is the sole task tracker.** Status/handoff docs are narrative context — never put
  checkbox task lists in them; reference bd ids instead.
- **Expand epics at phase start:** before coding a phase, break its epic into child bd issues
  (`bd create --parent <epic-id>`), then claim one. Phase 0 is pre-seeded (`dp-atb.1`–`dp-atb.6`).
- **Commit and push after every completed bd issue**, not just at session end. A cutoff must
  never strand more than one issue's work.
- **Update `PHASE_X_CURRENT_STATUS.md`** (copy from `designs/templates/PHASE_STATUS_TEMPLATE.md`)
  when completing an issue, making a design decision, or before any long/risky operation. It is a
  snapshot, not a log: keep it under ~100 lines and overwrite stale content. Its "Next steps"
  section must be executable by a zero-context agent (exact files, commands, bd ids).
- **When context runs low, stop starting new work.** Update the status doc, commit, push. Never
  leave work uncommitted while beginning something new.
- **Record insights/gotchas with `bd remember`** so they survive across sessions.

### Phase completion

1. Verify every exit criterion in `designs/DESIGN.md` with evidence (`flutter analyze`,
   `flutter test`, platform builds — not just "it should work")
2. Write `designs/PHASE_X_HANDOFF.md` (copy from `designs/templates/PHASE_HANDOFF_TEMPLATE.md`),
   then delete that phase's `PHASE_X_CURRENT_STATUS.md`
3. File bd issues for anything deferred; `bd close` the epic's children and the epic
4. Commit, push, and run the Session Completion checklist above

## Conventions & Patterns

- Personal reference data (`Alex Bowels.xlsx`, `HuckleberryReference/`) is **local-only and
  gitignored** — never commit it; tests use synthetic fixtures instead.
