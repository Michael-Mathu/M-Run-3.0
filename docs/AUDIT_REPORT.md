# Mwendo (M-Run 2.0) — System Audit Report

**Date:** 2026-08-21
**Scope:** Full monorepo — Flutter client (`app/`), Go backend (`backend/`), Dart packages (`packages/gps_pipeline`, `packages/mwendo_gps_engine`, `packages/mwendo_fit_parser`), docs, CI/CD, and infra config.
**Method:** Full read of every backend Go file, every core/data Dart file, every feature-screen Dart file, every package/native file, all docs, all CI workflows, and repo/git metadata. Findings below are traceable to specific files and lines; severities reflect concrete failure scenarios, not stylistic taste.
**Project context:** This is a young, single-author codebase — 12 commits spanning roughly three weeks (Aug 1–16, 2026 per `git log`), with heavy "docs: add comprehensive documentation" and "feat: overhaul telemetry pipeline" commits suggesting rapid, possibly AI-assisted, greenfield development. Severities below are calibrated for a pre-release project, not a mature system with years of drift — sparse tests and rough edges are expected at this stage; the findings that matter most are the ones that would actively break the product's headline promises.

---

## 1. Executive Summary

Mwendo is an ambitious, well-architected *design* — a 7-stage deterministic GPS filtering pipeline, offline-first Drift persistence, a Go/PostGIS/Redis backend, and a "Beat Legends" ghost-racing mode. The GPS math itself is genuinely good: the Kalman filter, outlier detection, and coordinate transforms in `packages/gps_pipeline` largely match the architecture docs and are correctly implemented. The Go backend has clean SQL parameterization and correct bcrypt usage.

But the distance between the documented design and the shipped behavior is large, and it's concentrated exactly where users would notice it. Two of the app's three headline features are broken end-to-end in ways that are trivial to hit in normal use, not edge cases:

1. **"Zero-Loss Crash Recovery" doesn't recover anything.** The crash-recovery journal is durably written to the Drift database, but the code path that checks "is there a run to recover?" reads a JSON file that is never written anywhere in the codebase. A run interrupted by a crash is unrecoverable today, despite ~150 lines of code dedicated to making it recoverable. Confirmed independently by two separate audit passes (data layer and feature layer).
2. **The Beat Legends ghost-race result screen is broken.** The post-race route map is always empty and the split-by-split comparison table always renders zero rows, because the result screen has a stubbed JSON parser ("Simplified — in production use jsonDecode") that discards the real data `GhostRaceController` already computed and encoded correctly.
3. **Auth backend has a crash bug and an insecure default.** `refreshTokens`, a package-level map in `backend/internal/auth/handler.go`, is read/written/deleted with no mutex — two concurrent logins can trigger Go's *fatal* (non-recoverable) `concurrent map writes` error and kill the whole process. Separately, `JWT_SECRET` silently falls back to a hardcoded string with no fail-fast check for production environments.
4. **A DB migration bug will crash existing installs on update.** The `onUpgrade` path that bumps the schema to add GPS telemetry columns adds 6 of 7 new columns but omits `state` — any user who upgrades through this path (rather than a fresh install) hits `no such column: state` on every activity read.
5. **The Safety SOS feature doesn't do what its UI promises.** The countdown dialog implies an autonomous emergency alert ("Sending SOS… Alerting Contacts"), but `sendSos()` only opens the native SMS compose screen pre-filled — the user still has to manually tap Send, for each contact. In a genuine emergency, that gap between implied and actual behavior is dangerous.

