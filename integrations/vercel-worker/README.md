# Vercel connection prototype

This Worker is an **unreleased local prototype**, not a deployable production service. It is not connected to Agent Notch. Do not deploy it or use real credentials until the authentication flow, token lifecycle, abuse controls, revocation and storage retention have been security-reviewed and integration-tested.

Run the isolated tests with `node --test integrations/vercel-worker/index.test.mjs`. The tests use mocked Vercel responses and no credentials.

The intended deployment would require `VERCEL_CLIENT_ID`, `VERCEL_CLIENT_SECRET`, and `VERCEL_REDIRECT_URI` bindings and a Durable Object namespace. Use Cloudflare secret bindings for credentials, not `vars` or committed files.
