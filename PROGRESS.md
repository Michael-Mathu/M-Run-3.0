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

## Phase 3 — Structural — DONE (5/7 done, 2 blocked)

- `CQ-5` — Removed duplicate `appDatabaseProvider`; deleted the weaker unused `ensureLocationPermission` duplicate.
- `CQ-6` — Deleted dead `Activity`/`Trackpoint` model classes, dead `RunRecord.fromJson`/`_synthesizeRawFixes`, dead `main()` in `app.dart`.
- `CQ-7` — De-duplicated `_recommendTier` (byte-identical in two places) and consolidated `activity_type_selector.dart`'s three card builders into one parameterized `_ActivityCard`. Added a smoke test (`activity_type_selector_test.dart`) since there's no way to visually verify pixel-equivalence in this environment.
- `CQ-10` — Converted `auth`/`activity`/`leaderboard` from package-level globals + `Init()` to struct-based `API` types with `NewAPI(...)` constructors and methods. Verified behavior-preserving via the existing full-flow `TestAPIFlowInMemory` (register → login → create activity → fetch → leaderboard, through the real `buildHandler`), which passed unchanged.
- `CQ-9` — **Partial.** Did the safe, mechanical part: de-duplicated the filtered-distance recompute loop into `_recomputeFilteredDistanceM`. **Deliberately did not attempt** the larger "split into focused services" restructuring — investigated first, and found `TrackingModel` has no seam for testing its GPS-engine-coupled paths (`_engine = MwendoGpsEngine()` is constructed inline, not injected), so there's no way in this environment to verify a bigger structural split preserves behavior on the actual tracking/recovery state machine. Refactoring ~700 lines of safety-relevant code with no way to catch a regression is worse than leaving it alone. Logged the missing test seam as `DISCOVERED_ISSUES.md` #8 with a suggested fix (extract an injectable `GpsEngine` interface) that would unblock both real `TrackingModel` tests and a lower-risk future attempt at the full split.
- `CQ-11`, `UX-3` — **Blocked**, unchanged from Phase 1: both need a product decision (finish vs. remove/preview-mark) that isn't mine to make.

Full-suite phase-boundary check: backend and `app` both green (backend: build/vet/gofmt/test; app: analyze clean, 55 tests).

## Phase 4 — Hardening — DONE (15/19 done or partial, 4 blocked)

**Backend (verified via real test runs, plus one live smoke test):**
- `SEC-8`/`OPS-7` — CORS no longer sends `Allow-Credentials` alongside a wildcard origin.
- `SEC-10` — `http.MaxBytesReader` caps on auth (1MB) and activity (5MB) bodies; 50,000-trackpoint cap on activity creation.
- `SEC-11` — `MemoryStore`'s dev-mode user IDs are now opaque random values, not `"mem-"+email` (was leaking email via the public leaderboard).
- `PF-1` — Batched trackpoint inserts (500 rows/statement) instead of one `ExecContext` per point. Exercised by the existing (locally-skipped, no Postgres) integration test — will be verified on the next CI run.
- `PF-2` — Expanded the in-memory-leaderboard startup log and documented the multi-instance divergence risk.
- `PF-3` — Confirmed `ConnMaxLifetime`/`ConnMaxIdleTime` are set (landed in an earlier commit).
- `OPS-3` — Added structured JSON request logging (`log/slog`) and a stdlib-only `/api/v1/metrics` endpoint. **Manually smoke-tested by actually running the server** (falls back to in-memory stores, no Postgres/Redis needed) and confirming real log lines and correctly-incrementing counters via curl.
- `OPS-5` — Dockerfile now runs as a non-root user, pinned to `alpine:3.21` instead of floating `latest`. Not locally buildable (no `docker` in this environment).
- `OPS-4` — Documented the (manual, non-automated) deployment/rollback path in the new `docs/DEPLOYMENT.md`, honest about what's missing (CI build/push, a registry, a chosen platform, backups).

