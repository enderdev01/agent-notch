## Agent Notch 0.1.0

Live activity of your AI coding agents (Claude Code, Codex CLI, Pi / Gentle Shell) in the MacBook notch.

- Collapsed notch: mascot per agent, accent line while it works, turn timer, and a one-line peek of the last reply.
- Step by step: when an agent keeps a task list, each step shows a spinner while it runs and a check when done.
- Hover to expand: sessions grouped by agent, with today's summary and a detail card (prompt, reply, **Copy reply**).
- Allow / Deny permission requests right from the notch.
- Click a row to focus the exact Terminal.app or iTerm2 tab the agent runs in.
- "Your turn" state when the last reply asks you something.

### Install

1. Download `AgentNotch-0.1.0.dmg`, drag **Agent Notch** to Applications.
2. This build is **not notarized**: the first time, try to open it, then go to **System Settings → Privacy & Security**, scroll down to *Security*, click **Open Anyway** and confirm.
3. Connect your agents (needs `jq`: `brew install jq`):

   ```sh
   "/Applications/Agent Notch.app/Contents/Resources/scripts/install.sh"
   ```

4. Restart any running Claude Code / Codex / Pi session.

The installer only appends hook entries that run `agent-notch-hook`; `uninstall.sh` (same folder) removes exactly those.

### Known limitations

- Not notarized yet (see above).
- macOS 14+. Built for notched MacBooks; other screens get a pill at the top center.
- Codex `update_plan` step lists are untested on real Codex runs.
- Claude `TaskCreate` / `TaskUpdate` task lists are not shown (only `TodoWrite`).

### Checksum

SHA-256 of `AgentNotch-0.1.0.dmg`: `0ae1d8f770850b10bd9e6d3bd81576ef5f6496bbcbfc2d2e4a2fe3456b5bdbc8`
