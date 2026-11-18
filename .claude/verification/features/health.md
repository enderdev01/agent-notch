# Health route

`health` does GET /health on 127.0.0.1:<port>.

| Input | Observed output | Exit |
|---|---|---|
| `health` with the debug app running | `ok /health -> HTTP 200 "ok"` | 0 |
| `health` with nothing listening | `FAIL nothing answers on 127.0.0.1:47899  ->  start the app with: node scripts/control.mjs app start` | 1 |
| `health --port 47898` (app started without debug) | `ok /health -> HTTP 200 "ok"` | 0 |
| `health --port 99999` | `FAIL --port needs a port number from 1 to 65535, got "99999"` | 1 |
| `curl localhost:47899/nope` | HTTP 404 | n/a |
| `curl localhost:47899/event/claude` (GET) | HTTP 404 | n/a |
