# Mwendo Design System & UI Specification

> **Updated 2026-11-09 — Apple HIG / Liquid Glass refresh.** The UI was
> re-skinned to follow Apple's Human Interface Guidelines: system typography,
> Apple semantic colours, neutral grouped surfaces, and translucent "glass"
> used **only on the navigation layer** (tab bar, map controls, run controls).
> Features and screen structure did not change. The full audit and rationale
> are in [REVAMP_PLAN.md](REVAMP_PLAN.md). The single source of truth for every
> value below is `app/lib/core/theme/app_theme.dart`.

## Round 2 (2026-11-10): native iOS feel

- **iOS behaviour everywhere.** `ThemeData.platform = TargetPlatform.iOS`, so
  every platform gets bouncing scroll physics, iOS navigation bars and back
  chevrons, Cupertino switches/dialogs/pickers from the adaptive
  constructors and iOS text selection. On an iPhone it's simply native.
- **Collapsing large titles.** Tab roots and key drill-downs use
  `LargeTitlePage` (`widgets/ios.dart`), built on
  `CupertinoSliverNavigationBar`: a 34 pt title that shrinks into a blurred
  translucent bar whose hairline appears only once content scrolls under it.
- **iOS building blocks** (`widgets/ios.dart`): `IosSearchField`
  (`CupertinoSearchTextField`), `IosSegmented` (sliding segmented control),
  `IosFilterPills` (App Store–style capsule filters), `IosSectionHeader`
  (Title 3 + "See all"), `IosInsetGroup` (inset grouped rows with inset
  hairlines), `IosBarButton`, `IosBackButton`.
- **Legend artwork.** Each legend has a stable colour from a curated set
  (`legendAccent`), drawn as a two-stop gradient (`legendGradient`) behind
  their portrait (`LegendAvatar`) — the Apple Music artist-art idea. The
  portrait is a real photo (`assets/legends/<slug>.jpg`, Wikimedia Commons,
  free licences, credited in-app) or the emoji when no free photo exists.
- **Floating tab bar clearance.** Scrolling tab pages end with
  `AppTheme.tabBarClearance(context)` so the last item is never hidden.
- **Font.** On Android the bundled **Inter** (SIL Open Font License,
  `app/assets/fonts/`, ~3.3 MB, 8 weights) stands in for San Francisco:
  `InterDisplay` for bold text ≥ 20 pt (like SF Pro Display), `Inter`
  below (like SF Pro Text). iOS keeps the real system font.
  `AppTheme.fontFamilyFor(size, weight)` picks the family. Tabular figures
  are applied only to number styles, because Inter's `tnum` also widens
  hyphens.

## Round 6 (2026-11-10): field-test fixes

- **Start button** reads the chosen activity: "Go for a run / walk / ride /
  hike", "Start drive", "Start workout".
- **GPS issue banner** (`GpsIssueBanner`, `features/tracking/gps_status_widgets.dart`):
  a solid card (not glass, so it reads over a busy map) under the status pill
  for Approximate location, GPS start failure, no signal and mock location,
  with a Fix button (opens Settings) or a dismiss button. Chips below the
  pill move down while it shows.
- **GPS details sheet**: tap the status pill.
- **You header**: `LevelAvatar` (`widgets/level_ring.dart`) puts the level
  progress ring around the profile photo with a level badge on its lower
  edge; the separate "Lv" ring is gone from the header.

## Performance rules (round 4)

- Glass blur is the costliest effect. `GlassSurface` has no shadow by
  default, blurs share one backdrop (`BackdropGroup`), glass over the live
  map uses `blur: 0`, and `GlassQuality` turns blur off automatically on
  devices that can't keep up (Settings → Transparency effects).
- No infinite animations on screens people rest on: any running animation
  re-renders every blur on screen 60 times a second.

## Principles

1. **Content first, chrome second.** Neutral backgrounds; colour is reserved
   for meaning (brand accent, recording, paused, success, danger).
