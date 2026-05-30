# Frontend Stories

*Input: ADR-001, BACKEND-STORIES.md (API contract)*

---

## Framework Note

The ADR specifies a TypeScript SPA built with Vite + **Svelte**. Svelte was chosen over React for its simpler component model — less boilerplate, lower cognitive load alongside learning Haskell. The acceptance criteria below are framework-agnostic; implementation uses Svelte idioms.

---

## TypeScript Types

These types correspond directly to the API contract. Define them in a shared `src/types.ts` before implementing any API calls.

```typescript
// Matches the API contract from BACKEND-STORIES.md

export type SubmissionStatus =
  | "pass"
  | "fail"
  | "compile_error"
  | "timeout"
  | "runtime_error"
  | "error";

export type ProgressStatus = "not_started" | "attempted" | "passed";

export interface Exercise {
  id: string;
  title: string;
  chapter: string;
  order: number;
  learningObjective: string;
  stubCode: string;
  hints: string[];
}

export interface Chapter {
  slug: string;
  title: string;
  description: string;
  exercises: Exercise[];
}

export interface SubmissionResult {
  id: number;
  exerciseId: string;
  status: SubmissionStatus;
  output: string;
  passedCount: number;
  failedCount: number;
  evaluatedAt: string;
}

export interface ExerciseProgress {
  exerciseId: string;
  status: ProgressStatus;
  firstPassedAt: string | null;
  lastSubmittedAt: string | null;
}

export interface User {
  id: number;
  username: string;
  avatarUrl: string | null;
  email: string | null;
}
```

---

## Stories

Stories are sized for a developer familiar with TypeScript and React but new to this codebase:
- **S** — ~1–3 hours
- **M** — ~3–6 hours
- **L** — ~6–12 hours

---

## Phase 1: Walking Skeleton

**Goal:** One exercise renders with a working code editor. The user can submit code and see a pass/fail result. No auth, no routing, no database — just the core interaction loop working end to end.

---

### FE-01: Scaffold Vite + React + TypeScript project

**Size:** S

**Description:**
Initialise the frontend project using Vite with the React + TypeScript template. Configure a dev proxy so that `/api` requests are forwarded to the backend server (default `http://localhost:8080`). Verify the dev server starts and the backend health endpoint is reachable through the proxy.

**Acceptance criteria:**
- [ ] `npm run dev` starts the development server without errors
- [ ] `npm run build` produces a production bundle without errors
- [ ] `npm run typecheck` (or `tsc --noEmit`) passes with no type errors
- [ ] Requests to `/api/*` in the dev server are proxied to the backend
- [ ] A `src/types.ts` file contains the shared TypeScript types defined above
- [ ] `src/api.ts` (or `src/api/`) contains a typed fetch wrapper used by all API calls — no raw `fetch` calls in components

---

### FE-02: CodeMirror 6 editor component

**Size:** M

**Description:**
Build a reusable `<CodeEditor>` component wrapping CodeMirror 6 with Haskell syntax highlighting. The component is a controlled input: it accepts a `value` prop and fires an `onChange` callback. It must not lose the user's edits on re-render.

**Acceptance criteria:**
- [ ] The editor displays Haskell syntax highlighting
- [ ] The component is controlled: `value` sets the content; `onChange` fires on every edit
- [ ] Tab key inserts spaces (not a tab character), configurable via a `tabSize` prop (default 2)
- [ ] The editor is accessible via keyboard (focusable, readable by screen readers as a text input region)
- [ ] The component accepts a `readOnly` prop that disables editing without hiding the content
- [ ] The editor does not flash or reset to the initial value on parent re-renders

---

### FE-03: Hardcoded exercise page

**Size:** S

**Description:**
Build an `ExercisePage` component that displays a hardcoded exercise (the `hello-world` exercise). Shows the exercise title, learning objective, and the stub code loaded into the `<CodeEditor>`. No API calls yet.

