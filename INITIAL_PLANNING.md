# Haskell Koans — Planning Prompts

A sequence of prompts for generating the project architecture, stories, and tasks.
Run them in order. The output of each becomes input to the next — paste the ADR
from Prompt 1 into every subsequent prompt that asks for it.

---

## Prompt 1: Project Definition and Constraints

This prompt runs in three passes. Complete each pass before moving to the next.

### Context block (include verbatim at the top of every pass)

> I am building a Haskell learning tool — a Rustlings/koans-style web app where users
> complete Haskell exercises that are checked by running tests against their submitted
> code. The application has three main components:
>
> 1. A **backend API server** written in Haskell
> 2. A **frontend** (framework TBD)
> 3. A **code execution sandbox** that safely compiles and runs user-submitted Haskell
>    against a hidden test suite and returns pass/fail results
>
> About me: I am a senior software engineer with ~18 years of experience, primarily
> Ruby/Rails. I am actively learning Haskell and want to use it for the backend as both
> a learning exercise and a genuine open-source contribution. I am working solo with
> LLM assistance. I have no strong opinions on stack choices beyond wanting the backend
> in Haskell.

---

### Pass 1 — Generate the question list

> [Paste context block]
>
> Before we make any architectural decisions, generate the complete list of questions
> you would need answered to produce an Architecture Decision Record (ADR) for this
> project. Focus on decisions that are **hard to reverse** — framework lock-in, database
> choice, API shape, eval service architecture. Defer easily-changed decisions.
>
> Cover at minimum these domains:
> - **Backend Haskell framework**: Servant, Yesod, Scotty, IHP, or other — include a
>   brief comparison relevant to a Haskell beginner coming from Ruby/Rails
> - **Frontend approach**: framework, SPA vs MPA vs server-rendered
> - **Code editor component**: CodeMirror 6 vs Monaco vs other (bundle size, mobile
>   support, ease of embedding)
> - **Database and access layer**: choice and ORM/query library
> - **Code execution sandbox**: Judge0 (open-source, self-hostable, Haskell support),
>   Piston (alternative open-source runner), custom Docker solution, or managed service
>   — summarize tradeoffs including cost, Haskell-specific concerns (GHC compile time,
>   memory), and operational burden for a solo maintainer
> - **Authentication approach**
> - **Deployment target**
> - **Exercise content authoring**: how new exercises are added (git-based, admin UI,
>   seed files, other)
> - **Hard constraints**: budget, timeline, solo maintainer implications
>
> For each question: note whether you have a strong default recommendation (and what it
> is), or whether it genuinely requires my input. Group related questions together.
>
> Do not answer the questions or produce the ADR yet.

