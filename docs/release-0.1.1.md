## Agent Notch 0.1.1

Connecting your agents no longer needs a terminal.

### What's new

- **Connect agents…** in the menu bar item: adds the hooks to Claude Code, Codex and Pi and shows exactly what changed (`installed`, `updated`, `unchanged`). Safe to run again.
- **First-launch offer:** if the hooks are not installed yet, the app asks once whether to connect your agents.
- **The hook no longer needs `jq` while agents run.** `jq` is only used to connect them: macOS 15 and later include it; on macOS 14 run `brew install jq` once.
- README redesigned, with Spanish and German translations.

### Upgrading from 0.1.0

Replace the app, open it, and choose **Connect agents…** once. It refreshes the hook script copied to `~/.local/bin`; your existing hook entries are kept.

### Install

1. Download `AgentNotch-0.1.1.dmg`, drag **Agent Notch** to Applications.
2. This build is **not notarized**: the first time, try to open it, then go to **System Settings → Privacy & Security**, scroll down to *Security*, click **Open Anyway** and confirm.
3. Click **Connect** when the app offers it (or choose **Connect agents…** from the menu bar item).
4. Restart any running Claude Code / Codex / Pi session. Codex may ask you to trust the new hooks.

The installer only appends hook entries that run `agent-notch-hook`; `uninstall.sh` (inside the app, in `Contents/Resources/scripts`) removes exactly those.

### Known limitations

- Not notarized yet (see above).
- macOS 14+. Built for notched MacBooks; other screens get a pill at the top center.
- The "jq is required" message (macOS 14 without `jq`) is untested.
- Codex `update_plan` step lists are untested on real Codex runs.
- Claude `TaskCreate` / `TaskUpdate` task lists are not shown (only `TodoWrite`).

### Checksum

SHA-256 of `AgentNotch-0.1.1.dmg`: `dcd31464d1b444a634f69978d70a29735a4579e3f2b8de1cac475b737981e5f7`
