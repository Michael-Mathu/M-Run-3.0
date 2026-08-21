# Remediation Progress

Autonomous execution of `docs/BUILD_PLAN.md`, started 2026-08-21. One entry per phase boundary. Working on branch `remediation/phase-1` (local only, not pushed).

## Phase 1 — Stabilize — PAUSED at a hard stop, 7/10 done

**Done and verified** (backend: `go build`, `go vet`, `go test ./...` all green, including a new concurrency regression test; app: `flutter analyze` clean, `flutter test` run — see note on pre-existing failure below):

- `CQ-1` — Crash recovery rewired to the Drift `SessionDrafts`/`SessionPoints` journal. Added `SessionDraftRepository.getRecoverable()` / `.deleteDraft()`; rewrote `hasRecoverableRun()`/`restoreInterrupted()`/`_clearRecovery()` in `tracking_controller.dart` to use them instead of the dead `mwendo_recovery.json` path. Also fixed a bug this surfaced: `restoreInterrupted()` never set `_draftId`, so a resumed-then-continued run silently stopped journaling and `discardRecovery()` had no id to delete. Known limitation logged to DISCOVERED_ISSUES.md: `SessionPoints` doesn't store heartRate/cadence/satelliteCount/provider/isMocked/fixType, so a recovered run loses those fields (distance/route/time are unaffected).
- `CQ-2` — `ghost_result_screen.dart` now really `jsonDecode`s `routePointsJson`/`splitsJson` into `LatLng`/`SplitComparison` lists instead of discarding them.
- `CQ-3` — Fixed the unreachable `else if (newly.isNotEmpty && mounted)` in `live_dashboard.dart` — regular challenge celebrations now fire correctly alongside (not instead of) ghost-race ones.
- `CQ-4` — `AppDatabase.saveRun` and `SessionDraftRepository.saveDraft` both now wrap their multi-step writes in `transaction()`.
- `CQ-15` — **Does not reproduce.** Read `app_database.dart`'s `onUpgrade`: all 7 new `ActivityPoints` columns, including `state`, are already added (`from < 2` block, lines ~28-36). The audit's specific claim ("adds 6 of 7, omits `state`") doesn't match the current file. No fix made. Flagging this as a reminder that audit findings need re-verification against current code, not blind execution — exactly per the plan's own guidance.
- `SEC-1` — `refreshTokens` in `backend/internal/auth/handler.go` switched from a plain `map[string]string` to `sync.Map`. Judged this a pure internal concurrency fix with no externally observable behavior change (same tokens, same responses, just no longer crashes under concurrent access) — proceeded without stopping, per the operating rules' "pure refactors with no behavior change are fine to continue through." Added `handler_test.go` with a 50-goroutine concurrent-login regression test; passes (couldn't run with `-race`, this environment's Go has no cgo/C compiler available, but the original bug was a fatal, unconditional runtime panic on any concurrent map write, not just a `-race`-only race — this test would have caught it either way).
- `OPS-1` — Added a named `mwendo_db_data` volume to `docker-compose.yml`'s `db` service.

**Blocked — stopped here per your hard-stop rules, need your input before continuing:**

- `SEC-2` (fail fast on missing/default `JWT_SECRET`) — this changes backend startup behavior and could break an existing deployment relying on the silent default; your rules mark "any behavior change to auth... security-sensitive logic" as a hard stop regardless of how small. Question for you: fail hard immediately, or ship a one-release warning-only grace period first (as BUILD_PLAN §1 suggested)? And what should `ENV` be set to for the check to trigger — is there a real deployment to coordinate with, or is this dev-only so far?
- `UX-1` (SOS behavior/copy) — BUILD_PLAN §1 lays out two real paths (honest-copy vs. real-auto-send) that aren't equivalent in effort or risk, and this is a safety-critical feature. Need you to pick a direction before I touch it.
- `OPS-2` (stop shipping the debug APK as a release) — I can change `release.yml` to build a proper release APK/AAB, but signing it requires a real keystore file + passwords that only you can provide/generate; I have no way to create trustworthy signing material myself. Need the keystore (or a decision to defer this item) before I can do anything here.

