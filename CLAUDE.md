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

_Flutter project not yet scaffolded — this section gets real commands in Phase 0 (see `dp-atb.6`)._

```bash
# After Phase 0:
# flutter pub get
# flutter analyze
# flutter test
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
