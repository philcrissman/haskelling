# Backend Stories

*Input: ADR-001, DATA-MODEL.md, EVAL-SERVICE-DESIGN.md*

---

## Part 1: API Contract

This contract is the primary input for frontend development. All protected endpoints require a valid Clerk session JWT in the `Authorization: Bearer <token>` header.

---

### Authentication Model

Auth is handled by Clerk. The flow from the backend's perspective:

1. The frontend authenticates the user via Clerk's SDK (GitHub OAuth).
2. Clerk issues a signed JWT (session token) to the browser.
3. The frontend attaches it to every API request as `Authorization: Bearer <token>`.
4. The backend validates the JWT using Clerk's JWKS endpoint and extracts the user's Clerk ID.
5. On each authenticated request, if no User row exists for that Clerk ID, one is created.

The backend exposes no `/auth/*` redirect endpoints. Clerk owns the OAuth flow entirely.

---

### Endpoint Summary

| Method | Path | Auth | Rate Limit | Description |
|--------|------|------|------------|-------------|
| GET | `/health` | None | — | Health check |
| GET | `/api/me` | Required | — | Current user profile |
| GET | `/api/exercises` | None | — | All exercises grouped by chapter |
| GET | `/api/exercises/:id` | None | — | Single exercise |
| POST | `/api/submissions` | Required | 20/min per IP (per-user in Phase 10) | Submit code for evaluation |
| GET | `/api/exercises/:id/submissions` | Required | — | Submission history for an exercise |
| GET | `/api/progress` | Required | — | User's progress across all exercises |

**Note on exercise endpoint auth:** `GET /api/exercises` and `GET /api/exercises/:id` require no auth token. Exercise content is public learning material; the sensitive fields (`hiddenTests`, `canonicalSolution`) are stripped at the type level and never reach the wire regardless of auth state. Frontend routing enforces sign-in before any exercise is rendered; the backend does not duplicate that gate.

---

### GET /health

No auth required. Used by PaaS health checks.

**Response 200:**
```
{ "status": "ok" }
```

---

### GET /api/me

Returns the authenticated user's profile. Creates a User row on first call if one does not exist.

**Response 200:**
```
{
  "id":         number,
  "username":   string,
  "avatarUrl":  string | null,
  "email":      string | null
}
```

**Errors:**

| Code | Condition |
|------|-----------|
| 401 | Missing or invalid JWT |

---

### GET /api/exercises

Returns all exercises grouped by chapter, in display order. Strips `hiddenTests` and `canonicalSolution`.

**Response 200:**
```
{
  "chapters": [
    {
      "slug":        string,
      "title":       string,
      "description": string,
      "lesson":      string,   // markdown content for the chapter
      "exercises": [
        {
          "id":               string,
          "title":            string,
          "chapter":          string,
          "order":            number,
          "learningObjective": string,
          "stubCode":         string,
          "hints":            string[]
        }
      ]
    }
  ]
}
```

Chapters are ordered by `orderNum`. Exercises within each chapter are ordered by `orderInChapter`.

No auth required.

---

### GET /api/exercises/:id

Returns a single exercise by slug. Same shape as a single exercise object from the list endpoint.

**Path parameter:** `id` — exercise slug (e.g. `hello-world`)

**Response 200:**
```
{
  "id":                string,
  "title":             string,
  "chapter":           string,
  "order":             number,
  "learningObjective": string,
  "stubCode":          string,
  "hints":             string[]
}
```

No auth required.

**Errors:**

| Code | Condition |
|------|-----------|
| 404 | No exercise with that slug |

---

### POST /api/submissions

Submits user code for an exercise. Calls Judge0 synchronously and waits for the result. Rate limited.

**Request body:**
```
{
  "exerciseId": string,   // exercise slug
  "code":       string    // user-submitted Haskell; max 50 KB
}
```

**Response 200:**
```
{
  "status":      "pass" | "fail" | "compile_error" | "timeout" | "runtime_error" | "error",
  "output":      string,
  "passedCount": number,
  "failedCount": number
}
```

**Errors:**

| Code | Condition |
|------|-----------|
| 400 | Malformed request body |
| 401 | Missing or invalid JWT |
| 404 | Unknown exerciseId |
| 413 | Code exceeds 50 KB |
| 422 | Validation error |
| 429 | Rate limit exceeded (`Retry-After` header included) |
| 502 | Judge0 unreachable |
| 504 | Judge0 timed out |

---

### GET /api/exercises/:id/submissions

