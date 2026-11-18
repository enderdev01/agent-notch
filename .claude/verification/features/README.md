# Feature map

Run from the repo root. App-talking commands use debug port 47899 (never the real app's 47823). Start the app first with `app start`, and always `app stop` at the end.

| Feature | What it does | How to exercise it | Triggers | Details |
|---|---|---|---|---|
| Debug app lifecycle | Starts/stops the debug build with AGENT_NOTCH_DEBUG=1 on port 47899 | `node scripts/control.mjs app start` then `node scripts/control.mjs app stop` | Sources/AgentNotch/App/main.swift, Sources/AgentNotch/App/AppDelegate.swift, Package.swift | [app-lifecycle.md](app-lifecycle.md) |
| Health route | GET /health answers "ok" while the hook server is up | `node scripts/control.mjs health` | Sources/AgentNotch/Infrastructure/HookServer.swift, Sources/AgentNotch/Infrastructure/HTTPConnection.swift, Sources/AgentNotch/Infrastructure/HTTPParser.swift | [health.md](health.md) |
| Hook events | POST /event/{claude,codex,gentle} turns hook JSON into session updates | `node scripts/control.mjs event claude Stop --session t1` | Sources/AgentNotch/Infrastructure/HookServer.swift, Sources/AgentNotch/Infrastructure/HookPayloadDecoder.swift, Sources/AgentNotch/Domain/HookEvent.swift, Sources/AgentNotch/Application/SessionStore.swift | [events.md](events.md) |
| Session state | GET /debug/state lists the sessions the store holds (debug only) | `node scripts/control.mjs state` | Sources/AgentNotch/Application/SessionStore.swift, Sources/AgentNotch/Domain/AgentSession.swift, Sources/AgentNotch/Infrastructure/HookServer.swift | [state.md](state.md) |
| Vercel simulation | POST /debug/vercel/{building,ready,failed} fakes a deployment status (debug only) | `node scripts/control.mjs vercel building` | Sources/AgentNotch/Infrastructure/VercelMonitor.swift, Sources/AgentNotch/Domain/Deployment.swift, Sources/AgentNotch/Infrastructure/HookServer.swift | [vercel.md](vercel.md) |
| Bridge script | bridge/agent-notch-hook forwards agent hook JSON to the app and always exits 0 | `node scripts/control.mjs hook claude Stop` | bridge/agent-notch-hook | [bridge-hook.md](bridge-hook.md) |
| Install / uninstall | scripts/install.sh and uninstall.sh add/remove hooks under $HOME (run sandboxed) | `node scripts/control.mjs install --dry-run` | scripts/install.sh, scripts/uninstall.sh, scripts/lib.sh | [install.md](install.md) |
| Localized strings | Checks every L("...") key exists in the en/es/de locales | `node scripts/control.mjs strings` | scripts/check-strings.py, packaging/locales/**, Sources/AgentNotch/Domain/Localized.swift | [strings.md](strings.md) |
| Vercel Worker | Cloudflare Worker that proxies the Vercel OAuth and deployments API | `node scripts/control.mjs worker-test` | integrations/vercel-worker/** | [worker.md](worker.md) |
| Notch panel (screen) | Notch overlay with session list, mascot and steps | `manual verification` | Sources/AgentNotch/UI/**, Sources/AgentNotch/Infrastructure/NotchPanel.swift, Sources/AgentNotch/Infrastructure/NotchGeometry.swift | [screens.md](screens.md) |
| Status menu (screen) | Menu bar icon with preferences, Connect Vercel and agent setup | `manual verification` | Sources/AgentNotch/App/StatusMenu.swift, Sources/AgentNotch/App/Preferences.swift, Sources/AgentNotch/App/ConnectAgents.swift | [screens.md](screens.md) |
| Vercel connection page (screen) | Status menu -> Connect Vercel | `manual verification` | Sources/AgentNotch/Infrastructure/VercelMonitor.swift, Sources/AgentNotch/App/StatusMenu.swift | [screens.md](screens.md) |
| Screenshot command | Headless screenshot; not applicable to this native app | `node scripts/control.mjs screenshot` | scripts/control.mjs | [screens.md](screens.md) |
| Approval flow | POST /approve/{agent} blocks until Allow/Deny is clicked in the notch (up to 115s) | `manual verification` | Sources/AgentNotch/Infrastructure/HookServer.swift, Sources/AgentNotch/Domain/ApprovalRequest.swift, Sources/AgentNotch/UI/ApprovalCard.swift, bridge/agent-notch-hook | [approval.md](approval.md) |