**Acceptance criteria:**
- [ ] Exercise title and learning objective are displayed above the editor
- [ ] The editor is pre-populated with the stub code
- [ ] The user can edit the code in the editor
- [ ] A "Submit" button is present but may be non-functional in this story
- [ ] Layout is legible at a minimum viewport width of 768px

---

### FE-04: Submit code and display result

**Size:** M

**Description:**
Wire the Submit button to `POST /api/submissions` using the hardcoded exercise ID. Display the result below the editor: a pass/fail indicator, test counts, and the compiler/test output. Show a loading state while the submission is in flight (Judge0 may take 5–30 seconds).

**Acceptance criteria:**
- [ ] Clicking Submit sends `{ exerciseId, code }` to `POST /api/submissions`
- [ ] While awaiting the result, the Submit button is disabled and shows a loading indicator
- [ ] A `pass` result displays a visible success state (e.g. green badge) with passed/failed counts
- [ ] A `fail` result displays a visible failure state with passed/failed counts and the output
- [ ] A `compile_error` result displays the compiler output in a readable monospace block
- [ ] A `timeout` or `runtime_error` result displays a clear human-readable message
- [ ] Submitting while a request is in flight is prevented (button stays disabled)
- [ ] The output panel is scrollable if the output is long

---

## Phase 2: Curriculum Navigation

**Goal:** The full exercise list loads from the API. The user can navigate between exercises by URL. Progress indicators show which exercises have been completed.

---

### FE-05: Routing setup

**Size:** S

**Description:**
Add client-side routing. The exercise page lives at `/exercises/:id`. The root path (`/`) redirects to the first exercise in the first chapter. Add a 404 page for unknown routes.

**Acceptance criteria:**
- [ ] Navigating to `/exercises/hello-world` renders the hello-world exercise
- [ ] Navigating to `/` redirects to the first exercise
- [ ] Navigating to an unknown path renders a 404 page
- [ ] Browser back/forward navigation works correctly
- [ ] The URL updates when the user navigates between exercises

---

### FE-06: Exercise list from API

**Size:** M

**Description:**
Replace the hardcoded exercise with a `GET /api/exercises` call. Display a sidebar (or top nav on mobile) listing chapters and their exercises. The current exercise is highlighted in the nav.

**Acceptance criteria:**
- [ ] The sidebar fetches and renders all chapters and exercises from the API
- [ ] Chapters are collapsible (expanded by default)
- [ ] The current exercise is visually highlighted in the sidebar
- [ ] Clicking an exercise in the sidebar navigates to `/exercises/:id`
- [ ] If the API call fails, a non-crashing error message is shown in the sidebar
- [ ] The sidebar is not re-fetched on every exercise navigation (data is cached or stored at the app level)

---

### FE-07: Exercise page from API

**Size:** S

**Description:**
Replace the hardcoded exercise data with a `GET /api/exercises/:id` call. Populate the editor with `stubCode` from the API response. When navigating to a new exercise, the editor resets to the new exercise's stub code.

**Acceptance criteria:**
- [ ] The editor is populated with `stubCode` when an exercise loads
- [ ] Navigating to a different exercise resets the editor to the new stub code
- [ ] The user's edits are not lost when switching away and back to the same exercise (per-exercise editor state persisted in `localStorage`)
- [ ] A 404 response from the API renders the 404 page
- [ ] The exercise title and learning objective update when navigating

---

### FE-08: Progress indicators

**Size:** S

**Description:**
Fetch `GET /api/progress` and display a status badge on each exercise in the sidebar. Show distinct states for `not_started`, `attempted`, and `passed`.

**Acceptance criteria:**
- [ ] Each exercise in the sidebar has a badge or icon indicating its progress status
- [ ] `not_started`: no badge or a neutral indicator
- [ ] `attempted`: a visible but non-success indicator (e.g. yellow dot)
- [ ] `passed`: a visible success indicator (e.g. green checkmark)
- [ ] Progress updates in the sidebar after a successful submission without a full page reload
- [ ] If the progress API call fails, the sidebar still renders (without badges)

