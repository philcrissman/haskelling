# Infrastructure and Deployment Tasks

*Input: ADR-001*

---

## Overview

| Area | Choice |
|------|--------|
| Backend hosting | Fly.io (or Railway) |
| Frontend hosting | Vercel or Netlify |
| Database | Supabase or Neon (free tier dev; paid tier prod) |
| Sandbox | Managed Judge0 cloud |
| Auth | Clerk |
| CI | GitHub Actions |
| Secrets | Fly.io secrets (backend); Vercel/Netlify env vars (frontend) |

---

## Area 1: Local Development Environment

### INFRA-01: docker-compose for local PostgreSQL

**Description:**
Provide a `docker-compose.yml` that starts a PostgreSQL instance configured for local development. The backend and frontend run outside Docker (via `cabal run` and `npm run dev` respectively) to avoid slow container rebuilds during development.

**Acceptance criteria:**
- [ ] `docker compose up -d` starts a PostgreSQL container on port 5432
- [ ] The database name, user, and password match the defaults in `.env.example`
- [ ] `docker compose down -v` tears down the container and volume cleanly
- [ ] The container uses a named volume so the database persists across restarts
- [ ] A `docker-compose.yml` at the project root starts only the database (not the app or frontend)

---

### INFRA-02: Environment variable setup

**Description:**
Document and provide templates for all environment variables required by the backend and frontend. No secrets are committed to the repository.

**Acceptance criteria:**
- [ ] A `backend/.env.example` file lists every required backend variable with a comment explaining each
- [ ] A `frontend/.env.example` file lists every required frontend variable
- [ ] Both `.env.local` files are in `.gitignore`
- [ ] Required backend variables: `DATABASE_URL`, `PORT`, `JUDGE0_API_KEY`, `JUDGE0_API_URL`, `JUDGE0_MOCK`, `CLERK_JWKS_URL`, `RATE_LIMIT_PER_IP`, `RATE_LIMIT_PER_USER`
- [ ] Required frontend variables: `VITE_CLERK_PUBLISHABLE_KEY`, `VITE_API_BASE_URL`
- [ ] The server fails fast with a clear message naming the missing variable if any required variable is absent

---

### INFRA-03: Judge0 mock mode

**Description:**
Add a `JUDGE0_MOCK=true` mode to the backend that bypasses Judge0 entirely and returns a hardcoded submission result. This lets development and CI proceed without a live Judge0 API key and without incurring execution costs.

**Acceptance criteria:**
- [ ] When `JUDGE0_MOCK=true`, `POST /api/submissions` returns a hardcoded `pass` result with `passedCount: 1` and `failedCount: 0`
- [ ] The mock result matches the shape of a real submission response exactly
- [ ] A startup log message clearly states that Judge0 mock mode is active
- [ ] When `JUDGE0_MOCK` is absent or `false`, the real Judge0 client is used
- [ ] The mock bypasses Judge0 entirely — no HTTP calls are made to Judge0 in mock mode

---

### INFRA-04: Local development README

**Description:**
Write a `README.md` (or `DEVELOPMENT.md`) that explains how to start the full local stack from a fresh clone with no prior knowledge of the project.

**Acceptance criteria:**
- [ ] Prerequisites are listed (GHC version, cabal version, Node version, Docker)
- [ ] Step-by-step instructions for first-time setup are correct and complete
- [ ] A "daily workflow" section shows the minimal commands to start everything: database, backend, frontend
- [ ] The README explains how to run backend tests and frontend typechecking
- [ ] The README notes that `JUDGE0_MOCK=true` is recommended for local development

---

## Area 2: CI Pipeline

### INFRA-05: GitHub Actions — Haskell build and test

**Description:**
A GitHub Actions workflow that builds the Haskell backend and runs all tests on every push and pull request. Uses cabal's dependency caching to keep run time reasonable.

**Acceptance criteria:**
- [ ] Workflow runs on every push to any branch and on every pull request targeting `main`
- [ ] Workflow runs `cabal build` and fails if the build fails
- [ ] Workflow runs `cabal test` and fails if any test fails
- [ ] The cabal store and dist-newstyle directories are cached between runs
- [ ] Cache key includes the GHC version and the `cabal.project.freeze` hash
- [ ] The GHC version used in CI matches the version in the Dockerfile (no drift)
- [ ] Workflow completes within 10 minutes on a cache hit

---

### INFRA-06: GitHub Actions — Frontend typecheck and build

