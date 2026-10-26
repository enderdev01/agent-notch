## Agent Notch 0.2.0

Agent Notch now speaks English, Spanish and German.

### What's new

- **The app follows your system language.** Menu, dialogs, session list, detail card, approval card, statuses and error messages are translated to English, Spanish and German. If a language is not supported, you get English.
- **"Gentle Shell" is now the name of the Pi-based agent** in the interface, the README and the mascot sheet (it was shown as `gentle-shell`, the folder spelling). Paths such as `~/.gentle-shell/agent` do not change.
- "Your turn" detection also recognizes German phrases such as "gib mir Bescheid" or "bitte bestätige".
- The release script now checks that every string is translated before building.

### Upgrading

Replace the app. Nothing else is needed: the hook script installed by 0.1.1 is unchanged.

### Install

1. Download `AgentNotch-0.2.0.dmg`, drag **Agent Notch** to Applications.
2. This build is **not notarized**: the first time, try to open it, then go to **System Settings → Privacy & Security**, scroll down to *Security*, click **Open Anyway** and confirm.
3. Click **Connect** when the app offers it (or choose **Connect agents…** from the menu bar item).
4. Restart any running Claude Code / Codex / Pi session. Codex may ask you to trust the new hooks.

The installer only appends hook entries that run `agent-notch-hook`; `uninstall.sh` (inside the app, in `Contents/Resources/scripts`) removes exactly those.

### Known limitations

- Not notarized yet (see above).
- The translations are new: if some wording sounds odd, please open an issue.
- The screenshots in the README show the English interface.
- macOS 14+. Built for notched MacBooks; other screens get a pill at the top center. On macOS 14 the installer needs `jq` (`brew install jq`); macOS 15 and later include it.
- The "jq is required" message (macOS 14 without `jq`) is untested.
- Codex `update_plan` step lists are untested on real Codex runs.
- Claude `TaskCreate` / `TaskUpdate` task lists are not shown (only `TodoWrite`).

### Checksum

SHA-256 of `AgentNotch-0.2.0.dmg`: `0dc03262cc1ff72c1cd708069fa6c0a0d5a0017ddedb2de9e0527eadcb067ed7`
