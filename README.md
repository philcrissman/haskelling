# haskelling

A Rustlings/koans-style web app for learning Haskell. Complete exercises in your browser; a hidden test suite checks your solution and tells you pass or fail.

**Status:** Under active development — pre-launch.

---

## Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| GHC | 9.4.x | [ghcup](https://www.haskell.org/ghcup/) |
| cabal | 3.10+ | included with ghcup |
| Node | 20 LTS | [nvm](https://github.com/nvm-sh/nvm) or [nodejs.org](https://nodejs.org) |
| Docker | any recent | [OrbStack](https://orbstack.dev) (macOS) or [Docker Desktop](https://www.docker.com/products/docker-desktop/) |

Install GHC and cabal via ghcup:

```bash
curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | sh
ghcup install ghc 9.4
ghcup set ghc 9.4
```

---

## First-time setup

```bash
# 1. Clone
git clone git@github.com:philcrissman/haskelling.git
cd haskelling

# 2. Start the database
docker compose up -d

# 3. Configure backend environment
cp backend/.env.example backend/.env.local
# Edit backend/.env.local — see "Secret keys" below before proceeding.

# 4. Configure frontend environment
cp frontend/.env.example frontend/.env.local
# Edit frontend/.env.local — fill in VITE_CLERK_PUBLISHABLE_KEY from your Clerk dashboard.

# 5. Install backend dependencies (first run takes a few minutes)
cd backend && cabal build all && cd ..

# 6. Install frontend dependencies
cd frontend && npm install && cd ..
```

---

## Secret keys

The app uses two external services that require credentials:

**Clerk (auth)** — required. The backend will not start without both keys.
Get them from your [Clerk dashboard](https://dashboard.clerk.com) under the Development instance.
Set `CLERK_PUBLISHABLE_KEY` and `CLERK_SECRET_KEY` in `backend/.env.local`, and `VITE_CLERK_PUBLISHABLE_KEY` in `frontend/.env.local`.

**Judge0 (code evaluation)** — optional for local dev.
`JUDGE0_MOCK=true` is the default in `backend/.env.example`. With mock mode on, all submissions return a hardcoded pass result without calling Judge0, which is enough for most frontend and backend development.
Set `JUDGE0_MOCK=false` and provide a real `JUDGE0_API_KEY` (via [RapidAPI](https://rapidapi.com/judge0-official/api/judge0-ce)) only when you need to test actual code evaluation.

> **Note:** Running the app without Clerk keys is not currently supported — there is no unauthenticated dev mode. This is a known gap; a contributor-friendly dev mode that mocks auth is planned but not yet implemented.

---

## Daily workflow

Three things to start — database, backend, frontend. Each in its own terminal:

```bash
# Terminal 1 — database (if not already running)
docker compose up -d

# Terminal 2 — backend (from the repo root)
cd backend
export $(cat .env.local | xargs)
cabal run haskelling

# Terminal 3 — frontend (from the repo root)
cd frontend
npm run dev
```

- Backend: `http://localhost:8080`
- Frontend: `http://localhost:5173` (proxies `/api/*` to the backend)

---

## Checks

```bash
# Frontend type check
cd frontend && npm run typecheck

# Frontend production build
cd frontend && npm run build

# Verify all exercise solutions pass their own test suites (requires GHC on PATH)
./test-all-exercises
```

---

## Working with exercises

Exercises live under `curriculum/exercises/<chapter>/<slug>/`:

```
curriculum/
  exercises/
    basics/
      hello-world/
        exercise.json   ← title, order, learning_objective, hints
        stub.hs         ← starting code shown to the user
        tests.hs        ← hidden test suite run by Judge0
        solution.hs     ← canonical solution
  lessons/
    basics.md           ← chapter lesson (markdown)
    ...
```

**Test a single exercise locally** (no server needed):

```bash
./test-exercise basics/hello-world           # runs solution — should pass
./test-exercise basics/hello-world stub      # runs stub — expected to fail
```

**Verify all exercises before pushing:**

```bash
./test-all-exercises
```

**Add a new exercise:** create the directory, add the four files, restart the backend.

---

## Project structure

```
haskelling/
├── backend/            # Haskell API server (Servant)
├── frontend/           # Svelte SPA (Vite)
├── curriculum/
│   ├── exercises/      # One directory per exercise (see above)
│   └── lessons/        # Chapter lesson markdown files
├── docker-compose.yml
├── ADR-001.md          # Architecture decisions
├── DECISIONS.md        # Running decisions log
└── STORY-ORDER.md      # Implementation phase ordering
```
