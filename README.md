# Agent Notch

A macOS notch app that shows live activity of AI coding agents (Claude Code, Codex CLI, gentle-shell = Pi + gentle-pi) and lets you Allow / Deny permission requests right from the notch. Each agent gets a pixel-art mascot, an accent line tinted by the working agent, a step-by-step task list and a short "done" glow.

**Requirements:** macOS 14+ and `jq` for the hook installer (`brew install jq`). Built for notched MacBooks; on screens without a notch it draws a 200 pt pill at the top center instead.

## Architecture

```
 Claude Code ──hooks──┐                      ┌── SessionStore (@MainActor)
 Codex CLI  ──hooks──┤  agent-notch-hook     │      sessions, approval queue
                      ├─ (bash, curl+jq) ──►  HookServer (127.0.0.1:47823) ──► NotchRootView
 Pi extension ───────┘   POST /event/{agent}   │                              (collapsed / hover / approval)
   (fetch)               POST /approve/{agent} ◄┘  holds connection until you decide
```

Folders: `Domain/` (agent, session, approval, decision) - `Application/` (SessionStore) - `Infrastructure/` (HTTP server, notch panel) - `UI/` (SwiftUI notch) - `App/` (entry point, menu bar item).

## Install

**From the DMG:** drag *Agent Notch* to Applications and open it, then connect your agents (the installer ships inside the app):

```sh
"/Applications/Agent Notch.app/Contents/Resources/scripts/install.sh" --dry-run   # preview the exact config changes
"/Applications/Agent Notch.app/Contents/Resources/scripts/install.sh"             # copies the bridge, merges hooks, copies the Pi extension
```

Restart any running Claude Code / Codex / Pi session afterwards. If the build is not notarized (see *Releasing*), macOS blocks the first launch: right-click the app, choose *Open*, and confirm.

**From source:**

```sh
make app                          # builds build/Agent Notch.app (ad-hoc signed)
open "build/Agent Notch.app"      # or: make run
scripts/install.sh --dry-run
make install
```

`uninstall.sh` (next to `install.sh`) removes only entries whose command contains `agent-notch-hook`, plus the copied files. Config files are backed up once as `*.bak-agent-notch`.

## Releasing

```sh
scripts/release.sh                # build/AgentNotch-<version>.dmg, ad-hoc signed (not notarized)

DEVELOPER_ID="Developer ID Application: Your Name (TEAMID)" \
NOTARY_PROFILE=agent-notch \
scripts/release.sh                # signs with the hardened runtime, notarizes and staples the DMG
```

To publish on GitHub, create a release with the DMG attached and `docs/release-0.1.0.md` as its notes (`gh release create v0.1.0 build/AgentNotch-0.1.0.dmg --title "Agent Notch 0.1.0" --notes-file docs/release-0.1.0.md`).

Notarization needs a paid Apple Developer Program account, a *Developer ID Application* certificate in your keychain, and a profile stored once with `xcrun notarytool store-credentials agent-notch --apple-id <id> --team-id <TEAMID> --password <app-specific-password>`. Bump `CFBundleShortVersionString` in `packaging/Info.plist` for each release. Regenerate the app icon with `scripts/make-icon.py`.

## How each agent integrates

- **Claude Code**: hooks in `~/.claude/settings.json` (SessionStart, UserPromptSubmit, PreToolUse, PostToolUse, Notification, Stop, StopFailure -> `event`; PermissionRequest -> `approve`).
- **Codex CLI**: hooks in `~/.codex/hooks.json` (same minus Notification and StopFailure, plus Interrupt). Codex may require you to trust new hooks; review them when prompted.
- **gentle-shell and Gentle Dot (Pi)**: `~/.pi/agent/extensions/agent-notch.ts` reports lifecycle events and gates risky `bash` commands (rm -rf, sudo, force push, chmod/chown 777, curl|sh, dd, mkfs; edit the list at the top of the file). Each Pi-based app with an isolated home (`~/.gentle-shell/agent`, `~/.gentle-dot/agent`) gets its own copy, installed only if that home exists.

Decisions are returned in the agent's native format. Allow/Deny answer the prompt; "Answer in terminal" (or timeout after 110 s) hands control back to the agent's own prompt.

## Mascots

Each agent has a pixel-art mascot (Claude, Codex, gentle) that lives in the notch ears and reacts to state: working (per-agent rhythm), waiting for approval (shake + badge), done (hops + sparkles). Sprites live in `Sources/AgentNotch/Resources/Mascots/` and are copied into the app bundle by `make app`. Regenerate raw art with `scripts/gen-mascots.sh` (APIMart; key read from the Keychain item `com.onilabs.oni.apimart`).

## Menu bar item

Pause approvals (everything falls back to the terminal), play a sound when an agent finishes, launch at login (only works from the bundled `.app`), quit.

## Troubleshooting

- **App not running / port busy**: the bridge prints nothing and exits 0, so agents fall back to their normal terminal prompt. Check `curl http://127.0.0.1:47823/health` (should print `ok`). Override the port with `AGENT_NOTCH_PORT` (app and agents must agree).
- **Nothing shows up**: restart the agent session after install; confirm `~/.local/bin/agent-notch-hook` exists and `jq` is installed.
- **Keyboard hints**: Return / Cmd-Delete work once the panel has focus (after you click it); the panel never steals focus on its own, so global shortcuts are intentionally not registered.
- **Debug**: launch with `AGENT_NOTCH_DEBUG=1` to enable `GET /debug/state` and `POST /debug/resolve-all/{allow|deny}`.

## Info and preferences

- **Peek**: for ~5 s after a turn ends, one readable line of the agent's last reply shows under the notch (markdown removed; amber when the reply ends asking you for something). Failures show a plain-language error in red (e.g. "Rate limit reached").
- **Steps**: when an agent keeps a task list (Claude `TodoWrite`, Codex `update_plan`), the collapsed notch shows one icon per step (check, spinner, empty ring) with the active step and `n/m`; the expanded row lists every step.
- **Timer**: `m:ss` in the right ear while an agent works, and in each session row.
- **Hover the notch** to expand the session list. Hover a row to see the full prompt and reply (**Copy reply** button); click a row to focus the terminal the agent runs in (Terminal.app and iTerm2 select the exact tab; other terminals come to front; sessions without terminal info open the folder in Finder). The first click asks for the macOS Automation permission.
- **Today's summary** per agent in the list header (`Today · ✓ 3 · ✕ 1 · 1h 20m`): turns finished, failed, and time worked (kept in UserDefaults, resets each day).
- **Your turn**: when an agent's last reply asks you something, its row says "Your turn" (amber) and its mascot gets an amber dot until the next activity or for 5 minutes by default (menu: Off / 2 / 5 / 15 / 30 minutes).
- **Preferences** live in the menu bar menu: finish and approval sounds, sound volume, whether the idle mascot shows, and how long until it falls asleep. They apply immediately.
- `AGENT_NOTCH_REDUCE_MOTION=1` forces the Reduce Motion path for testing.

## License

MIT, see [LICENSE](LICENSE).

Agent Notch is an independent project. It is not affiliated with or endorsed by Anthropic, OpenAI, or the Gentleman Programming / Gentle AI projects; "Claude Code", "Codex" and "gentle" are only used to name the tools it integrates with. The mascots are AI-generated pixel art (see `scripts/gen-mascots.sh`).
