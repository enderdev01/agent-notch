# Hook events

`event <agent> <EventName> [--session <id>] [--cwd <path>]` POSTs `{"hook_event_name", "session_id", "cwd"}` to /event/<agent>. Defaults: session `control-test`, cwd `/tmp/control-test`. Valid agents: claude, codex, gentle. Check the result with `state`.

| Input | Observed output | Exit |
|---|---|---|
| `event claude SessionStart --session t1 --cwd /tmp/x` | `ok POST /event/claude SessionStart -> HTTP 204` | 0 |
| `event claude UserPromptSubmit --session t1` then `state` | `claude:t1  claude  Thinking  control-test` | 0 |
| `event claude Stop --session t1` then `state` | `claude:t1  claude  Done  control-test` | 0 |
| `event codex Stop --session c1` then `state` | 204; `codex:c1  codex  Done  control-test` | 0 |
| `event gentle SessionStart --session g1` then `state` | 204; `gentle:g1  gentle  Idle  control-test` | 0 |
| `event bogusagent Stop` | `ok POST /event/bogusagent Stop -> HTTP 204` (ignored, no session created) | 0 |
| `event claude ""` / `event claude` / `event` | `FAIL usage: event <agent> <EventName> [--session <id>] [--cwd <path>], e.g. event claude Stop --session t1` | 1 |
| any event, app not running | `FAIL nothing answers on 127.0.0.1:47899  ->  start the app with: node scripts/control.mjs app start` | 1 |
| `curl -X POST -d 'not json' /event/claude` (bad JSON) | HTTP 204, no session | n/a |
| `curl -X POST /event/claude` (empty body) | HTTP 204 | n/a |
| 200KB prompt in the JSON body | HTTP 204; session `mid1` shows with the full message (the `state` command clips text to 80 chars) | n/a |
| 1MB prompt (body over the 1,048,576-byte limit in HTTPParser.swift) | HTTP 400, no session; app keeps running (`/event/codex` same) | n/a |
