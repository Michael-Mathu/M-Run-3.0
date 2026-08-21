# Backend Deployment

**Status as of this writing: there is no automated deployment pipeline.** `.github/workflows/release.yml` only builds and publishes an Android APK — nothing in this repository builds, pushes, or deploys the Go backend anywhere. This document describes the manual path that exists today (`backend/Dockerfile`) and what a real pipeline would need to add. Treat it as a starting point, not a finished runbook.

## What exists today

- `backend/Dockerfile` — a working multi-stage build producing a small, non-root Alpine image (`golang:1.26-alpine` builder → `alpine:3.21` runtime, `CGO_ENABLED=0`).
- `docker-compose.yml` — **local development only**. It builds the backend from source alongside Postgres/PostGIS and Redis containers on your machine. It has no analog for a real environment (no secrets management, no external database endpoint, no restart/health policy beyond the dev healthchecks).
- No container registry is configured. No image is ever pushed anywhere by CI.
- No environment-specific configuration exists (dev/staging/prod). `backend/internal/config/config.go` reads everything from plain environment variables with no per-environment profiles or validation beyond individual defaults.

## Manual deployment (what you'd do today)

1. **Build and tag the image:**
   ```bash
   cd backend
   docker build -t <registry>/mwendo-backend:<version> .
   ```
   Use a real version tag (a git SHA or semver), never `:latest` — you need a specific, previous tag to roll back to.

2. **Push to a registry** (Docker Hub, GHCR, ECR, etc. — none is currently wired up):
   ```bash
   docker push <registry>/mwendo-backend:<version>
   ```

3. **Provision Postgres (with PostGIS 16-3.4) and Redis 7** as managed services or your own containers — `docker-compose.yml`'s services are a reference for versions, not something to run in production as-is (no persistence/backup/failover configured — see `docs/BUILD_PLAN.md` `OPS-1`'s note about the local compose file, and provision real managed instances or properly-configured, backed-up instances instead).

4. **Run the image** with real environment variables:
   - `PORT` — defaults to `8080`.
   - `DATABASE_URL` — **required** for persistence; without it the backend silently runs on an in-memory store that's lost on restart (see the startup log it emits).
   - `REDIS_URL` — required if running more than one backend instance (see `docs/SETUP_AND_DEPLOYMENT.md`'s note on leaderboard divergence without it).
   - `JWT_SECRET` — **must** be set to a real, unique secret. The backend currently falls back to a hardcoded insecure default if unset (tracked as `docs/BUILD_PLAN.md` `SEC-2`, blocked pending your sign-off on fail-fast behavior) — don't rely on that changing; set this explicitly regardless.
   - `CORS_ORIGIN` — set to your real frontend origin(s), not the `*` dev default.
   - `ENV` — currently loaded but not actually branched on anywhere in the code (also part of `SEC-2`'s scope).

5. **Point traffic at it.** Nothing here terminates TLS — you need a reverse proxy/load balancer (or your platform's ingress) in front of the container for HTTPS; the backend itself only speaks plain HTTP on `PORT`. This is also why `docs/BUILD_PLAN.md` `SEC-3` (defaulting the Flutter client to HTTPS) is blocked — there's no HTTPS endpoint yet for it to default to.

## Rollback

There is no automated rollback. The manual path:
1. Identify the last known-good image tag (you tagged each build with a real version in step 1 above — this is why `:latest` is a trap).
2. Redeploy the container/service pointed at that previous tag.
3. **Database migrations are forward-only and idempotent** (`backend/internal/db/db.go`'s `Migrate` tracks applied versions in a `schema_migrations` table and skips ones already applied) but there is **no down-migration path**. If a bad deploy included a schema change, rolling back the *application* image does not undo the *schema* change — you'd need to manually assess whether the previous code version is still compatible with the new schema, or restore the database from a backup. **There is currently no documented or automated database backup strategy** — this is a real gap, not just an omission from this doc (see `docs/AUDIT_REPORT.md`'s `OPS-1` finding and `docs/BUILD_PLAN.md`'s note that `docker-compose.yml`'s local Postgres previously had no persistent volume at all, now fixed for local dev only).

## What a real pipeline would need (not built here)

This is a punch list for whoever picks this up, not a promise of what exists:

- A CI job that builds and pushes the Docker image on merge to `main` (or on a release tag), with proper image tagging (git SHA + semver).
- A container registry and a target platform (ECS/Cloud Run/Fly.io/a VM with a process manager/k8s — any of these work; none is currently chosen).
- Real secrets management for `JWT_SECRET`/`DATABASE_URL`/`REDIS_URL` (a secrets manager, not env vars baked into an image or committed anywhere).
- A managed Postgres instance with PostGIS enabled and automated backups, and a managed Redis instance (or accept the in-memory-leaderboard tradeoff deliberately, not by default).
- A health-check-gated rollout (the existing `/api/v1/health` endpoint already reports DB connectivity — wire it into whatever deployment target's readiness/liveness probes).
- An explicit rollback procedure once a real deployment target is chosen (most platforms have a "redeploy previous revision" primitive — use it rather than reinventing one).
