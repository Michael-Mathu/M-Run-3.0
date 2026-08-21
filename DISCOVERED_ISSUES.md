# Discovered Issues

Issues found during remediation execution that aren't in `docs/BUILD_PLAN.md`. Not fixed ad hoc — logged here for later triage.

## From Phase 1 (CQ-1 crash-recovery rewrite) — RESOLVED

1. ~~**`SessionPoints` doesn't persist enough fields for full-fidelity recovery.**~~ **Fixed.** Added `heartRate`/`cadence`/`satelliteCount`/`provider`/`isMocked`/`fixType` columns to `SessionPoints` (schema v3→v4, additive migration) and wired `saveDraft`/`getRecoverable` to round-trip them. Covered by `app/test/session_draft_repository_test.dart`.

2. ~~**`SessionDrafts` doesn't persist `activityType`/`ActivityProfile`.**~~ **Fixed**, same migration as #1. `restoreInterrupted()` now rebuilds the pipeline with the recovered `activityType` instead of always defaulting to `run`.

3. **`MapMatchJob`'s writes to `session_drafts.matchStatus`/`matchedDistanceM` appear to be a dead write-only channel.** Not fixed — this needs a product decision (build a reader, e.g. surface map-matched distance on `route_analysis_screen.dart`, or remove the write path entirely), not a mechanical code fix. Left a clarifying comment in `app/lib/features/tracking/map_match_job.dart` explaining the situation (including that it now frequently races against `CQ-1`'s `_clearRecovery()`, landing on an already-deleted row) so the next person touching this file doesn't have to re-derive it. No functional change.

## From Phase 1 verification — RESOLVED

4. ~~**`app/test/activity_repository_test.dart` has a pre-existing failing test.**~~ **Fixed** as part of `TS-2`: replaced the two JSON-file-format tests with real Drift-path equivalents (empty-rawFixes round-trip, save-twice-replaces-not-accumulates). Full suite is green.
