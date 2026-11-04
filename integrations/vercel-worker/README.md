# Vercel connection prototype

This Worker is an **unreleased prototype** and is not connected to Agent Notch. Do not deploy it or
use real credentials until the security review in `docs/vercel-security-review.md` has an
independent pass and the flow has run end to end.

Run the isolated tests with `node --test integrations/vercel-worker/index.test.mjs`. The tests use
mocked Vercel responses and no credentials.

## What only the owner can do

The code side is ready; these steps need accounts, secrets and accepting Vercel's terms.

### 1. Deploy the Worker

```bash
cd integrations/vercel-worker
wrangler secret put VERCEL_CLIENT_ID
wrangler secret put VERCEL_CLIENT_SECRET      # never a var, never a committed file
wrangler secret put VERCEL_REDIRECT_URI       # https://<worker-host>/callback
wrangler deploy
```

The Durable Object namespace, its migration and the rate limit are already declared in
`wrangler.toml`. Rotating the client secret is `wrangler secret put VERCEL_CLIENT_SECRET` again;
devices keep working because they never see it.

### 2. Register the Vercel integration

1. Create an integration with **deployment read** permissions only.
2. Set its redirect URL to `https://<worker-host>/callback`.
3. Submit the integration for review if it is going to other people's accounts.

The redirect URL must match `VERCEL_REDIRECT_URI` exactly, including the scheme and no trailing
slash, or the token exchange fails with `502`.

### 3. Build a release that can reach the Worker

The URL is injected at packaging time, so it is not committed:

```bash
VERCEL_WORKER_URL=https://<worker-host> VERCEL_INTEGRATION_SLUG=<slug> scripts/release.sh
```

Without those variables the app ships with the Vercel UI hidden and makes no Vercel requests.

### 4. Prove it end to end

- Connect from a build that has the Worker URL, complete the Vercel flow, and confirm the app says
  connected.
- Start a real production deployment from a throwaway repository; watch the badge appear when idle
  and the row in the expanded list.
- Disconnect, then confirm the Worker session is gone (`/status` returns 401) and the Vercel
  integration's access was revoked or flagged for manual removal.
- Restart the app while a deployment runs; the deployment must not notify for work that finished
  while it was closed.