---

### FE-09: Hint reveal

**Size:** S

**Description:**
Display hints progressively below the editor. A "Show hint" button reveals the first hint. Each subsequent click reveals the next hint. Once all hints are shown, the button is hidden.

**Acceptance criteria:**
- [ ] Hints are hidden by default
- [ ] A "Show hint" button appears when hints are available and not all hints are shown
- [ ] Each click reveals the next hint without hiding previous ones
- [ ] Hints are displayed in order (index 0 first)
- [ ] The hint section is visually distinct from the output panel
- [ ] Hint state resets when navigating to a new exercise

---

### FE-10: Submission history panel

**Size:** S

**Description:**
Add a collapsible panel below the result display showing the last N submissions for the current exercise, fetched from `GET /api/submissions?exercise_id=:id`.

**Acceptance criteria:**
- [ ] The panel is collapsed by default and can be expanded
- [ ] Shows the last 5 submissions at most, with status and timestamp
- [ ] The most recent submission is at the top
- [ ] Shows a "No previous submissions" message when the list is empty
- [ ] The panel refreshes after a new submission is made
- [ ] Does not show the submitted code (per the API contract)

---

## Phase 3: Auth

**Goal:** Users must sign in with GitHub via Clerk before accessing any exercise. The auth token is attached to all API requests. Sign-out works.

---

### FE-11: Clerk provider setup

**Size:** M

**Description:**
Install and configure the Clerk vanilla JS SDK (`@clerk/clerk-js`). Load and initialise Clerk with the publishable key from `VITE_CLERK_PUBLISHABLE_KEY`. Verify Clerk initialises without errors.

**Acceptance criteria:**
- [ ] `VITE_CLERK_PUBLISHABLE_KEY` is read from `.env.local` (not committed to git)
- [ ] The app boots without errors with Clerk configured
- [ ] `clerk.session` and `redirectToSignIn()` are available for auth checks
- [ ] A `.env.example` file documents all required environment variables

---

### FE-12: Auth-gated routing

**Size:** S

**Description:**
All routes except the sign-in page require authentication. Unauthenticated users are redirected to the sign-in page. After signing in, the user is redirected to their original destination (or the first exercise if no destination is stored).

**Acceptance criteria:**
- [ ] Visiting `/exercises/:id` while signed out redirects to the sign-in page
- [ ] After sign-in, the user lands on the originally requested exercise (or the first exercise)
- [ ] Signed-in users visiting the sign-in page are redirected to the first exercise
- [ ] The redirect destination survives a full page reload (stored in the URL or session storage)

---

### FE-13: Sign-in page

**Size:** S

**Description:**
Build a sign-in page at `/sign-in` using Clerk's pre-built `<SignIn>` component configured for GitHub OAuth only.

**Acceptance criteria:**
- [ ] The sign-in page renders Clerk's sign-in UI
- [ ] Signing in with GitHub completes successfully and redirects to the app
- [ ] The page is centred and readable at 375px viewport width (mobile)
- [ ] The page title and any surrounding copy clearly describe the product

---

### FE-14: Attach auth token to API requests

**Size:** S

**Description:**
Update the API client (`src/api.ts`) to attach the Clerk session JWT as a Bearer token on every request. Use Clerk's `getToken()` method. The API client must not be called before auth is confirmed (no race condition on initial load).

**Acceptance criteria:**
- [ ] Every request to `/api/*` includes `Authorization: Bearer <token>`
- [ ] The token is refreshed if it has expired before the request is made (Clerk handles this)
- [ ] A 401 response from the API redirects the user to the sign-in page
- [ ] No requests to `/api/*` are made before the auth state is known

---

### FE-15: User avatar and sign-out

**Size:** S

