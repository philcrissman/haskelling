# Decisions Log

Record every significant choice here — planned or forced — with a date and brief reasoning.
This is the primary input to periodic reviews. See INITIAL_PLANNING.md for the review prompt.

---

## 2026-05-15

**Backend framework: Servant**
Learning Haskell idioms is the primary goal; Servant's type-level routing teaches this better than Scotty. Also the most production-common choice for long-term project health. See ADR-001.

**Sandbox: Managed Judge0 cloud (~$33.75/month)**
Solo maintainer. Ops burden of self-hosting not worth the ~$10–25/month saving. Deferred until sandbox integration phase to keep dev costs near zero. See ADR-001.

**Auth: GitHub OAuth via Clerk (free tier)**
Developer audience universally has GitHub. Clerk avoids building password flows, reset emails, and credential storage. Email/password and GitLab OAuth deferred to post-MVP. See ADR-001.

**Deployment: Fly.io or Railway (PaaS)**
Minimise ops burden for solo maintainer. git-push deploys and managed TLS preferred over VPS. See ADR-001.

**Database: PostgreSQL + Persistent + Esqueleto**
Most documented Haskell web stack combination. Supabase/Neon free tier during development. See ADR-001.

**Frontend: TypeScript SPA with Vite**
Keeps frontend in familiar territory; concentrates Haskell learning on the backend. React recommended (best Clerk/CodeMirror integration examples) but not yet confirmed — decide before FE-01. See FRONTEND-STORIES.md.

**Code editor: CodeMirror 6**
~250KB, modular, mobile-friendly, adequate Haskell syntax support. Monaco too heavy for small exercise snippets. See ADR-001.

**Exercise module naming: exercise-specific PascalCase**
`hello-world` → `module HelloWorld where`. Consistent with Exercism; teaches that module names are meaningful. More idiomatic than a generic `module Solution`. See EVAL-SERVICE-DESIGN.md.

**Hints storage: JSONB on Exercise table**
Hints are always read/written as a complete ordered array, never queried element-by-element. JSONB + Aeson is the natural fit. A separate hints table would add joins for no benefit at this scale. See DATA-MODEL.md.

**UserProgress status: monotonically advancing**
A failing submission after a passing one does not regress status from `Passed` to `Attempted`. Once you've passed an exercise, it stays passed. Product decision: appropriate for a learning tool where the goal is eventual mastery. See DATA-MODEL.md.

**Judge0 injection: `additional_files` (two-file submission)**
User code and hidden test suite are both complete Haskell modules with their own `module` declarations. GHC cannot compile two module declarations concatenated into one file. Judge0's `additional_files` (base64 zip) allows sending both files separately. **Requires verification against the Judge0 managed cloud tier at BE-03 time** — the fallback is server-side assembly of a single valid module. See EVAL-SERVICE-DESIGN.md.

**User identifier: `clerkId Text`**
Clerk user IDs are strings (`user_2Nxxx`), not integers. Using the Clerk user ID directly is simpler than querying the underlying GitHub user ID from social connection data, and is provider-neutral for future OAuth additions. Fixed from original `githubId Int64`. See DATA-MODEL.md.