Returns submission history for the authenticated user on a specific exercise, newest first.

**Path parameter:** `id` — exercise slug

**Response 200:**
```
{
  "submissions": [
    {
      "id":          number,
      "status":      "pass" | "fail" | "compile_error" | "timeout" | "runtime_error" | "error",
      "output":      string,
      "passedCount": number,
      "failedCount": number,
      "createdAt":   string   // ISO 8601 timestamp
    }
  ]
}
```

Note: `code` is not returned in history responses. Users see their current editor state, not past submissions.

**Errors:**

| Code | Condition |
|------|-----------|
| 401 | Missing or invalid JWT |
| 404 | Unknown exercise slug |

---

### GET /api/progress

Returns the authenticated user's completion state across all exercises.

**Response 200:**
```
{
  "progress": [
    {
      "exerciseId":      string,
      "status":          "not_started" | "attempted" | "passed",
      "firstPassedAt":   string | null,   // ISO 8601
      "lastSubmittedAt": string | null    // ISO 8601; null if never submitted
    }
  ]
}
```

All exercises are included, even those with `not_started` status. Ordered to match the exercise list.

**Errors:**

| Code | Condition |
|------|-----------|
| 401 | Missing or invalid JWT |

---

### Error Response Shape

All error responses use this envelope:

```
{
  "error": string,   // human-readable message
  "code":  string    // machine-readable code, e.g. "rate_limit_exceeded"
}
```

---

## Part 2: User Stories

Stories are sized for a Haskell beginner with LLM assistance:
- **S** — ~1–3 hours
- **M** — ~3–6 hours
- **L** — ~6–12 hours

---

## Phase 1: Walking Skeleton

**Goal:** The app boots, one hardcoded exercise is served, a submission reaches Judge0 and returns a result. Rate limiting is in place. No database yet.

---

### BE-01: Scaffold Servant project

**Size:** M

**Description:**
Set up the Cabal project structure for the backend. Configure Servant, Wai, and Warp. The server starts and returns a response from the health endpoint.

**Acceptance criteria:**
- [ ] `cabal build` succeeds with no warnings
- [ ] `cabal run` starts a server on a configurable port (default 8080)
- [ ] `GET /health` returns `{"status":"ok"}` with status 200
- [ ] Port is read from an environment variable (`PORT`) with a fallback default
- [ ] The Servant API type is defined in its own module (`API.hs` or similar)

---

### BE-02: Hardcoded exercise endpoint

**Size:** S

**Description:**
Implement `GET /api/exercises/:id` with a single hardcoded exercise (the `hello-world` exercise from the curriculum). No database. The response must match the API contract exactly — `hiddenTests` and `canonicalSolution` are not present in the response.

**Acceptance criteria:**
- [ ] `GET /api/exercises/hello-world` returns the hello-world exercise in the specified shape
- [ ] `GET /api/exercises/unknown` returns 404 with the standard error envelope
- [ ] `GET /api/exercises` returns a chapters list containing the one hardcoded exercise
- [ ] Response is valid JSON matching the contract shapes defined in Part 1

---

### BE-03: Judge0 HTTP client

**Size:** M

**Description:**
Implement a module that calls the Judge0 cloud API to submit Haskell code and retrieve the result. The module is responsible for: constructing the combined source (user code + test harness), sending to Judge0, polling for completion (or using synchronous mode), and mapping the Judge0 response to the internal `SubmissionStatus` type.

**Acceptance criteria:**
- [ ] The Judge0 API key is read from an environment variable (`JUDGE0_API_KEY`), never hardcoded
- [ ] The combined source is assembled correctly: user module declaration + test suite imports + user definitions + test body
- [ ] All Judge0 status codes map to the internal `SubmissionStatus` type
- [ ] HSpec output is parsed to extract `passedCount` and `failedCount`
- [ ] Judge0 unavailability returns a structured error, not an unhandled exception
- [ ] A timeout from Judge0 is handled gracefully (maps to `StatusTimeout`)

---

### BE-04: Submission endpoint (walking skeleton)

**Size:** M

**Description:**
Implement `POST /api/submissions` using the hardcoded exercise and the Judge0 client. No database persistence yet — the response is returned directly from Judge0. Wire the endpoint into the Servant API type.

**Acceptance criteria:**
- [ ] Submitting correct code for `hello-world` returns `status: "pass"` with correct counts
- [ ] Submitting code with a syntax error returns `status: "compile_error"` with sanitized output
- [ ] Submitting an unknown `exerciseId` returns 404
- [ ] Code exceeding 50 KB returns 413 before calling Judge0
- [ ] The response shape matches the API contract exactly
- [ ] Judge0 is not called if the request fails validation

