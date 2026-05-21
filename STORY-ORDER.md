# Master Story Order

Derived from the Revised Execution Order in INITIAL_PLANNING.md.
Each phase should be independently testable before starting the next.

---

## Phase 1 — Local Development Environment

*Do this before writing any application code.*

| ID | Story |
|----|-------|
| INFRA-01 | Docker Compose for local PostgreSQL |
| INFRA-02 | Environment variable setup and `.env.example` files |
| INFRA-03 | Judge0 mock mode (`JUDGE0_MOCK=true`) |
| INFRA-04 | Development README / workflow documentation |

**Phase complete when:** `docker compose up -d` starts Postgres, `cabal run` starts the server against it, and `npm run dev` starts the frontend — all from a fresh clone following the README.

---

## Phase 2 — Eval Service Spike

*Prove the Judge0 + Haskell integration works before building the full backend around it.*
*The planning doc warns: "The eval service phase will almost certainly surface surprises about GHC compilation time and memory use. Run a dedicated review after this phase before proceeding."*

| Action | Detail |
|--------|--------|
| Research spike | Create a minimal Haskell script that submits a Haskell program to Judge0 cloud and parses the response. Not a full story — just enough to confirm language ID, resource limits, and whether `additional_files` is supported by the cloud tier. |
| Verify | Confirm Judge0 managed cloud accepts `additional_files` (base64 zip). If not, decide on the fallback assembly approach and update EVAL-SERVICE-DESIGN.md and DECISIONS.md. |
| Measure | Record actual cold compile + run latency for a trivial Haskell program. Update ADR-001 consequences if materially different from the 5–30s estimate. |

**Phase complete when:** A Judge0 submission of a Haskell program returns a result and the injection approach (additional_files or fallback) is confirmed and documented.

---

## Phase 3 — Data Model / Migrations

| ID | Story |
|----|-------|
| BE-06 | Database connection and migrations (`migrateAll` on startup) |
| BE-07 | Exercise seeding from `CURRICULUM.json` |

**Note (BE-07):** `CURRICULUM.json` uses `"order"` but the Persistent entity uses `orderInChapter`. The seeding code maps between them. Also maps `"chapter"` (slug string) to a `ChapterId` foreign key.

**Phase complete when:** The server starts, runs migrations, seeds all 30 exercises and 6 chapters, and `GET /api/exercises` (hardcoded, pre-BE-08) returns data from the database.

---

## Phase 4 — Backend Walking Skeleton

*One exercise is served, a real submission reaches Judge0, a result is returned. Rate limiting is active.*

| ID | Story |
|----|-------|
| BE-01 | Scaffold Servant project (health endpoint) |
| BE-02 | Hardcoded exercise endpoint |
| BE-03 | Judge0 HTTP client (uses the injection approach confirmed in Phase 2) |
| BE-04 | Submission endpoint (walking skeleton, no DB persistence yet) |
| BE-05 | Per-IP rate limiting on submissions |
| INFRA-08 | Dockerfile for Haskell backend (multi-stage, non-root) |
| INFRA-05 | GitHub Actions: Haskell build and test |
| INFRA-06 | GitHub Actions: Frontend typecheck and build |

**Phase complete when:** `POST /api/submissions` with correct code for `hello-world` returns `{"status":"pass"}` from real Judge0, and the Dockerfile builds successfully.

---

## Phase 5 — Frontend Walking Skeleton + Staging

*The UI loop works end-to-end. Staging environment is live.*

| ID | Story |
|----|-------|
| FE-01 | Scaffold Vite + React + TypeScript (confirm framework before starting) |
| FE-02 | CodeMirror 6 editor component |
| FE-03 | Hardcoded exercise page |
| FE-04 | Submit code and display result |
| INFRA-09 | Fly.io staging app setup |
| INFRA-10 | Staging database setup |
| INFRA-07 | GitHub Actions: auto-deploy to staging on merge to `main` |

**Phase complete when:** A user can open the staging URL, edit the hello-world stub in the browser, submit it, and see a pass/fail result returned from Judge0.

---

## Phase 6 — Curriculum Content

*Can proceed in parallel with Phases 7–8. Already substantially complete.*

| ID | Action | Detail |
|----|--------|--------|
| — | Review | Read through all 30 exercises in `CURRICULUM.json`. Verify stub code compiles, hints are useful, test cases are correct. |
| — | Fix | Correct any exercises found to be broken or unclear. |
| — | Extend | Optionally add exercises beyond the initial 30 if gaps are identified. |
| CONTENT-01 | Write chapter lessons | Write `curriculum/lessons/<slug>.md` for each of the 6 chapters. Each lesson should be self-contained enough that a reader can attempt all exercises in the chapter without leaving the site. Include: key concepts, type signatures to know, worked examples, and pointers to Hoogle/docs for deeper reference. |

**Note:** The `implementing-show` exercise (ID 28) uses Unicode suit symbols via `\9827` etc. Verify these display correctly in HSpec output when the test harness is wired up.

**Chapters needing lessons:** `basics`, `functions`, `lists`, `types`, `pattern-matching`, `recursion`, `typeclasses`.

**Phase complete when:** All 35 exercises have been manually reviewed, any broken ones fixed, and all 7 lesson files exist in `curriculum/lessons/`.

---

## Phase 7 — Backend Data Layer and Curriculum API