Beyond these, the release pipeline publishes a **debug, unsigned, unoptimized APK as a GitHub "Release"** — a real distribution risk, not a nitpick. Documentation (`docs/API_REFERENCE.md`) is significantly out of sync with the actual backend API (wrong response shapes, a documented endpoint that doesn't exist, undocumented working ones). Swahili localization is largely cosmetic — 200 of 319 lesson-content string pairs are byte-identical English copies. And the Rust FIT-file parser is non-functional scaffolding with a broken data path from Dart.

None of this is late-stage rot — it reads like feature work that outpaced the wiring between layers. The fixes are mostly targeted and well-scoped (see §4), not a rearchitecture.

---

## 2. Architecture Overview

```
                         Flutter Client (app/)
  ┌─────────────────┐   ┌──────────────────┐   ┌───────────────────────┐
  │ Live Tracking UI │   │ Beat Legends     │   │ Drift/SQLite Storage  │
  │ (MapLibre + HUD) │   │ Ghost Pacing     │   │ Activities / Drafts   │
  └────────▲─────────┘   └────────▲─────────┘   └───────────▲───────────┘
           │                      │                          │
  ┌────────┴──────────────────────┴──────────────────────────┴─────────┐
  │           Riverpod state layer (TrackingModel, GhostRaceController,│
  │           GamificationNotifier, SessionProvider)                   │
  └────────────────────────────────▲────────────────────────────────────┘
                                    │
        ┌───────────────────────────┼────────────────────────────┐
        │ (RawFix stream)           │ (Method/EventChannel)       │
        ▼                           ▼                             │
 ┌─────────────────────┐  ┌─────────────────────────┐             │
 │ packages/gps_pipeline│  │ packages/mwendo_gps_engine│           │
 │ pure-Dart 6-stage    │  │ Android foreground svc / │            │
 │ filter (validator →  │  │ iOS CLLocationManager    │            │
 │ Kalman → gap detect) │  └─────────────────────────┘             │
 └─────────────────────┘                                           │
        │ (post-session, HTTP)      ┌────────────────────────┐     │
        └───────────────────────────► packages/mwendo_fit_parser│  │
                                     │ Rust FFI (non-functional│   │
                                     │ stub — see §3.1)        │   │
                                     └────────────────────────┘   │
                                                                    │ HTTP/JSON
                                                                    ▼
                                          ┌─────────────────────────────┐
                                          │ Go backend (backend/)       │
                                          │ PostGIS geography storage,  │
                                          │ Redis leaderboard (w/       │
                                          │ in-memory fallback), JWT    │
                                          │ auth, bcrypt                │
                                          └─────────────────────────────┘
```

This matches `docs/ARCHITECTURE.md`'s intent reasonably well as a *static* diagram. The gap is in the runtime wiring: the pipeline's 7th stage (map-matching) is never actually invoked by the pipeline object itself (it's a separate, manually-orchestrated post-session job); the crash-recovery arrow between the DB and the UI is broken (§3.1 finding); and the "Beat Legends" arrow from `GhostRaceController` into the result screen is broken by a stub parser. The backend is real and mostly sound but is currently a single-instance-assuming service (in-memory leaderboard fallback, in-memory refresh-token store) with no persistence volume configured in `docker-compose.yml`, so it isn't yet safe to run as anything but a local dev box.

A stray `app-rn/` directory contains a single orphaned TypeScript file (`app-rn/src/db/models.ts`) with no `package.json` and no other RN scaffolding — it's dead weight, not a second client.

---

## 3. Findings by Category

### 3.1 Code Quality & Architecture

| ID | Severity | Location | Finding |
|---|---|---|---|
| CQ-1 | **Critical** | `app/lib/features/tracking/tracking_controller.dart:176-336`; `app/lib/features/tracking/live_dashboard.dart:52-57` | Crash-recovery write path (`_writeRecovery`, Drift-backed) and read path (`hasRecoverableRun`/`restoreInterrupted`, JSON-file-backed) target different storage entirely. Nothing writes `mwendo_recovery.json`. `hasRecoverableRun()` always returns `false`. |
| CQ-2 | **Critical** | `app/lib/features/beat/ghost_result_screen.dart:45-53,172,182` | Stubbed route/split parser ("Simplified — in production use jsonDecode") means `splitComparisons` and `routePoints` are always empty, even though `app_router.dart:234-235` passes real `jsonEncode`d data. |
| CQ-3 | **High** | `app/lib/features/tracking/live_dashboard.dart:626-661` | `else if (newly.isNotEmpty && mounted)` is nested inside a branch already gated on `mounted`, so the `else` is unreachable when `mounted` is true — regular (non-ghost) challenge-completion celebrations never render. |
| CQ-4 | **High** | `app/lib/data/database/app_database.dart:92-129`; `app/lib/data/repositories/session_draft_repository.dart:16-76` | Multi-step writes (upsert parent → delete old points → batch insert new points) are not wrapped in `transaction()`. A crash mid-write leaves stale/missing points — notably in the draft table that exists specifically to survive crashes. Contrast with `map_match_job.dart:101-117`, which does this correctly. |
| CQ-5 | Medium | `app/lib/core/network/leaderboard_provider.dart` / duplicate provider decls | `appDatabaseProvider` is declared twice (`app_database.dart:11` and `activity_repository.dart:50`); two functions named `ensureLocationPermission` exist (`core/permissions/location_permission.dart` — the real one, and `core/permissions/permissions.dart` — a weaker unused duplicate with no denial UI). |
| CQ-6 | Medium | `app/lib/data/models/activity.dart`, `trackpoint.dart`, `run_record.dart:145-217`; `app/lib/main.dart:7` vs `app/lib/app.dart:10` | Dead duplicate model classes (superseded by Drift-generated types), a dead `RunRecord.fromJson` path with unguarded `as num` casts, and two `main()` functions (only `main.dart`'s runs). |
| CQ-7 | Medium | `app/lib/features/beat/beat_legends_page.dart:227-239,259-269`; `activity_type_selector.dart:58-178` | `_recommendTier` logic duplicated verbatim between two widgets; three near-identical card builders in the activity-type selector. |
| CQ-8 | Medium | `app/lib/design_system/*` | 11 shared components (`app_button.dart`, `app_avatar.dart`, `app_lesson_card.dart`, `app_course_tile.dart`, `app_legend_card.dart`, `app_leaderboard_row.dart`, `app_streak_ring.dart`, `app_continue_banner.dart`, `app_fab.dart`, `app_coach_badge.dart`, `app_tip_sheet.dart`) are grep-confirmed unused anywhere in `lib/` — features hand-roll equivalent UI instead of reusing the design system built for them. |
| CQ-9 | Medium | `app/lib/features/tracking/tracking_controller.dart` (701 lines) | God-object: owns GPS stream handling, pipeline processing, recovery persistence, wall-clock ticking, and command queueing in one class. The "recompute distance from filtered results" loop is duplicated verbatim at lines 528-542 and 606-622. |
| CQ-10 | Medium | `backend/internal/{activity,auth,leaderboard}/handler.go` | Handler/store separation is clean and consistent across all three domains, but each relies on mutable package-level globals instead of struct-based DI — fine for a single-instance dev service, but blocks `t.Parallel()` tests and multi-instance safety. |
| CQ-11 | Low | `packages/mwendo_fit_parser/rust/src/lib.rs:5-19`; `lib/mwendo_fit_parser.dart:15-45` | `parseBytes()` never uses its own `bytes` argument — it fabricates a hardcoded Android-only path and passes that to Rust instead, which just echoes it back. The `fitparser` crate is a declared dependency but never imported. No `android/`/`ios/` build wiring exists to compile/bundle the Rust `cdylib` at all. This is scaffolding, not a working feature. |
| CQ-12 | Low | repo root | Stray tracked developer-debris files: `log.txt` and `router_log.txt` (502 lines each of raw, oddly-encoded `git log -p` output), `fix_page_file.ps1` (a personal Windows pagefile-tuning script for a Gradle OOM issue), `app/analyze_output.txt` (a **stale** pre-refactor `flutter analyze` capture — verified the errors it lists no longer exist in current code), `app/debug_crash_guide.md`, `.kilo/plans/mwendo-v2-upgrade-plan.md` (an AI assistant's internal planning doc). None of these belong in version control. |
| CQ-13 | Low | `app-rn/src/db/models.ts` | Orphaned single-file TypeScript stub with no `package.json`/build scaffolding — not a real second client, just dead weight that misleads anyone mapping the repo. |
| CQ-14 | Low | root | `LICENSE-AGPL` is a literal placeholder stub (`[AGPL v3 License Text Stub]`) with zero references anywhere else in the repo; README only claims Apache/MIT dual-licensing. License files carry legal weight regardless of intent — this should be deleted, not left ambiguous. |

### 3.2 Testing

| ID | Severity | Location | Finding |
|---|---|---|---|
| TS-1 | **High** | `backend/internal/{auth,activity}/store_test.go`, `main_test.go` | Every backend test exercises only the in-memory store fallback. The entire Postgres-backed `DBStore` (geography casts, `ST_Simplify`, transaction rollback) and the Redis-backed leaderboard branch have **zero** test coverage — and CI (`test.yml`) has no `services:` block, so it structurally cannot catch regressions in the code paths actually used by `docker-compose.yml`/production. |
| TS-2 | High | `app/test/activity_repository_test.dart` | Stale — tests a JSON-file-backed repository that no longer exists (the real `ActivityRepository` is Drift-backed). Several tests pass vacuously without exercising real behavior. |
| TS-3 | High | `app/lib/data/database/app_database.dart` (migrations) | No test exists for the `onUpgrade` migration path at all — this is exactly what would have caught the missing-`state`-column bug (CQ / see §3.1, "Critical" items list under Findings summary). |
| TS-4 | Medium | `packages/gps_pipeline/test/replay_test.dart` | Never touches the checked-in `synthetic_truth.ndjson`/`synthetic_raw.ndjson` fixtures; generates its own 3-point trace and asserts only array length and a status enum — no numeric accuracy assertions. |
| TS-5 | Medium | `packages/gps_pipeline/tool/kalman_calibrate.dart` | The actual ground-truth accuracy validation is a manual CLI tool that `print()`s deviation stats for a human to eyeball — never wired into `dart test` or CI, despite the fixtures existing specifically for this purpose. |
| TS-6 | Medium | `packages/gps_pipeline/` | Zero direct unit tests for `coordinate_util.dart`, `quality_gate.dart`, `gap_detector.dart`, `quality_metrics.dart`, `match_quality.dart`, and `OsrmMatchProvider`'s chunking/retry/backoff logic in `map_matcher.dart:74-146`. |
| TS-7 | Medium | `packages/mwendo_gps_engine/android/.../MwendoGpsEnginePluginTest.kt` | Tests a `"getPlatformVersion"` method that doesn't exist in the current plugin API — stale `flutter create` scaffolding that would fail if actually run. |
| TS-8 | Medium | `.github/workflows/test.yml` | No `flutter analyze` step despite the Makefile defining exactly that target and `docs/CONTRIBUTING.md` mandating "zero warnings" on every PR; no lint/format check (`dart format`/`gofmt`/`cargo fmt`) despite the same doc requiring it; **zero** CI coverage for the Rust crate (no `cargo build`/`test`/`clippy` job anywhere) even though it's unsafe FFI code that will eventually parse untrusted binary files. |
| TS-9 | Low | untested-but-fine | `ghost_race_controller.dart`'s pure computation functions and `challenge_evaluator.dart`'s evaluation logic are clean, side-effect-free, and easily testable — flagged only because they currently have no direct unit tests despite being the cheapest, highest-value tests to add. |

### 3.3 Security

| ID | Severity | Location | Finding |
|---|---|---|---|
| SEC-1 | **Critical** | `backend/internal/auth/handler.go:21,96,109,124` | Package-level `refreshTokens = make(map[string]string)` is mutated from `Login`/`Refresh`/`Logout` with no synchronization (unlike `MemoryStore`, which correctly mutexes). Two concurrent requests can trigger Go's fatal, unrecoverable `concurrent map writes` error, killing the whole process — trivially reproducible under real load. |
| SEC-2 | **High** | `backend/internal/config/config.go:14-17` | `JWT_SECRET` silently defaults to the hardcoded literal `"dev-insecure-secret-change-me"` with no fail-fast check when running in a production-like environment. `Config.Env` is loaded but never actually branched on anywhere. A prod deploy that forgets to override the secret (or inherits `docker-compose.yml`'s own `"change-me-in-production"` default) boots normally and silently signs forgeable JWTs. |
| SEC-3 | **High** | `app/lib/core/network/api_client.dart:7-10`; `app/android/app/src/main/AndroidManifest.xml:14` | `kApiBaseUrl` defaults to plaintext `http://10.0.2.2:8080`, and `android:usesCleartextTraffic="true"` is set — a build that forgets to override `API_BASE_URL` at build time ships with login/register credentials sent unencrypted. |
| SEC-4 | High | `app/lib/features/tracking/map_match_job.dart:22-33` | The user-consent check for sending GPS traces to a third party is commented-out dead code. Every completed run is unconditionally POSTed to the **public OSRM demo server** (`router.project-osrm.org`) for map-matching — a real privacy gap and a reliance on a third-party demo instance with no SLA for production traffic. |
| SEC-5 | Medium | `app/lib/core/network/api_client.dart:18-34`; `session_provider.dart:21-22,62-65` | JWT and session identity (userId/email) are persisted via plaintext `SharedPreferences`, not Keychain/Keystore-backed secure storage, on both platforms. Confirmed independently by both the data-layer and feature-layer audits. |
| SEC-6 | Medium | `backend/internal/auth/handler.go:69-88,59-61` | Login returns distinguishable error bodies for "account doesn't exist" vs. "wrong password" (both 401); Register echoes the conflicting email back on 409 — classic account-enumeration oracle. |
| SEC-7 | Medium | `backend/internal/auth/handler.go:97-99` | Refresh-token cookie is `HttpOnly`+`SameSite=Lax` but has no `Secure` flag and no expiry — server-side, entries never expire until explicit logout. A leaked token is valid indefinitely and can travel over plain HTTP. |
| SEC-8 | Medium | `backend/cmd/api/main.go:74-87` | CORS middleware defaults `Access-Control-Allow-Origin: *` while simultaneously setting `Access-Control-Allow-Credentials: true` — an invalid, spec-violating combination that's a red flag if `CORS_ORIGIN` is ever pointed at a real origin without tightening this. |
| SEC-9 | Medium | `app/lib/features/auth/session_provider.dart:114-121`; `auth_page.dart:34-39` | `_errMessage` returns `null` for any `DioException` that isn't a recognized 401/409/JSON-error shape — including plain timeouts/connection failures. The UI treats `err == null` as login success and dismisses the auth sheet, even though no session was actually established. |
| SEC-10 | Medium | none found (no request-body caps) | No handler wraps `r.Body` in `http.MaxBytesReader`; `activity/store.go`'s trackpoint-insert loop has no cap on array length before looping DB inserts inside one transaction — an authenticated (or, for `/auth/register`, unauthenticated) caller can send an unbounded JSON body. |
| SEC-11 | Low | `backend/internal/auth/store.go:91`; no-DB fallback | In no-DB dev mode, `MemoryStore` IDs users as `"mem-" + email`, and the leaderboard endpoint is intentionally public/unauthenticated — leaking email addresses in that fallback mode. |
| SEC-12 | Low | `packages/mwendo_fit_parser/rust/src/lib.rs` | No `catch_unwind` around `extern "C"` entry points; a future real parser hitting malformed FIT bytes could panic across the FFI boundary and abort the whole process rather than surfacing a Dart-catchable error. Not exploitable today only because the parser doesn't parse anything yet. |
| SEC-13 | Confirmed non-issue | `backend/internal/{activity,auth}/store.go` | SQL injection: every query is parameterized (`$1..`); the one string-built WKT fragment only interpolates `float64` via `%.8f` from server-computed coordinates, never attacker strings. IDOR: both `DBStore.Get`/`List` and `MemoryStore` equivalents correctly filter by `user_id`. Password hashing uses `bcrypt.DefaultCost` with no plaintext storage anywhere. |

### 3.4 Performance & Scalability

| ID | Severity | Location | Finding |
|---|---|---|---|
| PF-1 | Medium | `backend/internal/activity/store.go:116-128` | Trackpoints are inserted one row at a time in a loop of individual `ExecContext` calls rather than batched — many round-trips per activity for long GPS traces. |
| PF-2 | Medium | `backend/internal/leaderboard/leaderboard.go:17-21` | The in-memory leaderboard fallback map is confirmed per-process state — with `REDIS_URL` unset and more than one backend replica running, each replica shows a diverging leaderboard. |
| PF-3 | Low | `backend/internal/db/db.go:24-25` | `MaxOpenConns(25)`/`MaxIdleConns(5)` are set but `ConnMaxLifetime`/`ConnMaxIdleTime` are not — risk of stale-connection errors behind a load balancer or pgbouncer over long uptime. |
| PF-4 | Confirmed non-issue | `backend/internal/db/migrations/0001_init.sql` | Indexes match actual query patterns: `idx_activities_user(user_id, started_at DESC)` matches `List`; `idx_trackpoints_activity(activity_id, seq)` matches the ordered trackpoint fetch in `Get`. No missing-index problem found. |
| PF-5 | Low | `packages/gps_pipeline/lib/src/coordinate_util.dart:25-42` | No antimeridian (±180° longitude) wraparound handling in the ENU coordinate transform — a track crossing the dateline would produce a wildly wrong local position (~40,000 km off instead of ~11 km). Currently untested and likely irrelevant for most real usage, but a real correctness gap if the app is ever used near the dateline. |

### 3.5 Dependencies

| ID | Severity | Finding |
|---|---|---|
| DEP-1 | Medium | `backend/go.mod` declares `go 1.26.4` with no explicit `toolchain` directive; `.github/workflows/test.yml:23` and `docs/SETUP_AND_DEPLOYMENT.md:11` both still say "Go 1.22". Because Go's toolchain auto-switch (`GOTOOLCHAIN=auto`, default since 1.21) will silently download and re-exec 1.26.4 on GitHub-hosted runners, this **does not currently fail CI** — but it's real version-pin drift that would break on any network-restricted or self-hosted runner, and the docs are simply wrong. |
| DEP-2 | Low | `github.com/lib/pq v1.10.9` — the driver's upstream project has publicly stated it's in maintenance mode with no new development, in favor of `pgx`. Not urgent, but worth planning around for a project intending to scale the backend. |
| DEP-3 | Low | `app/pubspec.yaml:18` — `go_router: ^17.3.0` is a very new major version pinned against only a Dart SDK floor (`^3.12.2`), no explicit Flutter SDK floor in the pubspec itself. Worth a compatibility sanity check, not a confirmed break. |
| DEP-4 | Low | No `dependabot.yml`/Renovate config anywhere in the repo — no automated dependency-update mechanism for any of the four package ecosystems in play (pub, Go modules, npm for the orphaned `app-rn`, Cargo). |
| DEP-5 | Note | No network access was available during this audit to check live CVE databases for any ecosystem. Versions were reasoned about from the numbers alone; nothing in `jwt/v5`, `x/crypto`, `redis/go-redis/v9`, or the Cargo dependencies looked alarmingly stale, but this should be confirmed with `go list -m -u all`, `flutter pub outdated`, `cargo audit`, and `npm audit` (if `app-rn` is kept) before shipping. |

### 3.6 Infrastructure & DevOps

| ID | Severity | Location | Finding |
|---|---|---|---|
| OPS-1 | **High** | `docker-compose.yml` (`db` service) | **No `volumes:` entry at all** — Postgres data is not persisted across container recreation, let alone backed up. There is no backup or restore strategy documented anywhere in the repo. |
| OPS-2 | **High** | `.github/workflows/release.yml:29-32` | The "Release" workflow runs `flutter build apk --debug` and publishes the result as a GitHub Release artifact. This is a **debug** build: unsigned (Android debug keystore, not upgradeable/Play-Store-distributable), unoptimized (no R8/ProGuard shrinking or obfuscation), and debuggable (`android:debuggable="true"`, letting anyone attach ADB/a debugger to the running app). Labeling this a "Release" is actively misleading to anyone who downloads it. |
| OPS-3 | Medium | backend-wide | No structured logging (`main.go` uses only stdlib `log.Fatal`/`log.Println`), no request middleware, no correlation IDs, no `/metrics` endpoint, no Prometheus/OpenTelemetry anywhere. `GET /api/v1/health` does exist and correctly reports DB-connection state — that part is genuinely solid, it's just undocumented. |
| OPS-4 | Medium | repo-wide | No deployment or rollback pipeline exists for the Go API at all — `release.yml` only ever touches the Android APK. How the backend is meant to reach a real environment is entirely undocumented. |
| OPS-5 | Medium | `backend/Dockerfile` | Multi-stage build is otherwise sound (`golang:1.26-alpine` → `alpine:latest`, `CGO_ENABLED=0`), but there's no `USER` directive (container runs as root) and the final-stage base image tag (`alpine:latest`) is unpinned/floating. |
| OPS-6 | Medium | `.github/workflows/test.yml` | Single-OS, single-version matrix (`ubuntu-latest` only, floating `flutter-version: '3.x'`); no iOS build verification despite the docs describing iOS support; no dependency caching on either job. |
| OPS-7 | Low | `backend/cmd/api/main.go` | `corsMiddleware`'s wildcard-plus-credentials misconfiguration (see SEC-8) is really an infra/config issue as much as a security one — worth fixing in the same pass as environment-based CORS origin config. |

### 3.7 UX / Product

| ID | Severity | Location | Finding |
|---|---|---|---|
| UX-1 | **Critical** | `app/lib/core/safety/safety_service.dart:4-13`; `live_dashboard.dart` `_SosCountdownDialog` (~1006-1112) | SOS countdown dialog UI ("Sending SOS…", "Alerting Contacts") strongly implies an autonomous alert, but `sendSos()` only opens the native SMS compose screen per-contact — the user must manually tap Send for each one. In a real emergency, this expectation mismatch is dangerous. |
| UX-2 | High | `app/lib/features/learn/data/courses.dart` | Swahili localization is largely cosmetic: 200 of 319 `(en, sw)` string pairs are byte-identical. Short UI labels are genuinely translated; the substantive lesson-paragraph content — the actual educational value of the "Learn" feature — is English copy-pasted into the `sw` field with no visible indication to Swahili-locale users. |
| UX-3 | Medium | `app/lib/features/explore/explore_provider.dart:101-160`; `route_detail_page.dart:91-115`; `explore_page.dart` Segments tab | The Explore feature is a fully hardcoded, unwired mockup: sample route data, a "Start Run" button that ignores the selected route entirely (`context.go('/')`), and Segments-tab cards with no `onTap` at all despite looking identical to the tappable Routes cards. This is effectively the never-built "Route Planner" feature's placeholder shell. |
| UX-4 | Medium | `app/lib/features/beat/ghost_result_screen.dart:226-228` | Share button (`// TODO: Implement share image generation`) is a silent no-op — tapping it gives zero feedback rather than being disabled or showing "coming soon." |
| UX-5 | Medium | `app/lib/features/tracking/recovery_card.dart`, `route_analysis_screen.dart`, `activity_type_selector.dart` | Entire screens of hardcoded, non-localized English strings, including `route_analysis_screen.dart` surfacing raw internal pipeline jargon ("Rejection Rate", "Jumps/km") to end users with no explanation. `activity_type_selector.dart` also conveys selection state by color/border alone, with no `Semantics(selected:)` for screen readers. |
| UX-6 | Low | `app/lib/features/onboarding/onboarding_page.dart:182`; `activity_detail_page.dart:57,86` | Scattered hardcoded strings and a manually-formatted, non-locale-aware date (`d/M/yyyy`) alongside otherwise-localized text on the same screen. |
| UX-7 | Confirmed improvement over historical plan | `app/lib/features/profile/profile_page.dart` (1021 lines) | The `.kilo` upgrade-plan doc's characterization of Profile as "bare-bones" is now stale — it's genuinely feature-rich (photo/name edit with accessibility labels, theme mode, units, safety contacts, GPX export, leaderboard, badges). No dedicated Settings route exists, though — all configuration lives inside this one large screen. |

---

## 4. Prioritized Recommendations

### Critical — fix now (blocks any real release or user trust)

| # | Fix | Refs | Effort |
|---|---|---|---|
| 1 | Wire crash recovery to actually read from the Drift `SessionDrafts`/`SessionPoints` tables it already writes to, and delete the dead JSON-file code path | CQ-1 | 0.5–1 day |
| 2 | Implement the real JSON decode in `ghost_result_screen.dart` so route/splits actually render (the upstream data is already correct) | CQ-2 | 0.5 day |
| 3 | Add a mutex (or switch to `sync.Map`) around `refreshTokens` in `auth/handler.go`; add a startup check that refuses to boot with the default `JWT_SECRET` when `ENV` indicates production | SEC-1, SEC-2 | 0.5 day |
| 4 | Fix the `onUpgrade` migration to add the missing `state` column; add a regression test that runs the migration path end-to-end | CQ-4 (context), TS-3 | 0.5 day |
| 5 | Either make SOS actually send automatically (native SMS API / backend relay) or rewrite the UI copy so it accurately describes "opens a pre-filled text to each contact" | UX-1 | 1–2 days (UI-only fix is faster; real auto-send is more) |
| 6 | Stop shipping `flutter build apk --debug` as a GitHub "Release" — build a signed, obfuscated release APK/AAB with a real (secret-managed) keystore | OPS-2 | 1 day (assuming a keystore can be provisioned) |
| 7 | Wrap the two multi-step Drift write sequences (`saveRun`, `saveDraft`) in `transaction()` | CQ-4 | 0.5 day |
| 8 | Add a `volumes:` mount for the `db` service in `docker-compose.yml` so local/staging data survives container recreation | OPS-1 | <0.5 day |

### Important — fix soon (correctness, security posture, and product integrity)

| # | Fix | Refs | Effort |
|---|---|---|---|
| 9 | Fix the unreachable `else` branch gating regular challenge celebrations | CQ-3 | <0.5 day |
| 10 | Gate map-matching on real user consent (the check already exists, just commented out) before sending GPS traces to the public OSRM demo server; consider a self-hosted OSRM instance before any real launch | SEC-4 | 0.5 day (consent) + infra work for self-hosting |
| 11 | Move JWT/session storage to `flutter_secure_storage` (Keychain/Keystore) instead of `SharedPreferences` | SEC-5 | 1 day |
| 12 | Default `API_BASE_URL` to HTTPS and remove `usesCleartextTraffic="true"` once a real TLS-terminated backend exists | SEC-3 | 0.5 day + backend TLS setup |
| 13 | Fix `_errMessage`'s fallback-to-null-on-unknown-error, which currently makes network failures look like successful logins | SEC-9 | 0.5 day |
| 14 | Add integration tests (docker-compose-based, real Postgres/Redis) for the DB-backed store and Redis leaderboard paths, and wire them into CI with a `services:` block | TS-1 | 2–3 days |
| 15 | Add `flutter analyze`, `gofmt -l`/`go vet`, and `cargo build`/`clippy` steps to CI; align the CI Go version pin (or add an explicit `toolchain` directive) with `go.mod` | TS-8, DEP-1 | 1 day |
| 16 | Rewrite `docs/API_REFERENCE.md` against the actual handlers (login response shape, activity request/response fields, correct leaderboard route, and the four undocumented-but-real endpoints: register/refresh/logout/health) | — | 1–2 days |
| 17 | Real Swahili translation pass for lesson content in `courses.dart` (currently ~63% is English-in-disguise) | UX-2 | Content effort, not engineering — days to weeks depending on translator availability |
| 18 | Fix `copyWith` in `gps_pipeline/lib/src/models.dart` to actually preserve `smoothedSpeedMps` across gap/stationary-state transitions | (GPS packages audit) | 0.5 day |
| 19 | Add auth rate-limiting and generic (non-enumerable) error messages on login/register | SEC-6, SEC-10 | 1 day |
| 20 | Implement real iOS location-permission request/authorization-change handling and add the missing `Info.plist` usage-description keys (currently a near-certain crash risk on any real iOS device touching location APIs) | (GPS packages audit) | 1–2 days |

### Nice-to-have — fix eventually (quality, maintainability, hygiene)

| # | Fix | Refs | Effort |
|---|---|---|---|
| 21 | Remove stray tracked files (`log.txt`, `router_log.txt`, `fix_page_file.ps1`, stale `app/analyze_output.txt`, `app/debug_crash_guide.md`) and the placeholder `LICENSE-AGPL` | CQ-12, CQ-14 | <0.5 day |
| 22 | Delete or properly scaffold `app-rn/` — a single orphaned file with no build system is confusing dead weight | CQ-13 | <0.5 day |
| 23 | Consolidate duplicate providers/permission helpers/model classes and the duplicate `main()` | CQ-5, CQ-6 | 1 day |
| 24 | Split `tracking_controller.dart` into smaller services (GPS stream handling, recovery I/O, record-building) and de-duplicate the distance-recompute loop | CQ-9 | 1–2 days |
| 25 | Actually use the 11 unused design-system components, or delete them if the feature screens' hand-rolled equivalents are considered final | CQ-8 | Ongoing / low priority |
| 26 | Add unit tests for the currently-untested-but-cleanly-testable pure logic (`ghost_race_controller.dart` computations, `challenge_evaluator.dart`) and for `coordinate_util.dart`/`gap_detector.dart`/`quality_gate.dart` in `gps_pipeline` | TS-6, TS-9 | 2–3 days |
| 27 | Wire the `kalman_calibrate.dart`/ground-truth fixtures into an actual asserting test rather than a manual eyeball-the-printout tool | TS-4, TS-5 | 1 day |
| 28 | Either finish `mwendo_fit_parser` (real `fitparser` crate integration, real byte-passing from Dart, platform build wiring) or remove it from the dependency graph until it's ready | CQ-11 | Multi-day feature work, not a quick fix |
| 29 | Build out the Explore/Route Planner feature for real, or clearly mark it as a preview/placeholder in the UI rather than presenting dead taps as live features | UX-3 | Multi-day feature work |
| 30 | Add `dependabot.yml`/Renovate for pub, Go modules, and Cargo | DEP-4 | <0.5 day |
| 31 | Add structured logging, a `/metrics` endpoint, and connection-lifetime tuning to the Go backend | OPS-3, PF-3 | 1–2 days |

---

## 5. Suggested Roadmap

**Phase 0 — Stop the bleeding (this week).** Items 1–8 above. These are the bugs that break the app's actual headline promises (crash recovery, ghost racing) or that can crash the backend/mislead a user in an emergency. None of them require design decisions — they're bounded, well-understood fixes.

**Phase 1 — Make it safe to actually release (1–2 weeks).** Items 9–15 and 19–20: security posture (secure token storage, HTTPS default, consent gating, rate limiting), real integration test coverage against a live DB/Redis in CI, and iOS permission handling that currently risks an outright crash on first location use. Ship the corrected `docs/API_REFERENCE.md` (#16) alongside this phase so backend and client work stay in sync going forward.

**Phase 2 — Close the trust gaps (2–4 weeks, can run in parallel with Phase 1).** Real Swahili translation (#17), the Kalman `copyWith` data-loss fix (#18), and a decision on the FIT parser and Explore/Route Planner: either invest to finish them (items 28–29) or visibly mark them as previews so users don't hit dead taps and silent no-ops.

**Phase 3 — Cleanup and hardening (ongoing, low-risk work to interleave between feature work).** Repo hygiene (#21–22), de-duplication and the `tracking_controller` split (#23–24), design-system reuse (#25), the remaining test-coverage gaps (#26–27), dependency automation (#30), and backend observability (#31).

Given the single-author, three-week-old nature of this codebase, Phase 0 alone is realistically a few focused days of work — the underlying architecture doesn't need to change, the broken wiring between already-correct pieces does.