---

### BE-05: Per-IP rate limiting on submissions

**Size:** S

**Description:**
Add rate limiting middleware to `POST /api/submissions`. At this phase, limit by remote IP address. Limit: 20 requests per minute per IP.

**Acceptance criteria:**
- [ ] The 21st submission request from the same IP within 60 seconds returns 429
- [ ] The 429 response includes a `Retry-After` header (seconds until the window resets)
- [ ] The 429 response body uses the standard error envelope with code `"rate_limit_exceeded"`
- [ ] Rate limit state resets after the window expires
- [ ] The limit is configurable via an environment variable (`RATE_LIMIT_PER_IP`) with a sensible default

---

## Phase 2: Data Layer

**Goal:** Real database with Persistent migrations. Exercises are seeded from `CURRICULUM.json`. Submissions are persisted. History endpoint works.

---

### BE-06: Database connection and migrations

**Size:** M

**Description:**
Configure Persistent and postgresql-simple. On startup, run `migrateAll` to apply the schema from `DATA-MODEL.md`. The database URL is read from an environment variable.

**Acceptance criteria:**
- [ ] `DATABASE_URL` environment variable is read on startup; server fails fast with a clear message if it is missing
- [ ] `migrateAll` runs on startup and the schema matches `DATA-MODEL.md`
- [ ] Migrations are idempotent — running twice does not error
- [ ] The database connection pool size is configurable (`DB_POOL_SIZE`, default 10)
- [ ] A failed database connection on startup causes the server to exit with a non-zero code and a clear log message

---

### BE-07: Exercise seeding from CURRICULUM.json

**Size:** M

**Description:**
On startup (after migrations), read `CURRICULUM.json` and upsert all chapters and exercises into the database. The seed is idempotent — running it again updates changed fields without duplicating rows.

**Acceptance criteria:**
- [ ] All 30 exercises and their 6 chapters are present in the database after startup
- [ ] Upserting uses `UniqueExerciseSlug` and `UniqueChapterSlug` — no duplicates on restart
- [ ] `hiddenTests` and `canonicalSolution` are stored in the database
- [ ] Exercise `hints` are stored and retrieved correctly as a `[Text]` JSONB field
- [ ] A malformed or missing `CURRICULUM.json` causes the server to exit with a clear error

---

### BE-08: Exercise endpoints from database

**Size:** S

**Description:**
Replace the hardcoded exercise responses from BE-02 with database queries using Persistent and Esqueleto.

**Acceptance criteria:**
- [ ] `GET /api/exercises` queries the DB and returns all exercises grouped by chapter in correct order
- [ ] `GET /api/exercises/:id` queries by slug and returns 404 if not found
- [ ] `hiddenTests` and `canonicalSolution` are present in the DB row but absent from all API responses
- [ ] Response shape is identical to BE-02's output

---

### BE-09: Submission persistence

**Size:** S

**Description:**
After receiving a result from Judge0, persist the submission to the `submission` table before returning the response.

**Acceptance criteria:**
- [ ] Every completed submission (including failures and errors) creates a row in `submission`
- [ ] The submission row records: `userId` (null for now, updated in Phase 3), `exerciseId`, `code`, `status`, `output`, `passedCount`, `failedCount`, `createdAt`
- [ ] The `id` of the persisted row is returned in the API response
- [ ] Judge0 failures (502, 504) do not create a submission row

---

### BE-10: Submission history endpoint

**Size:** S

**Description:**
Implement `GET /api/submissions?exercise_id=:id`, querying the `submission` table for the authenticated user's past submissions on a given exercise.

**Acceptance criteria:**
- [ ] Returns submissions for the given exercise slug, newest first
- [ ] Returns 400 if `exercise_id` is missing
- [ ] Returns 404 if the exercise slug is unknown
- [ ] `code` field is not included in history responses
- [ ] Returns an empty array (not 404) if the exercise exists but has no submissions yet

---

## Phase 3: Auth

**Goal:** GitHub OAuth via Clerk. All non-health endpoints require a valid Clerk JWT. Per-user rate limiting added to submissions. `UserProgress` is created on first submission.

---

### BE-11: Clerk JWT validation middleware

**Size:** L

**Description:**
Implement a Servant auth middleware that validates the Clerk session JWT on each protected request. The middleware fetches Clerk's JWKS, caches the keys, validates the JWT signature and expiry, and extracts the Clerk user ID and username from the claims. Invalid or missing tokens return 401.