2. **Glass is for navigation, not content.** Tab bar, map buttons, live run
   controls and status chips float on `GlassSurface`. Cards and lists are
   solid.
3. **Readable at a glance while running.** Large metrics, tabular digits, one
   hero number per screen, 44 pt minimum tap targets.
4. **Respect the system.** Light/dark mode, Reduce Motion, Increase Contrast,
   Dynamic Type (layouts use `FittedBox` / scroll rather than fixed heights).

---

## 1. Colour

### Brand ("Red Earth" default palette)
| Token | Value | Use |
| :--- | :--- | :--- |
| `AppTheme.brand` / `earth` | `#B14A2A` | Primary accent, buttons, route line |
| `AppTheme.earthDeep` | `#8C3A20` | Pressed / deep accent |
| `AppTheme.brandSoft` | `#D6714E` | Brand lifted for contrast on black |
| `AppTheme.dawn` / `achievement` | `#D89A2E` | Achievements, streaks, gold tier |
| `AppTheme.highland` | `#3C8368` | "Ahead of ghost" (dark) |

Users can switch palette in Settings (`redEarth`, `orange`, `forest`, `ocean`,
`berry` — `ColorPalette.presets`); every screen reads colours from the theme,
so the swap is global.

### Semantic (Apple system colours)
| Token | Value | Meaning |
| :--- | :--- | :--- |
| `recording`, `danger`, `sos`, `flagRed` | `#FF3B30` | Live recording, SOS, errors |
| `paused`, `warning` | `#FF9500` | Paused, weak GPS |
| `success` | `#34C759` | Success, good GPS |
| `flagGreen` / `flagGreenLight` | `#30D158` / `#248A3D` | Ahead/positive (dark / light) |
| `idle` | `#8E8E93` | Secondary icons, idle state |
| `secondaryLabelLight` / `Dark` | `#3C3C43` @60% / `#EBEBF5` @60% | Secondary text |
| `separatorLight` / `Dark` | `#3C3C43` @29% / `#545458` @60% | Hairlines in grouped lists |

### Surfaces (iOS grouped style)
| | Light | Dark |
| :--- | :--- | :--- |
| Scaffold (`lightScaffold` / `darkScaffold`) | `#F2F2F7` | `#000000` |
| Card (`lightCard` / `darkCard`) | `#FFFFFF` | `#1C1C1E` |
| Elevated (`lightElevated` / `darkElevated`) | `#E5E5EA` | `#2C2C2E` |
| Glass (`glassLight` / `glassDark`) | `#F9F9F9` @80% | `#1C1C1E` @70% |

Cards have **no shadow** (`elevation0`–`elevation2` are empty); only floating
overlays (recovery card, sheets) use `elevation3`/`elevation4`.

### Map
- Basemap: **OpenStreetMap** vector tiles from OpenFreeMap in the `liberty`
  style (`kOsmStyle` in `widgets/mwendo_map.dart`) — the familiar OSM look
  (green parks, blue water, coloured road classes, street names), used in
  both light and dark mode. Attribution sits bottom-left. (The first round
  used the muted Positron/Dark styles, which looked like a blank map.)
- Route: brand-colour line with a darker casing, round joins/caps; a blue
  "you are here" dot at the head; green start dot and brand-colour end dot on saved runs.
- A track is drawn as **segments**: GPS gaps are left as gaps, never bridged
  with a straight line.

### Legend tiers
Bronze `#CD7F32`, Silver `#C0C6CC`, Gold `dawn`, Platinum `#6FB6A0`.

---

## 2. Typography

The app uses **San Francisco on iOS** (system font) and the bundled
**Inter / Inter Display** on Android (see Round 2 above). Fonts ship inside
the app — `google_fonts` was removed, so nothing downloads on mobile data.
Numbers use **tabular figures** so columns of digits don't jiggle.

Helpers (signatures unchanged so old call sites re-skinned automatically):
- `AppTheme.displayFont(size:)` — big metrics and large titles; heavy, tighter
  tracking from 28 pt up, tabular figures.
