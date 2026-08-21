# Mwendo / M‑Run — Follow‑up Audit & Plan (AUDIT_2)

**Date:** 2026‑08‑21
**Branch audited:** `remediation/phase-1` @ `67bb9bd`
**Method:** static review + full test-suite runs + **live on-device testing** (Pixel 7 emulator, debug build, both locales)
**Scope:** (1) verification of the completed `docs/BUILD_PLAN.md` work; then three new workstreams — (2) Kiswahili localization, (3) UI/interface professionalism, (4) functional checks of existing features (SOS, ghost‑race "Beat the Legends", and others found along the way).

This document is honest about what is broken. Several headline features look finished but are not wired to real behavior. Findings cite file:line and, where tested, describe the exact on-device observation. Nothing below has been fixed yet except where explicitly noted — this is the findings + plan; execution is a separate, gated step.

---

## 0. Executive summary

**The BUILD_PLAN.md remediation holds up.** All three test suites are green (app 65/65, backend, gps_pipeline 41/41), `flutter analyze` is clean, and the app builds and launches on a real Android emulator. One latent defect was surfaced *by* launching it (an invalid XML comment in `network_security_config.xml` that `flutter analyze` cannot see) and was fixed this session (`67bb9bd`). See §1.

**But the three new workstreams surface serious problems, two of them safety- or trust-critical:**

| # | Severity | Finding | Evidence |
|---|----------|---------|----------|
| A1 | **Critical** | **SOS does not send anything and gives no failure signal.** The countdown says "Sending SOS / Alerting contacts", completes, and then silently does nothing when the SMS intent can't be launched. Tested on-device: countdown finished, app returned to the map, no SMS composer, no error. | §4.1, on-device |
| A2 | **Critical** | Even on a real phone, SOS only *opens the SMS composer* — it never auto-sends. The "Sending…" UI is a lie. Multi-contact SOS is additionally broken (launches N `sms:` intents in a tight loop; only one composer can foreground). | §4.1, `safety_service.dart:4-13` |
| B1 | **High** | **You can "beat" a ghost without covering the distance.** Win = average pace ≤ ghost pace, with no completion/distance gate. Sprint 150 m and you beat a marathon legend. | §4.2, `live_dashboard.dart:590-608` |
| B2 | **High** | Ghost live-comparison math overstates your lead by ~one split for most of a race (`ghostExpectedTimeAtDistance`), unchanged since it was logged as DISCOVERED_ISSUES #5. | §4.2, `ghost_race_utils.dart:24-26` |
| C1 | **High** | **The entire "Routes" tab (a primary bottom-nav destination) is hardcoded sample data**, English-only, marked "will be replaced with real data". | §3.3 / §4.3, `explore_provider.dart:101` |
| D1 | **Medium** | **56% of Academy course content (181/319 en/sw pairs) is English pasted into the Swahili field** ("English-in-disguise"). Confirmed visible in-app: switch to Kiswahili and lesson bodies stay English. | §2.1, measured |
| D2 | **Medium** | A cluster of real Swahili *mistranslations* in otherwise-translated UI keys (e.g. "Stop run" → "Sita mbio" = "six runs"; "Locked" → "Imefuliwa" = "has been laundered"), plus one truncated and one dangling string. | §2.2 |

The UI *string catalog* itself is in good shape (315 UI pairs, only 6 legitimately identical). The localization problem is concentrated in **content data files** and a **handful of wrong translations**, not in coverage of the app chrome — an important distinction for planning.

---

## 1. Part 1 — Verification of completed BUILD_PLAN.md work

### 1.1 Current state: green

| Check | Result |
|---|---|
| `flutter analyze` (app) | ✅ No issues found |
| `flutter test` (app) | ✅ 65/65 pass |
| `go build ./...` + `go test ./...` (backend) | ✅ pass |
| `dart test` (gps_pipeline) | ✅ 41/41 pass |
| First real Android build + launch | ✅ builds, installs, launches to onboarding |
| UX‑5 work verified live | ✅ activity selector, recovery card strings, route-analysis screen all localize on-device |

