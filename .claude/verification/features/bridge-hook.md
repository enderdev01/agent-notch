# Bridge script

`hook <claude|codex|gentle> [EventName]` (default UserPromptSubmit) pipes a payload with a unique session id (`control-hook-<timestamp>`) into `bridge/agent-notch-hook <agent> event` with `AGENT_NOTCH_PORT=<port>`, then polls /debug/state (up to 3s) for that id.

| Input | Observed output | Exit |
|---|---|---|
| `hook claude` | `ok bridge claude UserPromptSubmit -> session control-hook-1795027833031 is in /debug/state` | 0 |
| `hook codex Stop` | `ok bridge codex Stop -> session control-hook-1795027833244 is in /debug/state` | 0 |
| `hook gentle` | `ok bridge gentle UserPromptSubmit -> session control-hook-1795027833467 is in /debug/state` | 0 |
| `hook pi` / `hook bogus` | `FAIL usage: hook <claude\|codex\|gentle> [EventName], e.g. hook claude Stop` | 1 |
| `hook claude`, nothing listening | `FAIL nothing answers on 127.0.0.1:47899  ->  start the app with: node scripts/control.mjs app start` | 1 |

Bridge by hand (always exits 0, prints nothing):

| Input | Observed exit |
|---|---|
| valid JSON, app not running | 0 |
| `garbage` on stdin | 0 |
| unknown agent `bogus` | 0 |
| no arguments | 0 |
