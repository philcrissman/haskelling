#!/usr/bin/env bash
# Creates all GitHub milestones, labels, and issues for haskelling.
#
# Prerequisites:
#   1. Install gh CLI: https://cli.github.com/
#   2. Authenticate: gh auth login
#   3. Run: bash create-github-issues.sh
#
# Safe to re-run: labels use --force, milestones skip if already present,
# but issues will be created again if re-run (GitHub allows duplicate titles).

set -euo pipefail

REPO="philcrissman/haskelling"

# ---------------------------------------------------------------------------
# Labels
# ---------------------------------------------------------------------------
echo "→ Creating labels..."

label() {
  gh label create "$1" --color "$2" --description "$3" --repo "$REPO" --force
}

label "backend"  "0075ca" "Backend Haskell stories"
label "frontend" "e4e669" "Frontend TypeScript stories"
label "infra"    "d93f0b" "Infrastructure and deployment tasks"

# ---------------------------------------------------------------------------
# Milestones
# ---------------------------------------------------------------------------
echo "→ Creating milestones..."

milestone() {
  local title="$1" desc="$2"
  local exists
  exists=$(gh api "repos/$REPO/milestones" \
    --jq ".[] | select(.title == \"$title\") | .title" 2>/dev/null || true)
  if [[ -z "$exists" ]]; then
    gh api "repos/$REPO/milestones" --method POST \
      -f title="$title" -f description="$desc" > /dev/null
    echo "  created: $title"
  else
    echo "  exists:  $title"
  fi
}

milestone "Phase 1: Local Dev Environment"               "Docker, env vars, Judge0 mock, README"
milestone "Phase 2: Eval Service Spike"                  "Prove Judge0+Haskell integration before building around it"
milestone "Phase 3: Data Model / Migrations"             "Database setup and exercise seeding"
milestone "Phase 4: Backend Walking Skeleton"            "Servant scaffold, Judge0 client, rate limiting, CI"
milestone "Phase 5: Frontend Walking Skeleton + Staging" "Editor, submit flow, result display, staging deploy"
milestone "Phase 6: Curriculum Review"                   "Review and validate all 30 exercises"
milestone "Phase 7: Backend Data Layer + Curriculum API" "DB-backed endpoints, progress tracking, logging"
milestone "Phase 8: Frontend Curriculum Navigation"      "Routing, sidebar, progress indicators, hints, history"
milestone "Phase 9: Auth (Both Sides)"                   "Clerk JWT, GitHub OAuth, protected routes"
milestone "Phase 10: Polish"                             "Loading states, errors, keyboard shortcuts, mobile, a11y"
milestone "Phase 11: CI + Production Deployment"         "Auto-deploy, production setup, monitoring"

# ---------------------------------------------------------------------------
# Issues
# ---------------------------------------------------------------------------
echo "→ Creating issues..."

issue() {
  local title="$1" labels="$2" ms="$3" body="$4"
  gh issue create \
    --repo "$REPO" \
    --title "$title" \
    --label "$labels" \
    --milestone "$ms" \
    --body "$body"
  sleep 0.4
}

# ── Phase 1: Local Dev Environment ─────────────────────────────────────────

issue "INFRA-01: Docker Compose for local PostgreSQL" \
  "infra" \
  "Phase 1: Local Dev Environment" \
  "## Description