**Acceptance criteria:**
- [ ] `CLERK_JWKS_URL` (or `CLERK_PUBLISHABLE_KEY`) is read from environment; server fails fast if missing
- [ ] A valid Clerk JWT allows the request through; the user's Clerk ID is available to handlers
- [ ] An expired JWT returns 401 with code `"unauthorized"`
- [ ] A malformed or missing `Authorization` header returns 401
- [ ] JWKS are cached in memory and refreshed on a configurable interval (`JWKS_REFRESH_SECONDS`, default 3600); a single key fetch failure does not crash the server
- [ ] All routes except `GET /health` require a valid JWT

---

### BE-12: User record creation on first login

**Size:** S

**Description:**
On each authenticated request, look up the User row by Clerk ID. If none exists, create one using the username and other claims from the JWT. This is transparent to the caller — the handler receives a fully populated `User` value.

**Acceptance criteria:**
- [ ] The first authenticated request from a new Clerk user creates a User row
- [ ] Subsequent requests from the same Clerk user retrieve the existing row without creating a duplicate
- [ ] `GET /api/me` returns the user's profile in the specified shape
- [ ] `UniqueGithubId` (clerk ID mapped to this column) constraint prevents duplicate rows

---

### BE-13: Link submissions to users

**Size:** S

**Description:**
Update the submission write path (BE-09) to populate `userId` with the authenticated user's database ID.

**Acceptance criteria:**
- [ ] Every submission row has a non-null `userId`
- [ ] `GET /api/submissions?exercise_id=:id` returns only submissions belonging to the authenticated user
- [ ] Submissions from one user are never visible to another user

---

### BE-14: Per-user rate limiting on submissions

**Size:** S

**Description:**
Add a per-user rate limit to `POST /api/submissions` (10 requests per minute per user), supplementing the existing per-IP limit from BE-05. The stricter of the two limits applies.

**Acceptance criteria:**
- [ ] The 11th submission from the same user within 60 seconds returns 429, even if from different IPs
- [ ] The per-user limit is configurable via `RATE_LIMIT_PER_USER` (default 10)
- [ ] The `Retry-After` header reflects the per-user window, not the per-IP window
- [ ] Per-IP limit from BE-05 is still enforced independently

---

## Phase 4: Progress and Curriculum API

**Goal:** `UserProgress` is maintained transactionally. The progress endpoint works. Exercise list is fully ordered and chapter-grouped.

---

### BE-15: UserProgress upsert on submission

**Size:** M

**Description:**
After persisting a submission, upsert the `UserProgress` row for the (user, exercise) pair within the same database transaction. Status advances monotonically: `NotStarted` → `Attempted` → `Passed`. A failing submission after a pass does not regress status.

**Acceptance criteria:**
- [ ] The first submission for a (user, exercise) pair creates a `UserProgress` row with status `Attempted` (or `Passed` if it passed)
- [ ] A passing submission sets status to `Passed` and records `firstPassedAt` (only the first time)
- [ ] A failing submission after a pass leaves status as `Passed`
- [ ] `lastSubmittedAt` is updated on every submission
- [ ] The submission insert and the progress upsert succeed or fail together (same transaction)

---

### BE-16: Progress endpoint

**Size:** S

**Description:**
Implement `GET /api/progress`. Return a progress entry for every exercise, including those with no submissions (status `not_started`).

**Acceptance criteria:**
- [ ] All exercises are present in the response, not only those with submissions
- [ ] Exercises with no `UserProgress` row appear with `status: "not_started"` and null timestamps
- [ ] Response is ordered to match the exercise list order (chapter order, then order within chapter)
- [ ] `firstPassedAt` and `lastSubmittedAt` are ISO 8601 strings or null

---

### BE-17: Fully ordered chapter-grouped exercise list

**Size:** S

**Description:**
Verify and harden the `GET /api/exercises` response: chapters are ordered by `Chapter.orderNum`, exercises within each chapter are ordered by `Exercise.orderInChapter`. This replaces any ordering assumptions from BE-08.

**Acceptance criteria:**
- [ ] Chapters appear in ascending `orderNum` order
- [ ] Exercises within each chapter appear in ascending `orderInChapter` order
- [ ] The response is stable across repeated requests (no non-deterministic ordering)
- [ ] An Esqueleto query (not in-memory sort) handles the ordering

---

### BE-18: Request logging middleware

**Size:** S