- `AppTheme.bodyFont(size:)` — everything a runner reads.
- `AppTheme.monoFont(size:)` — data labels; system font + tabular figures
  (minimum 11 pt).

Type ramp (iOS "Large" content size):

| Flutter style | Size / weight | iOS equivalent |
| :--- | :--- | :--- |
| `headlineLarge` | 34 / bold | Large Title |
| `headlineMedium` | 28 / bold | Title 1 |
| `titleLarge` | 22 / bold | Title 2 |
| `titleMedium` | 17 / semibold | Headline |
| `bodyLarge` | 17 / regular | Body |
| `bodyMedium`, `titleSmall` | 15 | Subheadline |
| `bodySmall` | 13 | Footnote |
| `labelSmall` | 11 / semibold | Caption 2 |

Metric styles (`AppExtensions`): hero metric 46 pt, display metric 60 pt,
metric value 32 pt, metric label 12 pt semibold grey, sentence case (no
ALL-CAPS labels).

---

## 3. Shape, spacing, motion

- **Spacing:** 2, 4, 6, 8, 10, 12, 14, 16, 20, 24, 28, 32, 48 (`AppTheme.s*`).
- **Radius:** 8, 12, 16 (cards), 24 (glass panels), 999 (capsules) — `r*`.
- **Buttons:** capsule shaped (`StadiumBorder`), minimum height 44 pt
  (`AppTheme.minTap`).
- **Press feedback:** no Material ripple (`NoSplash`); tappable things use
  `Pressable`, which dims/scales slightly like iOS.
- **Navigation:** native iOS-style push (`CupertinoPage` /
  `CupertinoPageTransitionsBuilder`) with swipe-back; back button is a
  chevron.
- **Durations:** fast 150 ms, medium 280 ms, slow 350 ms. Always wrap with
  `AppTheme.motion(context, d)` — it returns `Duration.zero` when the user has
  Reduce Motion on.
- **Dialogs:** `showAdaptiveDialog` — Cupertino alert on iOS, Material on
  Android.

---

## 4. Components

### Shared widgets (`app/lib/widgets`)
| Widget | Purpose |
| :--- | :--- |
| `GlassSurface` | Blurred translucent panel (blur σ 24, hairline border). Falls back to a solid surface when Increase Contrast is on. |
| `GlassIconButton` | Round 44 pt glass button for map controls (re-centre, layers). |
| `Pressable` | iOS-style press feedback wrapper (replaces `InkWell`). |
| `GroupedSection` / `GroupedRow` | iOS inset grouped list: header, rounded card, hairline separators, optional chevron. Used by Settings and the You tab. |
| `AppButton` | Capsule button: primary / secondary / ghost / destructive, optional icon. |
| `AppCard` / `TierCard` | Solid rounded card, flat (no shadow), pressable when tappable. |
| `MetricTile` | Value + unit + sentence-case label; shrinks to fit. |
| `SectionTitle` | Title 2 section header with optional trailing action. |
| `MwendoMap` / `RouteMap` | OSM map with segmented route, start/end dots, fit-to-route camera, follow button. |
| `RouteThumbnail` | Small route preview for activity rows. |

### Design-system atoms (`app/lib/design_system`)
`AppEmptyState`, `AppPermissionCard`, `AppSegmentedControl`, `AppShareCard`.

### Navigation chrome
- **Tab bar** (`_GlassTabBar` in `core/router/app_router.dart`): floating
  glass capsule — Home, **Legends**, **Run** (centre, brand colour, pulses
  while recording), Learn, You. Icons are SF Symbols-style
  (`CupertinoIcons`), outline when idle and filled when selected.
- **Live run screen** (`features/tracking/live_dashboard.dart`): one hero
  distance number, secondary metrics below; glass control bar with a large
  Start button, Pause/Resume, and a **hold-to-stop** button (800 ms ring, so a
  run can't be ended by accident); glass status pill (GPS quality), ghost chip,
  SOS capsule, and a paused banner.