**Description:**
A GitHub Actions workflow that typechecks and builds the frontend on every push and pull request.

**Acceptance criteria:**
- [ ] Workflow runs `npm ci` followed by `npm run typecheck`
- [ ] Workflow runs `npm run build` and fails if the build fails
- [ ] `node_modules` is cached using the `package-lock.json` hash
- [ ] Workflow fails if there are TypeScript type errors
- [ ] Workflow passes if no type errors exist and the build succeeds

---

### INFRA-07: GitHub Actions — Deploy to staging on merge

**Description:**
After a successful build and test run on the `main` branch, automatically deploy the backend to the staging environment on Fly.io. The frontend is deployed automatically by Vercel/Netlify on every push to `main` — no explicit step needed.

**Acceptance criteria:**
- [ ] Deployment to staging only runs on pushes to `main`, never on PRs
- [ ] Deployment only runs if the build and test jobs pass
- [ ] The Fly.io deploy token is stored as a GitHub Actions secret (`FLY_API_TOKEN`), never hardcoded
- [ ] The workflow uses `fly deploy --app haskell-koans-staging`
- [ ] A failed deployment fails the workflow and does not silently succeed
- [ ] The staging URL is visible in the workflow summary after a successful deploy

---

## Area 3: Staging Deployment

### INFRA-08: Dockerfile for Haskell backend

**Description:**
A multi-stage Dockerfile that builds the Haskell backend and produces a minimal production image. Dependency compilation is separated from application compilation to enable Docker layer caching.

**Acceptance criteria:**
- [ ] Stage 1 (builder): installs GHC dependencies, then copies and compiles application source
- [ ] The `cabal build --only-dependencies` step runs before copying source, so the dependency layer is cached when only source changes
- [ ] Stage 2 (runtime): copies the compiled binary into a minimal Debian Slim image with only runtime libraries (`libpq5`, `ca-certificates`)
- [ ] The final image does not contain GHC, cabal, or build tools
- [ ] `docker build` produces a working image that passes a health check (`GET /health` returns 200)
- [ ] The GHC version in the Dockerfile is pinned (not `latest`)
- [ ] The image runs as a non-root user

---

### INFRA-09: Fly.io staging app setup

**Description:**
Provision and configure the staging Fly.io application. This is a one-time setup task.

**Acceptance criteria:**
- [ ] A Fly.io app named `haskell-koans-staging` exists in the target organisation
- [ ] A `fly.toml` at the project root configures the staging app: port 8080, health check at `GET /health`, minimum memory 512MB
- [ ] The health check is configured with appropriate thresholds (e.g. 2 failures before marking unhealthy)
- [ ] All required secrets are set via `fly secrets set` — none are in `fly.toml` or committed to the repo
- [ ] The staging app URL is accessible and returns a 200 from `GET /health`
- [ ] Auto-scaling is disabled (single instance is sufficient for staging)

---

### INFRA-10: Staging database setup

**Description:**
Provision a PostgreSQL database for the staging environment. Supabase or Neon free tier is sufficient.

**Acceptance criteria:**
- [ ] A staging database exists and is reachable from the Fly.io staging app
- [ ] The `DATABASE_URL` secret is set on the Fly.io staging app pointing to the staging database
- [ ] Database migrations run automatically on startup (`migrateAll`)
- [ ] The staging database is separate from the production database (different credentials, different instance)
- [ ] The database connection is confirmed by checking that `GET /api/exercises` returns data after first deploy

---

## Area 4: Production Deployment

### INFRA-11: Fly.io production app setup

**Description:**
Provision the production Fly.io application. Production deploys are manual (not automatic on every merge) to allow for staging validation first.

**Acceptance criteria:**
- [ ] A Fly.io app named `haskell-koans` (or equivalent) exists
- [ ] A separate `fly.production.toml` (or a `fly.toml` environment switch) targets the production app
- [ ] All secrets are set on the production app independently of staging
- [ ] Production deploys require an explicit `fly deploy --app haskell-koans` command — no automatic production deploys from CI
- [ ] The production app URL resolves and returns 200 from `GET /health`

---

### INFRA-12: Frontend production deployment

**Description:**
Connect the frontend repository to Vercel or Netlify for automated deployments. The frontend deploys on every push to `main`.

