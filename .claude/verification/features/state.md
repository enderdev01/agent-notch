# Session state

`state` does GET /debug/state and prints `id  agent  status  project  message` per session (message clipped to 80 chars). Only exists when the app runs with AGENT_NOTCH_DEBUG=1.

| Input | Observed output | Exit |
|---|---|---|
| `state` on a fresh debug app | `ok no sessions` | 0 |
| `state` after events | `claude:t1  claude  Done  control-test` (one line per session) | 0 |
| `state --json` | `{"ok": true, "sessions": [...]}` | 0 |
| `state --port 47898` (app started without AGENT_NOTCH_DEBUG) | `FAIL /debug/state is 404: the app on 47898 was not started in debug mode  ->  start the app with: node scripts/control.mjs app start` | 1 |
| `state`, nothing listening | `FAIL nothing answers on 127.0.0.1:47899  ->  start the app with: node scripts/control.mjs app start` | 1 |
