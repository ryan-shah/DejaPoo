# DejaPoo — Design Document

> **This document is authoritative.** If implementation deviates from it, record the deviation
> here with a dated note. Task tracking lives in beads (`bd`), not here. Current work status
> lives in `designs/PHASE_X_CURRENT_STATUS.md`; completed phases produce `designs/PHASE_X_HANDOFF.md`.

**Product in one line:** an adult Huckleberry for bowel tracking — one-tap logging of events
classified by Bristol Stool Chart type via representative icons, with rich time-range analytics
and Google Drive sync/export. Targets: Android, iOS, web.

## Reference material findings

Reference files are **local-only and gitignored** (personal health data / family photos):
`Alex Bowels.xlsx` and `HuckleberryReference/` in the repo root.

### Alex Bowels.xlsx (historical data to import)
- Three sheets: `2024`, `2025`, `2026`. One row per calendar day.
- Columns C–I = count of movements per Bristol type 1–7 that day; J = daily total.
- Side table: year total, avg-per-day stat, and a key describing types 1–7.
- Totals: 2024 = 669 events (1.83/day), 2025 = 791 (2.17/day), 2026 YTD = 418 (2.13/day) — ~1,900 events.
- **Data is date-only counts, no times of day** → the data model needs a `dateOnly` flag and the
  importer expands counts into individual date-only events.

### Huckleberry app (UX to clone, cleaned up for adults)
- **Add-entry flow:** bottom sheet; big horizontally-scrolling tappable icon circles as the primary
  classifier; time picker defaulting to now; optional detail rows (size chips Little/Medium/Big,
  color swatches, consistency icons, toggle rows); free-text note; one big Save button.
- **Reports:** Day/Week/List/Summary tabs, range chips (7D/14D/30D), average stat tiles with icons,
  stacked bar chart by day, bottom nav (Home / Reports / Insights / …).
- **Visual language:** sage green (#6FAE8D) primary, forest green (#3E6B48) secondary, warm sand
  (#E9DFC8) accent, off-white (#FAFAF7) background. Light-first with derived dark variant.
  Generous spacing, clean minimal UI.

## Stack

| Concern | Choice | Why |
|---|---|---|
| Framework | Flutter (Android/iOS/web) | Requested |
| State mgmt | Riverpod | Testable, compile-safe, standard |
| Local DB | Drift (SQLite; WASM on web) | Aggregation-heavy metrics need real SQL; works on all three targets |
| Routing | go_router | Deep links, web URLs |
| Charts | fl_chart | Pure Flutter, renders identically on all platforms |
| Drive | `google_sign_in` + `googleapis` | Official path on Android/iOS/web |
| Icons | Custom SVG set for Bristol types 1–7 | The core UX element; nothing off-the-shelf fits |

## Data model

```
BowelMovement {
  id          uuid
  occurredAt  DateTime        // local time of event
  dateOnly    bool            // true for imported spreadsheet rows (no time-of-day)
  bristolType int (1–7)       // required — the primary classification
  size        enum? (small/medium/large)
  color       enum?
  urgency     int?
  strain      int?
  blood       bool?
  note        String?
  createdAt   DateTime
  updatedAt   DateTime        // drives sync merge (last-write-wins)
  deletedAt   DateTime?       // soft delete / tombstone for sync
}
```

Soft deletes and `updatedAt` exist from day one so Phase 5 sync is a merge problem, not a schema
migration. `dateOnly` events count toward daily stats but are excluded from time-of-day views.

## Phases

### Phase 0 — Scaffold & design foundation
`flutter create` with android/ios/web enabled; folder structure (`data / domain / features / ui`);
linting; theme system (dark navy + green accent, light mode variant); design tokens; go_router
shell with bottom nav (Home, Reports, Settings); the 7 Bristol-type icons as SVGs. Fill in the
CLAUDE.md Build & Test section with the real commands.
**Exit:** app builds and runs on all three platforms with themed empty screens.

### Phase 1 — Data layer
Drift schema + migrations, repository layer, seed/fixture generator modeled on the real
spreadsheet distributions, unit tests for CRUD and the date-range aggregation queries
(count per type per day/week/month, avg/day, streaks/gaps).
**Exit:** repository tests green, including web (WASM sqlite) smoke test.

### Phase 2 — Logging UX (the MVP loop)
Home screen: today-at-a-glance + reverse-chronological entry timeline. Add/Edit bottom sheet
cloning the Huckleberry pattern: horizontally scrolling Bristol icon circles (1–7) as the primary
selector, date/time picker defaulting to now, optional detail rows (size chips, color swatches,
urgency/strain, blood toggle, note), big Save. Swipe to edit/delete. Fast path: FAB long-press →
"log Type N now" for one-tap repeat logging.
**Exit:** an entry can be logged in under 5 seconds; full CRUD works on all platforms.

### Phase 3 — Metrics & reports
Reports screen with **Day / Week / Month / Year / Custom** range selector (custom = date-range
picker). Per range: stat tiles (total, avg/day, most common type, % in healthy range 3–5, longest
gap), stacked bar chart of counts by type over time (day bars for week/month, month bars for
year — mirroring the spreadsheet's own chart), type-distribution donut, and a List view with
filters. All computations via the Phase 1 aggregation queries.
**Exit:** every range renders correct numbers against fixture data verified by tests.

### Phase 4 — Historical import
Importer for the existing spreadsheet format (XLSX and CSV): parses the year-sheet layout
(date rows + Type 1–7 count columns), expands counts into `dateOnly` events, marks them imported,
dedupes on re-import. Tests use a **synthetic fixture** mimicking the layout (the real xlsx is
gitignored but can be used for a local manual check).
**Exit:** the real "Alex Bowels.xlsx" imports cleanly locally and Reports reproduce the
spreadsheet's own year totals (669 / 791 / 418) and avg-per-day figures.

### Phase 5 — Google Drive sync & export
Google sign-in; sync via a JSON snapshot in the Drive **appDataFolder** (per-record last-write-wins
merge on `updatedAt`, tombstones for deletes) with manual "Sync now" plus auto-sync on app open and
entry save; **export** CSV or XLSX (matching the original spreadsheet layout) to a user-chosen
Drive folder or local share sheet. Requires a Google Cloud OAuth client per platform — user-side
setup step.
**Exit:** two devices converge after concurrent edits; exported XLSX round-trips through the
Phase 4 importer.

### Phase 6 — Polish & release readiness
Optional daily-log reminder notifications, app icon/splash, responsive wide-screen layout for
web + PWA manifest, accessibility pass (semantics labels on the icon picker especially),
empty/error/loading states, release builds, store listing prep.
**Exit:** installable release artifacts for all three platforms.

## Sequencing

Phases 0→1→2 are strictly ordered; 3 and 4 can proceed in parallel after 1; 5 depends on 4
(so exports include history); 6 is last. The riskiest integration is Phase 5 (OAuth config across
three platforms), which is why sync-friendly schema decisions land in Phase 1 rather than being
retrofitted.

## Deviation log

2026-07-16 — Color palette changed from Huckleberry's dark-navy/lime-green to a custom
sage-green/off-white scheme (Primary #6FAE8D, Secondary #3E6B48, Accent #E9DFC8, Background
#FAFAF7, Error #D96C6C). Default theme mode changed from dark to light. Dark variant derived
from same hues. User-directed decision.