**Description:**
Display the signed-in user's avatar and username in the app header. Provide a sign-out button that clears the Clerk session and redirects to the sign-in page.

**Acceptance criteria:**
- [ ] The header shows the user's GitHub avatar and username when signed in
- [ ] A sign-out button (or menu item) is accessible from the header
- [ ] Signing out clears the session and redirects to `/sign-in`
- [ ] After sign-out, all API calls are blocked until the user signs in again
- [ ] The avatar falls back to a placeholder if `avatarUrl` is null

---

## Phase 4: Polish

**Goal:** The app is pleasant to use, resilient to errors, navigable by keyboard, accessible to screen reader users, and usable on a phone.

---

### FE-16: Loading states

**Size:** S

**Description:**
Add loading states to all data-fetching interactions: initial exercise list load, individual exercise load, and submission in flight.

**Acceptance criteria:**
- [ ] The sidebar shows a skeleton or spinner while the exercise list loads
- [ ] The exercise page shows a placeholder while the exercise data loads
- [ ] The Submit button shows a clear in-progress state while awaiting a submission result
- [ ] Loading states never persist indefinitely — they resolve to either data or an error state
- [ ] The page does not show a blank white screen at any point during a normal flow

---

### FE-17: Error states

**Size:** M

**Description:**
Handle all error conditions from the API gracefully. Each error state should be informative and offer a recovery action where possible.

**Acceptance criteria:**
- [ ] Network failure on exercise list load shows an error message with a Retry button
- [ ] Network failure on submission shows an error message; the editor and button remain usable
- [ ] A 429 response shows a human-readable rate-limit message including the retry delay (from `Retry-After` header)
- [ ] A 502 or 504 response shows a message indicating the evaluation service is unavailable
- [ ] A 401 response from any endpoint redirects to sign-in without a crash
- [ ] Error messages do not expose raw API error bodies or stack traces to the user

---

### FE-18: Keyboard shortcuts

**Size:** S

**Description:**
Add keyboard shortcuts for the primary actions. Show a visible shortcut hint in the UI.

**Acceptance criteria:**
- [ ] `Ctrl+Enter` / `Cmd+Enter` submits the current exercise (when the editor is focused or the page is focused)
- [ ] The Submit button displays the keyboard shortcut as a hint (e.g. `⌘↵`)
- [ ] The shortcut does not fire while a submission is in flight
- [ ] The shortcut does not conflict with CodeMirror's default bindings

---

### FE-19: Mobile layout

**Size:** M

**Description:**
Make the app usable on a phone. At narrow viewports the sidebar collapses into a drawer or bottom sheet. The editor is full-width. The result panel appears below the editor.

**Acceptance criteria:**
- [ ] At 375px viewport width the layout is fully usable with no horizontal scrolling
- [ ] The exercise navigation is accessible via a hamburger/menu button on mobile
- [ ] The code editor is touch-friendly (no accidental zoom on focus)
- [ ] The Submit button is large enough to tap comfortably (minimum 44×44px touch target)
- [ ] The result/output panel is readable at narrow widths (wraps correctly, no overflow)

---

### FE-23: Restore last submission code on exercise load

**Size:** S

**Description:**
When a user returns to an exercise and no `localStorage` entry exists (new device, different browser, cleared data), fetch their most recent submission from `GET /api/exercises/:id/submissions` and seed the editor with that code. Falls back to stub code if no prior submission exists.

**Depends on:** BE-22 (add `code` field to submission history response)

**Acceptance criteria:**
- [ ] If `localStorage` has saved code for the exercise, it takes precedence (no change to current behaviour)
- [ ] If no `localStorage` entry exists, `GET /api/exercises/:id/submissions` is called for the current exercise
- [ ] If a prior submission exists, the editor is pre-populated with the most recent submission's code
- [ ] If no prior submission exists, the editor falls back to the stub code
- [ ] The fetch does not block rendering — the editor shows stub/localStorage immediately and updates on response
- [ ] On successful restore, the code is written to `localStorage` so subsequent loads are instant
- [ ] Falls back gracefully to stub code if the user is unauthenticated