*Record the question list here after Pass 1:*
ADR Pre-Questions: Haskell Koans Web App

  ---
  1. Backend Haskell Framework

  Comparison context for a Ruby/Rails engineer:
  - Scotty — closest to Sinatra; minimal, low magic, good for learning the type system hands-on
  - Servant — type-level routing (routes are types); steep learning curve but industry-standard for APIs; mistakes caught at compile
  time
  - Yesod — closest to Rails; full-stack, lots of conventions, Template Haskell magic; can obscure what you're learning
  - IHP — opinionated Rails-alike built on Haskell; least transferable Haskell knowledge; not production-common
  - Wai/Warp raw — maximum learning, maximum pain

  Questions:

  1. Primary goal tension: Is this backend more about learning idiomatic Haskell (favor Servant — industry common, type-driven design)
  or shipping a working product quickly (favor Scotty — less ceremony)? This is the single most load-bearing question for framework
  choice.
  2. Do you want to experience type-level programming (Servant's hallmark), or would you rather that complexity be deferred until you're
   more comfortable?
  3. Are you open to Template Haskell (used heavily by Yesod and Persistent), knowing it can make compile errors harder to read as a
  beginner?

  ▎ Strong default: Servant for a learning-focused API backend. It's painful at first but teaches core Haskell idioms; the pain is
  ▎ productive. Scotty is the fallback if shipping speed matters more.

  ---
  2. Frontend Approach

  4. Do you have a strong preference for keeping the frontend in a language/ecosystem you already know (e.g., plain TypeScript/React)
  vs. using a Haskell-compiled-to-JS approach (e.g., GHCJS, Miso, Reflex)?
  5. Is this primarily a desktop-browser experience, or does mobile usability matter significantly? (Affects editor choice more than
  framework.)
  6. SPA vs. MPA tradeoff: Do you need real-time feedback (e.g., live test output streaming) or is a simple request/response loop
  (submit → wait → show results) acceptable?
  7. How much frontend complexity do you anticipate? Is this essentially: exercise list + code editor + results display, or do you
  foresee user dashboards, progress tracking, social features, etc.?

  ▎ Strong default: A thin TypeScript + Vite SPA (e.g., React or Svelte) calling the Haskell API. Keeps frontend familiar, lets you
  ▎ focus Haskell learning on the backend. Haskell-to-JS frameworks are a significant additional learning burden.

  ---
  3. Code Editor Component

  8. Is bundle size a hard constraint (e.g., targeting slow connections or low-end devices)?
  9. Do you need features beyond syntax highlighting and basic editing — e.g., inline type hints, LSP integration, vim keybindings?
  10. Is mobile editing a requirement or a nice-to-have?

  Comparison:
  - CodeMirror 6 — ~250KB, modular, mobile-friendly, good Haskell syntax support, simpler embedding
  - Monaco — ~4–5MB, VS Code engine, richer LSP support, poor mobile experience, heavier to embed
  - CodeJar / simple textarea — minimal, no syntax highlighting; fine for MVP

  ▎ Strong default: CodeMirror 6. For a koans app, users write small snippets; Monaco's power isn't needed and its bundle/mobile story
  ▎ is worse.

  ---
  4. Database and Access Layer

  11. What data needs to be persisted? At minimum: users, exercises, submission history — are there others (teams, courses,
  leaderboards)?
  12. Do you have a preference between PostgreSQL and SQLite? (SQLite is operationally much simpler for solo deployment; Postgres is
  more standard for multi-user apps.)
  13. For the Haskell ORM/query layer — are you willing to write raw SQL (via postgresql-simple or hasql) for simplicity, or do you want
   a type-safe query DSL (Esqueleto + Persistent, Opaleye, Beam)?

  ▎ Strong default: PostgreSQL + Persistent (schema migrations) + Esqueleto (type-safe queries). This is the most common Haskell web
  ▎ stack combination and has the most documentation. Raw SQL (postgresql-simple) is a reasonable simpler alternative.

  ---
  5. Code Execution Sandbox

  This is the hardest-to-reverse architectural decision.

  14. Operational burden tolerance: Are you willing to self-host and maintain a sandbox service (Judge0, Piston, or custom Docker), or
  do you strongly prefer a managed/hosted solution with no infra ownership?
  15. Cost ceiling: What is your rough monthly budget ceiling for infrastructure? (Judge0 cloud has per-execution pricing; self-hosted
  has VM cost; this is material for a solo open-source project.)
  16. Compile time tolerance: GHC compile times for small exercises are typically 5–30 seconds cold. Is that acceptable UX, or do you
  want to invest in warm cache strategies (pre-compiled base images, persistent GHC processes)?
  17. Security threat model: Who are the users? Anonymous public internet users (highest sandboxing requirement) vs.
  authenticated/trusted learners (lower risk)?
  18. Do you want the sandbox to be a separate deployable service (microservice boundary) or embedded/called as a subprocess from the
  main API server?
  19. Have you evaluated Judge0's Haskell support specifically? It supports GHC but memory limits and timeout behavior for Haskell
  specifically may need tuning — is this research you're willing to do, or a blocker?

  Comparison summary:
  - Judge0 (self-hosted): Full control, Haskell supported, Docker-based, significant ops burden, free at cost of infra
  - Judge0 (cloud): Managed, per-submission cost, least ops work
  - Piston: Simpler API, good language coverage, less battle-tested for Haskell at scale
  - Custom Docker: Maximum control, maximum work; only justified if others don't fit
  - Managed (e.g., Sphere Engine): Commercial, easiest, most expensive

  ▎ No strong default here — this genuinely requires your input on ops tolerance and budget.

  ---
  6. Authentication

  20. Do you need authentication at MVP, or is anonymous/unauthenticated use acceptable initially (e.g., stateless exercise sessions)?
  21. If auth is needed: do you want to own it (email/password with Haskell JWT libraries) or delegate it (OAuth via GitHub/Google, or a
   managed provider like Auth0/Clerk)?
  22. Is social login (GitHub OAuth specifically) important? (GitHub login is natural for a developer-facing learning tool.)

  ▎ Strong default: GitHub OAuth via a managed provider (Clerk or Auth0 free tier) or direct GitHub OAuth. Avoid building auth from
  ▎ scratch; the operational and security cost isn't worth it for a solo project.

  ---
  7. Deployment Target

  23. Where are you comfortable deploying? Options in roughly increasing ops burden: managed PaaS (Railway, Fly.io, Render) → VPS
  (Hetzner, DigitalOcean) → cloud (AWS/GCP/Azure).
  24. Does the sandbox need to run on the same host as the API, or are you open to running it on a separate machine/service?
  25. Do you need a container build pipeline (Docker), or are you comfortable with binary deployment (e.g., Nix, Cabal-built binaries)?
  26. Is high availability (zero-downtime deploys, multi-region) a requirement, or is best-effort uptime acceptable for an open-source
  learning tool?

  ▎ Strong default: Fly.io or Railway for the API (good Haskell Docker support, cheap, simple). Sandbox on a separate Fly machine or
  ▎ Hetzner VPS depending on isolation needs.

  ---
  8. Exercise Content Authoring

  27. Who authors exercises — just you, or do you want community contributions?
  28. Should exercises be stored in the database (dynamic, admin-editable) or in the repository as files (git-based, PR-driven
  contributions)?
  29. Do exercises have a fixed schema (description, stub code, hidden test suite, hints) or do you anticipate more complex structures
  (multi-file exercises, dependencies between exercises)?
  30. How should the hidden test suite be managed — committed to the repo but excluded from user-visible content, or stored separately?

  ▎ Strong default: Git-based exercise files (Markdown + Haskell stubs + test files in a structured directory). This is how Rustlings
  ▎ and Exercism work; it enables community contribution via PRs and keeps content version-controlled.

  ---
  9. Hard Constraints and Solo Maintainer Reality

  31. What is your target timeline to a working MVP (not production-ready, just demonstrable)?
  32. What is your monthly infrastructure budget?
  33. Are you building this to eventually hand off or grow a contributor community, or is this indefinitely a solo project?
  34. How much operational maintenance work are you willing to do on an ongoing basis (patching, monitoring, incident response)?

  ---
  Summary: Questions That Genuinely Require Your Input

  The following have no strong default and are load-bearing for the ADR:

  ┌─────┬────────────────────────────────────────┬────────────────────────────────┐
  │  #  │                Question                │         Why it matters         │
  ├─────┼────────────────────────────────────────┼────────────────────────────────┤
  │ 1   │ Learning vs. shipping as primary goal  │ Framework choice               │
  ├─────┼────────────────────────────────────────┼────────────────────────────────┤
  │ 14  │ Ops burden tolerance for sandbox       │ Self-host vs. managed          │
  ├─────┼────────────────────────────────────────┼────────────────────────────────┤
  │ 15  │ Monthly budget ceiling                 │ Sandbox and hosting choice     │
  ├─────┼────────────────────────────────────────┼────────────────────────────────┤
  │ 17  │ Security threat model (who are users?) │ Sandbox isolation requirements │
  ├─────┼────────────────────────────────────────┼────────────────────────────────┤
  │ 23  │ Deployment comfort level               │ Hosting architecture           │
  ├─────┼────────────────────────────────────────┼────────────────────────────────┤
  │ 31  │ MVP timeline                           │ Scope decisions throughout     │
  └─────┴────────────────────────────────────────┴────────────────────────────────┘

  Once you answer those six, most other questions resolve by default.

---

### Pass 2 — Q&A

> [Paste context block]
> [Paste question list from Pass 1]
ADR Pre-Questions: Haskell Koans Web App

  ---
  1. Backend Haskell Framework

  Comparison context for a Ruby/Rails engineer:
  - Scotty — closest to Sinatra; minimal, low magic, good for learning the type system hands-on
  - Servant — type-level routing (routes are types); steep learning curve but industry-standard for APIs; mistakes caught at compile
  time
  - Yesod — closest to Rails; full-stack, lots of conventions, Template Haskell magic; can obscure what you're learning
  - IHP — opinionated Rails-alike built on Haskell; least transferable Haskell knowledge; not production-common
  - Wai/Warp raw — maximum learning, maximum pain

  Questions:

  1. Primary goal tension: Is this backend more about learning idiomatic Haskell (favor Servant — industry common, type-driven design)
  or shipping a working product quickly (favor Scotty — less ceremony)? This is the single most load-bearing question for framework
  choice.
  2. Do you want to experience type-level programming (Servant's hallmark), or would you rather that complexity be deferred until you're
   more comfortable?
  3. Are you open to Template Haskell (used heavily by Yesod and Persistent), knowing it can make compile errors harder to read as a
  beginner?

  ▎ Strong default: Servant for a learning-focused API backend. It's painful at first but teaches core Haskell idioms; the pain is
  ▎ productive. Scotty is the fallback if shipping speed matters more.

  ---
  2. Frontend Approach

  4. Do you have a strong preference for keeping the frontend in a language/ecosystem you already know (e.g., plain TypeScript/React)
  vs. using a Haskell-compiled-to-JS approach (e.g., GHCJS, Miso, Reflex)?
  5. Is this primarily a desktop-browser experience, or does mobile usability matter significantly? (Affects editor choice more than
  framework.)
  6. SPA vs. MPA tradeoff: Do you need real-time feedback (e.g., live test output streaming) or is a simple request/response loop
  (submit → wait → show results) acceptable?
  7. How much frontend complexity do you anticipate? Is this essentially: exercise list + code editor + results display, or do you
  foresee user dashboards, progress tracking, social features, etc.?

  ▎ Strong default: A thin TypeScript + Vite SPA (e.g., React or Svelte) calling the Haskell API. Keeps frontend familiar, lets you
  ▎ focus Haskell learning on the backend. Haskell-to-JS frameworks are a significant additional learning burden.

  ---
  3. Code Editor Component

  8. Is bundle size a hard constraint (e.g., targeting slow connections or low-end devices)?
  9. Do you need features beyond syntax highlighting and basic editing — e.g., inline type hints, LSP integration, vim keybindings?
  10. Is mobile editing a requirement or a nice-to-have?

  Comparison:
  - CodeMirror 6 — ~250KB, modular, mobile-friendly, good Haskell syntax support, simpler embedding
  - Monaco — ~4–5MB, VS Code engine, richer LSP support, poor mobile experience, heavier to embed
  - CodeJar / simple textarea — minimal, no syntax highlighting; fine for MVP

  ▎ Strong default: CodeMirror 6. For a koans app, users write small snippets; Monaco's power isn't needed and its bundle/mobile story
  ▎ is worse.

  ---
  4. Database and Access Layer

  11. What data needs to be persisted? At minimum: users, exercises, submission history — are there others (teams, courses,
  leaderboards)?
  12. Do you have a preference between PostgreSQL and SQLite? (SQLite is operationally much simpler for solo deployment; Postgres is
  more standard for multi-user apps.)
  13. For the Haskell ORM/query layer — are you willing to write raw SQL (via postgresql-simple or hasql) for simplicity, or do you want
   a type-safe query DSL (Esqueleto + Persistent, Opaleye, Beam)?

  ▎ Strong default: PostgreSQL + Persistent (schema migrations) + Esqueleto (type-safe queries). This is the most common Haskell web
  ▎ stack combination and has the most documentation. Raw SQL (postgresql-simple) is a reasonable simpler alternative.

  ---
  5. Code Execution Sandbox

  This is the hardest-to-reverse architectural decision.

  14. Operational burden tolerance: Are you willing to self-host and maintain a sandbox service (Judge0, Piston, or custom Docker), or
  do you strongly prefer a managed/hosted solution with no infra ownership?
  15. Cost ceiling: What is your rough monthly budget ceiling for infrastructure? (Judge0 cloud has per-execution pricing; self-hosted
  has VM cost; this is material for a solo open-source project.)
  16. Compile time tolerance: GHC compile times for small exercises are typically 5–30 seconds cold. Is that acceptable UX, or do you
  want to invest in warm cache strategies (pre-compiled base images, persistent GHC processes)?
  17. Security threat model: Who are the users? Anonymous public internet users (highest sandboxing requirement) vs.
  authenticated/trusted learners (lower risk)?
  18. Do you want the sandbox to be a separate deployable service (microservice boundary) or embedded/called as a subprocess from the
  main API server?
  19. Have you evaluated Judge0's Haskell support specifically? It supports GHC but memory limits and timeout behavior for Haskell
  specifically may need tuning — is this research you're willing to do, or a blocker?

  Comparison summary:
  - Judge0 (self-hosted): Full control, Haskell supported, Docker-based, significant ops burden, free at cost of infra
  - Judge0 (cloud): Managed, per-submission cost, least ops work
  - Piston: Simpler API, good language coverage, less battle-tested for Haskell at scale
  - Custom Docker: Maximum control, maximum work; only justified if others don't fit
  - Managed (e.g., Sphere Engine): Commercial, easiest, most expensive

  ▎ No strong default here — this genuinely requires your input on ops tolerance and budget.

  ---
  6. Authentication

  20. Do you need authentication at MVP, or is anonymous/unauthenticated use acceptable initially (e.g., stateless exercise sessions)?
  21. If auth is needed: do you want to own it (email/password with Haskell JWT libraries) or delegate it (OAuth via GitHub/Google, or a
   managed provider like Auth0/Clerk)?
  22. Is social login (GitHub OAuth specifically) important? (GitHub login is natural for a developer-facing learning tool.)

  ▎ Strong default: GitHub OAuth via a managed provider (Clerk or Auth0 free tier) or direct GitHub OAuth. Avoid building auth from
  ▎ scratch; the operational and security cost isn't worth it for a solo project.

  ---
  7. Deployment Target

  23. Where are you comfortable deploying? Options in roughly increasing ops burden: managed PaaS (Railway, Fly.io, Render) → VPS
  (Hetzner, DigitalOcean) → cloud (AWS/GCP/Azure).
  24. Does the sandbox need to run on the same host as the API, or are you open to running it on a separate machine/service?
  25. Do you need a container build pipeline (Docker), or are you comfortable with binary deployment (e.g., Nix, Cabal-built binaries)?
  26. Is high availability (zero-downtime deploys, multi-region) a requirement, or is best-effort uptime acceptable for an open-source
  learning tool?

  ▎ Strong default: Fly.io or Railway for the API (good Haskell Docker support, cheap, simple). Sandbox on a separate Fly machine or
  ▎ Hetzner VPS depending on isolation needs.

  ---
  8. Exercise Content Authoring

  27. Who authors exercises — just you, or do you want community contributions?
  28. Should exercises be stored in the database (dynamic, admin-editable) or in the repository as files (git-based, PR-driven
  contributions)?
  29. Do exercises have a fixed schema (description, stub code, hidden test suite, hints) or do you anticipate more complex structures
  (multi-file exercises, dependencies between exercises)?
  30. How should the hidden test suite be managed — committed to the repo but excluded from user-visible content, or stored separately?

  ▎ Strong default: Git-based exercise files (Markdown + Haskell stubs + test files in a structured directory). This is how Rustlings
  ▎ and Exercism work; it enables community contribution via PRs and keeps content version-controlled.

  ---
  9. Hard Constraints and Solo Maintainer Reality

  31. What is your target timeline to a working MVP (not production-ready, just demonstrable)?
  32. What is your monthly infrastructure budget?
  33. Are you building this to eventually hand off or grow a contributor community, or is this indefinitely a solo project?
  34. How much operational maintenance work are you willing to do on an ongoing basis (patching, monitoring, incident response)?

  ---
  Summary: Questions That Genuinely Require Your Input

  The following have no strong default and are load-bearing for the ADR:

  ┌─────┬────────────────────────────────────────┬────────────────────────────────┐
  │  #  │                Question                │         Why it matters         │
  ├─────┼────────────────────────────────────────┼────────────────────────────────┤
  │ 1   │ Learning vs. shipping as primary goal  │ Framework choice               │
  ├─────┼────────────────────────────────────────┼────────────────────────────────┤
  │ 14  │ Ops burden tolerance for sandbox       │ Self-host vs. managed          │
  ├─────┼────────────────────────────────────────┼────────────────────────────────┤
  │ 15  │ Monthly budget ceiling                 │ Sandbox and hosting choice     │
  ├─────┼────────────────────────────────────────┼────────────────────────────────┤
  │ 17  │ Security threat model (who are users?) │ Sandbox isolation requirements │
  ├─────┼────────────────────────────────────────┼────────────────────────────────┤
  │ 23  │ Deployment comfort level               │ Hosting architecture           │
  ├─────┼────────────────────────────────────────┼────────────────────────────────┤
  │ 31  │ MVP timeline                           │ Scope decisions throughout     │
  └─────┴────────────────────────────────────────┴────────────────────────────────┘

  Once you answer those six, most other questions resolve by default.
>
> Now work through the questions. For each question where you have a strong
> recommendation: state it, give one-sentence reasoning, and ask me to confirm or
> redirect. For questions that genuinely require my input: ask them directly.
>
> Ask one question at a time. Acknowledge each answer before moving to the next.
> When all questions are answered, say "Ready for Pass 3" and do nothing else.

*Record answers here as Pass 2 proceeds:*

---

### Pass 3 — Produce the ADR

> [Paste context block]
> [Paste complete Q&A from Pass 2]
>
> All questions are answered. Before writing the ADR: scan the answers for
> contradictions or gaps that would force a significant assumption. If you find any,
> ask those clarifying questions now. Otherwise, produce the ADR.
>
> Use this format:
>
> **ADR-001: Initial Architecture**
> - **Status**: Accepted
> - **Date**: [today]
> - **Context**: [one paragraph — what we're building, who maintains it, why these
>   decisions are load-bearing]
> - **Decisions**: one subsection per domain (backend framework, frontend, code editor,
>   database, eval service, auth, deployment, content authoring). Each subsection:
>   decision made, alternatives considered, reasoning.
> - **Consequences**: known tradeoffs and risks from the chosen stack
> - **Review triggers**: specific, observable conditions that would cause revisiting a
>   decision (e.g. "eval p95 latency exceeds 15s", "GHC OOM in sandbox under real load")
>
> Target length: ~600 words. Trim alternatives to one sentence each if needed to fit.

---

## Prompt 2: Eval Service Design

> Given this architecture: [paste ADR from Prompt 1]
>
> Design the code execution sandbox service in detail. Produce:
> 1. A specification of the API contract (endpoints, request/response shapes, error
>    codes). Include the exercise object schema — the shape used both by the API and
>    for storing curriculum content. The exercise schema must include: `id`, `title`,
>    `chapter`, `order`, `learning_objective`, `stub_code`, `hidden_test_suite`,
>    `canonical_solution`, and `hints` (an ordered array of progressive hints, each
>    a plain string — at least one, at most five per exercise).
> 2. The Docker container configuration for safe Haskell execution including resource
>    limits and network isolation
> 3. A threat model listing what attacks the sandbox should resist and how
> 4. A testing plan specifically for the sandbox
>
> Do not write code yet.

---

## Prompt 3: Data Model

> Given this architecture: [paste ADR from Prompt 1]
>
> Design the database schema for the application. Entities to consider: users,
> exercises (including a `hints` field — ordered array of progressive hint strings),
> exercise sets/chapters, submissions, progress. Produce an annotated ERD in text
> form and the migration SQL (or Haskell migration code if using [your ORM]).
> Include indexes and any denormalization decisions with reasoning.

---

## Prompt 4: Exercise Curriculum

> Design a 30-exercise curriculum for a Haskell koans site targeting developers who
> know at least one other language but are new to Haskell. For each exercise produce:
> title, learning objective, the stub code a user sees, the hidden test suite, the
> canonical solution, and 2–4 progressive hints (ordered from least to most revealing —
> the first hint should nudge without spoiling, the last may point directly at the
> solution approach). Exercises should be ordered so each one builds on the last.
> Format each exercise as a self-contained JSON object matching this schema:
> [paste the exercise schema from the API contract in Prompt 2]

---

## Prompt 5: Backend Stories

> Given this architecture [paste ADR] and data model [paste schema from Prompt 3],
> first produce a structured API contract listing every endpoint the backend will
> expose: method, path, request shape, response shape, auth requirement, and error
> codes. This contract is the primary input for Prompt 6 (frontend stories) — make
> it complete enough that frontend work can proceed without ambiguity. Format it as
> an OpenAPI 3.1 YAML document or a clearly structured markdown table (your choice).
>
> Then write a complete set of user stories for the backend application server.
> Organize them into phases:
>
> 1. **Walking skeleton** — app boots, one hardcoded exercise is served, submission
>    is evaluated, result returned; rate limiting on the submission endpoint is in
>    place from the start (per-IP and, once auth exists, per-user)
> 2. **Data layer** — real database, all CRUD for exercises and submissions
> 3. **Auth** — GitHub OAuth, session management, progress persistence
> 4. **Progress and curriculum API** — chapters, ordering, completion state
>
> For each story include: title, description, acceptance criteria, and a rough size
> estimate (S/M/L).

---

## Prompt 6: Frontend Stories

> Given this architecture [paste ADR] and the backend API contract [paste OpenAPI/
> endpoint contract from Prompt 5], write a complete set of user stories for the
> frontend. Organize into phases mirroring the backend:
>
> 1. **Walking skeleton** — one exercise renders, code editor works, submission
>    returns feedback
> 2. **Curriculum navigation** — chapter list, exercise list, progress indicators
> 3. **Auth** — login/logout, progress syncing
> 4. **Polish** — keyboard shortcuts, error states, loading states, mobile layout,
>    accessibility (keyboard navigation, screen reader support for exercise feedback)
>
> Same format: title, description, acceptance criteria, size.

---

## Prompt 7: Infrastructure and Deployment

> Given this architecture [paste ADR], write the infrastructure setup as a series
> of tasks. Cover:
>
> 1. **Local development environment** — docker-compose bringing up app, eval service,
>    and database
> 2. **CI pipeline** — what runs on PR, what runs on merge
> 3. **Staging deployment** on Fly.io (or your chosen target)
> 4. **Production deployment** with secrets management
> 5. **Monitoring** — what metrics matter, how to alert on eval service failures
>    or cost anomalies
>
> Format as tasks with acceptance criteria, not stories.

---

## Revised Execution Order

Once all stories are generated, implement them in this order:

1. Local dev environment *(extracted from Prompt 7, task 1 — do this first)*
2. Eval service *(Prompt 2)*
3. Data model / migrations *(Prompt 3)*
4. Backend walking skeleton *(Prompt 5, phase 1)*
5. Frontend walking skeleton *(Prompt 6, phase 1)*
6. Curriculum content — can proceed in parallel from here *(Prompt 4)*
7. Backend data layer and curriculum API *(Prompt 5, phases 2 and 4)*
8. Frontend curriculum navigation *(Prompt 6, phase 2)*
9. Auth — both sides *(Prompts 5 and 6, auth phases)*
10. Polish *(Prompt 6, phase 4)*
11. CI, staging, production deployment *(Prompt 7, remainder)*

---

## Periodic Review Prompt

Run this at the end of each phase, pasting in current context:

> Here is our architecture decision record: [paste ADR]
>
> Here is a summary of what we have built so far: [paste DECISIONS.md or summary]
>
> Here are the remaining stories/tasks: [paste or link]
>
> Please review for the following:
> - Are there details in what we have implemented that will necessitate changes
>   in future stories?
> - Have we changed any fundamental assumptions that need to be reflected in
>   upcoming tasks?
> - Has anything we have done made future tasks more difficult than anticipated?
> - Are there decisions we need to make now that we had not anticipated?
> - Are there any new unknowns that surfaced during this phase worth flagging?

---

## Notes

- Keep a running `DECISIONS.md` in the repo. Every time a choice is made —
  planned or forced — record it with a date and brief reasoning. This is the
  primary input to the periodic review prompt above.
- The eval service phase will almost certainly surface surprises about GHC
  compilation time and memory use. Run a dedicated review after that phase
  before proceeding.
- Exercise content (Prompt 4) can be generated before any code is written,
  as long as the exercise JSON schema from Prompt 2 exists first.
- Stories that feel too large when you get to them can be handed to Claude
  as their own prompt: "Here is this story. Break it into finer-grained tasks."
