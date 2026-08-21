# Mwendo (M-Run 2.0) — Build / Remediation Plan

**Source:** `docs/AUDIT_REPORT.md` (2026-08-21 full-stack audit).
**Purpose:** An executable plan, not a summary. Every finding in the audit gets a task ID, a phase, acceptance criteria, an effort estimate, and its dependencies on other tasks. Work through it top to bottom within a phase; phases are ordered so nothing gets refactored before it's tested and nothing security-sensitive ships before it's reviewed.
**How to use this document:** Pick up any unchecked task in §3 (Master Checklist) whose "Depends on" list is fully checked, read its row in the matching phase table in §2 for full context, do the work, verify against its Acceptance Criteria, check it off. Re-verify file:line references before starting — this codebase was moving fast at audit time (12 commits in 3 weeks), so line numbers may have drifted.
**Scope accounting:** the audit produced 60 distinct findings. 57 are actionable tasks below; 3 (`SEC-13`, `PF-4`, `UX-7`) were confirmed *non-issues* during the audit and are listed in §2.7 for completeness only — no work required. Three findings appeared only in the audit's Executive Summary / Recommendations prose without a table row of their own; they've been given IDs here so nothing falls through the cracks: **`CQ-15`** (missing `state` column in the Drift upgrade migration), **`CQ-16`** (`copyWith` drops `smoothedSpeedMps` in `gps_pipeline`), **`SEC-14`** (iOS location-permission handling is entirely missing).

**⚠️ Tasks requiring your explicit sign-off before execution begins** (destructive/schema/auth-security-sensitive, per your standing instruction): `CQ-15`, `SEC-1`, `SEC-2`, `SEC-4`, `SEC-5`, `SEC-6`, `SEC-7`, `SEC-8`, `SEC-9`, `SEC-10`, `SEC-11`, `UX-1`, `OPS-2`, `CQ-9`, `CQ-11`, `UX-3`. These are marked 🔒 throughout. I will not start any of them without you confirming the approach in that task's row first — several have more than one valid path (see §4 Trade-offs) and the wrong default could cost real user trust or real user data.

---

## 1. Dependency Map & Trade-offs

**Hard sequencing constraints** (task B cannot safely start until task A is done):

| Must finish first | Before starting | Why |
|---|---|---|
| `OPS-1` (compose volumes) | `TS-1` (DB/Redis integration tests in CI) | `TS-1`'s CI service containers should run against a compose config that isn't silently dropping data on every restart — fix the base config before building test infra on it. |
| `CQ-1` (crash-recovery rewire) | `CQ-9` (tracking_controller split) | `CQ-9` restructures the exact file `CQ-1` fixes. Splitting a controller that still has the recovery bug risks scattering the bug across new files instead of fixing it. |
| `TS-3` (migration regression test harness) | `CQ-15` (missing-column fix) execution, same PR | Write the failing test first, then the fix, in one PR — otherwise there's no proof the fix actually works against a real pre-migration DB. |
| `TS-4`/`TS-5` (ground-truth-asserting Kalman test) | `CQ-16` (`copyWith` fix) | Land the test that can actually catch the regression before touching the model, or the "fix" is unverified. |
| `CQ-10` (backend DI refactor) | `PF-1` (batch trackpoint inserts), `OPS-3` (structured logging/middleware) | Both later changes are far cheaper to make once handlers/stores take dependencies instead of reaching into package globals — doing them first means redoing the same lines twice. |
| `TS-8` (CI analyze/lint gate) | Any Phase 3+ refactor PR | Land lint/analyze in **report-only** mode, clear the existing backlog, *then* flip it to blocking — otherwise Phase 3 PRs get blocked by pre-existing warnings unrelated to their change. |
| `SEC-4` consent-gate decision | Any change to `map_match_job.dart` | Don't let two people edit the same consent logic in parallel; the gate and its UI prompt must land in one PR (see trade-off below). |

**Trade-offs the plan does not resolve for you** — pick an approach before the linked task starts:

- **`UX-1` (SOS)** — *Fast path:* rewrite the countdown-dialog copy to accurately describe "opens a pre-filled text per contact, you still tap send" (≈1 day, ships this week, no new platform risk). *Real path:* build actual autonomous sending via a native SMS API or a backend relay (≈multi-day, needs its own safety review, and SMS delivery still isn't guaranteed — the UI would need honest language even after this). **These are not mutually exclusive on a timeline** — do the fast path in Phase 1 unconditionally (never ship misleading safety UI), and treat the real path as a separately-scoped feature investment, not a Phase 1/2 deliverable.
- **`CQ-11` (FIT parser)** — *Finish it:* real `fitparser` crate integration, real byte-passing from Dart, platform build wiring — multi-day speculative work for a feature with no confirmed user demand yet. *Remove it:* delete the package from the dependency graph and any UI entry points until there's a concrete need. This is a product call, not an engineering one — flagged 🔒.
- **`UX-3` (Explore/Route Planner)** — *Finish it:* build real route-following, multi-day feature work. *Mark it a preview:* disable the dead taps, add a "coming soon" affordance, ship in under a day. Also 🔒 — product call.
- **`SEC-4` (map-matching consent)** — the quick fix (re-enable the existing commented-out consent check) still sends data to a third-party **demo** server once consent is granted, which has no SLA. The complete fix requires standing up a self-hosted OSRM instance, which is infra work, not a code change. Do the consent gate now (Phase 1/4); track self-hosting as an Ongoing/Phase-6 infra item, not a blocker for the consent fix.
- **`SEC-2` (JWT_SECRET fail-fast)** — failing fast on a missing secret is correct, but it will break any existing deployment currently relying on the silent default. Ship with a one-release grace-period warning log before the hard failure goes live, and coordinate the cutover date with whoever operates the backend.

**Safe to parallelize** if more than one person is available — four largely independent tracks, cross-referenced only at the sequencing constraints above:

1. **Flutter app track:** `CQ-1,2,3,4,5,6,7,8,9,15`; `SEC-3,5,9`; `UX-1,2,3,4,5,6`; `TS-2,3,7,9`
2. **Go backend track:** `SEC-1,2,6,7,8,10,11`; `CQ-10`; `PF-1,2,3`; `OPS-1,3,4,5,7`; `TS-1`
3. **GPS/native packages track:** `CQ-11,16`; `SEC-12,14`; `PF-5`; `TS-4,5,6`
4. **Docs/CI/infra track:** `TS-8`; `DEP-1,4,5`; `OPS-6`; `CQ-12,13,14`; API reference rewrite

**Safe for bulk/automated execution** (mechanical, low ambiguity, no product or safety judgment call): `CQ-3,4,5,6,7,8,12,13,14,16`; `TS-2,3,4,5,6,7,9`; `DEP-1,4,5`; `PF-1,3,5`; `OPS-1,3,5,6,7`; `UX-4,5,6`.
**Requires human judgment at the point of execution, even where not 🔒-flagged**: `CQ-9` (large refactor — review the split boundaries before committing), `OPS-2` (real signing keystore must be generated and custodied by a human, never auto-generated by an agent), `UX-2` (translation content needs a fluent Swahili speaker, not a mechanical fix).

---

## 2. Phase Breakdown

### Phase 1 — Stabilize
**Goal by end of phase:** every bug that actively contradicts one of the app's own headline promises, or that can crash the backend outright, is fixed. Nothing here requires a design decision — every fix is bounded and well-understood. The app is not yet "release-ready" (that's Phase 2), but it no longer lies to users about what it does.

