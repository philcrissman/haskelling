# Triage — Session Handoff (2026-05-22)

All items from the 2026-05-21 audit have been resolved. See git log for details.

---

## Resolved (this session)

| # | Item | Resolution |
|---|------|-----------|
| A | `GET /api/progress` omitted not-started exercises | Fixed: progressHandler now fetches all exercises and fills gaps with `not_started` |
| B | Submission + progress upsert not transactional | Fixed: combined into single `runSqlPool` call |
| C | `GET /health` didn't check DB | Fixed: pings DB with `SELECT 1`, returns 503 on failure |
| D | `GET /api/me` never built | Built: full endpoint in API.hs + Server.hs |
| E | Per-user rate limiting not implemented | Moved to Phase 10 as BE-14; current limiting is per-IP only (documented) |
| F | Submission history route wrong in docs | Fixed: BACKEND-STORIES, EVAL-SERVICE-DESIGN updated to `GET /api/exercises/:id/submissions` |
| G | POST /api/submissions response shape wrong in docs | Fixed: removed `id`, `exerciseId`, `evaluatedAt`; matches actual `status`, `output`, `passedCount`, `failedCount` |
| H | `lesson` field missing from GET /api/exercises doc | Fixed in BACKEND-STORIES |
| I | Exercise endpoint auth decision undocumented | Documented: exercise endpoints intentionally have no auth (public content; frontend enforces sign-in) |
| J | `Submission.userId` shown as NOT NULL in DATA-MODEL | Fixed: entity def and migration SQL both show nullable |
| K | `UniqueGithubId` in DATA-MODEL indexes section | Fixed: changed to `UniqueClerkId` |
| L | README step 3 used `CLERK_JWKS_URL` | Fixed: now `CLERK_PUBLISHABLE_KEY` + `CLERK_SECRET_KEY` |
| M | README said "Not yet deployed" | Fixed: updated to reflect Fly.io staging |
| N | `CLERK_JWKS_URL` and `RATE_LIMIT_PER_USER` in INFRA-02 | Fixed in INFRA-TASKS.md |
| O | Snake_case fields throughout EVAL-SERVICE-DESIGN | Fixed: all field names now camelCase |
| P | FE-11 described React SDK | Fixed: updated to reflect `@clerk/clerk-js` vanilla JS usage |
| Q | FE-07 said "store in memory" | Fixed: updated to `localStorage` |
| R | Phase 8–9 notes were stale | Fixed in STORY-ORDER.md |
| S | BE-19 through BE-22 missing from BACKEND-STORIES | Added: all four story definitions + execution order updated |
| T | DB indexes never created (INFRA-17) | Created INFRA-17 story in INFRA-TASKS.md |
| U | BE-14 still in Phase 9 | Moved to Phase 10 in STORY-ORDER.md |

---

## Next up: Phase 10

Pick up from STORY-ORDER.md Phase 10. First story is BE-14 (per-user rate limiting).
