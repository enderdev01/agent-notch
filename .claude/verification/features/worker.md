# Vercel Worker

`worker-test` runs `node --test integrations/vercel-worker/index.test.mjs`.

| Input | Observed output | Exit |
|---|---|---|
| `worker-test` | `ok node --test ...`; 13 tests, 13 pass, 0 fail (e.g. "deployments proxy scopes Vercel requests and never returns its token", "router rejects invalid state and rate-limited clients") | 0 |

The test prints some `callback {...}`, `token exchange 200`, `revoke 200` log lines; they are normal.