---

### FE-20: Accessibility

**Size:** M

**Description:**
Ensure the app is navigable by keyboard alone and that submission results are announced to screen readers.

**Acceptance criteria:**
- [ ] All interactive elements (links, buttons, editor) are reachable and operable via Tab and Enter/Space
- [ ] Focus order is logical: sidebar → exercise content → editor → Submit button → result
- [ ] Submission results are announced by screen readers when they appear (use an ARIA live region)
- [ ] Pass/fail status is not conveyed by colour alone — an icon or text label accompanies every colour indicator
- [ ] The CodeMirror editor has an accessible label (e.g. `aria-label="Haskell code editor"`)
- [ ] The page has a logical heading hierarchy (`h1` for exercise title, `h2` for sections)
- [ ] The app passes automated accessibility checks (e.g. axe-core) with no critical violations

---

### FE-26: Add analytics page tracking

**Size:** S

**Description:**
Wire up the analytics tracker (from `~/Projects/philcrissman-analytics`) so every exercise navigation and initial page load is recorded. All navigation funnels through the `navigate()` function in `App.svelte` and the hash-read in `onMount`, so there are only two call sites.

**Depends on:** INFRA-20 (custom domain live and configured in the tracker)

**Acceptance criteria:**
- [ ] The analytics tracker script is loaded in `index.html`
- [ ] A page-view event fires on initial load (covering direct links and refreshes via the `onMount` hash read)
- [ ] A page-view event fires on every call to `navigate()` in `App.svelte`
- [ ] No tracking fires for unauthenticated or bot traffic (if the tracker supports it)
- [ ] The tracker domain/site ID is read from an environment variable, not hard-coded

---

## Execution Order

Implement stories in this sequence:

1. FE-01 → FE-02 → FE-03 → FE-04 *(walking skeleton — core loop working)*
2. FE-05 → FE-06 → FE-07 → FE-08 → FE-09 → FE-10 *(curriculum navigation complete)*
3. FE-11 → FE-12 → FE-13 → FE-14 → FE-15 *(auth complete)*
4. FE-16 → FE-17 → FE-18 → FE-19 → FE-20 → FE-23 *(polish complete)*

FE-23 depends on BE-22 (add `code` field to submission history response).

FE-08 (progress indicators) depends on the backend Phase 3 auth being complete — implement the component in Phase 2 but the progress data will be placeholder until auth is wired up in Phase 3.

---

### FE-27: Frontend test suite (issue #73)

**Size:** L

**Description:**
Add Vitest + @testing-library/svelte component tests and mocked API tests. Optionally add Playwright smoke tests. See issue #73 for full scope.

**Deferred — post-launch.**

---

### FE-36: Admin dashboard — users and progress view

**Size:** M

**Description:**
A view, reachable only by admins, listing all registered users and how far each has progressed (backed by BE-30's `GET /api/admin/users`). Read-only for v1 — no mutating actions (resetting progress, deleting users) in this story; capture those separately if wanted later.

Gate the route and nav entry on the `role` field from `GET /api/me` (BE-28). UI hiding is convenience only — the backend `403` from `requireAdmin` is the real boundary, and the view must handle that 403 gracefully (e.g. redirect or "not authorized") rather than assuming the nav was hidden.

**Depends on:** BE-28 (role in `/api/me`), BE-30 (admin users API)

**Acceptance criteria:**
- [ ] An "Admin" nav entry appears only when `me.role` is admin
- [ ] The admin route renders a table of users with their progress summary from `GET /api/admin/users`
- [ ] A non-admin hitting the admin URL directly gets a graceful "not authorized" state (handles the backend 403), not a broken page
- [ ] Loading and error states match the patterns established in FE-16/FE-17

**Deferred — post-launch.**
