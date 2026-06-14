# Go-Live Runbook (INFRA-18 / INFRA-19 / INFRA-20)

The remaining launch steps are dashboard + DNS work that must be done by hand. This is the ordered checklist, adapted to the **actual** architecture:

- **Frontend:** Netlify (`haskelling.netlify.app`), built from `frontend/`. `VITE_CLERK_PUBLISHABLE_KEY` is a Netlify build env var.
- **Backend:** Fly.io app `haskelling-app` (`haskelling-app.fly.dev`). Clerk keys are Fly secrets (`CLERK_PUBLISHABLE_KEY`, `CLERK_SECRET_KEY`).
- **API wiring:** the frontend calls relative `/api/*`; `netlify.toml` rewrites that to `https://haskelling-app.fly.dev/api/:splat`. There is no `VITE_API_BASE_URL`.

> The custom domain goes on **Netlify** (the user-facing app), not Fly — INFRA-20's `flyctl certs add` steps assume Fly serves the frontend, which it does not. The Fly backend can stay at `haskelling-app.fly.dev` behind the Netlify proxy.

Clerk *production* instances are bound to your domain, so **register the domain first** and do Clerk-production + domain together. Recommended order: **0 → 1 → 2 → 3 → 4 → 5 → 6**.

---

## 0. Prerequisites
- Admin access to: the GitHub account/org, Clerk dashboard, Netlify, Fly.io, and the domain registrar.
- `flyctl` authenticated locally (`flyctl auth login`) and Netlify CLI or dashboard access.

## 1. Register a domain
Pick and register one (e.g. `haskelling.dev`). Decide the canonical host — apex `haskelling.dev` or `www.haskelling.dev`. The rest of this doc assumes apex `haskelling.dev`.

## 2. Clerk production instance (INFRA-19) — domain-bound
1. Clerk dashboard → create a **Production** instance for the app.
2. Clerk will give you a set of **DNS records** (CNAMEs for `clerk`, `accounts`, `clkmail`, and DKIM entries). Add them at your registrar.
3. Wait for Clerk to verify the domain (DNS propagation — can take minutes to hours).
4. Once verified, copy the **production keys**: `pk_live_…` and `sk_live_…`.

## 3. Custom GitHub OAuth App (INFRA-18) — wire into the *production* instance
1. GitHub → Settings → Developer settings → OAuth Apps → **New OAuth App**
   - Application name: **Haskelling**
   - Homepage URL: `https://haskelling.dev`
   - Authorization callback URL: copy from Clerk → **Production** instance → Configure → SSO connections → GitHub → "Use custom credentials" → Authorized redirect URI.
2. Generate a client secret.
3. Clerk (Production) → GitHub connection → **Use custom credentials** → paste Client ID + Secret → Save.
4. The GitHub consent screen should now read "**Haskelling** is requesting access."

## 4. Point the domain at Netlify (INFRA-20, frontend)
1. Netlify → Site → Domain management → **Add custom domain** `haskelling.dev`.
2. At the registrar, add the DNS records Netlify specifies (Netlify DNS, or an `ALIAS`/`A` to Netlify's load balancer + `CNAME` for `www`). **Coexist with the Clerk records from step 2** — different subdomains, no conflict.
3. Let Netlify provision the Let's Encrypt certificate. Verify `https://haskelling.dev` loads.

## 5. Update config + redeploy
Repo / CLI changes (the parts touching this codebase):

- **Fly secrets** (backend) — switch to production Clerk keys:
  ```
  flyctl secrets set -a haskelling-app \
    CLERK_PUBLISHABLE_KEY=pk_live_… \
    CLERK_SECRET_KEY=sk_live_…
  ```
  (This restarts the app. The backend derives the JWKS URL + issuer from the publishable key automatically — no code change needed.)
- **Netlify env** (frontend) — set `VITE_CLERK_PUBLISHABLE_KEY=pk_live_…`, then **trigger a rebuild** (Vite inlines it at build time).
- **`index.html`** — update `og:url` to `https://haskelling.dev` (currently `https://haskelling.netlify.app`). Small repo edit + push.
- **`netlify.toml`** — no change needed; the `/api/*` → `haskelling-app.fly.dev` proxy still works under the new frontend domain. (Only change it if you also put a custom domain on the *backend*.)

## 6. Update Clerk allowed origins / redirects (INFRA-20)
1. Clerk (Production) → add `https://haskelling.dev` (and `www` if used) to allowed origins / redirect URLs.
2. Confirm the dev instance keys are rotated/retired so they can't be used against production.

---

## Verification checklist
- [ ] `https://haskelling.dev` loads over HTTPS with a valid cert
- [ ] GitHub sign-in completes from the new domain; consent screen says "Haskelling"
- [ ] No Clerk "Development mode" banner
- [ ] Submitting an exercise works end-to-end (auth → Judge0 → result)
- [ ] A signed-in reload stays signed in (token validates against production issuer)
- [ ] `/api/*` requests succeed (Netlify → Fly proxy intact)
- [ ] Old `*.netlify.app` URL still works or redirects to the custom domain
- [ ] Browser console is free of errors/warnings on the production build

## Deferred (can trail a soft launch)
- INFRA-13 secrets docs · INFRA-14 uptime monitoring · INFRA-16 error alerting · INFRA-15 Judge0 usage tracking
- BE-26 follow-up: pin the JWT `azp` (authorized party) to `https://haskelling.dev` once the production origin is fixed (issuer pinning already shipped).