The Phase 1–6 work described in `PROGRESS.md` is real and stands. No regressions were found in the committed diffs.

### 1.2 Defect surfaced by first real launch — already fixed this session

`app/android/app/src/main/res/xml/network_security_config.xml` (added in the SEC‑3 fix) contained ` -- ` used as an em‑dash **inside an XML comment**. XML forbids `--` anywhere in a comment; AAPT rejected the file with a `SAXParseException` and **every debug build failed**. `flutter analyze` does not validate Android resource XML, so it passed CI-style checks and only failed at `flutter run`.

- **Fixed:** commit `67bb9bd`, verified by building + launching on the emulator.
- **Lesson for the plan:** analyze/test green is necessary but not sufficient. Android/iOS resource XML, Gradle config, and plist changes need an actual platform build in CI. The `TS-1`/`OPS-6` CI already has a build step; it should be treated as a hard gate for any change under `android/` or `ios/`.

### 1.3 Still open / blocked (unchanged, re-confirmed)

These were correctly left blocked pending your decisions and remain so — this audit does not change their status, but note that **§4 below turns several of them from "unverified concern" into "confirmed defect":**

- `UX-1` (SOS) — now **confirmed broken on-device**, not just a copy question. See §4.1.
- `SEC-2` (JWT_SECRET fail-fast), `OPS-2` (release signing / keystore), `SEC-4/5/6/7` (auth/privacy behavior), `CQ-11` (FIT parser), `UX-3` (Explore/Routes) — unchanged. `UX-3` is now **confirmed to be shipping fake data on a primary tab** (§4.3).
- DISCOVERED_ISSUES #5, #6, #7, #8 — all still present; #5 re-confirmed live-relevant (§4.2).

---

## 2. Workstream A — Kiswahili localization

### 2.1 The real gap is content data, not UI chrome (measured)

| Source | en/sw pairs | Identical (untranslated) | % untranslated |
|---|---|---|---|
| `app/lib/core/l10n/app_strings.dart` (UI catalog) | 315 | 6 (all legitimate: `km`, `meters`, `imperial`, `proj`, `zoom_label`, `theme_berry`) | ~2% ✅ |
| `app/lib/features/learn/data/courses.dart` (Academy) | 319 | **181** | **56%** ❌ |
| `app/lib/features/learn/data/legends.dart` (bios) | 536 | 56 | 10% ⚠️ |
| **Total content** | **855** | **237** | **27%** |

**On-device confirmation:** with the app set to Kiswahili, the Learn tab chrome and most course titles localize correctly (e.g. "Fuel for the Run" → "Lishe ya Mbio"), **but** lesson *paragraphs* render in English, and some course titles/subtitles never translated at all (e.g. the "Stay Injury‑Free" card stays English on the Swahili Learn screen). This matches the 56% figure: titles/summaries were partly done; the multi-paragraph bodies were bulk-copied from English.

This is the same `UX-2` gap the first audit flagged, now quantified precisely. It is **content/translation work, not engineering** — it needs a fluent Kiswahili speaker, ideally one comfortable with running/sports register. It must not be machine-translated silently.

### 2.2 Genuine Swahili **mistranslations** in the UI catalog (engineering-adjacent, fixable now)

These keys *are* translated, but incorrectly. Unlike §2.1 these are small, high-visibility, and a competent reviewer can fix them quickly:

