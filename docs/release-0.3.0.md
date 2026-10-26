## Agent Notch 0.3.0

Pick the app's language from the menu bar.

### What's new

- **Language picker.** The menu bar item has a new **Language** submenu: *Match system language*, *English*, *Español* and *Deutsch*. It does not depend on your system language list any more (before, a system set to `English, Español` always got English).
- Choosing a language asks for confirmation and restarts the app. A restart sends pending approvals back to the terminal, and sessions reappear with their next activity.
- The choice is stored where System Settings keeps its per-app language, so picking it in the menu or in *System Settings → General → Language & Region → Applications* gives the same result.
- README updated in English, Spanish and German.

### Upgrading

Replace the app. Nothing else is needed: the hook script installed by 0.1.1 is unchanged.

### Install

1. Download `AgentNotch-0.3.0.dmg`, drag **Agent Notch** to Applications.
2. This build is **not notarized**: the first time, try to open it, then go to **System Settings → Privacy & Security**, scroll down to *Security*, click **Open Anyway** and confirm.
3. Click **Connect** when the app offers it (or choose **Connect agents…** from the menu bar item).
4. Restart any running Claude Code / Codex / Pi session. Codex may ask you to trust the new hooks.

The installer only appends hook entries that run `agent-notch-hook`; `uninstall.sh` (inside the app, in `Contents/Resources/scripts`) removes exactly those.

### Known limitations

- Not notarized yet (see above).
- The language picker was tested from a copy outside `/Applications`; the restart from `/Applications` or from a login item is untested.
- The translations are new: if some wording sounds odd, please open an issue. The screenshots in the README show the English interface.
- macOS 14+. Built for notched MacBooks; other screens get a pill at the top center. On macOS 14 the installer needs `jq` (`brew install jq`); macOS 15 and later include it.
- The "jq is required" message (macOS 14 without `jq`) is untested.
- Codex `update_plan` step lists are untested on real Codex runs.
- Claude `TaskCreate` / `TaskUpdate` task lists are not shown (only `TodoWrite`).

### Checksum

SHA-256 of `AgentNotch-0.3.0.dmg`: `274531af49f1b7a52eb060ea50349128e05656a36825f3e5639b7884a0c5812b`
