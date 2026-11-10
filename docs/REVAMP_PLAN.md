# Mwendo Revamp: Map Tracking Fix + Apple-Style Visual Refresh

_9 November 2026_

Two parts:

- **Part A, maps and tracking.** The fixes are already in the code. They still need to be tested on a phone.
- **Part B, design.** An audit against Apple's current design guidance (the Human Interface Guidelines plus Liquid Glass, as revised in iOS 27), with a phased plan. Part B is a **visual refresh only**: no features are removed, and every screen keeps what it does. It just gets clearer and faster.

---

## Implementation status (9 November 2026)

All 8 phases are implemented and verified with Flutter 3.47.9 (Dart 3.13.7):

- **`flutter analyze`** (app): no issues.
- **`flutter test`** (app): all 67 pass. `back_navigation_test.dart` waited 250 ms for a 200 ms transition; the native push takes about 500 ms, so its wait is now 600 ms. Back-navigation behaviour itself is unchanged.
- **`dart analyze` / `dart test`** (`packages/gps_pipeline`): no issues; all 55 pass, including 14 new tests.

**Ground-truth track (`test/fixtures/synthetic_*`), original vs new pipeline:**

| | Original | New |
|---|---|---|
| Points kept | 156 / 325 | **197 / 325** |
| Mean distance from true path | 4.00 m | **3.61 m** |
| 95th-percentile distance | 10.70 m | **9.10 m** |
| Worst point | 17.63 m | **13.93 m** |
| Distance vs truth | +26.5 % | **−0.1 %** (see below) |

Positional accuracy improved on every measure.

