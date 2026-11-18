# Screens (manual verification)

Native AppKit/SwiftUI: no canvas/WebGL and no headless screenshot. Verify by eye.

Setup: `swift build`, then `node scripts/control.mjs app start` (a notch panel appears; a ConnectAgents dialog may too). Always finish with `node scripts/control.mjs app stop`.

| Screen | Steps | What to see |
|---|---|---|
| Notch panel | `app start`; `event claude UserPromptSubmit --session t1`; hover the notch at the top of the screen | A session row `t1` with status Thinking; after `event claude Stop --session t1` it reads Done. Other agents: `event codex ...`, `event gentle ...` |
| Status menu | Click the Agent Notch icon in the menu bar | Menu with preferences, Connect Vercel and agent setup items |
| Vercel connection page | Status menu -> Connect Vercel | The connection page (needs the Worker for a real login; do not log in during checks) |
| Vercel deployment in the notch | `node scripts/control.mjs vercel building`, then `vercel ready` / `vercel failed` | The fake deployment appears in the notch and changes state |
| `node scripts/control.mjs screenshot` (no args) | Run it | Observed: `FAIL APP is not set  ->  set APP = { start, url, expect } in scripts/control.mjs (see the create-verification-skill skill)`, exit 1. APP is null on purpose: there is no web UI |

Not verified by an agent: what the panels look like (no one looked at the screen).