**Flutter (verified via real test runs):**
- `SEC-9` — `_errMessage` now always returns a message instead of `null` for timeouts/connection errors/unrecognized responses, which previously made a failed login look like a success. New `session_provider_test.dart` covers all the previously-broken cases plus the still-correct ones.
- `SEC-3` — **Partial.** The Dart-side HTTPS default is genuinely blocked (no HTTPS backend exists anywhere in this repo to point to; flipping it would just break local dev). What *was* real and fixable: Android's cleartext policy was a blanket allow-everywhere; scoped it to a `network_security_config.xml` `domain-config` covering only `10.0.2.2`/`localhost`/`127.0.0.1`, with everything else now requiring HTTPS. Not build-verified (no Android toolchain here).

**gps_pipeline (verified via real test runs):**
- `PF-5` — Fixed antimeridian wraparound in `toEnu`/`fromEnu`; the "KNOWN GAP" test from Phase 2 is now a real regression test asserting the correct ~22.2km distance instead of the old ~40,000km bug.
- `CQ-16` — Fixed `copyWith` dropping `smoothedSpeedMps`; new `models_test.dart` regression-tests it.

**iOS (code written, not build-verified — no Xcode/macOS in this environment):**
- `SEC-14` — Rewrote `MwendoGpsEnginePlugin.swift`'s `startRecording` to actually check/request authorization (previously it never did, matching the audit's "near-certain crash risk" framing) and added the missing authorization-change/error delegates. **Correction to the original audit finding**: re-reading the files before touching them, the real app's `Info.plist` (`app/ios/Runner/Info.plist`) already had the required usage-description keys and `UIBackgroundModes` — only the plugin's own standalone `example/` app was missing them (lower real-world severity than originally stated). Added the keys there too for consistency.

**Deliberately not attempted:** `SEC-4`, `SEC-5`, `SEC-6`, `SEC-7` remain blocked exactly as in Phase 1/BUILD_PLAN's original 🔒 flags — these change real auth/privacy behavior (consent defaults, token storage migration, auth error semantics, session cookie lifetime) and need your input on which path to take. `SEC-12` (Rust `catch_unwind`) is moot until `CQ-11`'s finish-or-remove decision is made.

Full-suite phase-boundary check: backend (build/vet/gofmt/test), `app` (analyze clean, 60 tests), `gps_pipeline` (analyze clean, 41 tests) all green.

## Phase 5 — Polish — DONE (5/6 done, 1 not executable by me)

- `CQ-12`, `CQ-13`, `CQ-14` — Debris files removed, `app-rn/` deleted (orphaned, no build scaffolding), `LICENSE-AGPL` stub removed.
- `UX-4` — Ghost-result share button now does a real `share_plus` text share instead of a silent no-op. Surfaced and fixed two adjacent bugs along the way (`DISCOVERED_ISSUES.md` #9, #10).
- `UX-6` — Fixed remaining hardcoded strings and non-locale-aware date formatting. While sweeping for this, found the app had 6 more missing-L10n-key bugs elsewhere (raw key names rendering to users) — fixed all of them and added `l10n_keys_test.dart` as a permanent regression test for the whole bug class (`DISCOVERED_ISSUES.md` #11).
- `UX-5` — Localized `route_analysis_screen.dart`, `recovery_card.dart`, `activity_type_selector.dart` (added ~30 new L10n keys, en/sw); reworded `route_analysis_screen.dart`'s raw pipeline jargon ("Rejection Rate", "95th %ile Accuracy", "Jumps/km") into plain runner-facing language; added `Semantics(selected:, button:, label:)` to `activity_type_selector.dart`'s card widget so screen readers announce selection state.
- `CQ-8` — Re-verified the plan's named component list against actual repo state (two named files no longer existed; the real unused set was different) and re-derived it via usage grep. Deleted 10 components with zero call sites anywhere in `app/lib`; kept 4 that already had real usages. Chose deletion over forced adoption — retrofitting unused components into existing screens is a design judgment call with real visual-regression risk, deleting confirmed-dead code isn't.
- `UX-2` — **Not executed.** This is a content task (translate ~200 lesson-content string pairs into real Swahili), not an engineering task — BUILD_PLAN's own risk note says not to attempt it mechanically, and I have no way to produce fluent, pedagogically-sound Swahili translations of lesson content myself. Left exactly as documented in the audit/plan; needs a human fluent Swahili speaker.

Full-suite phase-boundary check: `app` (`flutter analyze` clean, `flutter test` — 65 tests, all green). Backend/gps_pipeline untouched this phase, no re-check needed.

## Phase 6 — Ongoing
