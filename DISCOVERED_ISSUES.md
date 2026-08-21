# Discovered Issues

Issues found during remediation execution that aren't in `docs/BUILD_PLAN.md`. Not fixed ad hoc — logged here for later triage.

## From Phase 1 (CQ-1 crash-recovery rewrite)

1. **`SessionPoints` doesn't persist enough fields for full-fidelity recovery.** The table (`app/lib/data/database/tables.dart`) stores lat/lng/elevation/timestamp/accuracy/hdop/speedMps for raw fixes, but not `heartRate`, `cadence`, `satelliteCount`, `provider`, `isMocked`, or `fixType`. A recovered run's distance/route/pace/time are all correct, but any heart-rate/cadence data collected before the crash is lost, and every recovered `RawFix` reports `provider: null`, `isMocked: false`, `fixType: 'unknown'` regardless of the original values. Fix would be a small additive migration (new nullable columns on `SessionPoints`) plus updating `saveDraft`/`getRecoverable` to round-trip them. Not done as part of `CQ-1` to keep that diff minimal and avoid an unplanned schema migration.

2. **`SessionDrafts` doesn't persist `activityType`/`ActivityProfile`.** `SessionDraft.activityType` exists in the Dart model but `saveDraft()` never writes it to a column (there isn't one), so a recovered run always resumes pipeline processing with `ActivityProfile.run`, even if the interrupted run was a cycle/drive/walk/hike. This was already true before my change (the old JSON-based `restoreInterrupted()` didn't restore profile either), so it's not a regression — just an existing gap the rewrite didn't fix, since fixing it would require a schema migration outside `CQ-1`'s minimal-diff scope.

3. **`MapMatchJob`'s writes to `session_drafts.matchStatus`/`matchedDistanceM` appear to be a dead write-only channel.** Grepped the whole app: nothing ever reads those two columns back out anywhere (not `route_analysis_screen.dart`, not any repository). `MapMatchJob.processSession()` is still fired (fire-and-forget) from `TrackingModel.stop()` and will now frequently race against `CQ-1`'s new `_clearRecovery()`, which deletes the draft row shortly after — meaning the job's DB update becomes a silent no-op on a missing row. Verified this doesn't change any user-visible behavior (nothing read the old writes either), so left as-is, but worth a real audit of what `MapMatchJob` is actually supposed to feed — it looks like unfinished plumbing for a route-analysis feature that never got wired to a reader.

## From Phase 1 verification

4. **`app/test/activity_repository_test.dart` has a pre-existing failing test**, confirmed unrelated to this session's changes (reproduces identically via `git stash` against the unmodified branch tip). This is the exact issue already tracked as `TS-2` in `docs/BUILD_PLAN.md` Phase 2 — noted here only as confirmation it's real and currently red, not a new finding.