**Acceptance criteria:**
- [ ] The frontend project is connected to Vercel or Netlify via the dashboard
- [ ] `VITE_CLERK_PUBLISHABLE_KEY` and `VITE_API_BASE_URL` are set as environment variables in the Vercel/Netlify project (production values)
- [ ] Preview deployments are created for pull requests, using staging API and staging Clerk keys
- [ ] The production build deploys automatically on merge to `main`
- [ ] The production frontend URL is confirmed to load and reach the production API

---

### INFRA-13: Secrets management documentation

**Description:**
Document how to rotate secrets without downtime, and where each secret is stored.

**Acceptance criteria:**
- [ ] A `SECRETS.md` (not committed — a template only) or a section in `DEVELOPMENT.md` lists every secret, where it is used, and how to rotate it
- [ ] The procedure for rotating the Judge0 API key is documented: update in Fly.io with `fly secrets set`, app restarts automatically
- [ ] The procedure for rotating the Clerk keys is documented
- [ ] No secrets appear in `fly.toml`, GitHub Actions workflow files, or any committed file
- [ ] The `.gitignore` includes `.env`, `.env.local`, and `*.secret`

---

## Area 5: Monitoring

### INFRA-14: Uptime monitoring

**Description:**
Set up basic uptime monitoring for the production API health endpoint. Free-tier UptimeRobot (or equivalent) is sufficient.

**Acceptance criteria:**
- [ ] `GET /health` on the production API is checked every 5 minutes
- [ ] An alert fires (email to the maintainer) if the endpoint returns non-200 or times out for 2 consecutive checks
- [ ] The monitoring URL and alert contact are documented somewhere accessible (e.g. a line in the README)

---

### INFRA-15: Judge0 usage tracking

**Description:**
Track Judge0 submission counts to catch unexpected cost spikes early. The backend logs submission attempts and outcomes; aggregate counts are checked against the Judge0 plan limit.

**Acceptance criteria:**
- [ ] Every call to Judge0 (successful or failed) produces a structured log line including: exercise ID, outcome status, latency in ms
- [ ] A simple monthly review process is documented: how to count Judge0 calls from logs and compare to the plan limit
- [ ] If Fly.io log drains are configured, Judge0 call logs are included in the drain
- [ ] A note in the README warns that Judge0 mock mode must be on in CI to avoid consuming execution quota in automated tests

---

### INFRA-16: Application error rate alerting

**Description:**
Surface elevated backend error rates (5xx responses) so issues are caught before users report them. Fly.io's built-in metrics are sufficient at this scale.

**Acceptance criteria:**
- [ ] The Fly.io dashboard shows request count and error rate graphs for the production app
- [ ] A Fly.io alert is configured to notify the maintainer if the 5xx error rate exceeds 5% over a 10-minute window
- [ ] The `GET /health` endpoint returns 200 only when the database connection is healthy — a DB outage causes health check failure, triggering the Fly.io restart policy
- [ ] Request logging from BE-18 (structured log lines with status code) feeds into Fly.io's log viewer for manual inspection

---

## Execution Order

Tasks should be completed in this order. Local environment comes first so all subsequent work can be done against a running stack.

1. INFRA-01 → INFRA-02 → INFRA-03 → INFRA-04 *(local dev environment — do this before any application code)*
2. INFRA-08 *(Dockerfile — needed by CI and staging; write alongside backend Phase 1)*
3. INFRA-05 → INFRA-06 *(CI checks — add before first PR)*
4. INFRA-09 → INFRA-10 *(staging environment — set up once backend Phase 1 is deployable)*
5. INFRA-07 *(auto-deploy to staging — wire up once staging is proven)*
6. INFRA-11 → INFRA-12 → INFRA-13 *(production — set up after staging is stable)*
7. INFRA-14 → INFRA-15 → INFRA-16 *(monitoring — set up at or just before production launch)*

---

## Notes

**Haskell Docker build times:** The first `docker build` will take 20–40 minutes as GHC compiles all dependencies from source. Subsequent builds with unchanged dependencies take 2–5 minutes. Fly.io's remote build cache helps but is not perfectly reliable — budget time for occasional slow builds.

**Database migrations on deploy:** The backend runs `migrateAll` on startup. This means a deploy that includes a schema change will apply the migration before serving traffic. For the current scale this is acceptable; for future backwards-incompatible migrations, a more deliberate migration strategy will be needed.

**Staging Clerk keys:** Clerk provides separate publishable/secret keys per environment. Use a Clerk development instance for local and staging, and the production instance only for the production app.