| Key (`app_strings.dart`) | Current `sw` | Problem | Suggested |
|---|---|---|---|
| `stop_run` (:186) | `Sita mbio` | "Sita" = *six* / *I won't*; nonsense here | `Simamisha mbio` |
| `locked` (:175) | `Imefuliwa` | = *has been laundered/washed* | `Imefungwa` |
| `recenter_map` (:434) | `Rudisha ramani katik` | **truncated** ("katik" → "katikati") | `Weka ramani katikati` |
| `discipline` (:212) | `Nidhamu` | = *orderliness/discipline of conduct*, not a sporting event | `Mchezo` / `Aina ya mbio` |
| `alerting_contacts` (:223) | `Inatahadharisha anwani katika ` | **dangling** — a trailing preposition with no value ever concatenated (visible on-device as "…katika " with nothing after) | rework as a full sentence with the countdown substituted, e.g. `Inatahadharisha anwani baada ya {n}s` |
| `start_run` (:65) | `Nenda ukimbi` | `ukimbi` → `ukimbie` | `Nenda ukimbie` |
| `first_run_prompt` (:100) | `Tokea kwa mbio yako ya kwanza.` | "Tokea" is awkward | `Anza mbio yako ya kwanza.` |
| `all_caught_up` (:116) | `Umekwisha yote!` | awkward | `Umemaliza zote!` |
| `kilocalories` (:433) | en `kcal` / sw `kilokalori` | register mismatch (abbrev vs full word) | keep `kcal` both, or `kkal` |

### 2.3 Architectural gaps in localization

1. **No placeholder substitution engine.** `L10n.tr()` returns the raw string; only two call sites manually `.replaceFirst('{…}', …)` (`legend_detail_page.dart:611`, and `no_route_recorded`). Keys carrying `{name}`/`{userPace}`/`{ghostPace}` placeholders (`ghost_held_off`, `you_beat_ghost`) are **dead** — superseded by non-placeholder variants (`ghost_held_you_off`, `you_beat`). Risk: the next person who reuses a `{placeholder}` key will ship literal `{name}` to users. Add a tiny `L10n.tr(key, locale, params: {...})` that substitutes, and delete the dead keys.
2. **Pluralization is unhandled** (see §3.2, "1 Emergency contacts" / "1 Anwani za dharura").
3. **Content in `explore_provider.dart` is English-only** regardless of locale (§4.3) — route/segment names never pass through any localization at all.

### 2.4 Plan — localization

| ID | Task | Effort | Owner | Notes |
|---|---|---|---|---|
| L‑1 | Fix the §2.2 mistranslations (9 keys) | S (<2h) | eng + any Swahili reader | Mechanical; no behavior change. Do first — cheap, high-visibility. |
| L‑2 | Add placeholder substitution to `L10n.tr`; delete dead `{…}` keys; migrate the 2 manual call sites | S (2‑3h) | eng | Prevents a whole future bug class. |
| L‑3 | Real Swahili pass on `courses.dart` (181 bodies) | L (weeks, content) | **fluent translator** | Split per course; review by 1 eng for structural integrity + 1 native speaker. **Do not machine-translate.** |
| L‑4 | Swahili pass on `legends.dart` (56 remaining) | M (content) | translator | Lower volume; mostly proper nouns already handled. |
| L‑5 | Add an "identical en==sw" guard test over content files (warn threshold) so new English-in-disguise pairs are caught in CI | S | eng | Same spirit as the existing `l10n_keys_test.dart`. Start as report-only (there are 237 today), ratchet down as L‑3/L‑4 land. |

---

## 3. Workstream B — UI / interface professionalism pass

Assessment from live screenshots in both locales across Onboarding, Run/track, Home, Learn, Profile, and the SOS dialog. Overall the visual language is **coherent and reasonably polished** — consistent dark theme, good type hierarchy, sensible spacing, working theme + language toggles, accessibility semantics present (from UX‑5). The issues below are the gap between "looks like a real app" and "feels finished".

### 3.1 Layout / polish issues