**Description:**
Add structured request logging to all endpoints. Log method, path, status code, and latency for every request. Do not log request bodies (may contain user code) or auth tokens.

**Acceptance criteria:**
- [ ] Every request produces one log line on completion: method, path, status, latency in ms
- [ ] Request and response bodies are not logged
- [ ] Authorization headers are not logged
- [ ] Log output goes to stdout in a format that is readable locally and parseable in production (structured JSON or logfmt)

---

### BE-19: `GET /api/me` endpoint *(implemented)*

**Size:** S

**Description:**
Return the authenticated user's profile. If no User row exists for the Clerk ID (first call after sign-in), upsert one before responding.

**Acceptance criteria:**
- [ ] `GET /api/me` with a valid JWT returns `{ id, username, avatarUrl, email }`
- [ ] `id` is the database primary key (Int64)
- [ ] `avatarUrl` and `email` are `null` if absent on the Clerk user record
- [ ] Missing or invalid JWT returns 401

---

### BE-19b: Return 502/504 for Judge0 network failures

**Size:** S

**Description:**
The API contract specifies HTTP 502 when Judge0 is unreachable and 504 when Judge0 times out (poll exhausted). Currently the Judge0 client uses `fail` on network errors, which Servant catches as a generic 500. Poll-exhausted timeout produces a `SubmissionResult` with `StatusTimeout` (returned as 200 + `"status":"timeout"`), not a 504. Restructure the Judge0 error model to return typed errors.

**Acceptance criteria:**
- [ ] Judge0 network error → HTTP 502 with `{"error": "...", "code": "sandbox_unavailable"}`
- [ ] Judge0 poll timeout (attempts exhausted) → HTTP 504 with `{"error": "...", "code": "sandbox_timeout"}`
- [ ] Non-network errors (parse failures, unexpected status codes) → HTTP 500
- [ ] `submitAndWait` in `Judge0.hs` returns `Either` instead of using `fail`
- [ ] `submitHandler` maps the typed errors to the correct HTTP status codes

---

### BE-20: Add `lesson` column to Chapter

**Size:** S

**Description:**
Add a `lesson` column (TEXT NOT NULL) to the `chapter` table. Seed it from `curriculum/lessons/<slug>.md` at startup alongside other chapter data.

**Acceptance criteria:**
- [ ] `migrateAll` adds the `lesson` column to `chapter`
- [ ] Seeding reads `curriculum/lessons/<slug>.md` for each chapter and populates the column
- [ ] If a lesson file is missing, the server fails fast at startup with a clear error naming the missing file

---

### BE-21: Include `lesson` field in chapter API response

**Size:** S

**Description:**
Include the `lesson` field (markdown string) in each chapter object returned by `GET /api/exercises`.

**Acceptance criteria:**
- [ ] Each chapter object in `GET /api/exercises` includes `"lesson": string`
- [ ] The content matches what was seeded from `curriculum/lessons/<slug>.md`

---

### BE-22: Add `code` field to submission history response

**Size:** S

**Description:**
Include the submitted code in submission history items so the frontend can restore a user's last submission across devices.

**Acceptance criteria:**
- [ ] Each item in `GET /api/exercises/:id/submissions` includes `"code": string`
- [ ] The field contains the code that was submitted, unchanged

---

## Execution Order

Implement stories in this sequence; each phase should be independently testable before starting the next:

1. BE-01 → BE-02 → BE-03 → BE-04 → BE-05 *(walking skeleton complete)*
2. BE-06 → BE-07 → BE-08 → BE-09 → BE-10 *(data layer complete)*
3. BE-11 → BE-12 → BE-13 *(auth complete)*
4. BE-15 → BE-16 → BE-17 → BE-18 → BE-19 → BE-20 → BE-21 *(progress, curriculum API, and me endpoint complete)*
5. BE-14 → BE-19b → BE-22 *(Phase 10: per-user rate limiting, Judge0 error model, cross-device code restore)*

---

### BE-23: Backend test suite (issue #72)

**Size:** L

**Description:**
Add a Haskell test suite covering unit tests (pure logic, no DB) and integration tests (against a real test DB). See issue #72 for full scope.

**Deferred — post-launch.**

---

## Admin Dashboard (post-launch)

*An authenticated operator view of registered users and their progress. Not launch-blocking.*

### BE-28: Admin role and authorization gate

**Size:** M