| ID | Task | Files / Modules | Acceptance Criteria | Effort | Depends on | Risk |
|---|---|---|---|---|---|---|
| `CQ-1` | Rewire crash recovery to read from the Drift `SessionDrafts`/`SessionPoints` tables it already writes to; delete the dead `mwendo_recovery.json` code path | `tracking_controller.dart:176-336`, `live_dashboard.dart:52-57` | Force-kill the app mid-run, relaunch: a recovery prompt appears and restores the in-progress run's points/state. No references to `_recoveryFile()`/`mwendo_recovery.json` remain. | M (6-8h) | none | Touches the app's core tracking state machine — smoke-test thoroughly before Phase 3 refactors it further. |
| `CQ-2` | Implement the real JSON decode in the ghost-result screen | `ghost_result_screen.dart:45-53,172,182` | After a completed ghost race, the result screen's route map renders the actual path and the split-comparison table shows non-zero rows matching what `GhostRaceController` computed. | S (3-4h) | none | Low — isolated to one screen, upstream data already correct. |
| `CQ-3` | Fix the unreachable `else` branch gating regular (non-ghost) challenge celebrations | `live_dashboard.dart:626-661` | Completing a non-ghost run that unlocks a challenge (e.g. First 5K) shows the `CelebrationOverlay`. | S (1-2h) | none | None. |
| `CQ-4` | Wrap `saveRun`/`saveDraft` multi-step writes in `transaction()` | `app_database.dart:92-129`, `session_draft_repository.dart:16-76` | Simulated crash between the delete-old-points and insert-new-points steps (e.g. throw injected mid-write in a test) leaves the DB in its pre-write state, not a half-written one. | S (3-4h) | none | Low — mirrors the pattern already correct in `map_match_job.dart:101-117`. |
| `CQ-15` 🔒 | Add the missing `state` column to the `onUpgrade` migration path | `app_database.dart` (`MigrationStrategy.onUpgrade`, `from < 3` block) | A DB fixture at schema v2 upgrades to v3 without throwing `no such column: state`; all 7 new columns present post-upgrade, verified by `TS-3`'s new test. | S (2-3h) | `TS-3` written in the same PR | **Schema migration on real user data — confirm approach with the user before merging.** Consider whether any v2-schema installs exist in the wild yet; if not, risk is purely internal/dev-DB. |
| `SEC-1` 🔒 | Add synchronization around `refreshTokens` (prefer `sync.Map` or a scoped `sync.RWMutex`) | `backend/internal/auth/handler.go:21,96,109,124` | A concurrent-login load test (N goroutines hitting `/auth/login` simultaneously) that previously panicked with `concurrent map writes` now passes cleanly. | S (2-3h) | none | Auth-path change — confirm approach (Map vs Mutex) before merging; add the load test as permanent regression coverage. |
| `SEC-2` 🔒 | Fail fast on startup if `JWT_SECRET` is unset/default while `ENV` indicates production; log a grace-period warning otherwise | `backend/internal/config/config.go:14-17`, `cmd/api/main.go` | Starting the server with `ENV=production` and no `JWT_SECRET` refuses to boot with a clear error. Starting with `ENV=dev`/unset logs a visible warning but still boots. | S (2-3h) | none | **Will break any deployment currently relying on the silent default — coordinate cutover timing before merging (see §1 trade-offs).** |
| `UX-1` 🔒 | Fix the SOS UX/copy mismatch (fast path: honest copy; see §1 for the real-auto-send trade-off) | `safety_service.dart:4-13`, `live_dashboard.dart` `_SosCountdownDialog` (~1006-1112) | Countdown dialog text accurately describes what happens (opens per-contact pre-filled SMS, user must send) — no implication of autonomous sending unless the real-auto-send path is explicitly chosen instead. | S (3-4h) for copy fix | none | **Safety-critical feature — confirm which path (copy fix vs. real auto-send) with the user before starting.** |
| `OPS-1` | Add a `volumes:` mount to the `db` service in `docker-compose.yml` | `docker-compose.yml` | `docker compose down && docker compose up -d` preserves previously-written activity data. | XS (<1h) | none | None. |
| `OPS-2` 🔒 | Stop publishing `flutter build apk --debug` as a GitHub Release; build a signed, optimized release APK/AAB | `.github/workflows/release.yml:29-32` | Tag-triggered release workflow produces a release-signed, non-debuggable, R8/ProGuard-shrunk artifact. `android:debuggable` is `false` in the built manifest. | M (1 day, assuming a keystore exists) | none | **Requires generating and custodying a real signing keystore — a human must own this secret material; do not let an agent generate/store it unsupervised. Confirm keystore provisioning plan before starting.** |

**Verification before moving to Phase 2:** run the full existing test suite (`make test-all`) plus manual smoke tests for each item above (kill-and-relaunch for `CQ-1`, complete-a-ghost-race for `CQ-2`, complete-a-challenge for `CQ-3`, kill-mid-write simulation for `CQ-4`, v2→v3 DB fixture upgrade for `CQ-15`, concurrent-login load test for `SEC-1`, missing-secret boot attempt for `SEC-2`, SOS dialog read-through for `UX-1`, container-restart data check for `OPS-1`, built-artifact inspection for `OPS-2`).

**Branching/PR strategy:** one small PR per task (10 PRs) — they touch disjoint files, are independent, and you want each mergeable/revertable on its own. Suggested branch names: `fix/crash-recovery-wiring`, `fix/ghost-result-parser`, `fix/challenge-celebration-branch`, `fix/drift-transactions`, `fix/migration-state-column`, `fix/refresh-token-race`, `fix/jwt-secret-failfast`, `fix/sos-copy-accuracy`, `fix/compose-db-volume`, `fix/release-signing`. Merge each independently as it passes review; consider tagging a single hotfix release once all ten are in, since together they fix the app's core broken promises.

