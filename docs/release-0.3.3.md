## Agent Notch 0.3.3

Claude desktop plan updates now advance the task list instead of leaving it stuck.

### What's fixed

- **Incremental `update_plan` calls advance the existing list.** The Claude desktop app sends `items` only on its first call; later calls carry `advance` (finish the running step and start the next pending one), `done` and `start` (1-based step numbers), or `wrap_up` (finish every step). Those now move the steps already on screen instead of leaving a stale checklist or showing the raw JSON in the row.
- Incremental changes apply on `PreToolUse` only, so `PostToolUse` does not advance the same step a second time.
- The list keeps its identity between updates, so the collapsed strip and the expanded checklist move one step at a time instead of jumping back.

### Upgrading

Quit Agent Notch, replace the app in Applications, and reopen it. Nothing else is needed: the hook bridge, the installer and the Pi extension are unchanged since 0.3.1.

### Install

1. Download `AgentNotch-0.3.3.dmg`, drag **Agent Notch** to Applications.
2. This build is **not notarized**: the first time, try to open it, then go to **System Settings → Privacy & Security**, scroll down to *Security*, click **Open Anyway** and confirm.
3. Click **Connect** when the app offers it (or choose **Connect agents…** from the menu bar item).
4. Restart any running Claude Code / Codex / Pi session.

On macOS 14 the installer needs `jq` (`brew install jq`); macOS 15 and later include it.

### Known limitations

- Not notarized yet (see above).
- Gentle Shell phase poses require explicit `gentle_odd_phase` reports; inferred phases do not change the mascot.
- Codex task-list rendering remains untested on real runs.
- This build does not monitor Vercel deployments. That prototype stays on `main` and is not part of 0.3.3.

### Checksum

SHA-256 for `AgentNotch-0.3.3.dmg`:

```text
dc55021f9f87d720f2032440bddcdbbfa1242f96ada9492e7fbed92af8296fa7  AgentNotch-0.3.3.dmg
```
