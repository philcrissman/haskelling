# Decisions Log

Record every significant choice here — planned or forced — with a date and brief reasoning.
This is the primary input to periodic reviews. See INITIAL_PLANNING.md for the review prompt.

---

## 2026-05-15

**Backend framework: Servant**
Learning Haskell idioms is the primary goal; Servant's type-level routing teaches this better than Scotty. Also the most production-common choice for long-term project health. See ADR-001.

**Sandbox: Managed Judge0 cloud, pay-per-use to start**
Judge0 signup redirects to RapidAPI (their billing layer). Actual pay-per-use price via RapidAPI: $0.0017/submission (Judge0's own site lists $0.0013 — use $0.0017 for cost estimates). Volume pricing on RapidAPI: $44.99/month intro tier; break-even ~882 submissions/day (~26,465/month) at $0.0017/submission. Starting with pay-per-use — development costs near zero with JUDGE0_MOCK=true as default. Self-hosting considered but ops burden + hosting cost (~$10–20/month for a VPS with enough RAM for GHC) not worth it for a solo maintainer. See ADR-001.

**Auth: GitHub OAuth via Clerk (free tier)**
Developer audience universally has GitHub. Clerk avoids building password flows, reset emails, and credential storage. Email/password and GitLab OAuth deferred to post-MVP. See ADR-001.

**Deployment: Fly.io or Railway (PaaS)**
Minimise ops burden for solo maintainer. git-push deploys and managed TLS preferred over VPS. See ADR-001.

**Database: PostgreSQL + Persistent + Esqueleto**
Most documented Haskell web stack combination. Supabase/Neon free tier during development. See ADR-001.

**Frontend: TypeScript SPA with Vite + Svelte**
Keeps frontend in familiar territory; concentrates Haskell learning on the backend. Svelte chosen over React for its simpler component model — less boilerplate, lower cognitive load alongside learning Haskell. LLM assistance will compensate for thinner example coverage vs React. See FRONTEND-STORIES.md.

**Code editor: CodeMirror 6**
~250KB, modular, mobile-friendly, adequate Haskell syntax support. Monaco too heavy for small exercise snippets. See ADR-001.

**Exercise module naming: exercise-specific PascalCase**
`hello-world` → `module HelloWorld where`. Consistent with Exercism; teaches that module names are meaningful. More idiomatic than a generic `module Solution`. See EVAL-SERVICE-DESIGN.md.

**Hints storage: JSONB on Exercise table**
Hints are always read/written as a complete ordered array, never queried element-by-element. JSONB + Aeson is the natural fit. A separate hints table would add joins for no benefit at this scale. See DATA-MODEL.md.

**UserProgress status: monotonically advancing**
A failing submission after a passing one does not regress status from `Passed` to `Attempted`. Once you've passed an exercise, it stays passed. Product decision: appropriate for a learning tool where the goal is eventual mastery. See DATA-MODEL.md.

**Judge0 injection: `additional_files` (two-file submission) — VERIFIED**
`additional_files` is supported on the managed cloud tier. Spike confirmed: user code goes in the zip as `HelloWorld.hs` (or equivalent); test module is `source_code`. All submissions must use `base64_encoded=true` to handle special characters safely. See EVAL-SERVICE-DESIGN.md.

**Judge0 environment: language ID 61, GHC 8.8.1, base-only packages**
Spike confirmed language ID is 61 (not 12 as estimated). GHC version is 8.8.1 — older than local dev (9.6.x) but adequate for all planned exercises. HSpec is not installed; only `base` packages are available. Resource limit caps: `cpu_time_limit` ≤ 20s, `wall_time_limit` ≤ 30s (lower than originally planned).

**Test runner: custom base-only framework (no HSpec)**
HSpec is unavailable in Judge0's environment. Replaced with a minimal `assertEqual`-style runner using only `System.Exit` from `base`. Output format: `N examples, M failures` (same summary line as HSpec for consistent parsing). Fail path returns `NZEC` exit status (Runtime Error in Judge0 terms), which maps to our `fail` status. All 30 `hidden_test_suite` entries in CURRICULUM.json rewritten accordingly. See EVAL-SERVICE-DESIGN.md.

**User identifier: `clerkId Text`**
Clerk user IDs are strings (`user_2Nxxx`), not integers. Using the Clerk user ID directly is simpler than querying the underlying GitHub user ID from social connection data, and is provider-neutral for future OAuth additions. Fixed from original `githubId Int64`. See DATA-MODEL.md.

---

## 2026-05-17

**Docker builder image: `haskell:9.12` (Debian bookworm)**
`haskell:9.4.8` is based on Debian buster (EOL June 2022) — apt returns 404. `haskell:9.8.4` is bullseye, which ships libpq 13; `postgresql-libpq-configure 0.11` requires libpq ≥ 14.12 and fails. `haskell:9.12` is bookworm with libpq 15 and satisfies all requirements. GHC version in Docker (9.12.4) differs from local dev (9.4.8) but our `base >= 4.17 && < 5` bound covers both.

**Docker runtime image: `debian:bookworm-slim`**
Matches the builder's Debian version (bookworm), ensuring `libffi.so.8` and `libpq.so.5` are present. Runtime deps: `libffi8`, `libgmp10`, `libpq5`, `zlib1g`, `ca-certificates`. Final image size: 223MB. Runs as non-root uid 1001.

**Docker dep-caching workaround for cabal 3.14**
cabal 3.14 (shipped with `haskell:9.12`) builds the local library as part of dependency resolution, unlike older cabal where `--only-dependencies` skipped local packages. Workaround: copy `.cabal` file, create minimal placeholder source files for all modules, attempt `cabal build exe:haskelling || true` (external packages land in `~/.cabal/store` even when local lib fails), then `COPY` real source and build properly. This preserves the dependency caching layer — external packages are only recompiled when `haskelling.cabal` changes.
