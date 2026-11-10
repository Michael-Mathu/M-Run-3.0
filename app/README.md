# Mwendo Client Application (`app`)

Mwendo is a high-precision, offline-first GPS running application featuring East African heritage-driven virtual pacing ("Beat the Legends"), mathematical state-space telemetry filtering, and zero-loss crash recovery.

---

## 🏃 Key Features

### 1. Ghost Racing & Virtual Pacing (Pillar 4)
Race in real-time against mathematical models of iconic world-record performances across distances from 800m to Marathon, or race against your own local offline activities:

- **12 Legend Ghosts**: Eliud Kipchoge, Kelvin Kiptum, Paul Tergat, Faith Kipyegon, Beatrice Chebet, David Rudisha, Kenenisa Bekele, Joshua Cheptegei, Brigid Kosgei, Ruth Chepngetich, Haile Gebrselassie, Kipchoge Keino.
- **Offline Ghost Race**: Convert any previous local `RunRecord` into an offline ghost pace via `toGhostPace()` and race your past personal bests with zero network connectivity.
- **4 Difficulty Tiers**: Bronze (125% of WR) → Silver (110%) → Gold (102%) → G.O.A.T. (100% WR).
- **Live Map Visualization**: Ghost route (dashed polyline) + animated pulsing ghost marker at interpolated position along runner route.
- **Per-Split Comparison**: Swipe-up HUD drawer displaying split progress bar, target vs projected time, live delta ($\pm\text{mm:ss}$), and status icon.
- **Pre-Race Sheet**: Tier selector, split table preview, PB context, and personalized tier recommendation based on personal bests.
- **Post-Race Results & Reconciliation**: Full-screen hero with win/loss detection, route overlay, split comparison table, summary metrics, and rematch CTAs.

### 2. Core GPS Tracking & Multi-Stage Telemetry
- **Single Source of Truth**: All distance, pace, and split calculations are driven by the deterministic `gps_pipeline` (Kalman state-space filtered and stationary-suppressed points). Distance is integrated from the phone's Doppler speed (`DistanceAccumulator`), and the live screen and the saved run use the same calculation.
- **No phantom lines**: the track is split into segments at pauses and long signal gaps (`TrackSegments`), so a gap is never drawn as a straight line. The filter never draws a position the GPS didn't measure.
- **Live Signal Quality HUD**: Dynamic `StatusPill` displaying real-time GPS horizontal accuracy in metres, color-coded readiness warnings, and satellite telemetry.
- **Interactive Auto-Follow Affordance**: One-tap glass follow button (`GlassIconButton` in `MwendoMap`) to lock/unlock map tracking or inspect route progress freely.
- **Auto-Pause Semantics Overlay**: Visual feedback card explaining stationary suppression thresholds and manual override options.
- **Hold-to-Stop**: the Stop button must be held for 0.8 s, so a run can't be ended by an accidental tap.
- **Route Analysis Screen** (debug builds only): diagnostic breakdown of raw vs filtered tracks, GPS accuracy distribution, and rejection counts. Post-run OSRM map matching is no longer used (it uploaded the trace and snapped footpath runs onto car roads).

### 3. Resilience & Offline-First Storage
- **Drift SQLite Relational Database**: Fast on-device persistence via `AppDatabase` across `activities`, `activity_points`, `session_drafts`, and `session_points`.
- **Durable Session Drafts**: Real-time atomic journaling that enables instant recovery if the OS terminates the app during an active workout.
- **GPX Export**: Industry-standard GPX 1.1 workout track exports, one `<trkseg>` per track segment so exports match the map.

### 4. Apple-Style Interface (November 2026 refresh)
- System font with tabular figures, Apple semantic colours, neutral grouped surfaces, capsule buttons, iOS-style push transitions and press feedback.
- Floating "Liquid Glass" tab bar with a centre Run button; glass controls on the live run map.
- Respects Reduce Motion and Increase Contrast; 44 pt minimum tap targets.
- Details: [`docs/DESIGN_SYSTEM.md`](../docs/DESIGN_SYSTEM.md) and [`docs/REVAMP_PLAN.md`](../docs/REVAMP_PLAN.md).

### 5. Legends Tab (November 2026)
- The second tab (it replaced the placeholder Routes/Explore tab, whose data was sample-only).
- Legend of the day feature card, a "Race a legend" carousel, and the full searchable roster (country segmented control, distance filters, era filter).
- Each legend has an Apple Music–style profile page: collapsing artwork header, personal bests, story, how you compare, career, records, quotes, rivals and related legends.
- Real portraits for 28 of 30 legends (Wikimedia Commons, free licences; credits on each page and in Settings → Photo credits).
- Old links (`/learn/legends`, `/explore`) redirect to `/legends`.

### 6. Bilingual Localization
- **English + Swahili (`sw`)**: In-app language switching for all screens, training courses, and heritage profiles.
- **Localized Content**: Legends and course prose use `LocalizedText` `(en, sw)` pairs rendered via the `lt()` resolver.

---

## 🏗️ Architecture

- **State Management**: Riverpod 2.5+ (`NotifierProvider` and code generation patterns).
- **Navigation**: GoRouter with `StatefulShellRoute` for bottom navigation tabs.
- **Mapping**: MapLibre GL with OpenStreetMap vector tiles from OpenFreeMap (free, keyless, no quota) in the `liberty` style — the classic OpenStreetMap look, used in light and dark mode. Vector tiles keep mobile-data use low.
- **Database**: Pure Drift SQLite database (`ActivityRepository`).

---

## 🚀 Getting Started

### Prerequisites
* Flutter SDK: `^3.22.0` (Dart `^3.12.0`). Verified with Flutter 3.47.9 / Dart 3.13.7 (November 2026).

### Installation & Run
```bash
flutter pub get
flutter run
```

### Testing & Analysis
```bash
flutter analyze
flutter test
```
