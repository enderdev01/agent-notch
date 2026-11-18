# Vercel simulation

`vercel <building|ready|failed>` POSTs /debug/vercel/<status> (debug app only). The notch should show the fake deployment: check it by eye (see screens.md).

| Input | Observed output | Exit |
|---|---|---|
| `vercel building` | `ok vercel building -> HTTP 200 {"ok":true}` | 0 |
| `vercel ready` | `ok vercel ready -> HTTP 200 {"ok":true}` | 0 |
| `vercel failed` | `ok vercel failed -> HTTP 200 {"ok":true}` | 0 |
| `vercel nope` | `FAIL status must be building, ready or failed, got "nope"` | 1 |
| `vercel` | `FAIL status must be building, ready or failed, got ""` | 1 |
| `vercel building`, nothing listening | `FAIL nothing answers on 127.0.0.1:47899  ->  start the app with: node scripts/control.mjs app start` | 1 |
| `vercel ready --port 47898` (non-debug app) | `FAIL /debug/vercel is 404: the app on 47898 was not started in debug mode  ->  start the app with: node scripts/control.mjs app start` | 1 |

Known problem (not wrapped by any command): `curl localhost:47899/debug/vercel/notifications` returns no response (curl code 000) and the debug app process dies, twice reproduced. The handler calls `UNUserNotificationCenter.current()` in Sources/AgentNotch/Infrastructure/HookServer.swift, which very likely aborts for an unbundled binary (cause not confirmed). Do not call it against `.build/debug/AgentNotch`.

`POST /debug/resolve-all/allow` with no pending approvals returned `{"resolved":0}` (HTTP 200).
