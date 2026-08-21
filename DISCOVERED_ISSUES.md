# Discovered Issues

Issues found during remediation execution that aren't in `docs/BUILD_PLAN.md`. Not fixed ad hoc — logged here for later triage.

## From Phase 1 (CQ-1 crash-recovery rewrite) — RESOLVED

1. ~~**`SessionPoints` doesn't persist enough fields for full-fidelity recovery.**~~ **Fixed.** Added `heartRate`/`cadence`/`satelliteCount`/`provider`/`isMocked`/`fixType` columns to `SessionPoints` (schema v3→v4, additive migration) and wired `saveDraft`/`getRecoverable` to round-trip them. Covered by `app/test/session_draft_repository_test.dart`.

2. ~~**`SessionDrafts` doesn't persist `activityType`/`ActivityProfile`.**~~ **Fixed**, same migration as #1. `restoreInterrupted()` now rebuilds the pipeline with the recovered `activityType` instead of always defaulting to `run`.

3. **`MapMatchJob`'s writes to `session_drafts.matchStatus`/`matchedDistanceM` appear to be a dead write-only channel.** Not fixed — this needs a product decision (build a reader, e.g. surface map-matched distance on `route_analysis_screen.dart`, or remove the write path entirely), not a mechanical code fix. Left a clarifying comment in `app/lib/features/tracking/map_match_job.dart` explaining the situation (including that it now frequently races against `CQ-1`'s `_clearRecovery()`, landing on an already-deleted row) so the next person touching this file doesn't have to re-derive it. No functional change.

## From Phase 1 verification — RESOLVED

4. ~~**`app/test/activity_repository_test.dart` has a pre-existing failing test.**~~ **Fixed** as part of `TS-2`: replaced the two JSON-file-format tests with real Drift-path equivalents (empty-rawFixes round-trip, save-twice-replaces-not-accumulates). Full suite is green.

## From Phase 2 (`TS-9` — new unit tests for `ghost_race_utils.dart`)

5. **HIGH — `ghostExpectedTimeAtDistance()` in `app/lib/features/beat/ghost_race_utils.dart:6-29` overstates the ghost's elapsed time by roughly one split's duration for most of a race, not just at boundaries.** Root cause: when interpolating within split `lowerIndex`, it computes `lowerTime = splits.take(lowerIndex + 1)...` and `upperTime = splits.take(upperIndex + 1)...` — both sums *already include* the split the runner is currently inside of, instead of `lowerTime` being the cumulative time *before* entering it (`splits.take(lowerIndex)`). Verified with a flat 4-split, 100s/km ghost (`app/test/ghost_race_utils_test.dart`, tests tagged "KNOWN BUG"): at 500m of 4000m (12.5% done, should read ~50s), it returns **150s**; at the exact halfway point (2000m, should read 200s), it returns **300s**. Not fixed here — this task was scoped to adding test coverage, not changing behavior, and the fix affects a live, user-facing number people watch mid-run.
   - **User impact**: this feeds `GhostRaceController.update()`'s `deltaSeconds` (the "you're Xs ahead/behind" ghost-race comparison shown live during a run in `live_dashboard.dart`'s ghost chip, and the split table on `ghost_result_screen.dart` via `computeCurrentSplitComparison`, which also calls this function for `userSplitStartTime`). For most of a race, the app is currently telling users they're roughly one split *further ahead* of the ghost than they actually are — a real, visible correctness bug in one of the app's three headline features ("Beat Legends"), not a cosmetic one.
   - **Suggested fix**: change `lowerTime` to `ghost.splits.take(lowerIndex).fold(0.0, (a, b) => a + b)` (cumulative time *before* `lowerIndex`, i.e. drop the `+ 1`), keep `upperTime` as-is (cumulative time through `lowerIndex`), and interpolate with `t` as the fractional position *within* `lowerIndex`. Needs its own regression test asserting the corrected values (e.g. 500m → 50s, 2000m → 200s for the flat-ghost fixture) once the fix lands, and a check of whether `computeCurrentSplitComparison`'s own math still makes sense once its `ghostExpectedTimeAtDistance` calls return corrected values.
