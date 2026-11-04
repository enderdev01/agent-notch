# Vercel integration: security review

Scope: the pairing flow in `integrations/vercel-worker/index.mjs` and its client in
`Sources/AgentNotch/Infrastructure/VercelMonitor.swift`. Reviewed against the design in
`docs/vercel-deployment-monitoring.md` on 2026-11-04. This is a code review by the author of the
change, not an independent audit; treat the "residual risk" items as decisions to confirm, not as
cleared findings.

## Design summary

1. The desktop app generates a 256-bit `state` and a 256-bit `verifier`, sends only
   `SHA-256(verifier)` to the Worker, and opens Vercel's integration page with `state`.
2. Vercel redirects to the Worker with an authorization `code`; the Worker exchanges it using
   `VERCEL_CLIENT_SECRET`, which never leaves Cloudflare, and stores the resulting token in the
   Durable Object for that `state`.
3. The app proves possession of `verifier` on every later call. The Worker compares
   `SHA-256(verifier)` with the stored challenge; the token is never returned to the app.
4. The app keeps `state` + `verifier` in the Keychain
   (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`) and calls `/deployments` with the bearer.

## Findings

| # | Severity | Finding | Status |
|---|----------|---------|--------|
| F1 | Medium | **Disconnect deletes the local session but does not revoke the Vercel token.** Access remains until the user removes the integration in Vercel; the confirmation dialog says so, but a user who disconnects and forgets leaves a live token. | Open: `POST https://api.vercel.com/v2/oauth/revoke` answers `415` instead of `404` to an empty request, so the endpoint likely exists, but its contract is not in the pages reviewed. Confirm the parameters before calling it; until then keep the current copy and make it louder. |
| F2 | Medium | **An expired Vercel token was reported as a generic failure.** A `401` from Vercel became `502` to the client, so the app showed "Could not connect to Vercel" forever instead of asking to reconnect. | Fixed: Vercel `401` now maps to `401`, which the client already treats as expired and clears. |
| F3 | Low | The callback response carried no `X-Content-Type-Options`. | Fixed: `nosniff` added. |
| F4 | Low | **The callback is bound to Vercel only by the `code` and the secrecy of `state`.** Someone who learns a live `state` (it travels in the Vercel redirect URL, so it can appear in logs) could attach their own authorization to that session; they still cannot read deployments or disconnect, which require `verifier`. | Accepted: standard OAuth-with-state trade-off. Shorten the 10-minute window if that ever matters. |
| F5 | Low | Rate limiting is per `CF-Connecting-IP` and shared across all routes; clients behind one NAT share 120 requests/minute. | Accepted. The limit exists to stop brute force, not to meter legitimate use. |
| F6 | Info | The digest comparison is not constant-time. | Accepted: both values are 256-bit secrets; a timing attack needs an infeasible number of samples. |
| F7 | Info | `state` also selects the Durable Object, and any 64-hex value creates one. | Accepted: creations are rate-limited and unclaimed sessions delete themselves after 10 minutes. |
| F8 | Info | Token retention: a claimed session keeps the token until `/disconnect`; an unclaimed one is deleted by the alarm at 10 minutes. Cloudflare encrypts Durable Object storage at rest. | Documented. There is no periodic rotation; reconnecting is the rotation. |
| F9 | Info | The verifier never leaves the device, and the token never reaches it. A stolen `state` alone is not enough to read deployments. | Design property; keep it. |
| F10 | Info | The Worker returns only `uid`, `name`, `state` and git metadata for production deployments of the stored team. No project list, env vars or logs. | Design property; keep it. |
| F11 | Medium | **Personal-account installations failed.** Vercel answers the token exchange with `team_id: null` when the integration is installed on a personal account, and the Worker demanded a string, so the callback returned `502` after a successful authorization. | Fixed: a null or absent team is stored as empty and `teamId` is omitted from Vercel requests. Covered by a test. |
| F12 | Low | The Worker called `https://api.vercel.com/v7/deployments`, which is not the endpoint in Vercel's current reference. | Fixed: uses the documented `/v6/deployments`. |
| F13 | High | **The callback threw an unhandled exception on the edge.** `fetch(..., { redirect: 'error' })` is accepted by Node but rejected by the Workers runtime ("must be one of follow or manual"), so the token exchange failed with a Cloudflare `1101` page after a successful authorization. The Node test suite could not catch it. | Fixed: `redirect: 'manual'` plus an explicit 3xx check, a `try/catch` that answers `502` with a reason, and logs that state whether each binding is present. Add `wrangler dev` to the test pass so runtime-only rejections surface before deploy. |

## Residual risk before a public release

1. **Independent review.** This document is not one. Someone who did not write the flow should
   read it against the Vercel integration contract before real users connect.
2. **Real end-to-end run.** The pairing flow has now completed once against production on
   2026-11-04 (team installation: `/start` → Vercel authorization → callback → `/status` connected),
   which is how F13 was found. Still unproven: a personal-account installation, deployment
   rendering after a real build, disconnect with token revocation, and a run on a clean Mac. Repeat
   the checklist in `integrations/vercel-worker/README.md` after any change to the Worker.
3. **Secret handling in Cloudflare.** `VERCEL_CLIENT_SECRET` must be a Worker secret
   (`wrangler secret put`), never a `var` or a committed file; rotation must be documented.
4. **Privacy promise.** The app currently states it never sends anything anywhere. Shipping this
   requires the wording change drafted in `docs/vercel-privacy.md` to land with it.
