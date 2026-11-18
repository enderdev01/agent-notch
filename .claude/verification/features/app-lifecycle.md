# Debug app lifecycle

`app start` spawns `.build/debug/AgentNotch` detached with `AGENT_NOTCH_DEBUG=1 AGENT_NOTCH_PORT=<port>` (default 47899), writes the pid to `$TMPDIR/agent-notch-control.pid`, and waits up to 15s for /health. Side effect: a notch panel appears (and possibly the ConnectAgents dialog). Needs `swift build` first.

| Input | Observed output | Exit |
|---|---|---|
| `app start` | `ok app started pid 14088 on port 47899` | 0 |
| `app start --json` | `{"ok": true, "pid": 17081, "port": 47899}` | 0 |
| `app start` while running | `FAIL port 47899 already answers: another app holds it  ->  run: node scripts/control.mjs app stop, or pass --port <n>` | 1 |
| `app stop --dry-run` | `dry-run: would kill pid 17081 (.../.build/debug/AgentNotch) and remove <tmp>/agent-notch-control.pid` | 0 |
| `app stop` | `ok killed pid 17081` | 0 |
| `app stop` with no pid file | `FAIL no pid file at <tmp>/agent-notch-control.pid: nothing started by this tool  ->  node scripts/control.mjs app start` | 1 |
| `app bogus` | `FAIL usage: app <start\|stop> [--port <n>] [--dry-run]` | 1 |
| `health --port 99999` (any command) | `FAIL --port needs a port number from 1 to 65535, got "99999"` | 1 |
| `app stop` when the pid died (observed after a crash) | `FAIL pid 14088 is not AgentNotch (not running): removed the stale pid file, killed nothing` | 1 |

Not observed: missing binary message ("run swift build first") and the 15s timeout path.