---

### Phase 2 — Foundation
**Goal by end of phase:** the test suite and CI actually catch regressions in the code paths that matter (real DB/Redis, not just in-memory fallbacks; the migration path; the pure GPS math), and CI enforces the quality bar the project's own contributing guide already claims to enforce. This phase exists so that Phase 3's refactors don't have to be taken on faith.

| ID | Task | Files / Modules | Acceptance Criteria | Effort | Depends on | Risk |
|---|---|---|---|---|---|---|
| `TS-1` | Add docker-compose-based integration tests for the Postgres-backed `DBStore` and Redis-backed leaderboard; wire a `services:` block into CI | `backend/internal/{auth,activity,leaderboard}`, `.github/workflows/test.yml` | CI spins up real Postgres+Redis, runs a test suite exercising `DBStore.Create/Get/List`, geography casts, `ST_Simplify`, transaction rollback, and the Redis leaderboard path; test fails if any of those regress. | L (2-3 days) | `OPS-1` | Larger PR — review CI cost/runtime impact; keep in-memory tests too (fast unit tier) alongside new integration tier. |
| `TS-2` | Rewrite `app/test/activity_repository_test.dart` against the real Drift-backed repository | `app/test/activity_repository_test.dart` | Test file no longer references a JSON-file-backed repository; exercises real Drift CRUD, including an induced-corruption/error scenario. | S (3-4h) | none | Low. |
| `TS-3` | Add a migration-path regression test (paired with `CQ-15`, same PR) | `app/test/` (new file, e.g. `migration_test.dart`) | Test constructs/loads a schema-v2 DB fixture, runs `onUpgrade`, asserts all v3 columns exist and are queryable. | S (2-3h) | ships with `CQ-15` | None additional beyond `CQ-15`'s own risk. |
| `TS-4` | Wire `synthetic_truth.ndjson` into an asserting test (not just `replay_test.dart`'s length/status check) | `packages/gps_pipeline/test/`, `synthetic_truth.ndjson` | New/updated test runs the pipeline against `synthetic_raw.ndjson` and asserts numeric deviation from `synthetic_truth.ndjson` stays under an explicit tolerance. | M (4-6h) | none | None. |
| `TS-5` | Turn `tool/kalman_calibrate.dart`'s manual eyeball-the-printout check into a `dart test`-integrated assertion | `packages/gps_pipeline/tool/kalman_calibrate.dart`, `test/` | Calibration deviation stats are asserted against a bound in `dart test`, not just printed for a human. | S (2-3h) | `TS-4` (shares fixture/tolerance groundwork) | None. |
| `TS-6` | Add direct unit tests for `coordinate_util.dart`, `quality_gate.dart`, `gap_detector.dart`, `quality_metrics.dart`, `match_quality.dart`, and `OsrmMatchProvider`'s chunk/retry/backoff logic | `packages/gps_pipeline/lib/src/*`, `test/` | Each listed module has direct unit tests covering its core branches, including at least one edge case per module (e.g. empty input, boundary accuracy value). | M (1-1.5 days) | none | None. |
| `TS-7` | Fix or delete the stale Kotlin plugin test referencing a nonexistent `getPlatformVersion` method | `packages/mwendo_gps_engine/android/.../MwendoGpsEnginePluginTest.kt` | Test file either tests the real `onMethodCall` surface (`startRecording`/`pause`/`resume`/`stop`/`getPlatformMetadata`) or is removed; running it doesn't fail. | S (1-2h) | none | None. |
| `TS-8` | Add `flutter analyze`, `gofmt -l`/`go vet`, and `cargo build`/`clippy` steps to CI, plus align the Go CI version pin with `go.mod`'s `1.26.4` (or add an explicit `toolchain` directive) | `.github/workflows/test.yml`, `backend/go.mod` | New CI jobs run on every push/PR. **Land in report-only/non-blocking mode first**, clear any pre-existing warnings, then flip to blocking in a follow-up PR. Go CI pin and `go.mod` agree, or a `toolchain` line makes the intent explicit. | M (1 day + backlog cleanup time) | none | Blocking mode too early will stall unrelated PRs — see the two-step rollout above. |
| `TS-9` | Add unit tests for the currently-clean-but-untested pure logic in `ghost_race_controller.dart` and `challenge_evaluator.dart` | `app/lib/features/beat/ghost_race_controller.dart`, `app/lib/features/challenges/challenge_evaluator.dart`, `app/test/` | Both modules have direct unit tests covering their computation branches — cheapest, highest-value tests in the repo since the logic is already pure/side-effect-free. | S (3-4h) | none | None. |
| `DEP-1` | Align Go toolchain pin (see `TS-8`, same PR is fine) | `backend/go.mod`, `.github/workflows/test.yml`, `docs/SETUP_AND_DEPLOYMENT.md` | Docs, CI, and `go.mod` all state the same Go version/toolchain policy. | XS (<1h, bundle with `TS-8`) | none | None. |
| `DEP-5` | Run `go list -m -u all`, `flutter pub outdated`, `cargo audit`, and `npm audit` (if `app-rn` is kept); record and triage results | repo-wide | A short findings note (can live in this doc's Ongoing section or a new `docs/DEPENDENCY_AUDIT.md`) lists any flagged CVEs/outdated majors with a decision per item (upgrade now / defer / accept). | S (2-3h) | none | None — informational task. |
| `OPS-6` | Improve CI matrix: add iOS build verification, pin Flutter version instead of floating `3.x`, add dependency caching to both jobs | `.github/workflows/test.yml` | CI runs on the versions actually documented as supported; cache hit reduces job runtime measurably. | S (3-4h) | none | None. |

**Verification before moving to Phase 3:** deliberately break something in a scratch branch for each new test category (e.g. remove a `WHERE user_id` clause, revert the migration fix, corrupt a Kalman constant) and confirm the corresponding new test actually fails — a green test suite that can't catch real regressions isn't foundation, it's decoration.

**Branching/PR strategy:** batch by sub-area to keep review focused — one PR for CI workflow changes (`TS-8` + `DEP-1` + `OPS-6`, all touch `test.yml`), one PR for stale-test fixes (`TS-2` + `TS-7`), one PR for new pure-logic unit tests (`TS-9` + `TS-6`), one PR for the ground-truth-asserting test wiring (`TS-4` + `TS-5`), one larger dedicated PR for `TS-1` (integration harness, deserves focused review), and `DEP-5` as a short write-up (PR only if it results in an actual dependency bump).

---

### Phase 3 — Structural
**Goal by end of phase:** the architecture matches what the docs already claim — no duplicate providers/models, no god-objects, consistent DI in the backend — and the two speculative/unfinished features (FIT parser, Explore/Route Planner) have an explicit, decided fate instead of silently rotting as dead taps.

| ID | Task | Files / Modules | Acceptance Criteria | Effort | Depends on | Risk |
|---|---|---|---|---|---|---|
| `CQ-5` | Remove the duplicate `appDatabaseProvider` declaration; delete the weaker unused `ensureLocationPermission` duplicate | `app_database.dart:11`, `activity_repository.dart:50`, `core/permissions/location_permission.dart`, `core/permissions/permissions.dart` | Only one `appDatabaseProvider` and one `ensureLocationPermission` exist repo-wide; both compile and behave identically to the previously "real" versions. | S (2-3h) | none | None. |
| `CQ-6` | Delete dead duplicate model classes (`Activity`, `Trackpoint`), the dead `RunRecord.fromJson` path, and the dead `main()` in `app.dart` | `data/models/activity.dart`, `data/models/trackpoint.dart`, `run_record.dart:145-217`, `app/lib/app.dart:10` | `grep` confirms zero references to the removed classes/method anywhere in `lib/`; app still builds and runs identically. | S (2-3h) | none | None. |
| `CQ-7` | De-duplicate `_recommendTier` logic and the three near-identical card builders | `beat_legends_page.dart:227-239,259-269`, `activity_type_selector.dart:58-178` | Single shared implementation used from both call sites; card builders consolidated into one parameterized widget. | S (3-4h) | none | Low — visual regression risk, needs a UI smoke pass. |
| `CQ-9` 🔒 | Split `tracking_controller.dart` into focused services (GPS stream handling, recovery I/O, record-building); de-duplicate the distance-recompute loop | `app/lib/features/tracking/tracking_controller.dart` (701 lines) | File is decomposed into ≥3 smaller, independently-testable units; the distance-recompute logic exists in exactly one place; all Phase 1 tracking/recovery smoke tests still pass unchanged. | L (1.5-2 days) | `CQ-1` merged first | **Largest single refactor in this plan, touches the safety-relevant crash-recovery code path. Confirm the proposed split boundaries with the user before starting; require a full manual re-run of the Phase 1 recovery smoke test before merging.** |
| `CQ-10` | Refactor backend handlers/stores from package-level globals to struct-based dependency injection | `backend/internal/{activity,auth,leaderboard}/handler.go` and `store.go` files, `cmd/api/main.go` | Handlers take their store as a constructor argument, not a package global; `go test ./... -parallel` runs safely; behavior unchanged (existing tests still pass). | M (1.5 days) | none (but do before `PF-1`, `OPS-3`) | Touches every backend request path — run full backend test suite (including new `TS-1` integration tests) before merging. |
| `CQ-11` 🔒 | Decide and execute: finish `mwendo_fit_parser` for real, or remove it from the dependency graph and UI | `packages/mwendo_fit_parser/*`, any app-side entry points referencing it | Either (a) `parseBytes` genuinely round-trips real FIT file bytes through a working Rust parser with platform build wiring on both OSes, or (b) the package and all references to it are removed from `pubspec.yaml`/app UI. | L (multi-day if finishing; S if removing) | none | **Product decision, not an engineering call — confirm direction with the user before starting either path.** |
| `UX-3` 🔒 | Decide and execute: build Explore/Route Planner for real, or mark it a clearly-labeled preview and disable dead taps | `explore_provider.dart:101-160`, `route_detail_page.dart:91-115`, `explore_page.dart` Segments tab | Either (a) "Start Run" actually uses the selected route and Segments cards are functional, or (b) all dead taps are disabled/removed and the feature is visibly labeled as a preview so users don't hit silent no-ops. | L (multi-day) if finishing; S (<1 day) if marking preview | none | **Product decision — confirm direction before starting.** |

**Verification before moving to Phase 4:** full regression pass of Phase 1's manual smoke tests (especially recovery, after `CQ-9`); backend integration test suite (from `TS-1`) green after `CQ-10`; code review by a second person recommended for `CQ-9` and `CQ-10` specifically given their size and blast radius.

**Branching/PR strategy:** each item gets its own PR given the higher risk/larger diffs in this phase — `CQ-5`+`CQ-6` can be bundled into one "dedup cleanup" PR since both are small and mechanical; `CQ-7`, `CQ-9`, `CQ-10`, `CQ-11`, `UX-3` each stand alone. Merge `CQ-9` and `CQ-10` only after their respective full test suites are confirmed green in CI, not just locally.

---

### Phase 4 — Hardening
**Goal by end of phase:** remaining security gaps, performance issues, and infra rough edges are closed. This is the largest phase by task count (20 items) but individually low-risk once Phases 1-3 have landed, since most of these fixes now have real tests (Phase 2) and clean seams to attach to (Phase 3's DI refactor).

| ID | Task | Files / Modules | Acceptance Criteria | Effort | Depends on | Risk |
|---|---|---|---|---|---|---|
| `SEC-3` | Default `API_BASE_URL` to HTTPS; remove `android:usesCleartextTraffic="true"` once backend TLS exists | `api_client.dart:7-10`, `AndroidManifest.xml:14` | Default build config points at an HTTPS origin; cleartext flag removed; a build without an overridden `API_BASE_URL` cannot send credentials in plaintext. | S (2-3h) + backend TLS setup (infra, separate) | Backend TLS termination must exist first (infra, track separately) | Blocked on infra, not code — sequence with whoever owns backend deployment. |
| `SEC-4` 🔒 | Re-enable the map-matching consent check; ship a real consent-prompt UI in the same PR | `map_match_job.dart:22-33` | Map-matching only fires after explicit user consent via an in-app prompt; declining consent skips the OSRM POST entirely. | S (4-6h) | none | **Privacy-sensitive default — confirm default-on-vs-default-off consent stance with the user before starting.** |
| `SEC-5` 🔒 | Move JWT/session storage from `SharedPreferences` to `flutter_secure_storage` (Keychain/Keystore) | `api_client.dart:18-34`, `session_provider.dart:21-22,62-65` | Tokens/session identity persist via secure storage on both platforms; a plaintext SharedPreferences dump no longer contains the JWT. | M (1 day) | none | **Auth-sensitive storage change — confirm migration path for existing logged-in users (force re-login vs. migrate) before starting.** |
| `SEC-6` 🔒 | Return generic, non-enumerable error responses on login/register | `backend/internal/auth/handler.go:69-88,59-61` | "Account doesn't exist" and "wrong password" return identical bodies/status; register conflict no longer echoes the submitted email. | S (2-3h) | none | Low, but auth-path — bundle into the backend security PR for one focused review pass. |
| `SEC-7` 🔒 | Add `Secure` flag and a real expiry to the refresh-token cookie; expire server-side entries | `backend/internal/auth/handler.go:97-99` | Cookie is `HttpOnly`+`Secure`+`SameSite=Lax` with a `Max-Age`; server-side refresh-token map entries expire automatically. | S (3-4h) | none | Same as above. |
| `SEC-8` | Fix CORS to not combine wildcard origin with credentialed requests | `backend/cmd/api/main.go:74-87` | `CORS_ORIGIN` is environment-driven and never resolves to `*` when credentials are allowed. | S (1-2h) | none | Low. |
| `SEC-9` | Fix `_errMessage` treating unrecognized `DioException`s (timeouts, connection errors) as `null`/success | `session_provider.dart:114-121`, `auth_page.dart:34-39` | A login attempt during a network outage shows a real error and does not dismiss the auth sheet. | S (2-3h) | none | Low. |
| `SEC-10` | Add `http.MaxBytesReader` request-body caps on all handlers; cap trackpoint array length before the DB insert loop | `backend/internal/{activity,auth,leaderboard}/handler.go`, `activity/store.go` | Oversized request bodies are rejected with a clear 4xx before hitting business logic; an absurd trackpoint count (e.g. 10M points) is rejected, not looped over. | S (3-4h) | none | Low. |
| `SEC-11` | Stop deriving user IDs as `"mem-"+email` in the no-DB dev fallback; don't expose email via the public leaderboard in that mode | `backend/internal/auth/store.go:91`, leaderboard handler | Dev-mode (no `DATABASE_URL`) leaderboard responses never contain raw email addresses. | S (2h) | none | Low — dev-mode only. |
| `SEC-12` | Wrap `extern "C"` FFI entry points in `catch_unwind` | `packages/mwendo_fit_parser/rust/src/lib.rs` | A deliberately malformed input that would otherwise panic returns a Dart-catchable error instead of aborting the process. | S (2-3h) | Best done alongside/after `CQ-11`'s decision (moot if the package is removed) | Depends on `CQ-11` outcome. |
| `SEC-14` | Implement iOS `requestWhenInUseAuthorization`/`requestAlwaysAuthorization` and `didChangeAuthorization`/`didFailWithError` delegates; add missing `Info.plist` usage-description keys | `MwendoGpsEnginePlugin.swift`, `ios/Runner/Info.plist` (app + example) | Denying location permission on iOS produces a handled error state, not silence; granting it works end-to-end; app does not crash on first `CLLocationManager` use due to missing `Info.plist` keys. | M (1-1.5 days) | none | Real device/simulator testing required — cannot be fully verified without a physical iOS test pass. |
| `PF-1` | Batch trackpoint inserts instead of one `ExecContext` per row | `backend/internal/activity/store.go:116-128` | A multi-hundred-point activity save issues a small constant number of round-trips, not one per point (verify via query count in a test or log). | S (3-4h) | `CQ-10` | Low once DI refactor is in place. |
| `PF-2` | Document/decide the multi-instance leaderboard divergence risk; either require `REDIS_URL` in any multi-replica deployment or add a clear startup warning | `backend/internal/leaderboard/leaderboard.go:17-21` | Deployment docs explicitly state Redis is required beyond a single replica; a startup log warns if running without Redis. | S (2h, mostly docs) | none | None. |
| `PF-3` | Set `ConnMaxLifetime`/`ConnMaxIdleTime` on the DB connection pool | `backend/internal/db/db.go:24-25` | Pool config includes explicit lifetime/idle bounds tuned to the deployment target (e.g. behind pgbouncer). | XS (<1h) | none | None. |
| `PF-5` | Add antimeridian (±180° longitude) wraparound handling to the ENU coordinate transform | `packages/gps_pipeline/lib/src/coordinate_util.dart:25-42` | ✅ Done — `toEnu`/`fromEnu` both wrap through a new `_wrapLngDeltaDeg` helper; `coordinate_util_test.dart` asserts the antimeridian case now resolves to ~22.2km, not ~40,000km, plus a `fromEnu` round-trip check. |
| `CQ-16` | Fix `copyWith` to preserve `smoothedSpeedMps` across gap/stationary-state transitions | `packages/gps_pipeline/lib/src/models.dart` (`copyWith`), call sites in `gap_detector.dart:24,28` and `stationary_suppressor.dart` | ✅ Done — added the missing `smoothedSpeedMps` parameter/passthrough; `models_test.dart` regression-tests it. |
| `OPS-3` | Add structured logging (levels, correlation IDs), a `/metrics` endpoint, request middleware to the backend | `backend/cmd/api/main.go` and handlers | Requests are logged with level/correlation ID; a `/metrics` endpoint exposes basic counters (request count/latency/error rate) in a scrapeable format. | M (1.5 days) | `CQ-10` | Low — additive, no behavior change to existing endpoints. |
| `OPS-4` | Document (or build) a deployment/rollback path for the Go API — currently nonexistent | new `docs/DEPLOYMENT.md` or CI workflow | A documented (at minimum) or automated (ideally) path exists for getting the backend from a merged PR to a running environment, and for rolling back a bad deploy. | M (1 day for docs; more if automating) | none | Scope depends on chosen hosting target — confirm target platform before estimating automation effort. |
| `OPS-5` | Add a non-root `USER` directive to the backend Dockerfile; pin the `alpine:latest` base image to a specific digest/tag | `backend/Dockerfile` | Container runs as a non-root user; base image tag is pinned, not floating. | XS (<1h) | none | Low. |
| `OPS-7` | Fix CORS misconfiguration as part of infra config pass (same underlying issue as `SEC-8`) | `backend/cmd/api/main.go` | Same acceptance criteria as `SEC-8` — listed here only because it's also an infra/config concern; implement once, close both. | — (bundled with `SEC-8`) | `SEC-8` | None — duplicate tracking entry, not separate work. |

**Verification before moving to Phase 5:** security-specific checks — scripted probe confirming `SEC-6`'s generic error responses, a rooted-device (or documented manual) inspection confirming `SEC-5`'s secure storage actually holds the token, a network capture confirming `SEC-3`'s HTTPS default, a load test confirming `SEC-10`'s body-size caps reject oversized payloads, and a real iOS device pass for `SEC-14`.

**Branching/PR strategy:** bundle by codebase area for focused review — one "backend auth hardening" PR (`SEC-6,7,8,10,11`), one "secure networking" PR (`SEC-3,5`), `SEC-9` standalone, `SEC-4` standalone (consent UI needs its own review), one "native/gps_pipeline hardening" PR (`SEC-12,14,PF-5,CQ-16`), one "backend perf/infra" PR (`PF-1,2,3,OPS-3,4,5,7`).

---

### Phase 5 — Polish
**Goal by end of phase:** the codebase and the user-facing product match the quality bar the project's own docs claim, and repo hygiene stops misleading future contributors (or future audits).

| ID | Task | Files / Modules | Acceptance Criteria | Effort | Depends on | Risk |
|---|---|---|---|---|---|---|
| `CQ-8` | Either adopt the 11 unused design-system components in the screens that hand-roll equivalents, or delete them | `app/lib/design_system/*` (`app_button.dart`, `app_avatar.dart`, `app_lesson_card.dart`, `app_course_tile.dart`, `app_legend_card.dart`, `app_leaderboard_row.dart`, `app_streak_ring.dart`, `app_continue_banner.dart`, `app_fab.dart`, `app_coach_badge.dart`, `app_tip_sheet.dart`) | Every remaining design-system component has at least one real usage; any deleted component has zero remaining references. | M (1 day initial pass; can continue incrementally) | none | Low — visual regression risk on any screen touched, needs UI smoke pass. |
| `CQ-12` | Remove stray tracked developer-debris files | `log.txt`, `router_log.txt`, `fix_page_file.ps1`, `app/analyze_output.txt`, `app/debug_crash_guide.md` | Files removed from git; `.gitignore` updated if they're likely to recur (e.g. `*.txt` logs at root). | XS (<1h) | none | None. |
| `CQ-13` | Delete or properly scaffold `app-rn/` | `app-rn/src/db/models.ts` | Either the directory is removed, or it becomes a real, buildable RN project with its own `package.json`. | XS (<1h) if deleting | none | Confirm with the user it's genuinely unused before deleting — check for any external references first. |
| `CQ-14` | Remove the placeholder `LICENSE-AGPL` stub | `LICENSE-AGPL` | File removed; README's Apache/MIT dual-license claim is the sole, accurate statement. | XS (<1h) | none | None. |
| `UX-2` | Real Swahili translation pass for lesson content | `app/lib/features/learn/data/courses.dart` (200 of 319 pairs currently English-in-disguise) | A fluent Swahili speaker reviews and replaces the identical-to-English pairs with real translations; spot-check confirms `sw` fields are no longer byte-identical to `en`. | L (days to weeks, content work — needs a translator, not just engineering time) | none | **Not a code task — needs a human translator; do not attempt to mechanically translate.** |
| `UX-4` | Fix the ghost-result share button no-op | `ghost_result_screen.dart:226-228` | Tapping share either performs real share-image generation, or the button is disabled/shows "coming soon" — never silently does nothing. | S (2-4h for "coming soon"; more for real share-image generation) | none | None. |
| `UX-5` | Localize `recovery_card.dart`, `route_analysis_screen.dart`, `activity_type_selector.dart`; rewrite `route_analysis_screen.dart`'s raw pipeline jargon into user-facing language; add `Semantics(selected:)` to selection UI | `recovery_card.dart`, `route_analysis_screen.dart`, `activity_type_selector.dart` | All three screens pull strings from `L10n`; "Rejection Rate"/"Jumps/km"-style jargon is replaced with plain-language equivalents (with an optional "details" disclosure for the technical view); selection state is screen-reader-visible. | M (1 day) | none | Low. |
| `UX-6` | Fix remaining scattered hardcoded strings and the non-locale-aware date format | `onboarding_page.dart:182`, `activity_detail_page.dart:57,86` | No hardcoded user-facing strings remain in the listed files; date formatting is locale-aware. | S (2-3h) | none | None. |

**Verification before moving to Phase 6:** full test suite green; manual UX pass across both locales (en/sw) for every screen touched in this phase; accessibility pass (screen reader) for `UX-5`'s `Semantics` additions.

**Branching/PR strategy:** one "housekeeping" PR for `CQ-12,13,14`; one "UX polish" PR for `UX-4,5,6`; `CQ-8` as its own PR (or several small incremental ones if adopting components screen-by-screen); `UX-2` as its own PR(s), likely one per course/module, reviewed by the translator plus one engineer for structural correctness.

---

### Phase 6 — Ongoing
**Goal:** the practices that prevent this audit from needing to happen again in the same shape become part of normal operation, not one-time fixes.

| ID | Task | What "ongoing" looks like |
|---|---|---|
| `DEP-4` | Add `dependabot.yml`/Renovate for pub, Go modules, and Cargo (one-time setup, ~2-3h), then let it run | Weekly/monthly automated PRs for dependency bumps, triaged against the now-real Phase 2 test suite before merging. |
| *(process)* | CI quality gates stay blocking | `TS-8`'s analyze/lint/test gates (once flipped to blocking) apply to every future PR without exception. |
| *(process)* | Recurring dependency audit | Re-run `DEP-5`'s `go list -m -u all` / `flutter pub outdated` / `cargo audit` / `npm audit` on a quarterly cadence or before any public release, whichever comes first. |
| *(process)* | Recurring design-system audit | Periodically re-check `CQ-8`'s "adopted vs. unused" component list as new screens are added, so drift doesn't reaccumulate. |
| *(process)* | Backend observability review | Once `OPS-3`'s `/metrics` endpoint exists, actually look at it — set up a dashboard/alert threshold, don't just expose the data. |
| *(process)* | Re-run a scoped audit before any public/production launch | Given how fast this codebase moves (12 commits in 3 weeks at last audit), treat `docs/AUDIT_REPORT.md` as a snapshot, not a permanent record — a lighter-weight re-audit of just the "headline feature" paths (crash recovery, ghost racing, SOS) before any real user ever sees the app is cheap insurance against this exact class of "looks done, isn't wired up" bug recurring. |

---

## 3. Master Checklist

### Phase 1 — Stabilize
- [x] `CQ-1` — Rewire crash recovery to the Drift-backed journal
- [x] `CQ-2` — Fix ghost-result screen's stubbed JSON parser
- [x] `CQ-3` — Fix unreachable challenge-celebration `else` branch
- [x] `CQ-4` — Wrap `saveRun`/`saveDraft` in transactions
- [x] `CQ-15` 🔒 — does not reproduce in current code (all 7 columns, incl. `state`, are already added in `onUpgrade`) — no fix needed, see PROGRESS.md
- [x] `SEC-1` 🔒 — Synchronize `refreshTokens` map access (judged a pure internal fix, no auth behavior change — proceeded per operating rules; regression test added)
- [ ] `SEC-2` 🔒 — Fail fast on missing/default `JWT_SECRET` in prod — **blocked, needs your input**
- [ ] `UX-1` 🔒 — Fix SOS UI/behavior mismatch — **blocked, needs your input**
- [x] `OPS-1` — Add Postgres data volume to docker-compose
- [ ] `OPS-2` 🔒 — Replace debug-APK release with signed release build — **blocked, needs a real keystore + your input**

### Phase 2 — Foundation
- [x] `TS-1` — Postgres/Redis integration tests + CI wiring (code written and compile/skip-verified; the actual Postgres/Redis runs are **unexecuted** — no Docker in this environment. First real verification happens on the next CI run.)
- [x] `TS-2` — Rewrite stale `activity_repository_test.dart`
- [x] `TS-3` — adapted: `CQ-15` didn't reproduce, so nothing to regression-test there; added `session_draft_repository_test.dart` covering the real v3→v4 migration this session did add
- [x] `TS-4` — Assert against `synthetic_truth.ndjson` in real tests (surfaced a real finding — see DISCOVERED_ISSUES.md #7)
- [x] `TS-5` — adapted: `kalman_calibrate.dart` stays a multi-sigma exploration CLI (no single right answer to assert); `ground_truth_test.dart` asserts the one config that matters, the production default
- [x] `TS-6` — Unit tests for `gps_pipeline` untested pure modules (surfaced a real bug — see DISCOVERED_ISSUES.md #6)
- [x] `TS-7` — Fix/remove stale Kotlin plugin test (rewritten but **not executed** — no Gradle/Android toolchain available in this session; verify with `./gradlew testDebugUnitTest` before trusting in CI)
- [x] `TS-8` — Added analyze/gofmt+vet/Rust build+clippy CI steps, all blocking immediately (no report-only phase needed — cleared the entire pre-existing backlog first: `flutter analyze` was already clean, `gofmt -w`'d the whole backend). Rust job added but **not locally verified** (no MSVC linker in this Windows dev environment — GH Actions' Linux runners should build fine, but this is unconfirmed)
- [x] `DEP-1` — CI Go pin bumped to `1.26` to match `go.mod`; `docs/SETUP_AND_DEPLOYMENT.md` corrected
- [x] `DEP-5` — Ran and triaged (`go list -m -u all`, `flutter pub outdated`; `cargo audit` couldn't complete — no MSVC linker in this environment). Full triage in `docs/DEPENDENCY_AUDIT.md`. No version bumps applied — deferred to their own reviewed PRs per the doc's grouping.
- [x] `OPS-6` — partial: pinned Flutter version + dependency caching (Flutter, Go, Rust) added. iOS build verification deliberately **not** added — no macOS runner/toolchain available to verify a working job, and a broken unverified CI check is worse than no check; left as a follow-up for someone who can validate it on macOS

### Phase 3 — Structural
- [x] `CQ-5` — Remove duplicate provider/permission-helper declarations
- [x] `CQ-6` — Remove dead duplicate models and dead `main()`
- [x] `CQ-7` — De-duplicate `_recommendTier`/card-builder logic (added a smoke test for the card consolidation — no way to visually verify pixel-equivalence in this environment)
- [~] `CQ-9` — partial: de-duplicated the distance-recompute loop (the one piece of this task with a safe, mechanical, verifiable fix) into `_recomputeFilteredDistanceM`. The larger "split into 3+ focused services" restructuring is **deferred, not attempted** — see PROGRESS.md for why (no way to test the GPS-engine-coupled paths in this environment, and refactoring 700 lines of safety-relevant crash-recovery/tracking code without a way to verify behavior preservation is worse than leaving it as-is).
- [x] `CQ-10` — Backend handlers/stores to struct-based DI
- [ ] `CQ-11` 🔒 — Decide & execute: finish or remove FIT parser — **blocked, needs your input**
- [ ] `UX-3` 🔒 — Decide & execute: finish or preview-mark Explore/Route Planner — **blocked, needs your input**

### Phase 4 — Hardening
- [ ] `SEC-3` — Default HTTPS API base URL, remove cleartext flag
- [ ] `SEC-4` 🔒 — Re-enable map-match consent gate + consent UI
- [ ] `SEC-5` 🔒 — Move JWT/session to secure storage
- [ ] `SEC-6` 🔒 — Generic, non-enumerable auth error responses
- [ ] `SEC-7` 🔒 — Secure + expiring refresh-token cookie
- [ ] `SEC-8` / `OPS-7` — Fix CORS wildcard+credentials misconfiguration
- [ ] `SEC-9` — Fix network-error-treated-as-login-success bug
- [ ] `SEC-10` — Request body size caps + trackpoint count cap
- [ ] `SEC-11` — Stop leaking email via dev-mode leaderboard fallback
- [ ] `SEC-12` — `catch_unwind` around Rust FFI entry points
- [ ] `SEC-14` — Real iOS location-permission handling + Info.plist keys
- [ ] `PF-1` — Batch trackpoint DB inserts
- [ ] `PF-2` — Document/warn on multi-instance leaderboard divergence
- [ ] `PF-3` — Set DB connection pool lifetime/idle bounds
- [ ] `PF-5` — Antimeridian handling in ENU coordinate transform
- [ ] `CQ-16` — Fix `copyWith` dropping `smoothedSpeedMps`
- [ ] `OPS-3` — Structured logging, `/metrics`, request middleware
- [ ] `OPS-4` — Document/build backend deployment + rollback path
- [ ] `OPS-5` — Non-root Dockerfile user, pin base image

### Phase 5 — Polish
- [ ] `CQ-8` — Adopt or delete unused design-system components
- [ ] `CQ-12` — Remove stray tracked debris files
- [ ] `CQ-13` — Delete or properly scaffold `app-rn/`
- [ ] `CQ-14` — Remove placeholder `LICENSE-AGPL`
- [ ] `UX-2` — Real Swahili translation pass for lesson content
- [ ] `UX-4` — Fix ghost-result share-button no-op
- [ ] `UX-5` — Localize + de-jargon remaining tracking screens, add Semantics
- [ ] `UX-6` — Fix remaining hardcoded strings + date localization

### Phase 6 — Ongoing
- [ ] `DEP-4` — Set up Dependabot/Renovate (then runs automatically)
- [ ] Flip `TS-8` CI gates from report-only to blocking once backlog is clear
- [ ] Schedule recurring dependency audit (quarterly / pre-release)
- [ ] Schedule recurring design-system usage check
- [ ] Stand up dashboard/alerting on `OPS-3`'s `/metrics` once live
- [ ] Re-run a scoped headline-feature audit before any public launch

### Non-issues (confirmed during audit — no action, listed for completeness)
- [x] `SEC-13` — SQL injection / IDOR: confirmed clean, no action needed
- [x] `PF-4` — Backend indexing: confirmed matches query patterns, no action needed
- [x] `UX-7` — Profile screen: confirmed already feature-rich, no action needed

---

## 4. Risk Register

| # | Risk | Where it applies | Mitigation |
|---|---|---|---|
| 1 | Refactoring `tracking_controller.dart` (`CQ-9`) reintroduces or scatters the crash-recovery bug across new files | Phase 3 | `CQ-1` must land and be smoke-tested first; require a full manual "kill app mid-run, relaunch" QA pass before merging `CQ-9`. |
| 2 | Schema migration fix (`CQ-15`) corrupts or fails to upgrade real user data | Phase 1 | Test against a real pre-migration DB fixture (`TS-3`); get explicit user sign-off before merging; consider whether any v2-schema installs exist in the wild. |
| 3 | Mutex/`sync.Map` fix (`SEC-1`) introduces a deadlock or performance regression under load | Phase 1 | Prefer `sync.Map` for simplicity; add a concurrent-load regression test proving both correctness and no hang. |
| 4 | `JWT_SECRET` fail-fast (`SEC-2`) breaks an existing deployment relying on the silent default | Phase 1 | Ship a one-release grace-period warning before the hard failure; coordinate cutover date with backend operator. |
| 5 | Release signing keystore (`OPS-2`) is lost, mismanaged, or leaked | Phase 1 | Generate via a documented process, store in a secrets manager (not the repo), back it up — losing it means the app can never be updated under the same identity again. A human must own this, not an agent. |
| 6 | SOS auto-send (`UX-1`, if the "real" path is chosen) creates false confidence in a safety feature that still can't guarantee delivery | Phase 1 / ongoing | Keep UI copy honest about what's actually guaranteed regardless of which implementation path is chosen; consider a hybrid auto-attempt + visible manual fallback. |
| 7 | Map-matching consent gate (`SEC-4`) ships without a real consent-prompt UI, silently breaking Route Analysis for existing users | Phase 4 | Ship the gate and the prompt UI in the same PR, never the gate alone. |
| 8 | Removing the FIT parser or Explore feature (`CQ-11`, `UX-3`) removes something a stakeholder wanted live soon | Phase 3 | Treat as explicit product decisions surfaced in this plan, not unilateral engineering calls — confirm before starting either path. |
| 9 | New CI lint/analyze gates (`TS-8`) block all in-flight PRs on pre-existing, unrelated warnings | Phase 2 | Land in report-only mode first, clear the backlog, then flip to blocking. |
| 10 | Dependency bumps (`DEP-1`, future Dependabot PRs) introduce breaking API changes | Phase 2 / 6 | Bump one ecosystem at a time; rely on the now-real Phase 2 test suite to catch regressions before merging. |
| 11 | This plan drifts from the current codebase state as development continues in parallel | All phases | Re-verify each task's file:line references immediately before starting it — this codebase moves fast (12 commits/3 weeks at audit time). |
| 12 | Backend DI refactor (`CQ-10`) has a wide blast radius across every request path | Phase 3 | Run the full backend test suite, including Phase 2's new integration tests, before merging; consider a second reviewer given the scope. |

---

## 5. Resourcing & Sequencing

**Total estimated one-time effort:** roughly **40-45 developer-days** (~8-9 weeks solo, full-time) across Phases 1-5, excluding: `UX-2`'s translation content work (separately scoped, needs a translator not an engineer), and either "finish it for real" path under `CQ-11`/`UX-3` if that direction is chosen (both are open-ended feature investments, not bounded remediation). Rough phase totals: Phase 1 ≈ 5.5 days, Phase 2 ≈ 8.5 days, Phase 3 ≈ 8 days (excluding open-ended `CQ-11`/`UX-3` paths), Phase 4 ≈ 12.5 days, Phase 5 ≈ 7-9 days (excluding `UX-2` content time).

**Suggested solo execution order:** exactly the phase order above (1→2→3→4→5→6) — it's already sequenced by dependency and risk, not just severity. Within Phase 4, do the backend security bundle (`SEC-6,7,8,10,11`) before the Flutter security bundle (`SEC-3,5,9`) since the backend items are more isolated/lower-risk, giving you momentum before the riskier client-side storage migration (`SEC-5`).

**If more hands are available:** split along the four tracks in §1 (Flutter app / Go backend / GPS-native packages / Docs-CI-infra) — they're largely independent, with the cross-track dependencies already called out in §1's sequencing table. A team of 3-4 could realistically compress the 8-9 week solo estimate to 2-3 weeks by running all four tracks in parallel through Phase 4, converging for Phase 5 polish.

**Do not batch-execute without a human decision point:** every 🔒-flagged task above, plus `OPS-2` (keystore custody), `UX-2` (translation quality), and `CQ-9` (refactor split boundaries) even though not security-flagged. Everything else in §1's "safe for bulk/automated execution" list can be picked up and run without a mid-task check-in — but still report back per-PR rather than silently batch-merging, so review stays possible.

---

## 6. Definition of Done

This plan is "fully implemented" when all of the following are true:

- [ ] Every task in §3 is checked off, or explicitly deferred with a written reason and an owner (nothing silently dropped).
- [ ] CI enforces `flutter analyze`, Go lint/vet, Rust build/clippy, and the full test suite — including real Postgres/Redis integration tests — as a **blocking** gate on every PR.
- [ ] Manual QA confirms all of the following end-to-end:
  - [ ] Killing the app mid-run and relaunching surfaces a recovery prompt and restores the run.
  - [ ] A completed ghost race shows a populated route map and a non-empty split-comparison table.
  - [ ] Two simultaneous backend logins do not crash the process.
  - [ ] A prod-configured backend deploy without `JWT_SECRET` set refuses to start.
  - [ ] An existing v2-schema local install upgrades to v3 without crashing.
  - [ ] The SOS flow's UI copy accurately reflects its actual behavior.
  - [ ] The published release artifact is a signed, non-debuggable, optimized build.
- [ ] No Critical or High severity finding from `docs/AUDIT_REPORT.md` remains open.
- [ ] `docs/API_REFERENCE.md` matches the real backend API surface (response shapes, routes, and status codes verified against the handlers).
- [ ] The Ongoing-phase practices (§2, Phase 6) are actually running, not just documented: Dependabot/Renovate is active, CI gates are blocking, and a note exists in the repo for when the next scoped re-audit is due.
- [ ] Nice-to-have items either shipped or have an explicit owner/ticket — "eventually" has a name attached, not just a hope.