| ID | Severity | Screen | Issue |
|---|---|---|---|
| U‑1 | Medium | Run / track | The primary orange **Play FAB overlaps the Walk/Cycle/Hike/Drive 2×2 grid**, sitting on top of the grid's center gap. It reads as an accidental overlap rather than an intentional focal point, and its glow bleeds onto the cards. Consider anchoring the FAB below the grid or giving the grid a center gutter sized for it. |
| U‑2 | Low | Run / track | The map shows Google HQ / Mountain View (emulator default location) with no run started — expected in-emulator, but confirm the "searching for GPS" empty state and permission-priming actually show on a real cold start. |
| U‑3 | Low | Home | On navigating back to Home, a card can be left **clipped at the top edge** (retained scroll offset). Low confidence it's a true layout bug vs. scroll state; verify whether Home should reset scroll to top on tab re-selection. |
| U‑4 | Low | Learn | Section carousels intentionally clip the next card ("Stay Inj…", "A Histor…") as a scroll affordance — acceptable, but the **first section header sits flush under the translucent app bar** with little breathing room. Add top padding below the app bar. |

### 3.2 Copy / correctness in the UI

| ID | Severity | Where | Issue |
|---|---|---|---|
| U‑5 | Medium | Profile → Emergency contacts (`profile_page.dart:273`) | **"1 Emergency contacts"** — no pluralization; worse in Swahili ("1 Anwani za dharura"). Needs count-aware phrasing in both languages. |
| U‑6 | Medium | Home | "How to Start Running" appears twice on one screen (Continue-learning card **and** a promo banner under Recent Activity). Redundant; pick one placement. |
| U‑7 | Low | Profile | Language toggle selected-state fill is a muted olive/khaki that doesn't match the Kinetic-Orange accent used everywhere else; reads as a different design system. |

### 3.3 Placeholder/fake content presented as real

| ID | Severity | Where | Issue |
|---|---|---|---|
| U‑8 | **High** | Routes tab (`explore_provider.dart`) | Entire tab is hardcoded sample routes/segments/leaderboards with placeholder-quality copy ("finish at CBD landmarks", "close to actual course"), English-only. See §4.3. A primary nav tab should not ship stub data without a "Preview/Coming soon" treatment. |

### 3.4 Plan — UI professionalism

| ID | Task | Effort |
|---|---|---|
| U‑1 fix | Rework Run-screen FAB/grid layout so the play button doesn't overlap activity cards | S‑M |
| U‑5 fix | Count-aware pluralization for emergency-contacts label (depends on L‑2 substitution or a small helper) | S |
| U‑6 fix | De-duplicate the "How to Start Running" entry on Home | XS |
| U‑7 fix | Align language-toggle selected fill with the active palette accent | XS |
| U‑4 fix | Add top padding under Learn app bar; verify Home scroll-reset (U‑3) | S |
| U‑8 | Product decision on Routes tab: wire real data, or mark it "Preview" and localize the sample copy (ties to `UX-3` / §4.3) | M‑L |

---

## 4. Workstream C — Functional checks of existing features

### 4.1 SOS — **CRITICAL, confirmed broken on-device**

**What the code does** (`app/lib/features/safety/safety_service.dart:4-13`):
```dart
static Future<void> sendSos(List<EmergencyContact> contacts, double lat, double lng) async {
  final locationUrl = 'https://maps.google.com/?q=$lat,$lng';
  for (final contact in contacts) {
    final smsBody = 'Mwendo SOS: I need help. Location: $locationUrl';
    final uri = Uri.parse('sms:${contact.phone}?body=...');
    if (await canLaunchUrl(uri)) { await launchUrl(uri); }   // opens composer; never sends
  }
}
```

**On-device test (Pixel 7 emulator, contact "Mathu" configured):**
1. Tapped the SOS shield → confirmation → 3‑2‑1 countdown titled **"Inatuma SOS" (Sending SOS)** with **"Inatahadharisha anwani…" (Alerting contacts…)**.
2. Let it complete.
3. **Result: dialog dismissed, app returned to the map, `topResumedActivity` still `com.mwendo.mwendo_app/.MainActivity`. No SMS composer, no error toast, no confirmation.** The emulator has no SMS handler, so `canLaunchUrl` was false and `sendSos` silently did nothing.