**Description:**
Introduce a role on `User` and an authorization gate for admin-only endpoints. Use a `UserRole` enum (`RegularUser | Admin`) stored via `derivePersistField`, mirroring the existing `SubmissionStatus`/`ProgressStatus` pattern in `Schema.hs` — this costs no more than a boolean here but reads better at call sites and leaves room for future roles. (If we decide we'll never have more than admin/not, swapping to a plain `isAdmin :: Bool` is a one-line change.)

Add a `requireAdmin` helper that builds on `requireUser`: resolve the caller's `UserId`, look up their role, and reject non-admins with `403` (`{"code":"forbidden"}`) before any admin handler body runs — the backend is the real gate, never UI hiding alone.

Also expose the caller's role in `GET /api/me` so the frontend can decide whether to render admin navigation (FE-36).

**Acceptance criteria:**
- [ ] `User` has a `role` column; new users default to `RegularUser`
- [ ] Migration runs cleanly on the existing production table (existing rows backfill to `RegularUser`)
- [ ] `requireAdmin` returns `403` with a JSON error for authenticated non-admins and `401` for unauthenticated requests
- [ ] `GET /api/me` includes a `role` field (camelCase value, e.g. `"admin"` / `"regularUser"`)
- [ ] No admin endpoint relies on UI hiding for access control

---

### BE-29: Promote an account to admin

**Size:** S

**Description:**
A repeatable, low-ceremony way to mark an account as admin — needed to bootstrap the first admin (the owner's account) and any later ones. Recommended: read an env var (e.g. `BOOTSTRAP_ADMIN_EMAILS` or `BOOTSTRAP_ADMIN_CLERK_IDS`) at startup and, idempotently, set matching existing users to `Admin`. This fits the existing `Main.hs` env-reading pattern and avoids manual SQL against Neon: set the Fly secret, restart, done. Note the ordering wrinkle — a user row only exists after first sign-in, so the bootstrap should promote on startup *and/or* at user-creation time, and must no-op safely when the user isn't present yet.

Manual SQL (`UPDATE "user" SET role = 'Admin' WHERE clerk_id = '…'`) is the documented fallback.

**Depends on:** BE-28

**Acceptance criteria:**
- [ ] Setting the bootstrap env var and restarting promotes the matching account(s) to `Admin`
- [ ] Running it again with the same value is a no-op (idempotent)
- [ ] Promotion before the user has signed in does not crash startup; it applies once the user record exists
- [ ] The mechanism is documented (env var name + manual SQL fallback) in the secrets/ops notes

---

### BE-30: Admin API — list users with progress summary

**Size:** M

**Description:**
An admin-gated endpoint backing the dashboard: list all registered users with a summary of how far each has gotten. Aim for one aggregate query rather than N+1 over `UserProgress`.

**Depends on:** BE-28

**Acceptance criteria:**
- [ ] `GET /api/admin/users` is gated by `requireAdmin` (403 for non-admins)
- [ ] Response includes, per user: id, username, email, avatar, createdAt, exercises attempted, exercises passed, and last activity timestamp
- [ ] Progress counts are computed in the query/aggregation layer, not by per-user round-trips
- [ ] Fields are camelCase, consistent with the rest of the API
- [ ] Sensible default ordering (e.g. most-recently-active first)

**Deferred — post-launch.**

---

## Multi-file exercises (post-launch)

### BE-31: Multi-file exercise support (issue #90)

**Size:** L

**Description:**
Enable exercises with more than one editable Haskell file, so a learner can write a module in one file and use it from another. This unblocks **LYAH ch. 7 (Modules)**, skipped during the LYAH curriculum build because the single-file harness can't express "write your own module and import it."

Judge0 is not the blocker: `backend/src/Judge0.hs` already ships the user's solution to Judge0 as a base64 zip via `additional_files` (`makeAdditionalFiles`), alongside the hidden test runner in `source_code`, and GHC compiles them together. Additional user files are just more zip entries. The work is in our layers: the `Exercise` data model (currently a single `stubCode`/`canonicalSolution`), the curriculum file format (declare additional editable files), and the `/submit` API (accept multiple files, stay backward compatible with the single `code` field).

**Depends on:** —

**Acceptance criteria:**
- [ ] An exercise can define N editable files; single-file exercises are unaffected
- [ ] Seed loads multi-file exercises from the curriculum format
- [ ] `/submit` accepts multiple files and packs them all into Judge0's `additional_files`
- [ ] Hidden tests can import any of the user's modules
- [ ] API fields are camelCase; existing single-file submissions still work
- [ ] At least one ch. 7 (Modules) exercise exists end-to-end as proof

**Deferred — post-launch.** Pairs with FE-37.