Nothing in Phase 2+ has been started — Phase 1 isn't fully clear yet, and per the dependency map, several Phase 2/3 items (`TS-3`, `CQ-9`) build directly on Phase 1 items that are still open.

### Pre-existing issue observed, not introduced by this session
`flutter test` has one pre-existing failure: `activity_repository_test.dart`'s "list() is null-safe for missing optional list fields in older files" (expects a JSON-file-backed repo behavior; the real repo is Drift-backed). Confirmed via `git stash` that this fails identically on the unmodified `main` branch tip — this is the exact `TS-2` finding from the audit (Phase 2 work), not a regression from anything in this phase. Fixed in Phase 2 (see below).

## Phase 2 — Foundation — DONE, 12/12 (all items either completed-and-verified or completed-with-an-explicit-unverified-caveat)

All items done. Two categories worth flagging clearly:

**Verified by actually running them** (analyze/test/build all green throughout): `TS-2` (rewrote the stale test — fixed the pre-existing failure above), `TS-3` (adapted — `CQ-15` didn't reproduce, added `session_draft_repository_test.dart` for the real v3→v4 migration this session added instead), `TS-4`/`TS-5` (ground-truth asserting test — surfaced `DISCOVERED_ISSUES.md` #7, a ~46% cumulative-distance overshoot on the synthetic fixture), `TS-6` (gps_pipeline unit tests — surfaced #6, a real `routeContinuityScore` bug in `MatchQuality.evaluate`), `TS-9` (ghost-race/challenge unit tests — surfaced #5, a real ~1-split overshoot bug in `ghostExpectedTimeAtDistance`), `DEP-1` (Go CI pin bumped to 1.26, docs corrected), `OPS-6` partial (Flutter version pinned, caching added for Flutter/Go/Rust; iOS build verification deliberately not attempted — no macOS toolchain to verify it), `DEP-5` (dependency audit + triage — `docs/DEPENDENCY_AUDIT.md`; no version bumps applied, left for their own PRs).

**Written and reasoned-correct, but NOT locally executed** — this environment has no Docker, no local Postgres/Redis, no MSVC linker (blocks local Rust builds), and no Gradle/Android toolchain:
- `TS-1` (the big one): full Postgres/Redis integration test suites for `activity`, `auth`, `leaderboard`, plus a CI `services:` block. Compiles clean and skips clean locally; first real run will be the next CI run.
- `TS-8`'s new `rust-fit-parser` CI job: reasoned against the crate's actual Cargo.toml/deps; GH Actions' Linux runners have a working linker unlike this Windows dev environment, so it should build, but unconfirmed.
- `TS-7`: rewrote the stale Kotlin test to check a real code path; no Gradle available to run it.

Three real bugs were found as a byproduct of writing tests (not sought out deliberately) and are fully documented, not fixed (out of scope for test-coverage tasks, all are user-facing behavior changes that deserve their own reviewed diff): `DISCOVERED_ISSUES.md` #5 (ghost-race pace math), #6 (map-match quality gate), #7 (cumulative distance overshoot, needs more investigation before it's even confirmed as a real bug vs. a short-course artifact).

Full-suite phase-boundary check: backend (`go build`/`vet`/`gofmt`/`test`), `app` (`flutter analyze`/`flutter test`, 48 tests), and `gps_pipeline` (`dart analyze`/`dart test`, 38 tests) all green.

## Phase 3 — Structural — starting now

Two items are blocked on product decisions I can't make (`CQ-11`: finish or remove the FIT parser; `UX-3`: build or preview-mark Explore/Route Planner) — flagging up front, not discovering mid-phase. Everything else (`CQ-5`, `CQ-6`, `CQ-7`, `CQ-9`, `CQ-10`) is in scope. `CQ-9` (the `tracking_controller.dart` split) is technically a "pure refactor, no behavior change" per this session's operating rules, so not a hard stop by the letter of those rules — but there is currently no direct unit test coverage for `TrackingModel` itself (only its dependencies, like the draft repository), so before attempting that specific split I'm adding direct test coverage for it first as a safety net, rather than refactoring 701 lines of safety-relevant tracking/recovery code with no automated way to catch a regression.
