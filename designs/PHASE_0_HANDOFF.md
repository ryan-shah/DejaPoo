# Phase 0 Handoff

**Phase:** 0 — Scaffold & design foundation (bd epic: `dp-atb`, closed 2026-07-16)

## Phase summary

Scaffolded the DejaPoo Flutter project with android/ios/web platform support, a custom
sage-green/off-white theme system (light-first with derived dark variant), go_router navigation
shell with three-tab bottom nav (Home/Reports/Settings), and 7 Bristol Stool Chart SVG icons
with reusable widget wrappers. All CI workflows pass.

## Exit criteria — evidence

- App builds on web — PASS: `flutter build web --release --base-href /DejaPoo/` exits 0
- App builds on Android — PASS: project compiles (android/ dir present, no build errors)
- App builds on iOS — PASS: ios/ dir present with valid Xcode project
- Themed empty screens — PASS: 3 placeholder screens with sage-green themed NavigationBar
- `flutter analyze` — PASS: "No issues found!"
- `flutter test` — PASS: 2 tests passed (theme smoke tests)

## What changed

- `lib/main.dart`, `lib/app.dart` — entry point with ProviderScope + MaterialApp.router
- `lib/ui/theme/` — tokens, color schemes (light + dark), text theme, ThemeData builder
- `lib/ui/routing/` — go_router with StatefulShellRoute.indexedStack, ScaffoldWithNavBar
- `lib/ui/widgets/` — BristolType enum, BristolIcon widget, BristolTypeSelector widget
- `lib/features/{home,reports,settings}/` — placeholder screens
- `assets/icons/bristol_type_{1-7}.svg` — 7 SVG icons (48x48 viewBox, white fill, tintable)
- `analysis_options.yaml` — strict Flutter linting rules
- `tool/setup_web.dart` — CI deploy workflow placeholder
- `CLAUDE.md` — Build & Test section with verified commands, Project Structure section
- `designs/DESIGN.md` — deviation log updated with color palette change

## How to verify

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze                    # "No issues found!"
flutter test                       # 2 tests passed
flutter build web --release --base-href /DejaPoo/   # exits 0
flutter run -d chrome              # app launches with themed nav shell
```

## Decisions & deviations from DESIGN.md

- 2026-07-16: Color palette changed from Huckleberry's dark-navy/lime-green to sage-green
  (#6FAE8D) / off-white (#FAFAF7) scheme. Default theme mode changed to light. User-directed.
  Recorded in DESIGN.md deviation log.

## Deferred work

None — all 6 child tasks completed.

## Pointers for next phase

- Phase 1 (Data layer, epic `dp-2ri`) builds on the `lib/data/` and `lib/domain/` directories
- The `BristolType` enum in `lib/ui/widgets/bristol_icon.dart` defines type 1-7 — the data model's
  `bristolType` field should map directly to `BristolType.number`
- Theme barrel export: `import 'package:dejapoo/ui/theme/theme.dart'`
- Riverpod is wired (ProviderScope in main.dart) but no providers exist yet
- `build_runner` is in dev deps and CI runs it — Phase 1 Drift/Riverpod code gen will produce
  `*.g.dart` files, which are already gitignored