**Distance (fixed, DISCOVERED_ISSUES.md #7).** Summing point-to-point hops added every sideways GPS wobble to the total. Distance now comes from `DistanceAccumulator`:

1. It integrates the phone's Doppler speed over time, the way Apple Watch and Garmin do.
2. It bridges briefly missing speed readings.
3. It falls back to a position hop only once the movement exceeds the fix's accuracy.

The live screen and the saved run use the same estimator.

The −0.1 % above is optimistic because the fixture's speeds are noiseless. A fairer test used 54 synthetic runs (3 routes × walk, run and fast pace) with realistic speed noise and 30 % missing readings:

| | Before | After |
|---|---|---|
| Average error | +51 % | +1.3 % |
| Typical error (absolute) | 51 % | 2.3 % |
| Worst cases | +15 … +104 % | −8.6 … +9.9 % |
| Phones that never report speed (typical) | +57 % | +23 % |

**Related bug fixed.** Phones that don't report a speed sent 0, which the stop detector read as "standing still", so it discarded the whole run. Missing speed is now −1 ("unknown") from Android, iOS and Dart through to the pipeline. The platform contract test was updated to match. The Kotlin edit compiles: the Android debug APK builds and the app runs on the Android emulator (API 37). The one-line Swift edit hasn't been compiled, because there is no Xcode on this PC.

**Still not verified:** how it looks and behaves on a real phone. Run the 15-minute walk test in Part A.

| Phase | Done | Notes / deviations |
|---|---|---|
| A. GPS + map | ✅ | Plus: the stop detector now resets between runs; elevation gain ignores GPS altitude noise (3 m threshold); GPX export writes one `<trkseg>` per segment. The OSRM upload was being triggered from **two** places (controller and Run screen); both are removed. |
| 1. Theme | ✅ | **System font** (SF Pro / Roboto) instead of *bundled* fonts. No download is needed and it is the most Apple-native option. `google_fonts` is removed from pubspec. Apple semantic colours, neutral grouped surfaces, capsule buttons, no ripples, native push transitions, adaptive alerts. Legacy font helpers keep their signatures. |
| 2. Components | ✅ | New: `Pressable`, `GlassSurface`/`GlassIconButton`, `GroupedSection`/`GroupedRow`, `RouteThumbnail`. Restyled: `AppButton`, `AppCard`, `TierCard`, `SectionTitle`, `MetricTile` (long values now scale down instead of overflowing). |
| 3. Navigation | ✅ | Floating glass tab bar with a solid Run button (red while recording, orange while paused). Re-tapping a tab returns to its root. iOS back chevron. |
| 4. Run screen | ✅ | Glass status, SOS, ghost and pause pills. One hero metric (distance) plus time, pace and calories. Solid Start button. Glass control bar. **Stop is now press-and-hold**: there was no confirmation before. The pause banner wrongly said "Auto-paused"; that is fixed. |
| 5. Home + Activity | ✅ | One "This week" hero card that contains Start. Recent runs as an inset list with route thumbnails. Activity list: route thumbnails, FAB removed. Detail: 320 pt map, glass controls, 2-column metrics, and the route-analysis button shown only in debug builds. **Not done:** weekly-goal rings, because the app has no goal setting to drive them and adding one would be a feature change. Month grouping was also skipped, because the list can be sorted by distance or duration. |
| 6. You | ✅ | A header and stats, then grouped rows that open Achievements, Leaderboard and Settings pages, plus Safety and Account sections. Also fixed: the stats row was rendered twice. |
| 7. Other screens | ✅ | Hard-coded brand colours replaced with the theme tint, so every palette works. Challenge cards are flat. Learn section headers are restyled. Routes has a large title. **Not done:** a full-screen map with a bottom sheet on Routes. The route data there is still placeholder (see `explore_provider.dart`), so a map of fake routes would mislead. |
| 8. Polish | ✅ | Respects Reduce Motion (press feedback, tab pulse, metric fades). High-contrast mode replaces glass with solid surfaces. Touch targets are at least 44 pt. Screen-reader labels added for the hold-to-stop button, tabs, metrics and leaderboard rows. |

---

## Part A: Why the map drew phantom, jagged lines (fixed)

I traced every path from the phone's GPS chip to the line on the map. There was no single bug. Five separate faults stacked on top of each other.

| # | Cause | What you saw | Fix |
|---|---|---|---|
| 1 | **The filter invented points.** When a GPS fix disagreed with the filter's prediction, the filter (`kalman_filter.dart`) kept the predicted position as if it were real, for up to 5 seconds. The prediction just means "keep going straight at the last speed". | At every corner the line shot straight on, through buildings, then snapped back: spiky "places I never went". | The filter no longer invents points. A fix that disagrees with the prediction is dropped. If 3 fixes in a row disagree, the filter restarts at the *measured* position. |
| 2 | **Pauses were drawn as straight lines.** All points were joined into one line, both on the live map and on the saved activity. | You pause, walk to another street, resume, and get a straight line across the block. | New shared rule (`track_segments.dart`): the line breaks at a pause or long signal gap, so no jump is drawn. Gaps under 50 m (a bridge, tree cover) are still joined. The live map, saved route and distance all use the same rule. |
| 3 | **Fixes from mobile data were over-trusted.** Fixes taken over mobile data or Wi-Fi often carry no speed, which the phone reports as 0. The filter treated "speed 0" as "standing still" and trusted the fix as if it were accurate to 5 m, even when it was only accurate to 20 m. | The line was dragged sideways toward bad cell-tower or Wi-Fi fixes. | The filter always uses the real accuracy, never trusts better than 3 m, and judges whether you're moving from its own estimate when the phone reports no speed. |
| 4 | **The jump detector was tuned badly.** It allowed 12 m/s and ignored GPS uncertainty. At one fix per second, normal jitter looks like sprinting, and a wrong fix 100 m away got through once a few seconds had passed. | Occasional long, thin spikes. | It now subtracts each fix's uncertainty before working out speed, with a 10 m/s ceiling for runs. It also has a 20-second warm-up that rejects coarse start fixes worse than 12 m, which removes the "hook" at the start of runs. |
| 5 | **The live filter was reset in the middle of the run.** The crash-recovery snapshot re-ran the whole track every 10 points, and it did so on the *live* filter, dropping buffered points. Also, the stop detector was never reset, so a saved run was processed differently from the live one. | Small kinks and gaps. The saved route and distance didn't match what you saw while running. | Reprocessing now uses a separate, fresh filter. The stop detector is reset properly. |

**Map-side changes** (`widgets/mwendo_map.dart`):

- **OpenStreetMap basemap.** Tiles now come from OpenFreeMap: OSM data as vector tiles, free, with no API key and no quota. Light mode uses the "Positron" style and dark mode uses "Dark", following the system setting.
  - Vector tiles use far less mobile data than standard OSM picture tiles.
  - They stay sharp at every zoom and scroll smoothly.
  - Loading tiles straight from `tile.openstreetmap.org` inside an app breaks OSM's usage policy, so OpenFreeMap is the compliant way to use OSM data.
  - The OSM attribution stays visible, as the licence requires.
- **Rounded line joins and a white or dark outline under the route.** The old line used sharp joins, which made every tiny GPS zig-zag look like a spike.
- **Your position while running is a blue dot drawn from the filtered track.** It always sits on the end of your line. The old dot was the phone's raw location, which wandered off the route: the "ghosting".
- **Before a run, the map now shows your real location.** Previously it sat on Nairobi until you had recorded a point.
- **Saved runs frame the whole route** and show a green start dot and a brand-colour end dot. Tap the map to re-frame. Previously the map centred on the last point and much of the route was off-screen.
- **Post-run "road snapping" is turned off.** It sent your whole GPS trace over mobile data to a public demo server that only knows car roads. That server would have snapped park and footpath runs onto roads, and nothing in the app used its result. Strava and Apple Fitness don't snap runs to roads either.

**How the best apps do it.** Strava, Apple Fitness, Nike Run Club and similar apps follow the same principles, and the fixes above apply them:

- Request high-accuracy GNSS (satellite positioning) at about 1 fix per second.
- Weight every fix by its reported accuracy.
- Reject physically impossible jumps.
- Never draw a position the GPS didn't measure.
- Break the line at pauses.
- Collapse stops into a single point.
- Smooth the track for display without moving it off your path.

Mobile data helps the phone find satellites faster at the start (assisted GPS). The position itself should still come from satellites, not cell towers. That is what the warm-up and the accuracy weighting enforce.

### Still to do in Part A

1. ~~**Run the tests.**~~ **Done.** Flutter 3.47.9 was installed and every suite passes (see "Implementation status" above). `ground_truth_test.dart` now asserts distance error under 8% (was a loose 60%).
2. **Test on a phone (Android).** Do a 15-minute walk or run that includes at least one sharp corner, one stop at a crossing, and one pause where you walk 100 m before resuming. Expected result:
   - The line follows the path round corners.
   - The stop doesn't scribble.
   - There is a clean break at the pause.
   - The distance shown live matches the saved distance, and both match a course of known length (a running track or a measured road).
3. **Smaller tracking items:**
   - ~~Elevation gain adds up raw GPS altitude noise.~~ **Done:** 3 m hysteresis (Strava-style).
   - ~~GPX export writes one track segment.~~ **Done:** one `<trkseg>` per segment.
   - Auto-pause, as an option. Today stops are suppressed but the clock runs. *(Not done: it's a feature change.)*
   - Colour the route by pace, Apple Fitness-style. *(Optional; not done.)*
   - Phones that never report Doppler speed are still ~+23% on distance (`DISCOVERED_ISSUES.md` #12). Next step if it matters: smooth the saved route before measuring it.

---

## Part B: Design audit against Apple's current playbook

### What "the Apple playbook" means in November 2026

Apple's current design language is **Liquid Glass**, introduced in iOS 26 and revised in iOS 27 (WWDC 2026). The iOS 27 revision mostly fixes legibility: it adds a user setting from "clear" to "tinted" glass and blurs harder behind text. The lasting rules from the Human Interface Guidelines:

1. **Content first. Glass is only for the navigation layer.** Tab bars, toolbars, floating buttons and sheets can be translucent glass. Content (cards, lists, metrics) is solid and calm. Never put glass on top of glass.
2. **Clear hierarchy.** One large title per screen, one primary action, and generous spacing. Group content into inset lists instead of a stack of shadowed cards.
3. **Legibility over decoration.** Use the system typeface with Dynamic Type, so text scales with the user's setting. Meet contrast requirements in both light and dark mode, and respect Reduce Transparency and Reduce Motion.
4. **Consistency.** Use platform-standard controls (sheets with snap heights, standard alerts, segmented controls, switches), and use them the same way everywhere.
5. **Fluid, physical motion.** Use springs, not bounces. Transitions should start immediately and be interruptible, with a haptic at each meaningful moment.
6. **Touch targets of at least 44 × 44 pt.** Use SF Symbols-style icons with consistent weight.

Mwendo runs on Android as well as iOS, so the plan applies these principles in Flutter on both platforms. It doesn't copy iOS screens.

### App-wide findings

| Area | Today | Problem against the guidelines | Change |
|---|---|---|---|
| **Typography** | Three Google Fonts (Big Shoulders condensed display, Work Sans, IBM Plex Mono), **downloaded at runtime**. Nothing is bundled. | Each font is fetched over the network on first launch, which is slow on mobile data and makes text change typeface as it loads. Condensed all-caps display type is hard to read at a glance while running. Three typefaces is noisy, and font sizes are hard-coded in ~30 places, so Dynamic Type isn't honoured. | Use the **system font** (SF Pro on iOS, Roboto Flex/Inter bundled on Android) with **tabular numbers** for every metric. Introduce one typography scale (Large Title 34, Title 28/22, Headline 17 semibold, Body 17, Callout 16, Footnote 13, Caption 12) and remove the hard-coded sizes. Keep a single, rounded, heavy number style for big run metrics (like Apple Fitness). |
| **Colour** | "Red Earth" palette: earth, dawn, highland, a separate recording red, a *different* route red (`#FE2E4B`), and heart-rate zone colours from yet another palette. | Too many competing accents, so nothing reads as "the button". The route colour doesn't match the brand. | **One tint colour** (keep Earth as the brand) for every action. Use system-style semantic colours: green for success/ahead, orange for warnings and pause, red only for recording, stop and SOS. Use the brand tint for the route. Use neutral grey surfaces in light and dark (warm "paper" becomes optional). |
| **Surfaces** | Shadowed cards everywhere, plus gradients on hero cards. | Shadows and gradients compete with the content. | Use flat **inset grouped** sections on a grouped background, with no shadows on content. Keep at most one hero moment per screen. |
| **Navigation bar** | Material `NavigationBar`, 72 pt, with blur behind it. Five tabs: Home, Explore, Run, Learn, You. | The blur is close to Apple's style, but the Material pill indicator and fixed labels read as Android. One label key (`explore_routes`) is long. | A **floating glass tab bar**: translucent, rounded, inset from the screen edge, filled icon plus colour when selected, no pill. Run stays in the centre with a filled accent icon. Short labels: Home · Routes · Run · Learn · You. Respect Reduce Transparency, falling back to a solid bar. |
| **Controls** | 15 Material SnackBars, Material AlertDialogs, `SegmentedButton`, ripple `InkWell`s, `ListTile`s, an extended FAB. | Mixed design vocabulary. Ripples and snackbars are Android patterns. | Adaptive controls: Cupertino-style alerts, action sheets and segmented controls on iOS. Replace snackbars with a small top **toast/banner** on both platforms. Use press-to-dim instead of ripples. Use a single `AppButton` (filled, tinted, plain) everywhere. |
| **Motion** | `Curves.elasticOut` "spring" (bouncy), plus a 6% slide-up page transition on every push. | Bouncy overshoot feels toy-like. Slide-up on every push is a modal gesture, not a navigation one. | Critically damped springs. A native-style horizontal push for drill-down pages (with iOS swipe-back), and vertical presentation only for sheets and modals. Animations shorter than 350 ms, and honour Reduce Motion. |
| **Icons** | Material Rounded icons. | Fine, but stroke weights vary. | One icon style: rounded, regular weight, filled when selected. |
| **Speed** | Runtime fonts, shadows, and a blur behind the bar on every frame. | Dropped frames on mid-range Android. | Bundled fonts, no shadows on lists, `RepaintBoundary` around maps and charts, `const` widgets, and skeletons only when loading takes longer than 300 ms. |

### Screen by screen

The rule for every screen: **in one glance you know where you are, what matters, and what to tap.**

**Home (`dashboard_page.dart`)**
- Today: a top bar with streak and level chips, a weekly card with a gradient, a Start Run button, then Recent, Challenges and Learn sections.
- Problem: the Start Run button duplicates the Run tab, and the streak, level and weekly gradient all compete to be the main thing on screen.
- Plan:
  - A large title ("Good morning, {name}") with your avatar on the right.
  - **One hero: "This week" rings** (distance goal, runs, time), Activity-rings style.
  - Then an inset-grouped "Recent runs" list with a small route preview on each row, a "Challenges" section, and a "Continue learning" section.
  - Start Run becomes a single prominent button in the hero, or is removed in favour of the Run tab.

**Run (`live_dashboard.dart`)**
- The most important screen. Today the map takes 55% of the screen and the metrics 45%. There are status pills, ghost chips and an SOS button on the map, plus a control bar.
- Plan:
  - **Before starting:** a full-screen map with a floating glass card at the bottom showing the activity type, GPS readiness ("GPS ready, ±5 m") and a big round Start button.
  - **While running:** one hero metric (time or distance, which you can swap), three secondary metrics in tabular numbers, and a glass control bar (Pause in the middle, Stop on the left behind a press-and-hold, Lock on the right).
  - SOS goes into a clearly labelled glass button at the top, never next to Stop.
  - Swipe the metrics panel up or down to switch between "Map focus" and "Metrics focus".
  - Large touch targets, readable at arm's length, with a haptic at each km.

**Routes / Explore (`explore_page.dart`, `route_detail_page.dart`)**
- Plan:
  - A full-bleed map with a bottom sheet you can drag to three heights (Apple Maps pattern) listing nearby routes.
  - Route detail shows the OSM map preview, distance, elevation and surface, with a single "Run this route" button.

**Learn (`learn_page.dart`, courses, lessons, legends)**
- Plan:
  - Large title, then a "Continue" card (only one), then horizontally scrolling course shelves, App Store "Today" style.
  - Lessons get a readable layout: 17 pt body, 60–70 characters per line, a progress bar at the top, and Next and Previous controls at the bottom.
  - Legends get one image header, a short biography and a "Race this legend" button.

**You (`profile_page.dart`)**
- Today one long page holds: profile, stats with a segmented week/month/all control, legends, titles, leaderboard, account, settings, theme picker, language, emergency contacts and export.
- That is too much for one screen.
- Plan:
  - A profile header and a stats summary.
  - Then inset-grouped navigation rows: Achievements (legends and titles), Leaderboard, Safety (emergency contacts), Settings (units, appearance, language, data export) and Account.
  - Each row opens its own page.

**Activity list and detail**
- List:
  - Grouped by month, with a route thumbnail, distance, pace and date on each row.
  - Filter chips stay.
  - The extended FAB is removed, since the Run tab exists.
- Detail:
  - A full-width map with the route framed, using the fix from Part A.
  - A metric grid, then pace, elevation and heart-rate charts.
  - Splits table, and Share in the navigation bar.

**Beat the Legends / Ghost race and Challenges**
- Keep everything.
- Apply the unified cards, typography and colour.
- The ghost race keeps one consistent "ahead/behind" colour pair: green and orange.

**Onboarding and Sign-in**
- Three short pages, each with one idea and one button.
- Ask for permissions in context with an explanation first: location just before the first run, notifications when they are first needed.
- "Sign in with Apple" / Google buttons in their standard style.

**Route analysis (`route_analysis_screen.dart`)**
- This is a developer screen (raw, filtered and matched layers).
- Hide it behind a developer toggle in Settings.
- Use it to check the GPS fixes on real runs.

### Rollout: what I'll build, in order

Each phase is shippable on its own and changes visuals only. No feature or data changes.

1. **Foundations: tokens and theme.**
   - Bundle fonts and drop runtime font downloads.
   - New typography scale, colour roles, spacing, corner radii and motion springs in `app_theme.dart`.
   - Light and dark themes, plus Reduce Motion and Reduce Transparency support.
   - Every screen picks this up automatically, so this is the biggest visual change for the least risk.
2. **Shared components** (`widgets/`, `design_system/`):
   - `AppButton` (filled, tinted, plain)
   - Inset grouped section and row
   - Glass bar and glass card
   - Toast/banner (replaces SnackBar)
   - Adaptive alert and action sheet
   - Stat tile, ring and empty state
3. **Navigation:**
   - Floating glass tab bar.
   - Native push transitions with swipe-back.
   - Large collapsing titles.
4. **Run screen**, the highest-value screen: pre-run and in-run layouts, glass controls, press-and-hold stop.
5. **Home and Activity** (list and detail).
6. **You:** split into grouped settings pages.
7. **Learn, Routes, Legends, Challenges, Onboarding:** apply the components.
8. **Polish:**
   - Haptics review.
   - Check Dynamic Type at the largest text size and the accessibility labels.
   - Contrast check in both themes.
   - Measure frame rate in profile mode on a mid-range Android phone.

**Definition of done for each screen:**

- No hard-coded colours or font sizes remain.
- The layout works at the largest text size.
- All touch targets are at least 44 pt.
- It works in light and dark mode.
- No frame takes longer than 16 ms while scrolling.
- Existing widget tests pass.

---

### Sources

- [Liquid Glass (Wikipedia)](https://en.wikipedia.org/wiki/Liquid_Glass)
- [Apple updated its HIG for Liquid Glass (Pixel Envy)](https://pxlnv.com/linklog/hig-liquid-glass/)
- [iOS and iPadOS 27 review (MacStories)](https://www.macstories.net/stories/ios-and-ipados-27-review/2/)
- [iOS 27 Liquid Glass changes (Cult of Mac)](https://www.cultofmac.com/news/liquid-glass-changes-ios-27-macos-27)
- [OpenFreeMap quick start](https://openfreemap.org/quick_start/)

---

## Round 2 (10 November 2026): native iOS look, Legends tab, OSM basemap, Inter

Feedback after seeing the app on the emulator: not enough had changed, the
map didn't look like OpenStreetMap, Routes was useless and Legends were
buried. Done:

| Area | Change |
|---|---|
| Map | Basemap switched to OpenFreeMap's **Liberty** style (classic OSM look) in light and dark mode. Route casing is always white. Only the background tiles changed: the GPS pipeline, segments and distance code are untouched. |
| Navigation | **Routes tab removed** (its data was placeholder); **Legends** is now tab 2. `/explore` and `/learn/legends(/:slug)` redirect to `/legends`. Explore feature files deleted. |
| Legends tab | New `features/legends/`: Legend of the day feature card, "Race a legend" carousel, searchable roster with country segmented control, distance pills and an era action sheet. Each legend has a stable artwork colour. |
| Legend page | Rebuilt like an Apple Music artist page: collapsing gradient header with portrait, Race / Learn buttons, personal-best tiles, expandable About, How you compare, career, records, training, notable races, quote carousel, "Did you know?", rivals and related-legend avatar strips. The made-up "community results" count was removed (it was a formula, not data). |
| Beat the Legends | Large title, distance pills, avatar picker, gradient hero with big target time, segmented difficulty, inset pace chart. **Bug fixed:** target times were passed to `formatDuration` as seconds instead of milliseconds, so a 2:01:09 marathon showed as "00:07" (also in the pre-race sheet). |
| Whole app | `platform: TargetPlatform.iOS` (bounce, Cupertino controls), collapsing large titles on Legends/Learn/You and You sub-pages, SF Symbols-style icons (`cupertino_icons`, from the local pub cache), iOS activity checklist and full-width Start capsule on the Run tab. |
| Font | **Inter 4.1** (github.com/rsms/inter, SIL OFL) bundled for Android: Inter Regular/Italic/Medium/SemiBold/Bold and Inter Display SemiBold/Bold/ExtraBold (~3.3 MB, `app/assets/fonts/`, licence alongside). iOS keeps San Francisco. Tabular figures apply only to number styles (Inter's `tnum` also spaces out hyphens). |
| Learn | Apple Books–style shelves. **Bug fixed:** "Technique" and "Health" both said "Technique & Health" (duplicate heading); now "Technique" and "Health & Nutrition". Tiles no longer overflow at large text sizes, and the page bottom no longer hides under the tab bar. |
| You | Large title, iOS segmented control. **Bug fixed:** the four-stat row overlapped ("0.00 km0"); now a 2 × 2 grid. |
| Home | Layout unchanged (as requested); iOS pull-to-refresh; the recent-runs list now animates (its key had a literal `\${...}` typo). |
| Onboarding | The "Explore routes" slide is now "Race the legends". |

Verification: `flutter analyze` clean; `flutter test` all 67 pass
(`back_navigation_test` updated for `/legends/:slug`); built and checked
screen by screen on the Android emulator.

Open: the ghost pace model's ±10 % split ramp (`DISCOVERED_ISSUES.md` #14).

---

## Round 3 (10 November 2026): real legend portraits

Every legend's emoji was replaced by a real photo where a freely licensed
one exists.

- **Source:** Wikimedia Commons only, licences CC BY, CC BY-SA, CC0, UK OGL
  or public domain. GFDL photos were avoided (impractical in an app).
- **Coverage:** 28 of 30 legends. **Moses Tanui** and **Ibrahim Hussein**
  have no freely licensed photo anywhere on Commons and keep their emoji.
- **Verification:** every photo was checked by eye: the athlete's name is on
  their race bib in most shots (Kipchoge, Sawe, Bekele, Cheptegei, Kosgei,
  Chepngetich, Assefa, Keitany, Jepchirchir, Lornah Kiplagat, Rudisha,
  Dibaba, Defar, Hassan, Edna Kiplagat, Mutai, Kemboi, Chebet), and the rest
  are captioned portraits on Commons. Several first choices were replaced:
  Rudisha (distant aerial shot), Chebet (distant podium), Lornah Kiplagat
  and Ndereba (too small), and seven GFDL photos.
- **Processing:** 800 px (or full-size) originals downloaded, cropped to a
  head-and-shoulders square, resized to 512 px JPEG (~30–75 KB each,
  ~1.3 MB total) in `app/assets/legends/<slug>.jpg`. Originals are not
  bundled.
- **Credits (required by the licences):** `lib/features/legends/legend_photos.dart`
  (generated from Commons metadata) holds author, licence, licence URL and
  file page per legend. Shown as a credit line at the bottom of each legend
  page and in **You → Settings → Photo credits** (tap opens the Commons
  page). Cropped versions of CC BY-SA photos stay CC BY-SA.
- **UI:** `LegendAvatar` shows the photo (emoji fallback) everywhere a legend
  appears: roster, featured card, race cards, legend header, rivals/related
  strips, Beat the Legends picker and hero, pre-race sheet, live ghost
  drawer, home "legend of the day", activity detail and achievements.
- **Known quality limits:** Abel Mutai's only photo is a pack shot, so his
  portrait is grainy; Faith Kipyegon's and Lornah Kiplagat's sources are
  small, so theirs are slightly soft.
- **Personality rights:** using real athletes' photos on biography pages is
  editorial-style use; using them in advertising or store screenshots could
  imply endorsement and may need their consent (not legal advice).

---

## Round 4 (10 November 2026): performance sweep

Measured with an opt-in frame probe (`lib/core/perf/frame_stats.dart`,
`--dart-define=MWENDO_FRAME_STATS=true`) on profile builds, same scripted
scroll/tap scenario each time. The emulator renders through emulated graphics,
so absolute times are pessimistic; the before/after differences are the point.

| Screen (per 120 frames) | Dropped frames before | After | GPU time / frame |
|---|---|---|---|
| Home at rest | continuous redraw (~15 fps) | **0 frames** | — |
| Legends scrolling | 32–71 | **13–17** | 14–21 → ~10 ms |
| Legend page | 40 | **26** | 15 → 12 ms |
| You | 64 | **31** | 21 → 12 ms |
| Learn | 40 | 39 | unchanged |

**Tracking path (matters on long runs):**
- Crash-recovery snapshots used to re-filter the whole run and rewrite every
  row every 10 points (O(n²) per run, on the UI isolate). Now
  `SessionDraftRepository.journalDraft` appends only the new raw fixes
  (serialized writes, idempotent retries); recovery re-derives everything from
  raw fixes as before. Test added.
- The Run screen copied the whole route into new lists twice per second. The
  controller now keeps map-ready `mapSegments`/`flatRoute` incrementally with a
  `routeRevision`; the map pushes the route only when it changes. Very long
  routes are thinned for drawing only (recorded track unchanged).
- The ghost race reuses that list instead of copying it.
- Stop's two identical full re-filters are memoized.
- SQLite runs on a background isolate (`NativeDatabase.createInBackground`);
  run history loads in one query instead of one per run; saved runs build
  their route/elevation/pace lists lazily.

**Rendering:**
- Removed two always-running animations: the Home empty-state runner (looped
  forever) and the Run button "breathing" during recording. Each forced a
  new frame — and a glass-blur re-render — 60 times a second.
- Glass: blurred shadow under the tab bar removed; blurs share one backdrop
  (`BackdropGroup` + `BackdropFilter.grouped`); glass floating over the live
  map no longer blurs (denser tint instead).
- **Adaptive glass** (`lib/core/perf/glass_quality.dart`): in Auto mode the
  app watches its own GPU frame times and, if the device can't keep up,
  switches glass to a solid frosted tint and remembers it. Settings →
  Transparency effects: Auto / On / Off.
- Map: the Liberty style's 3D building extrusions (zoom ≥ 14) are removed at
  load; flat footprints stay.

**Verified on the emulator with simulated GPS:** recording, backgrounding
(foreground service stayed alive and distance kept counting), killing the app
mid-run (recovery offered with the journaled distance and route), resume, and
stop/save (run appears on Home). Fixed along the way: the map stopped
following when a run started (first-round bug), the live pace could show
nonsense like "2179:28" (now "--:--" below walking speed), and the floating
control bar covered the metrics (it double-counted the tab-bar height).

---

## Round 5 (10 November 2026): instant GPS

Reported on a real phone: getting a GPS position always took a long time.
Causes, in order of impact:

1. **Cold start every time.** GPS was only switched on when Start was tapped,
   so every run paid the full satellite-acquisition time.
2. **The Android request waited for an "accurate" first fix**
   (`setWaitForAccurateLocation(true)`), holding back early fixes.
3. **My warm-up gate** rejected anything worse than 12 m for up to 20 s,
   with the pill saying "Searching for GPS" even while fixes arrived.
4. **The pre-run map dot** used MapLibre's default *balanced* (cell/Wi-Fi)
   location engine.

Fixes:

- **GPS warm-up** (`MwendoGpsEngine.warmUp/coolDown`, Android + iOS): starts
  at app launch (90 s) and whenever the Run tab is opened (3 min); stops when
  the app goes to the background. The OS's cached position is shown
  instantly; satellites are locked by the time you tap Start.
- **Instant first point:** recording hands the freshest warm fix to the run.
- Recording request: no wait-for-accurate, no batching.
- Warm-up gate retuned to 15 m / 10 s (tests added).
- Status pill before a run: **Locating…** → **GPS ready ±5 m** (green) or
  **GPS weak ±25 m** (orange); during a run it shows the live accuracy even
  while the pipeline is still holding fixes back.
- Map: centres on the warm-up fix immediately; MapLibre's own dot uses high
  accuracy.

Emulator check (simulated stationary GPS, release build): opening the Run
tab showed the street-level map and **GPS ready ±5 m** within ~1.5 s; one
second after Start the pill read **Recording ±5 m** (previously "Searching
for GPS"). Real-world time to a satellite lock still depends on sky view and
the phone, but it now happens before Start instead of after.

Battery: the warm-up is bounded (90 s / 3 min, never in the background) and
uses the same GPS session the run would use anyway.

---

## Round 6 (10 November 2026): field-test fixes

Reported from a run on a real phone:

1. **"Go for a run" ignored the chosen activity.** The Start button now
   follows the selection: Go for a run / walk / ride / hike, Start drive,
   Start workout (English and Swahili).
2. **No route and no distance after a run.** Several causes, all fixed:
   - **No summary after stopping.** A normal run was saved silently and the
     Run screen just reset, so nothing showed the route or distance. Stopping
     now opens the saved run (map with the route, distance, pace, time). Runs
     are also saved with their real type (Walk, Ride, Hike…) instead of
     always "Run", and the chosen activity is kept for the next run.
   - **Accuracy limits too strict for many phones.** Run fixes worse than
     20 m were all thrown away; budget phones often report 20–35 m outdoors.
     New limits: run 32 m, walk 35, cycle 32, hike 40, drive 50.
   - **"Approximate" location went unnoticed.** Android 12+ lets you grant
     only approximate location (1–3 km), which the app counted as granted;
     every fix was then rejected. The app now detects it, warns before
     starting (Open Settings / Start anyway) and shows a "Precise location is
     off — Fix" banner on the Run screen.
   - **Silent GPS failures.** If the tracking service failed to start, the
     timer kept counting with no GPS behind it. Now the run is stopped (or
     paused, if something was already recorded) with a "GPS couldn't start"
     banner. A "No GPS signal" banner appears if no fix arrives for 25 s, and
     a "Mock location detected" banner if a mock-location app is active.
   - **GPS details.** Tap the status pill on the Run screen for a sheet with
     permission level, accuracy, fixes received / used / rejected and why,
     time since the last fix and the source. If a run ever records nothing
     again, this shows why.
   - After a run the GPS warms up again, so the pill no longer sticks on
     "Locating…".
3. **Overlapping level graphic on the You page.** The separate "Lv 1" ring
   (its label overflowed onto the arc) was replaced by a progress ring around
   the profile photo with a level badge on its edge, the Apple Fitness /
   Game Center pattern. `LevelRing` itself was also fixed (label scales to
   fit) for the Challenges page.

Emulator check (release build): Approximate-only permission showed the
banner; Cycle showed "Go for a ride"; a simulated 80-second run at ~3 m/s,
with the screen locked for 35 s in the middle, drew the full route and
measured 0.25 km (~240 m expected); stopping a simulated walk opened the
saved Walk with its route and 0.18 km; the You header no longer overlaps.
Kotlin compiled; Swift not (no Xcode). app 68/68, gps_pipeline 57/57,
engine 3/3.
