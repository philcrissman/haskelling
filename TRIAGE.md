# Triage — Session Handoff (2026-05-21)

Quick-reference for the next session. Work through this before picking up new feature work.
Sourced from the doc audit done at end of Phase 9.

---

## 1. Functional Gaps (code is wrong or incomplete)

| # | What | Where | Notes |
|---|------|-------|-------|
| A | `GET /api/progress` omits exercises with no submissions | `Server.hs:progressHandler` | BE-16 AC says all exercises should appear with `not_started`; currently only returns exercises that have a `UserProgress` row |
| B | Submission + progress upsert are not transactional | `Server.hs:submitHandler` | Two separate `runSqlPool` calls; BE-15 AC requires them in one transaction |
| C | `GET /health` doesn't check DB | `Server.hs:healthHandler` | INFRA-16 requires DB health gate; currently always returns 200 |
| D | `GET /api/me` never built | — | Listed in BACKEND-STORIES.md API contract and BE-12 AC; decide: build it or formally descope it |
| E | BE-14 (per-user rate limiting) not implemented | — | Listed as Phase 9 complete in STORY-ORDER but the code only does per-IP limiting; move to Phase 10 or create a focused story |

---

## 2. Doc Fixes (docs don't match the code)

| # | What | File(s) | Fix needed |
|---|------|---------|------------|
| F | Submission history route is wrong | BACKEND-STORIES.md, EVAL-SERVICE-DESIGN.md | Docs say `GET /api/submissions?exercise_id=:id`; actual is `GET /api/exercises/:id/submissions` |
| G | `POST /api/submissions` response shape | BACKEND-STORIES.md | Docs say response includes `id`, `exerciseId`, `evaluatedAt`; actual only has `status`, `output`, `passedCount`, `failedCount` |
| H | `GET /api/exercises` missing `lesson` field | BACKEND-STORIES.md | `ChapterResponse` includes `lesson`; API contract shape doesn't show it |
| I | Exercise endpoints auth decision undocumented | BACKEND-STORIES.md, EVAL-SERVICE-DESIGN.md | Docs say auth required; implementation has no auth check — make the call and document it |
| J | `Submission.userId` shown as NOT NULL | DATA-MODEL.md | Schema has `userId UserId Maybe`; migration SQL shows `NOT NULL`; DECISIONS.md is correct but DATA-MODEL is stale |
| K | `UniqueGithubId` reference | DATA-MODEL.md (indexes section) | Should be `UniqueClerkId` |
| L | `CLERK_JWKS_URL` in README setup | README.md | Step 3 says fill in `CLERK_JWKS_URL`; actual var is `CLERK_PUBLISHABLE_KEY` |
| M | "Not yet deployed" status | README.md | App is live on Fly.io staging |
| N | `CLERK_JWKS_URL` and `RATE_LIMIT_PER_USER` in env var list | INFRA-TASKS.md (INFRA-02) | Neither var exists; use `CLERK_PUBLISHABLE_KEY` + `CLERK_SECRET_KEY` |
| O | Snake_case field names throughout | EVAL-SERVICE-DESIGN.md | All field names are camelCase; doc uses `submission_id`, `passed_count`, `evaluated_at` etc. |
| P | FE-11 describes the React SDK | FRONTEND-STORIES.md | Story mentions `<ClerkProvider>`, `useAuth()`, `useUser()`; actual uses `@clerk/clerk-js` vanilla JS with `redirectToSignIn()` |
| Q | FE-07 says "store in memory" | FRONTEND-STORIES.md | AC says "store per-exercise editor state in memory"; now done in `localStorage` |
| R | Phase notes are stale | STORY-ORDER.md | Notes like "mock GET /api/progress in this phase" still present for Phases 8–9 which are complete |
| S | BE-19 through BE-22 missing | BACKEND-STORIES.md | Four issues exist (GitHub #58–60) with no story definitions in the doc; execution order section ends at BE-18 |

---

## 3. New Issues to Create

| # | What | Suggested ID | Notes |
|---|------|-------------|-------|
| T | Create DB indexes | INFRA-17 | Indexes specified in DATA-MODEL.md (`idx_submission_user_exercise` etc.) were never created; `migrateAll` doesn't cover manual indexes |
| U | Move BE-14 out of Phase 9 | — | Re-slot to Phase 10 in STORY-ORDER.md; update Phase 9 completion criteria |

---

## Suggested order for next session

1. **Quick wins first:** Fix README (L, M) — 5 minutes, high visibility for anyone onboarding.
2. **Decide on `GET /api/me`** (D) — build it or close the issue; it's blocking a clean API contract.
3. **Fix the API contract docs** (F, G, H, I) — BACKEND-STORIES.md is the source of truth for frontend work; stale contract causes confusion.
4. **Fix functional gaps** (A, B, C) — progress completeness (A) affects real UX; transaction safety (B) is a correctness issue.
5. **Remaining doc fixes** (J–S) — mechanical, can batch in one pass.
6. **New issues** (T, U) — create and slot into STORY-ORDER.md.
