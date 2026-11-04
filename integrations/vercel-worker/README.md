# Vercel connection prototype

This Worker is an **unreleased prototype** and is not connected to Agent Notch. Do not deploy it or
use real credentials until the security review in `docs/vercel-security-review.md` has an
independent pass and the flow has run end to end.

Run the isolated tests with `node --test integrations/vercel-worker/index.test.mjs`. The tests use
mocked Vercel responses and no credentials.

## Where the credentials come from

There are three values, and only two are secrets:

| Value | Where it comes from |
|-------|---------------------|
| `VERCEL_CLIENT_ID` | Vercel assigns it when you create the integration (bottom of its settings page) |
| `VERCEL_CLIENT_SECRET` | Same page; rotatable with **Rotate Secret** |
| `VERCEL_REDIRECT_URI` | Not a credential: the callback URL you type in the integration form, exactly |

None of them live in a `.env` you generate. Vercel creates a client ID and secret per integration,
so the integration has to exist before the Worker can hold them. That forces the order below: the
Worker is deployed first so its URL can be used as the redirect URL.

## 1. Deploy the Worker (no secrets yet)

Run from the repository root. If `cd` fails, you are in the wrong directory: `wrangler deploy`
without a `wrangler.toml` looks for a Pages project and fails with "Could not detect a directory
containing static files", deploying nothing.

```bash
cd integrations/vercel-worker
npx wrangler login
npx wrangler whoami          # confirms the login
npx wrangler deploy
```

`wrangler deploy` prints the URL, normally
`https://agent-notch-vercel.<your-subdomain>.workers.dev`. Smoke-test it with any 64-hex state; a
`401` means the Worker and its Durable Object are up and the session is unauthenticated:

```bash
curl -s -o /dev/null -w '%{http_code}\n' \
  "https://<worker-host>/status?state=$(openssl rand -hex 32)"   # expect 401
```

Use that URL (or a custom domain) as the
callback host everywhere below. The Worker deploys fine without secrets because they are only read
at request time; `wrangler secret put` would also refuse to run before the Worker exists.

The Durable Object namespace, its SQLite migration and the rate limit are declared in
`wrangler.toml`. Workers Free supports SQLite-backed Durable Objects; if `wrangler deploy` objects
to the `[[ratelimits]]` binding, that is the one piece that may need a paid plan — remove the binding
and the check in `index.mjs` to stay on Free.

## 2. Create the Vercel integration (this is where the credentials are born)

1. Open the Vercel dashboard, pick your team, then **Integrations → Integrations Console → Create**.
2. Fill in the required profile fields (name, URL slug, developer, contact emails, logo, category,
   website, documentation, EULA and privacy URLs, overview).
3. Set **Redirect URL** to `https://<worker-host>/callback` and keep the API scopes to
   **deployments read** only.
4. Save. The **client ID and client secret** are at the bottom of the integration's settings page,
   under **Credentials**.
5. The **URL slug** you chose is `VERCEL_INTEGRATION_SLUG`; it is also the install URL
   `https://vercel.com/integrations/<slug>/new`.

You do not need to submit the integration for review to use it yourself; the review is for listing
it publicly.

## 3. Store the values as Worker secrets

```bash
npx wrangler secret put VERCEL_CLIENT_ID
npx wrangler secret put VERCEL_CLIENT_SECRET
npx wrangler secret put VERCEL_REDIRECT_URI      # https://<worker-host>/callback
```

Secrets take effect immediately; no redeploy needed. Never put the secret in `wrangler.toml`, a
committed file, or a `var`. Rotating the client secret is `wrangler secret put` again with the new
value from **Rotate Secret**: devices keep working because they never see it.

## 4. Build a release that can reach the Worker

The URL is injected at packaging time, so it is not committed:

```bash
VERCEL_WORKER_URL=https://<worker-host> VERCEL_INTEGRATION_SLUG=<slug> scripts/release.sh
```

Without those variables the app ships with the Vercel UI hidden and makes no Vercel requests.

## 5. Verify it end to end

The pairing flow completed once against production on 2026-11-04 (a team installation on
`agent-notch-vercel.onilabs-dev.workers.dev`), which is how the `redirect: 'error'` rejection in F13
was found. Repeat this list after any Worker change:

- Connect from a build that has the Worker URL, complete the Vercel flow, and confirm the app says
  connected. The browser shows a confirmation page you can close.
- Start a real production deployment from a throwaway repository; watch the badge appear when idle
  and the row in the expanded list.
- Disconnect, then confirm the Worker session is gone (`/status` returns 401) and the Worker logs
  `revoke 200` for the token revocation. If it logs another status, Vercel rejected the revocation
  for that token and the integration must be removed manually.
- Restart the app while a deployment runs; the deployment must not notify for work that finished
  while it was closed.
