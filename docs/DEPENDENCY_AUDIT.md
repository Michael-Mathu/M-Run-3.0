# Dependency Audit

Ran per `docs/BUILD_PLAN.md` `DEP-5`, 2026-08-21. No live CVE database access in this environment — this records what the local tooling (`go list -m -u all`, `flutter pub outdated`, `cargo audit`) reports and a triage decision per flagged item, not a CVE scan. Re-run against a real vulnerability database (e.g. GitHub Dependabot alerts, `govulncheck`, `osv-scanner`) before a real release.

## Go backend (`go list -m -u all`)

| Module | Current | Latest | Decision |
|---|---|---|---|
| `golang.org/x/crypto` | v0.31.0 | v0.55.0 | **Upgrade soon** — this is the bcrypt/crypto primitives package; 24 minor versions behind is more staleness than a security-relevant package should carry. Low risk to bump (stdlib-adjacent, stable API). |
| `github.com/redis/go-redis/v9` | v9.7.0 | v9.22.0 | **Upgrade opportunistically** — 15 minor versions behind. Re-run `TS-1`'s new Redis integration tests after bumping to catch any behavior drift. |
| `github.com/golang-jwt/jwt/v5` | v5.2.0 | v5.3.1 | **Upgrade opportunistically** — small gap, this is the JWT signing/verification library so worth staying current, but no known urgent issue at this version. |
| `github.com/lib/pq` | v1.10.9 | v1.12.3 | **Defer** — already flagged in the audit as effectively unmaintained upstream (maintenance-mode, no new development, community favors `pgx`). A version bump doesn't address that; migrating to `pgx` is the real fix and is a bigger, separately-scoped change. |
| `golang.org/x/net`, `golang.org/x/sys`, `golang.org/x/term`, `golang.org/x/text` | various | various (30+ minor behind each) | **Accept for now, bundle with the `x/crypto` bump** — these are indirect/transitive `golang.org/x/*` deps that will likely move together when `go mod tidy` runs after upgrading direct deps. |
| `github.com/cespare/xxhash/v2` | v2.2.0 | v2.3.0 | **Accept** — indirect, trivial version gap. |
| `github.com/dgryski/go-rendezvous` | pseudo-version (2020) | (none newer listed) | **Accept** — indirect, no newer version available. |

**Not done in this session**: actually bumping any of these. Version bumps are exactly the kind of change that should go through the now-real test suite (`TS-1`, `TS-9`, etc.) in its own reviewed PR, not get bundled silently into an unrelated change. Recommend one PR per upgrade batch (e.g. "bump golang.org/x/* " as one PR), verified against `go test -race ./...` (now in CI as of this session).

## Flutter app (`flutter pub outdated`)

Full table in the command output; highlights:

| Package | Current | Latest | Decision |
|---|---|---|---|
| `permission_handler` | 11.4.0 | 13.0.1 (2 majors behind) | **Defer, but track** — this package gates location/notification permission flows, which are safety/tracking-critical (see `SEC-14` on iOS permission handling already pending). A major bump here should be its own carefully-tested change, not bundled with anything else. |
| `google_fonts` | 6.3.3 | 8.2.1 (2 majors behind) | **Defer** — cosmetic-only package, low urgency, but a 2-major gap is worth closing eventually to avoid a bigger jump later. |
| `shimmer` | 3.0.0 | 4.0.0 (major) | **Defer** — cosmetic loading-skeleton package, low risk either way. |
| `sqlite3_flutter_libs` | 0.5.42 | 0.6.0+eol | **Investigate before upgrading** — the `+eol` build suffix on the latest version is worth understanding before bumping (could mean the *current* 0.5.x line is what's end-of-lifed, i.e. this may actually be more urgent than a routine bump — check the package's changelog). Flagging, not deciding, since this needs a read of the actual release notes. |
| `flutter_riverpod` / `riverpod` | 3.3.2 | 3.4.2 | **Upgrade opportunistically** — minor version, core state-management dependency, worth staying current. Re-run the full test suite after. |
| `maplibre_gl` | 0.26.2 | 0.27.0 | **Defer, test carefully** — map rendering is highly visual/platform-specific; a bump here needs manual on-device verification this session couldn't do (no way to visually verify map rendering). |
| `go_router`, `dio`, `drift`, `share_plus`, `flutter_local_notifications` | various | various (minor versions behind) | **Upgrade opportunistically** — all minor-version gaps on actively-used core packages, low risk. |
| `build_runner`, `drift_dev`, `flutter_launcher_icons` (dev deps) | various | various | **Accept for now** — dev-only tooling, no runtime/security exposure. |

**Not done in this session**: same reasoning as the Go deps — version bumps deserve their own reviewed PR(s) backed by the real test suite, not a silent bundle into this remediation branch. Suggest grouping into: (1) a "safe minor bumps" PR (riverpod, go_router, dio, drift, share_plus, flutter_local_notifications), (2) a dedicated `permission_handler` major-version PR with manual device testing, (3) a dedicated `maplibre_gl` major-version PR with manual map-rendering verification, (4) research `sqlite3_flutter_libs`'s `+eol` tag before deciding.

## Rust (`packages/mwendo_fit_parser/rust`)

Locked versions (`Cargo.lock`): `fitparser 0.5.1`, `serde_json 1.0.150` — both reasonably current, no immediate concern from version numbers alone. `cargo audit` (RustSec advisory database) was attempted in this session but could not complete — `cargo install cargo-audit` requires compiling it, and this Windows dev environment has no MSVC linker (`link.exe`) available (the same limitation that blocked locally verifying the new CI Rust job — see `docs/BUILD_PLAN.md` `TS-8`'s caveat). **Run `cargo audit` in CI or on a properly-provisioned machine** before relying on "no known issues" for this crate.

## `app-rn`

No `package.json` exists (confirmed during the original audit — it's a single orphaned `.ts` file with no build scaffolding), so `npm audit` has nothing to audit. Moot pending `docs/BUILD_PLAN.md` `CQ-13`'s decision to delete or properly scaffold this directory.

## Summary

Nothing found here rises to "drop everything and patch now" — no flagged item has a known, named vulnerability, only staleness. The two genuine gaps in this audit are: (1) `cargo audit` couldn't actually run against the RustSec database in this environment, and (2) none of this was checked against a real CVE/advisory database (GitHub Dependabot, `govulncheck`, `osv-scanner`) since this environment has no such access — treat this document as a staleness triage, not a security clearance.