**Three distinct defects:**
1. **Silent failure (Critical).** When the intent can't launch, the user is shown a "Sending SOS" success flow and then nothing — they believe help is on the way. For a safety feature this is the worst possible failure mode. There must be an explicit failure surface ("Couldn't open your messaging app — call for help directly").
2. **"Sending" is a lie even on success (Critical).** Best case, `launchUrl` opens the SMS composer pre-filled; the user still has to hit send. The countdown/"Sending SOS/Alerting contacts" copy claims automatic dispatch that never happens.
3. **Multi-contact is broken (High).** The `for` loop fires N `sms:` intents back-to-back; a device can only foreground one composer, so contacts 2..N are dropped. Even the honest "open a composer" behavior only works for the first contact.

**This is the crux of the still-open `UX-1` decision, now with evidence.** Two honest paths:
- **(a) Honest manual path:** relabel the flow ("Prepare emergency message"), open **one** composer with all contacts in the recipient list, and on `canLaunchUrl==false` fall back to a visible error + a one-tap dialer. No claim of auto-send. Ships quickly, safe.
- **(b) Real auto-send:** requires a backend SMS/push gateway (Twilio/Africa's Talking, etc.), consent, and cost/abuse controls — a real project, not a copy fix.

Given it's safety-critical and currently actively misleading, **(a) should ship regardless**, even if (b) is later pursued.

### 4.2 Ghost race ("Beat the Legends") — **High**

**B1 — win without covering the distance.** In `live_dashboard.dart` the finish handler (`:590-608`) determines the result as:
```dart
final userAvg = (elapsedMs/60000)/(finalDistanceM/1000);
final beat = userAvg <= ghost.avgPaceMinPerKm;   // pace-only; no distance/completion gate
```
The only guard on finishing is `m.distanceM >= 1` (metre). So a user can start a marathon ghost, sprint 150 m, stop, and be told **"You beat Kipchoge! 🏆"**. The ghost's `distanceKm` is never compared against the user's actual distance. **Fix:** gate the win on covering (within tolerance) the ghost's distance; otherwise present it as "did not finish" or compare only over the distance actually run.

**B2 — live delta overstates your lead (DISCOVERED_ISSUES #5, still present).** `ghost_race_utils.dart:24-26` computes the pre-split cumulative time with `take(lowerIndex + 1)` instead of `take(lowerIndex)`, so `ghostExpectedTimeAtDistance` returns ~one split too much for most of a race. This feeds the live "you're Xs ahead/behind" chip and the split table. There is already a "KNOWN BUG" locking test; the fix is a ~3-line change plus updating that test to assert corrected values.

**B3 — dead computation.** `ghost_race_utils.dart:35`: `ghostProjectedFinishTime` calls `ghostExpectedTimeAtDistance(...)` and discards the result. Harmless but confusing; remove.

**B4 — stale ghost position (Low).** `GhostRaceRacingData.copyWith` (`ghost_race_controller.dart:263`) uses `ghostPosition ?? this.ghostPosition`, so once set it can never be cleared back to null (same nullable-copyWith class as CQ‑16). Minor.

### 4.3 Explore / Routes tab — **High** (confirms `UX-3`)

`explore_provider.dart:88-96` builds the entire tab from module-level `_sampleRoutes` / `_sampleSegments` / `_sampleLeaderboards` with the comment *"Sample data for explore - will be replaced with real data from repository."* It's a **primary bottom-nav tab** ("Njia/Routes") shipping fabricated routes, segments, and a fake elite leaderboard, all English-only. Either wire it to real data or mark it clearly as a preview and localize the copy.

### 4.4 Other functional observations

- **Emergency-contacts persistence** works (contact survived across navigation; `safety_provider.dart` SharedPreferences round-trip is sound).
- **Language + theme + units toggles** all work live and persist (verified on-device).
- **Activity selection / recovery / route-analysis** (UX‑5 work) function and localize correctly on-device.
- **Ghost split table "completed split" rows** (`ghost_race_controller.dart:134-139`) show the same projected average for every completed split rather than per-split times — misleading but lower priority than B1/B2.

### 4.5 Plan — functional

| ID | Task | Severity | Effort | Gate |
|---|---|---|---|---|
| F‑1 | SOS honest path (a): relabel, single composer with all recipients, visible failure + dialer fallback, remove the "auto-send" implication | **Critical** | M | **Safety-sensitive — needs your sign-off on copy + fallback behavior before merge.** |
| F‑2 | Decide on SOS real auto-send (b) — backend gateway, consent, cost controls | Critical (product) | L | Product decision; out of scope for a code pass. |
| F‑3 | Ghost win-condition: gate on ghost distance covered (B1) | High | S‑M | Behavior change to a headline feature — sign-off. |
| F‑4 | Fix `ghostExpectedTimeAtDistance` (B2) + update KNOWN-BUG test | High | S | Behavior change; has a locking test. |
| F‑5 | Remove dead `ghostProjectedFinishTime` call (B3); fix ghost-position copyWith (B4) | Low | XS | Safe. |
| F‑6 | Routes tab: real data or explicit "Preview" + localized copy (U‑8/UX‑3) | High | M‑L | Product decision. |
| F‑7 | Per-split projected times for completed splits (§4.4) | Low | S | Safe. |

---

## 5. Consolidated priority & sequencing

**Do now (safe, cheap, high-value; no behavior/product decisions):**
1. L‑1 (Swahili mistranslations), L‑2 (placeholder engine + dead-key cleanup)
2. U‑5/U‑6/U‑7 (pluralization, dup Home entry, toggle color), F‑5 (dead ghost code)
3. L‑5 (content untranslated-guard test, report-only)

**Do next, but gated on your sign-off (behavior/safety changes to shipped features):**
4. **F‑1 — SOS honest path (Critical).** Highest priority of everything here; the current flow actively misleads users in an emergency.
5. F‑3, F‑4 (ghost win-condition + delta math)
6. U‑1 (Run-screen FAB overlap), U‑4 (Learn padding)

**Product decisions required before work can proceed:**
7. F‑2 (SOS auto-send infra), F‑6 / U‑8 (Routes tab real data vs. preview), and the still-open BUILD_PLAN blockers (`SEC-2/4/5/6/7`, `OPS-2`, `CQ-11`).

**Content track (parallel, needs a human translator):**
8. L‑3 (courses.dart, 181 bodies), L‑4 (legends.dart, 56).

### Definition of done for this audit's remediation
- SOS never claims to send without either sending or showing a clear failure + fallback (F‑1).
- No ghost "win" is possible without covering the ghost distance (F‑3); the live delta is numerically correct (F‑4).
- No primary tab ships fabricated data unlabeled (F‑6/U‑8).
- Swahili UI has no semantic mistranslations (L‑1); `{placeholder}` keys can't leak literal braces (L‑2).
- A CI guard prevents new English-in-disguise content pairs (L‑5); course/legend content translation tracked to completion (L‑3/L‑4).

---

## Appendix — verification commands run
- `flutter analyze` (app) → clean
- `flutter test` (app) → 65/65
- `go build ./... && go test ./...` (backend) → pass
- `dart test` (gps_pipeline) → 41/41
- `flutter run -d emulator-5554` → built, installed, launched; drove Onboarding → Run → Home → Learn → Profile → SOS in both en/sw and captured screenshots.
- Untranslated-content measurement: regex pair-diff over `courses.dart` / `legends.dart` (855 pairs, 237 identical).