| ID | Story |
|----|-------|
| BE-08 | Exercise endpoints from database (replaces hardcoded) |
| BE-09 | Submission persistence |
| BE-10 | Submission history endpoint |
| BE-15 | UserProgress upsert on submission |
| BE-16 | Progress endpoint |
| BE-17 | Fully ordered chapter-grouped exercise list |
| BE-18 | Request logging middleware |
| BE-20 | Add `lesson` column to Chapter; seed from `curriculum/lessons/<slug>.md` at startup |
| BE-21 | Include `lesson` field in chapter API response (`/api/exercises`) |

**Note (BE-10):** Auth is not yet active in this phase. The history endpoint returns submissions without user filtering — all submissions for the exercise are returned. This is acceptable for pre-auth development. BE-13 (Phase 9) locks it to the authenticated user.

**Phase complete when:** All exercises load from the database, submissions are persisted, submission history is returned, and progress is tracked and exposed via the API.

---

## Phase 8 — Frontend Curriculum Navigation

| ID | Story |
|----|-------|
| FE-05 | Routing setup (`/exercises/:id`) |
| FE-06 | Exercise list from API (sidebar with chapters) |
| FE-07 | Exercise page from API (stub code in editor) |
| FE-08 | Progress indicators (progress badges in sidebar) |
| FE-09 | Hint reveal (progressive, one at a time) |
| FE-10 | Submission history panel |
| FE-22 | Lesson panel per chapter — render `lesson` markdown above exercise list; requires a markdown renderer (e.g. `marked`) |

**Note (FE-08):** Progress data requires auth (Phase 9). In this phase, mock the `GET /api/progress` response locally or render the component with placeholder/empty state. Wire to the real endpoint in Phase 9.

**Phase complete when:** A user can navigate between all 30 exercises by URL and sidebar, see their stub code, submit, and see results and history — all without auth.

---

## Phase 9 — Auth (Both Sides)

*Backend and frontend auth implemented together. After this phase, all routes are protected.*

| ID | Story |
|----|-------|
| BE-11 | Clerk JWT validation middleware |
| BE-12 | User record creation on first login |
| BE-13 | Link submissions to users |
| BE-14 | Per-user rate limiting on submissions |
| FE-11 | Clerk provider setup |
| FE-12 | Auth-gated routing |
| FE-13 | Sign-in page (GitHub OAuth via Clerk) |
| FE-14 | Attach auth token to API requests |
| FE-15 | User avatar and sign-out |

**Suggested sub-order within this phase:**
1. FE-11 (Clerk provider) + BE-11 (JWT validation) — prove the token round-trip first
2. BE-12, FE-12, FE-13, FE-14 — wire auth end-to-end
3. BE-13 — link existing submissions to users
4. BE-14, FE-15 — rate limit + sign-out polish

**Phase complete when:** Unauthenticated users are redirected to sign-in, GitHub OAuth completes successfully, all API calls include the Clerk JWT, and progress data is user-scoped.

---

## Phase 10 — Polish

| ID | Story |
|----|-------|
| FE-16 | Loading states |
| FE-17 | Error states (network failures, 429, 502/504) |
| FE-18 | Keyboard shortcuts (Cmd/Ctrl+Enter to submit) |
| FE-19 | Mobile layout |
| FE-20 | Accessibility (ARIA live regions, keyboard navigation, heading hierarchy) |

**Phase complete when:** The app is usable on a phone, resilient to API errors, keyboard-navigable, and has no critical accessibility violations under axe-core.

---

## Phase 11 — CI, Staging, Production Deployment

*Set up production and long-term monitoring. The app is MVP-ready after this phase.*

| ID | Story |
|----|-------|
| INFRA-11 | Fly.io production app setup |
| INFRA-12 | Frontend production deployment (Vercel/Netlify) |
| INFRA-13 | Secrets management documentation |
| INFRA-14 | Uptime monitoring (UptimeRobot or equivalent) |
| INFRA-15 | Judge0 usage tracking |
| INFRA-16 | Application error rate alerting |

**Phase complete when:** The production app is live, monitored, and a deployment procedure for future releases is documented.

---

## Full Story Count

| Phase | Stories | IDs |
|-------|---------|-----|
| 1 — Local dev | 4 | INFRA-01–04 |
| 2 — Eval spike | — | (research, not a formal story) |
| 3 — Data model | 2 | BE-06–07 |
| 4 — Backend skeleton | 7 | BE-01–05, INFRA-05–06, INFRA-08 |
| 5 — Frontend skeleton + staging | 7 | FE-01–04, INFRA-07, INFRA-09–10 |
| 6 — Curriculum review + lessons | 1 | CONTENT-01 (+ review tasks) |
| 7 — Backend data layer | 9 | BE-08–10, BE-15–18, BE-20–21 |
| 8 — Frontend navigation | 7 | FE-05–10, FE-22 |
| 9 — Auth | 9 | BE-11–14, FE-11–15 |
| 10 — Polish | 5 | FE-16–20 |
| 11 — Production | 6 | INFRA-11–16 |
| **Total** | **57** | |

---

## Open Decisions Before Starting

These must be resolved before the indicated phase:

| Decision | Resolve before | Note |
|----------|---------------|------|
| ~~Frontend framework~~ | ~~Phase 5 (FE-01)~~ | **Resolved: Svelte** |
| Judge0 `additional_files` support in cloud tier | Phase 2 | Determines injection approach for BE-03 |
