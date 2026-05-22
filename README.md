# haskelling

A Rustlings/koans-style web app for learning Haskell. Complete exercises in your browser; a hidden test suite checks your solution and tells you pass or fail.

**Status:** Under active development. Backend deployed to Fly.io staging.

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
# Edit backend/.env.local — JUDGE0_MOCK=true is already set for local dev.
# Fill in CLERK_PUBLISHABLE_KEY and CLERK_SECRET_KEY when you have a Clerk account.

# 4. Configure frontend environment
cp frontend/.env.example frontend/.env.local
# Edit frontend/.env.local — fill in VITE_CLERK_PUBLISHABLE_KEY from your Clerk dashboard.

# 5. Install backend dependencies
cd backend && cabal build all && cd ..

# 6. Install frontend dependencies
cd frontend && npm install && cd ..
```

---

## Daily workflow

Three things to start — database, backend, frontend. Each in its own terminal:

```bash
# Terminal 1 — database (if not already running)
docker compose up -d

# Terminal 2 — backend
cd backend
cabal run

# Terminal 3 — frontend
cd frontend
npm run dev
```

The backend runs on `http://localhost:8080`.
The frontend dev server runs on `http://localhost:5173` and proxies `/api/*` to the backend.

---

## Running tests and checks

```bash
# Backend tests
cd backend && cabal test

# Frontend type checking
cd frontend && npm run typecheck

# Frontend production build check
cd frontend && npm run build
```

---

## Judge0 mock mode

By default, `backend/.env.local` has `JUDGE0_MOCK=true`. This makes the submission endpoint return a hardcoded pass result without calling Judge0, so you can develop without an API key or incurring costs.

Set `JUDGE0_MOCK=false` (and provide a real `JUDGE0_API_KEY`) when you need to test real code evaluation.

---

## Project structure

```
haskelling/
├── backend/           # Haskell API server (Servant)
├── frontend/          # Svelte SPA (Vite)
├── docker-compose.yml
├── CURRICULUM.json    # All 30 exercises
├── ADR-001.md         # Architecture decisions
├── DECISIONS.md       # Running decisions log
└── STORY-ORDER.md     # Implementation phase ordering
```

---

## Contributing

Exercises are added by editing `CURRICULUM.json` and opening a pull request. See `CURRICULUM.json` for the exercise schema and existing examples.