Provide a \`docker-compose.yml\` that starts a PostgreSQL instance for local development. The backend and frontend run outside Docker (via \`cabal run\` and \`npm run dev\`) to avoid slow container rebuilds.

## Acceptance Criteria
- [ ] \`docker compose up -d\` starts PostgreSQL on port 5432
- [ ] Database name, user, and password match defaults in \`.env.example\`
- [ ] \`docker compose down -v\` tears down container and volume cleanly
- [ ] A named volume persists the database across restarts
- [ ] No application services in docker-compose (database only)

_See \`INFRA-TASKS.md\` and \`STORY-ORDER.md\`._"

issue "INFRA-02: Environment variable setup" \
  "infra" \
  "Phase 1: Local Dev Environment" \
  "## Description
Document and provide templates for all environment variables. No secrets committed to the repository.

## Acceptance Criteria
- [ ] \`backend/.env.example\` lists every required backend variable with a comment
- [ ] \`frontend/.env.example\` lists every required frontend variable
- [ ] Both \`.env.local\` files are in \`.gitignore\`
- [ ] Required backend vars: \`DATABASE_URL\`, \`PORT\`, \`JUDGE0_API_KEY\`, \`JUDGE0_API_URL\`, \`JUDGE0_MOCK\`, \`CLERK_JWKS_URL\`, \`RATE_LIMIT_PER_IP\`, \`RATE_LIMIT_PER_USER\`
- [ ] Required frontend vars: \`VITE_CLERK_PUBLISHABLE_KEY\`, \`VITE_API_BASE_URL\`
- [ ] Server fails fast with a clear message naming any missing required variable

_See \`INFRA-TASKS.md\`._"

issue "INFRA-03: Judge0 mock mode" \
  "infra,backend" \
  "Phase 1: Local Dev Environment" \
  "## Description
Add \`JUDGE0_MOCK=true\` support to the backend so development and CI can proceed without a live Judge0 API key.

## Acceptance Criteria
- [ ] When \`JUDGE0_MOCK=true\`, \`POST /api/submissions\` returns a hardcoded \`pass\` result with \`passedCount: 1\`, \`failedCount: 0\`
- [ ] Mock response shape is identical to a real submission response
- [ ] A startup log message clearly states mock mode is active
- [ ] No HTTP calls are made to Judge0 in mock mode
- [ ] When \`JUDGE0_MOCK\` is absent or \`false\`, the real Judge0 client is used

_See \`INFRA-TASKS.md\`._"

issue "INFRA-04: Development README" \
  "infra" \
  "Phase 1: Local Dev Environment" \
  "## Description
Write a README (or DEVELOPMENT.md) that explains how to start the full local stack from a fresh clone.

## Acceptance Criteria
- [ ] Prerequisites listed (GHC version, cabal version, Node version, Docker)
- [ ] Step-by-step first-time setup instructions are correct and complete
- [ ] Daily workflow section shows minimal commands to start database, backend, frontend
- [ ] Instructions for running backend tests and frontend typecheck are included
- [ ] Notes that \`JUDGE0_MOCK=true\` is recommended for local development

_See \`INFRA-TASKS.md\`._"

# ── Phase 2: Eval Service Spike ─────────────────────────────────────────────

issue "SPIKE: Verify Judge0 + Haskell integration" \
  "backend,infra" \
  "Phase 2: Eval Service Spike" \
  "## Description
Before building the full backend around Judge0, prove the integration works. This is a research spike — write the minimum code needed to confirm key assumptions. Record findings in \`DECISIONS.md\`.

## Tasks
- [ ] Confirm the Haskell language ID in the Judge0 cloud API (documented as 12 — verify it hasn't changed)
- [ ] Submit a trivial Haskell program and confirm a result is returned
- [ ] Confirm whether the Judge0 **managed cloud tier** supports \`additional_files\` (base64 zip for multi-file submissions). This is the planned injection approach — see \`EVAL-SERVICE-DESIGN.md\`
- [ ] Measure actual cold compile + run latency for a trivial Haskell program
- [ ] If \`additional_files\` is NOT supported, decide on the fallback approach and update \`EVAL-SERVICE-DESIGN.md\` and \`DECISIONS.md\`
- [ ] Record actual observed latency in \`DECISIONS.md\`; update \`ADR-001.md\` consequences if materially different from the 5–30s estimate

## ⚠️ Note
The planning doc warns: *'The eval service phase will almost certainly surface surprises about GHC compilation time and memory use. Run a dedicated review after this phase before proceeding.'*

_See \`EVAL-SERVICE-DESIGN.md\`, \`DECISIONS.md\`, \`STORY-ORDER.md\`._"

# ── Phase 3: Data Model / Migrations ───────────────────────────────────────

issue "BE-06: Database connection and migrations" \
  "backend" \
  "Phase 3: Data Model / Migrations" \
  "## Description
Configure Persistent and run \`migrateAll\` on startup. The database URL is read from an environment variable.

## Acceptance Criteria
- [ ] \`DATABASE_URL\` is read on startup; server fails fast with a clear message if missing
- [ ] \`migrateAll\` runs on startup and schema matches \`DATA-MODEL.md\`
- [ ] Migrations are idempotent — running twice does not error
- [ ] \`DB_POOL_SIZE\` is configurable (default 10)
- [ ] Failed DB connection on startup causes the server to exit with a non-zero code and clear log message

_See \`BACKEND-STORIES.md\`, \`DATA-MODEL.md\`._"

issue "BE-07: Exercise seeding from CURRICULUM.json" \
  "backend" \
  "Phase 3: Data Model / Migrations" \
  "## Description
On startup (after migrations), read \`CURRICULUM.json\` and upsert all chapters and exercises into the database.

## Acceptance Criteria
- [ ] All 30 exercises and 6 chapters are present in the database after startup
- [ ] Upsert uses \`UniqueExerciseSlug\` and \`UniqueChapterSlug\` — no duplicates on restart
- [ ] \`hiddenTests\` and \`canonicalSolution\` are stored in the database
- [ ] \`hints\` are stored and retrieved correctly as a \`[Text]\` JSONB field
- [ ] Maps \`\"order\"\` from JSON to \`orderInChapter\` in the Persistent entity
- [ ] Maps \`\"chapter\"\` slug string to the correct \`ChapterId\` foreign key
- [ ] Missing or malformed \`CURRICULUM.json\` causes server to exit with a clear error

_See \`BACKEND-STORIES.md\`, \`DATA-MODEL.md\`, \`CURRICULUM.json\`._"

# ── Phase 4: Backend Walking Skeleton ──────────────────────────────────────

issue "BE-01: Scaffold Servant project" \
  "backend" \
  "Phase 4: Backend Walking Skeleton" \
  "## Description
Set up the Cabal project for the backend. Servant, Wai, Warp. Server starts and the health endpoint responds.

## Acceptance Criteria
- [ ] \`cabal build\` succeeds with no warnings
- [ ] \`cabal run\` starts a server on a configurable port (default 8080, from \`PORT\` env var)
- [ ] \`GET /health\` returns \`{\"status\":\"ok\"}\` with status 200
- [ ] Servant API type is defined in its own module

_See \`BACKEND-STORIES.md\`._"

issue "BE-02: Hardcoded exercise endpoint" \
  "backend" \
  "Phase 4: Backend Walking Skeleton" \
  "## Description
Implement \`GET /api/exercises/:id\` with a single hardcoded exercise (hello-world). No database yet.

## Acceptance Criteria
- [ ] \`GET /api/exercises/hello-world\` returns the hello-world exercise matching the API contract shape
- [ ] \`GET /api/exercises/unknown\` returns 404 with the standard error envelope
- [ ] \`GET /api/exercises\` returns a chapters list containing the one hardcoded exercise
- [ ] Response never includes \`hiddenTests\` or \`canonicalSolution\`

_See \`BACKEND-STORIES.md\`, \`EVAL-SERVICE-DESIGN.md\` (API contract)._"

issue "BE-03: Judge0 HTTP client" \
  "backend" \
  "Phase 4: Backend Walking Skeleton" \
  "## Description
Implement the module that submits Haskell code to Judge0 and returns a typed result. Uses the injection approach confirmed in the Phase 2 spike.

## Acceptance Criteria
- [ ] \`JUDGE0_API_KEY\` is read from environment; never hardcoded
- [ ] Submission uses \`additional_files\` (or fallback approach per spike findings) — see \`EVAL-SERVICE-DESIGN.md\`
- [ ] Filename in the zip matches the module name (slug → PascalCase + \`.hs\`)
- [ ] All Judge0 status codes map to the internal \`SubmissionStatus\` type
- [ ] HSpec stdout is parsed to extract \`passedCount\` and \`failedCount\`
- [ ] Judge0 unavailability returns a structured error, not an unhandled exception
- [ ] Timeout maps to \`StatusTimeout\`; internal error maps to \`StatusError\`
- [ ] Judge0 network isolation verified (submitted code cannot make network calls)

_See \`BACKEND-STORIES.md\`, \`EVAL-SERVICE-DESIGN.md\`._"

issue "BE-04: Submission endpoint (walking skeleton)" \
  "backend" \
  "Phase 4: Backend Walking Skeleton" \
  "## Description
Implement \`POST /api/submissions\` using the hardcoded exercise and the Judge0 client. No database persistence yet.

## Acceptance Criteria
- [ ] Correct code for hello-world returns \`status: \"pass\"\` with correct counts
- [ ] Syntax error in submitted code returns \`status: \"compile_error\"\` with sanitized output
- [ ] Unknown \`exerciseId\` returns 404
- [ ] Code exceeding 50KB returns 413 before calling Judge0
- [ ] Response shape matches the API contract exactly
- [ ] Judge0 is not called if request fails validation

_See \`BACKEND-STORIES.md\`._"

issue "BE-05: Per-IP rate limiting on submissions" \
  "backend" \
  "Phase 4: Backend Walking Skeleton" \
  "## Description
Add rate limiting middleware to \`POST /api/submissions\` by remote IP address.

## Acceptance Criteria
- [ ] 21st submission from the same IP within 60 seconds returns 429
- [ ] 429 response includes \`Retry-After\` header (seconds until window resets)
- [ ] 429 response body uses standard error envelope with code \`\"rate_limit_exceeded\"\`
- [ ] Rate limit state resets after window expires
- [ ] Limit is configurable via \`RATE_LIMIT_PER_IP\` env var (default 20)

_See \`BACKEND-STORIES.md\`._"

issue "INFRA-08: Dockerfile for Haskell backend" \
  "infra" \
  "Phase 4: Backend Walking Skeleton" \
  "## Description
Multi-stage Dockerfile that builds the Haskell backend and produces a minimal production image.

## Acceptance Criteria
- [ ] Stage 1 (builder): \`cabal build --only-dependencies\` before copying source (enables layer caching)
- [ ] Stage 2 (runtime): minimal Debian Slim with only \`libpq5\` and \`ca-certificates\`
- [ ] Final image does not contain GHC, cabal, or build tools
- [ ] \`docker build\` produces an image that passes a health check (\`GET /health\` returns 200)
- [ ] GHC version is pinned (not \`latest\`)
- [ ] Image runs as a non-root user

_See \`INFRA-TASKS.md\`._"

issue "INFRA-05: GitHub Actions — Haskell build and test" \
  "infra" \
  "Phase 4: Backend Walking Skeleton" \
  "## Description
CI workflow that builds the Haskell backend and runs all tests on every push and PR.

## Acceptance Criteria
- [ ] Runs on every push to any branch and on every PR targeting \`main\`
- [ ] Runs \`cabal build\` — fails if build fails
- [ ] Runs \`cabal test\` — fails if any test fails
- [ ] Cabal store and \`dist-newstyle\` are cached between runs
- [ ] Cache key includes GHC version and \`cabal.project.freeze\` hash
- [ ] GHC version in CI matches version in Dockerfile
- [ ] Completes within 10 minutes on a cache hit

_See \`INFRA-TASKS.md\`._"

issue "INFRA-06: GitHub Actions — Frontend typecheck and build" \
  "infra" \
  "Phase 4: Backend Walking Skeleton" \
  "## Description
CI workflow that typechecks and builds the frontend on every push and PR.

## Acceptance Criteria
- [ ] Runs \`npm ci\` then \`npm run typecheck\`
- [ ] Runs \`npm run build\` — fails if build fails
- [ ] \`node_modules\` cached using \`package-lock.json\` hash
- [ ] Fails on TypeScript type errors
- [ ] Passes if no type errors and build succeeds

_See \`INFRA-TASKS.md\`._"

# ── Phase 5: Frontend Walking Skeleton + Staging ───────────────────────────

issue "FE-01: Scaffold Vite + React + TypeScript project" \
  "frontend" \
  "Phase 5: Frontend Walking Skeleton + Staging" \
  "## Description
Initialise the frontend with Vite + React + TypeScript. Configure a dev proxy to forward \`/api\` to the backend.

## ⚠️ Decide frontend framework (React vs Svelte) before starting this issue.

## Acceptance Criteria
- [ ] \`npm run dev\` starts without errors
- [ ] \`npm run build\` produces a production bundle without errors
- [ ] \`npm run typecheck\` (\`tsc --noEmit\`) passes with no type errors
- [ ] \`/api/*\` requests in dev server are proxied to the backend
- [ ] \`src/types.ts\` contains shared TypeScript types matching the API contract
- [ ] \`src/api.ts\` contains a typed fetch wrapper — no raw \`fetch\` calls in components

_See \`FRONTEND-STORIES.md\`._"

issue "FE-02: CodeMirror 6 editor component" \
  "frontend" \
  "Phase 5: Frontend Walking Skeleton + Staging" \
  "## Description
Build a reusable \`<CodeEditor>\` component wrapping CodeMirror 6 with Haskell syntax highlighting. Controlled input: accepts \`value\` prop, fires \`onChange\` callback.

## Acceptance Criteria
- [ ] Editor displays Haskell syntax highlighting
- [ ] Controlled: \`value\` sets content; \`onChange\` fires on every edit
- [ ] Tab key inserts spaces; \`tabSize\` prop configurable (default 2)
- [ ] Accessible via keyboard; readable as a text input region by screen readers
- [ ] Accepts a \`readOnly\` prop
- [ ] Does not reset to initial value on parent re-renders

_See \`FRONTEND-STORIES.md\`._"

issue "FE-03: Hardcoded exercise page" \
  "frontend" \
  "Phase 5: Frontend Walking Skeleton + Staging" \
  "## Description
Build an \`ExercisePage\` component displaying a hardcoded hello-world exercise. No API calls yet.

## Acceptance Criteria
- [ ] Exercise title and learning objective displayed above the editor
- [ ] Editor pre-populated with stub code
- [ ] User can edit code in the editor
- [ ] Submit button is present
- [ ] Layout is legible at ≥768px viewport width

_See \`FRONTEND-STORIES.md\`._"

issue "FE-04: Submit code and display result" \
  "frontend" \
  "Phase 5: Frontend Walking Skeleton + Staging" \
  "## Description
Wire the Submit button to \`POST /api/submissions\`. Display the result with a loading state during the request (Judge0 may take 5–30 seconds).

## Acceptance Criteria
- [ ] Submit sends \`{ exerciseId, code }\` to \`POST /api/submissions\`
- [ ] While awaiting: Submit button disabled and shows a loading indicator
- [ ] \`pass\`: visible success state with passed/failed counts
- [ ] \`fail\`: visible failure state with counts and output
- [ ] \`compile_error\`: compiler output in a readable monospace block
- [ ] \`timeout\` / \`runtime_error\`: clear human-readable message
- [ ] Submitting while a request is in flight is prevented
- [ ] Output panel is scrollable for long output

_See \`FRONTEND-STORIES.md\`._"

issue "INFRA-09: Fly.io staging app setup" \
  "infra" \
  "Phase 5: Frontend Walking Skeleton + Staging" \
  "## Description
Provision and configure the staging Fly.io application.

## Acceptance Criteria
- [ ] Fly.io app \`haskell-koans-staging\` exists
- [ ] \`fly.toml\` configures: port 8080, health check at \`GET /health\`, min memory 512MB
- [ ] Health check has appropriate failure thresholds
- [ ] All secrets set via \`fly secrets set\` — none in \`fly.toml\` or committed files
- [ ] Staging URL returns 200 from \`GET /health\`
- [ ] Auto-scaling disabled (single instance)

_See \`INFRA-TASKS.md\`._"

issue "INFRA-10: Staging database setup" \
  "infra" \
  "Phase 5: Frontend Walking Skeleton + Staging" \
  "## Description
Provision a PostgreSQL database for the staging environment (Supabase or Neon free tier).

## Acceptance Criteria
- [ ] Staging database exists and is reachable from the Fly.io staging app
- [ ] \`DATABASE_URL\` secret is set on the staging app
- [ ] Migrations run automatically on startup
- [ ] Staging database is separate from production (different credentials and instance)
- [ ] \`GET /api/exercises\` returns seeded data after first deploy

_See \`INFRA-TASKS.md\`._"

issue "INFRA-07: GitHub Actions — auto-deploy to staging on merge" \
  "infra" \
  "Phase 5: Frontend Walking Skeleton + Staging" \
  "## Description
After passing CI on \`main\`, automatically deploy the backend to staging on Fly.io.

## Acceptance Criteria
- [ ] Deployment to staging only runs on pushes to \`main\`, never on PRs
- [ ] Deployment only runs if build and test jobs pass
- [ ] Fly.io deploy token stored as GitHub Actions secret (\`FLY_API_TOKEN\`), never hardcoded
- [ ] Uses \`fly deploy --app haskell-koans-staging\`
- [ ] Failed deployment fails the workflow
- [ ] Staging URL is visible in workflow summary after successful deploy

_See \`INFRA-TASKS.md\`._"

# ── Phase 6: Curriculum Review ─────────────────────────────────────────────

issue "Review and validate all 30 exercises in CURRICULUM.json" \
  "backend" \
  "Phase 6: Curriculum Review" \
  "## Description
Read through all 30 exercises. Verify stub code compiles, hints are useful, test cases are correct, and all hidden test suites are syntactically valid Haskell.

## Checklist
- [ ] All stub codes compile (syntax is valid Haskell with \`undefined\` as placeholder)
- [ ] All canonical solutions satisfy their own hidden test suites
- [ ] All hidden test suites are valid HSpec modules
- [ ] Hints are ordered from least to most revealing
- [ ] Exercise 28 (\`implementing-show\`) Unicode suit symbols (\`\\9827\` etc.) display correctly in HSpec output
- [ ] All exercise module names match slug → PascalCase convention (\`hello-world\` → \`HelloWorld\`)
- [ ] Fix any broken or unclear exercises found

_See \`CURRICULUM.json\`, \`STORY-ORDER.md\`._"

# ── Phase 7: Backend Data Layer + Curriculum API ───────────────────────────

issue "BE-08: Exercise endpoints from database" \
  "backend" \
  "Phase 7: Backend Data Layer + Curriculum API" \
  "## Description
Replace hardcoded exercise responses with database queries using Persistent and Esqueleto.

## Acceptance Criteria
- [ ] \`GET /api/exercises\` queries DB and returns all exercises grouped by chapter in correct order
- [ ] \`GET /api/exercises/:id\` queries by slug; returns 404 if not found
- [ ] \`hiddenTests\` and \`canonicalSolution\` are present in DB row but absent from all API responses
- [ ] Response shape is identical to the hardcoded output from BE-02

_See \`BACKEND-STORIES.md\`._"

issue "BE-09: Submission persistence" \
  "backend" \
  "Phase 7: Backend Data Layer + Curriculum API" \
  "## Description
After receiving a result from Judge0, persist the submission to the \`submission\` table.

## Acceptance Criteria
- [ ] Every completed submission (including failures and errors) creates a \`submission\` row
- [ ] Row records: \`userId\` (null until Phase 9), \`exerciseId\`, \`code\`, \`status\`, \`output\`, \`passedCount\`, \`failedCount\`, \`createdAt\`
- [ ] The \`id\` of the persisted row is returned in the API response
- [ ] Judge0 failures (502, 504) do not create a submission row

_See \`BACKEND-STORIES.md\`._"

issue "BE-10: Submission history endpoint" \
  "backend" \
  "Phase 7: Backend Data Layer + Curriculum API" \
  "## Description
Implement \`GET /api/submissions?exercise_id=:id\`. Returns past submissions for the given exercise.

## Note
Auth is not yet active in this phase. The endpoint returns all submissions for the exercise (not user-scoped). BE-13 (Phase 9) locks it to the authenticated user.

## Acceptance Criteria
- [ ] Returns submissions for the given exercise slug, newest first
- [ ] Returns 400 if \`exercise_id\` is missing
- [ ] Returns 404 if the exercise slug is unknown
- [ ] \`code\` field is not included in history responses
- [ ] Returns empty array (not 404) if exercise exists but has no submissions

_See \`BACKEND-STORIES.md\`._"

issue "BE-15: UserProgress upsert on submission" \
  "backend" \
  "Phase 7: Backend Data Layer + Curriculum API" \
  "## Description
After persisting a submission, upsert the \`UserProgress\` row for the (user, exercise) pair within the same database transaction.

## Acceptance Criteria
- [ ] First submission for a (user, exercise) pair creates a \`UserProgress\` row (\`Attempted\` or \`Passed\`)
- [ ] A passing submission sets status to \`Passed\` and records \`firstPassedAt\` (first time only)
- [ ] A failing submission after a pass leaves status as \`Passed\` (status is monotonically advancing)
- [ ] \`lastSubmittedAt\` updated on every submission
- [ ] Submission insert and progress upsert succeed or fail together (same transaction)

_See \`BACKEND-STORIES.md\`, \`DATA-MODEL.md\`._"

issue "BE-16: Progress endpoint" \
  "backend" \
  "Phase 7: Backend Data Layer + Curriculum API" \
  "## Description
Implement \`GET /api/progress\`. Returns a progress entry for every exercise, including those with no submissions.

## Acceptance Criteria
- [ ] All exercises present in response, not only those with submissions
- [ ] Exercises with no \`UserProgress\` row appear with \`status: \"not_started\"\` and null timestamps
- [ ] Response ordered to match exercise list order (chapter order, then order within chapter)
- [ ] \`firstPassedAt\` and \`lastSubmittedAt\` are ISO 8601 strings or null

_See \`BACKEND-STORIES.md\`._"

issue "BE-17: Fully ordered chapter-grouped exercise list" \
  "backend" \
  "Phase 7: Backend Data Layer + Curriculum API" \
  "## Description
Harden \`GET /api/exercises\` ordering: chapters by \`orderNum\`, exercises within chapters by \`orderInChapter\`. Ordering done in the Esqueleto query, not in memory.

## Acceptance Criteria
- [ ] Chapters appear in ascending \`orderNum\` order
- [ ] Exercises within each chapter appear in ascending \`orderInChapter\` order
- [ ] Response is stable across repeated requests (no non-deterministic ordering)
- [ ] An Esqueleto query (not in-memory sort) handles the ordering

_See \`BACKEND-STORIES.md\`._"

issue "BE-18: Request logging middleware" \
  "backend" \
  "Phase 7: Backend Data Layer + Curriculum API" \
  "## Description
Add structured request logging. Log method, path, status code, and latency. Do not log request bodies or auth tokens.

## Acceptance Criteria
- [ ] Every request produces one log line on completion: method, path, status, latency in ms
- [ ] Request and response bodies are not logged
- [ ] Authorization headers are not logged
- [ ] Log output goes to stdout in a format parseable in production (structured JSON or logfmt)

_See \`BACKEND-STORIES.md\`._"

# ── Phase 8: Frontend Curriculum Navigation ────────────────────────────────

issue "FE-05: Routing setup" \
  "frontend" \
  "Phase 8: Frontend Curriculum Navigation" \
  "## Description
Add client-side routing. Exercise page at \`/exercises/:id\`. Root redirects to first exercise.

## Acceptance Criteria
- [ ] \`/exercises/hello-world\` renders the hello-world exercise
- [ ] \`/\` redirects to the first exercise
- [ ] Unknown path renders a 404 page
- [ ] Browser back/forward navigation works correctly
- [ ] URL updates when navigating between exercises

_See \`FRONTEND-STORIES.md\`._"

issue "FE-06: Exercise list from API" \
  "frontend" \
  "Phase 8: Frontend Curriculum Navigation" \
  "## Description
Replace hardcoded exercise with \`GET /api/exercises\`. Display a sidebar listing chapters and exercises.

## Acceptance Criteria
- [ ] Sidebar fetches and renders all chapters and exercises from the API
- [ ] Chapters are collapsible (expanded by default)
- [ ] Current exercise is visually highlighted in the sidebar
- [ ] Clicking an exercise navigates to \`/exercises/:id\`
- [ ] If API call fails, a non-crashing error message is shown
- [ ] Sidebar is not re-fetched on every navigation (cached at app level)

_See \`FRONTEND-STORIES.md\`._"

issue "FE-07: Exercise page from API" \
  "frontend" \
  "Phase 8: Frontend Curriculum Navigation" \
  "## Description
Replace hardcoded exercise data with \`GET /api/exercises/:id\`. Editor pre-populated with \`stubCode\`.

## Acceptance Criteria
- [ ] Editor is populated with \`stubCode\` when an exercise loads
- [ ] Navigating to a different exercise resets editor to new stub code
- [ ] Per-exercise editor state is preserved in memory within the session
- [ ] 404 response from API renders the 404 page
- [ ] Exercise title and learning objective update on navigation

_See \`FRONTEND-STORIES.md\`._"

issue "FE-08: Progress indicators" \
  "frontend" \
  "Phase 8: Frontend Curriculum Navigation" \
  "## Description
Fetch \`GET /api/progress\` and display status badges on each exercise in the sidebar.

## Note
Progress data requires auth (Phase 9). In this phase, mock the response or render with empty/placeholder state.

## Acceptance Criteria
- [ ] Each exercise in the sidebar has a badge or icon indicating progress status
- [ ] \`not_started\`: no badge or neutral indicator
- [ ] \`attempted\`: non-success indicator (e.g. yellow dot)
- [ ] \`passed\`: success indicator (e.g. green checkmark)
- [ ] Progress updates in sidebar after a successful submission without a full page reload
- [ ] If progress API call fails, sidebar still renders (without badges)

_See \`FRONTEND-STORIES.md\`._"

issue "FE-09: Hint reveal" \
  "frontend" \
  "Phase 8: Frontend Curriculum Navigation" \
  "## Description
Display hints progressively below the editor. Each click reveals the next hint.

## Acceptance Criteria
- [ ] Hints are hidden by default
- [ ] A 'Show hint' button appears when hints are available and not all are shown
- [ ] Each click reveals the next hint without hiding previous ones
- [ ] Hints displayed in order (index 0 first)
- [ ] Hint section is visually distinct from the output panel
- [ ] Hint state resets when navigating to a new exercise

_See \`FRONTEND-STORIES.md\`._"

issue "FE-10: Submission history panel" \
  "frontend" \
  "Phase 8: Frontend Curriculum Navigation" \
  "## Description
Collapsible panel showing the last 5 submissions for the current exercise, from \`GET /api/submissions?exercise_id=:id\`.

## Acceptance Criteria
- [ ] Panel is collapsed by default and can be expanded
- [ ] Shows last 5 submissions at most, with status and timestamp
- [ ] Most recent submission is at the top
- [ ] Shows 'No previous submissions' message when list is empty
- [ ] Panel refreshes after a new submission
- [ ] Does not show submitted code

_See \`FRONTEND-STORIES.md\`._"

# ── Phase 9: Auth (Both Sides) ─────────────────────────────────────────────

issue "BE-11: Clerk JWT validation middleware" \
  "backend" \
  "Phase 9: Auth (Both Sides)" \
  "## Description
Servant auth middleware that validates the Clerk session JWT on each protected request. Fetches and caches Clerk's JWKS.

## Acceptance Criteria
- [ ] \`CLERK_JWKS_URL\` (or \`CLERK_PUBLISHABLE_KEY\`) read from environment; server fails fast if missing
- [ ] Valid Clerk JWT allows request through; Clerk user ID available to handlers
- [ ] Expired JWT returns 401 with code \`\"unauthorized\"\`
- [ ] Malformed or missing \`Authorization\` header returns 401
- [ ] JWKS cached in memory; refreshed on configurable interval (\`JWKS_REFRESH_SECONDS\`, default 3600)
- [ ] Single key fetch failure does not crash the server
- [ ] All routes except \`GET /health\` require a valid JWT

_See \`BACKEND-STORIES.md\`._"

issue "BE-12: User record creation on first login" \
  "backend" \
  "Phase 9: Auth (Both Sides)" \
  "## Description
On each authenticated request, look up the User row by Clerk ID. Create one if it doesn't exist.

## Acceptance Criteria
- [ ] First authenticated request from a new Clerk user creates a User row
- [ ] Subsequent requests retrieve the existing row without creating a duplicate
- [ ] \`GET /api/me\` returns the user's profile in the specified shape
- [ ] \`UniqueClerkId\` constraint prevents duplicate rows

_See \`BACKEND-STORIES.md\`, \`DATA-MODEL.md\`._"

issue "BE-13: Link submissions to users" \
  "backend" \
  "Phase 9: Auth (Both Sides)" \
  "## Description
Update the submission write path to populate \`userId\` with the authenticated user's database ID.

## Acceptance Criteria
- [ ] Every submission row has a non-null \`userId\`
- [ ] \`GET /api/submissions?exercise_id=:id\` returns only submissions belonging to the authenticated user
- [ ] Submissions from one user are never visible to another user

_See \`BACKEND-STORIES.md\`._"

issue "BE-14: Per-user rate limiting on submissions" \
  "backend" \
  "Phase 9: Auth (Both Sides)" \
  "## Description
Add per-user rate limit to \`POST /api/submissions\` (10/min per user), supplementing the existing per-IP limit.

## Acceptance Criteria
- [ ] 11th submission from the same user within 60 seconds returns 429, even from different IPs
- [ ] \`RATE_LIMIT_PER_USER\` configurable (default 10)
- [ ] \`Retry-After\` header reflects the per-user window
- [ ] Per-IP limit from BE-05 still enforced independently

_See \`BACKEND-STORIES.md\`._"

issue "FE-11: Clerk provider setup" \
  "frontend" \
  "Phase 9: Auth (Both Sides)" \
  "## Description
Install and configure the Clerk React SDK. Wrap the app in \`<ClerkProvider>\`.

## Acceptance Criteria
- [ ] \`VITE_CLERK_PUBLISHABLE_KEY\` read from \`.env.local\` (not committed)
- [ ] App boots without errors with Clerk configured
- [ ] \`useAuth()\` and \`useUser()\` hooks available in components
- [ ] \`.env.example\` documents all required environment variables

_See \`FRONTEND-STORIES.md\`._"

issue "FE-12: Auth-gated routing" \
  "frontend" \
  "Phase 9: Auth (Both Sides)" \
  "## Description
All routes except sign-in require authentication. Unauthenticated users redirected to sign-in page.

## Acceptance Criteria
- [ ] Visiting \`/exercises/:id\` while signed out redirects to sign-in page
- [ ] After sign-in, user lands on originally requested exercise (or first exercise)
- [ ] Signed-in users visiting sign-in page are redirected to first exercise
- [ ] Redirect destination survives a full page reload

_See \`FRONTEND-STORIES.md\`._"

issue "FE-13: Sign-in page" \
  "frontend" \
  "Phase 9: Auth (Both Sides)" \
  "## Description
Sign-in page at \`/sign-in\` using Clerk's \`<SignIn>\` component configured for GitHub OAuth only.

## Acceptance Criteria
- [ ] Sign-in page renders Clerk's sign-in UI
- [ ] Signing in with GitHub completes and redirects to the app
- [ ] Page is centred and readable at 375px viewport width
- [ ] Page title and surrounding copy clearly describe the product

_See \`FRONTEND-STORIES.md\`._"

issue "FE-14: Attach auth token to API requests" \
  "frontend" \
  "Phase 9: Auth (Both Sides)" \
  "## Description
Update \`src/api.ts\` to attach the Clerk session JWT as a Bearer token on every request.

## Acceptance Criteria
- [ ] Every request to \`/api/*\` includes \`Authorization: Bearer <token>\`
- [ ] Token is refreshed if expired before the request is made (Clerk handles this)
- [ ] A 401 response from the API redirects the user to sign-in
- [ ] No requests to \`/api/*\` are made before auth state is known

_See \`FRONTEND-STORIES.md\`._"

issue "FE-15: User avatar and sign-out" \
  "frontend" \
  "Phase 9: Auth (Both Sides)" \
  "## Description
Display the signed-in user's avatar and username in the app header. Provide a sign-out button.

## Acceptance Criteria
- [ ] Header shows user's GitHub avatar and username when signed in
- [ ] Sign-out button accessible from the header
- [ ] Signing out clears session and redirects to \`/sign-in\`
- [ ] After sign-out, all API calls are blocked until user signs in again
- [ ] Avatar falls back to a placeholder if \`avatarUrl\` is null

_See \`FRONTEND-STORIES.md\`._"

# ── Phase 10: Polish ────────────────────────────────────────────────────────

issue "FE-16: Loading states" \
  "frontend" \
  "Phase 10: Polish" \
  "## Description
Add loading states to all data-fetching interactions.

## Acceptance Criteria
- [ ] Sidebar shows skeleton or spinner while exercise list loads
- [ ] Exercise page shows placeholder while exercise data loads
- [ ] Submit button shows in-progress state while awaiting submission result
- [ ] Loading states always resolve to data or an error state (never persist indefinitely)
- [ ] No blank white screen at any point during a normal flow

_See \`FRONTEND-STORIES.md\`._"

issue "FE-17: Error states" \
  "frontend" \
  "Phase 10: Polish" \
  "## Description
Handle all error conditions from the API gracefully with informative messages and recovery actions.

## Acceptance Criteria
- [ ] Network failure on exercise list load shows error message with Retry button
- [ ] Network failure on submission shows error; editor and button remain usable
- [ ] 429 response shows human-readable rate-limit message including retry delay (\`Retry-After\` header)
- [ ] 502/504 response shows message indicating evaluation service is unavailable
- [ ] 401 response from any endpoint redirects to sign-in without a crash
- [ ] Error messages do not expose raw API error bodies or stack traces

_See \`FRONTEND-STORIES.md\`._"

issue "FE-18: Keyboard shortcuts" \
  "frontend" \
  "Phase 10: Polish" \
  "## Description
Add keyboard shortcuts for primary actions.

## Acceptance Criteria
- [ ] \`Ctrl+Enter\` / \`Cmd+Enter\` submits the current exercise
- [ ] Submit button displays the keyboard shortcut as a hint (e.g. ⌘↵)
- [ ] Shortcut does not fire while a submission is in flight
- [ ] Shortcut does not conflict with CodeMirror's default bindings

_See \`FRONTEND-STORIES.md\`._"

issue "FE-19: Mobile layout" \
  "frontend" \
  "Phase 10: Polish" \
  "## Description
Make the app usable on a phone. Sidebar collapses to a drawer at narrow viewports.

## Acceptance Criteria
- [ ] At 375px viewport width layout is fully usable with no horizontal scrolling
- [ ] Exercise navigation accessible via a menu button on mobile
- [ ] Code editor is touch-friendly (no accidental zoom on focus)
- [ ] Submit button has minimum 44×44px touch target
- [ ] Result/output panel is readable at narrow widths

_See \`FRONTEND-STORIES.md\`._"

issue "FE-20: Accessibility" \
  "frontend" \
  "Phase 10: Polish" \
  "## Description
Ensure the app is keyboard-navigable and screen reader friendly.

## Acceptance Criteria
- [ ] All interactive elements reachable and operable via Tab and Enter/Space
- [ ] Focus order is logical: sidebar → exercise content → editor → Submit button → result
- [ ] Submission results are announced by screen readers (ARIA live region)
- [ ] Pass/fail status is not conveyed by colour alone — icon or text label accompanies every colour indicator
- [ ] CodeMirror editor has an accessible label (e.g. \`aria-label=\"Haskell code editor\"\`)
- [ ] Page has logical heading hierarchy (\`h1\` for exercise title, \`h2\` for sections)
- [ ] No critical violations under axe-core automated checks

_See \`FRONTEND-STORIES.md\`._"

# ── Phase 11: CI + Production Deployment ──────────────────────────────────

issue "INFRA-11: Fly.io production app setup" \
  "infra" \
  "Phase 11: CI + Production Deployment" \
  "## Description
Provision the production Fly.io application. Production deploys are manual (not automatic on every merge).

## Acceptance Criteria
- [ ] Fly.io app \`haskell-koans\` (or equivalent) exists
- [ ] Separate \`fly.production.toml\` (or environment switch) targets the production app
- [ ] All secrets set independently of staging
- [ ] Production deploys require explicit \`fly deploy --app haskell-koans\` — no automatic production deploys from CI
- [ ] Production URL returns 200 from \`GET /health\`

_See \`INFRA-TASKS.md\`._"

issue "INFRA-12: Frontend production deployment" \
  "infra" \
  "Phase 11: CI + Production Deployment" \
  "## Description
Connect the frontend repository to Vercel or Netlify for automated deployments.

## Acceptance Criteria
- [ ] Frontend project connected to Vercel/Netlify via the dashboard
- [ ] \`VITE_CLERK_PUBLISHABLE_KEY\` and \`VITE_API_BASE_URL\` set as environment variables (production values)
- [ ] Preview deployments created for PRs, using staging API and staging Clerk keys
- [ ] Production build deploys automatically on merge to \`main\`
- [ ] Production frontend URL loads and reaches the production API

_See \`INFRA-TASKS.md\`._"

issue "INFRA-13: Secrets management documentation" \
  "infra" \
  "Phase 11: CI + Production Deployment" \
  "## Description
Document how to rotate secrets without downtime, and where each secret is stored.

## Acceptance Criteria
- [ ] A section in \`DEVELOPMENT.md\` (or separate doc) lists every secret, where it is used, and how to rotate it
- [ ] Procedure for rotating the Judge0 API key is documented
- [ ] Procedure for rotating the Clerk keys is documented
- [ ] No secrets appear in \`fly.toml\`, workflow files, or any committed file
- [ ] \`.gitignore\` includes \`.env\`, \`.env.local\`, and \`*.secret\`

_See \`INFRA-TASKS.md\`._"

issue "INFRA-14: Uptime monitoring" \
  "infra" \
  "Phase 11: CI + Production Deployment" \
  "## Description
Basic uptime monitoring for the production API health endpoint (UptimeRobot free tier or equivalent).

## Acceptance Criteria
- [ ] \`GET /health\` on production is checked every 5 minutes
- [ ] Alert fires (email to maintainer) if endpoint returns non-200 or times out for 2 consecutive checks
- [ ] Monitoring URL and alert contact are documented

_See \`INFRA-TASKS.md\`._"

issue "INFRA-15: Judge0 usage tracking" \
  "infra" \
  "Phase 11: CI + Production Deployment" \
  "## Description
Track Judge0 submission counts to catch unexpected cost spikes.

## Acceptance Criteria
- [ ] Every call to Judge0 (successful or failed) produces a structured log line: exercise ID, outcome status, latency in ms
- [ ] A monthly review process is documented: how to count Judge0 calls from logs and compare to plan limit
- [ ] README warns that \`JUDGE0_MOCK=true\` must be on in CI to avoid consuming execution quota in automated tests

_See \`INFRA-TASKS.md\`._"

issue "INFRA-16: Application error rate alerting" \
  "infra" \
  "Phase 11: CI + Production Deployment" \
  "## Description
Surface elevated backend error rates (5xx responses) via Fly.io's built-in metrics.

## Acceptance Criteria
- [ ] Fly.io dashboard shows request count and error rate graphs for the production app
- [ ] Fly.io alert configured: notify maintainer if 5xx error rate exceeds 5% over 10-minute window
- [ ] \`GET /health\` returns 200 only when database connection is healthy — DB outage causes health check failure
- [ ] Request logging from BE-18 feeds into Fly.io's log viewer

_See \`INFRA-TASKS.md\`._"

echo ""
echo "✓ Done. All issues created at https://github.com/$REPO/issues"
echo ""
echo "⚠️  One open decision before starting Phase 5:"
echo "   Frontend framework (React vs Svelte) — confirm before FE-01."
