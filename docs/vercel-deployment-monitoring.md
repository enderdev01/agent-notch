# Vercel deployment monitoring plan

Show production deployments from every project available to a Vercel integration, with a compact indeterminate indicator and macOS notifications on completion or failure. No personal API token is entered by the user.

## Implementation

1. Build a Cloudflare Worker for the Vercel integration's authorization-code exchange. Keep the client secret and integration tokens server-side. Bind each installation to a desktop-initiated, short-lived, one-time state and proof-of-possession; reject replay, unsolicited callbacks, and untrusted redirects. Define revocation, expiry, storage encryption, and disconnect before exposing endpoints.
2. Register a separate Vercel integration with deployment read access. Complete the redirect URL after the Worker has an authorized deployment destination. The owner must review and accept the Vercel agreement.
3. Add a local connection flow, secure device credentials, production deployment polling with pagination and rate-limit recovery, and visible authentication/network errors. Track installations separately; never mix deployments from different teams.
4. Present active deployments in the existing compact accent line without increasing the collapsed hit area. Show project, repository, commit, author, and real state on hover; treat missing Git metadata as unavailable. Do not imply a percentage or equate a successful build with production promotion.
5. Request macOS notification permission and notify once for new terminal transitions, including failures and cancellations. The tracker starts empty on every run, so the initial snapshot and any deployment that finished while the app was closed stay silent; only transitions observed while it runs are announced, with multiple concurrent deployments handled.

## Verification

- Unit tests for authentication state, replay, invalid callbacks, missing metadata, status transitions, pagination, retries, and notification deduplication.
- Local integration tests with fake Vercel responses and no real credentials, including multiple projects and concurrent deployments.
- Manual macOS verification: login, disconnect, permissions denied, display while agents are active, browser tab hit testing, success and failure.
- End-to-end deployment only after explicit authorization for the Cloudflare destination, operation, and credential/session.

## Current status

An unreleased Worker and desktop prototype exist, with local pairing, polling, UI, notification code, and mocked tests. The Worker URL is unset and the Vercel menu is hidden. The integration form is not submitted. Security review, real installation, deployment, and end-to-end verification remain required; see `integrations/vercel-worker/README.md` before any deployment.

References: [Vercel integration authorization](https://vercel.com/docs/integrations/create-integration/vercel-api-integrations), [Vercel integration registration](https://vercel.com/docs/integrations/create-integration/submit-integration), [Cloudflare Worker secrets](https://developers.cloudflare.com/workers/configuration/secrets/).
