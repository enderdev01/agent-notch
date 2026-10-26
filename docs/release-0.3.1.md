## Agent Notch 0.3.1

Questions from Claude now show up as questions.

### What's fixed

- **Claude's question tool (`AskUserQuestion`) is shown as "Your turn".** Before, the notch showed it as a running tool ("Running AskUserQuestion", timer included) and raised an Allow / Deny card. An Allow there could not carry your answers back to Claude. Now:
  - the peek under the notch shows the question in amber and the mascot gets the amber dot;
  - the session row says **Your turn** with the question underneath, and the hover card lists the question and its options;
  - the permission request for the question is handed back to the terminal, so Claude uses its own question UI;
  - it sounds like an approval, does not count as a finished turn, and the row goes back to "Thinking" when you answer.
- Found by recording the real hook events of a question: Claude sends the tool event, then a permission request, then a notification, and finally the answers.

### Upgrading

Replace the app. Nothing else is needed: the hook script installed by 0.1.1 is unchanged.

### Install

1. Download `AgentNotch-0.3.1.dmg`, drag **Agent Notch** to Applications.
2. This build is **not notarized**: the first time, try to open it, then go to **System Settings → Privacy & Security**, scroll down to *Security*, click **Open Anyway** and confirm.
3. Click **Connect** when the app offers it (or choose **Connect agents…** from the menu bar item).
4. Restart any running Claude Code / Codex / Pi session. Codex may ask you to trust the new hooks.

The installer only appends hook entries that run `agent-notch-hook`; `uninstall.sh` (inside the app, in `Contents/Resources/scripts`) removes exactly those.

### Known limitations

- Not notarized yet (see above).
- If one call asks several questions, the notch shows the first and counts the rest.
- Plan approval (`ExitPlanMode`) and questions from MCP servers probably need the same treatment; they are not covered yet.
- Tested by replaying real recorded events against the app, not with a new live question on the final build.
- The language picker was tested from a copy outside `/Applications`; the restart from `/Applications` or from a login item is untested.
- macOS 14+. Built for notched MacBooks; other screens get a pill at the top center. On macOS 14 the installer needs `jq` (`brew install jq`); macOS 15 and later include it.
- The "jq is required" message (macOS 14 without `jq`) is untested.
- Codex `update_plan` step lists are untested on real Codex runs.
- Claude `TaskCreate` / `TaskUpdate` task lists are not shown (only `TodoWrite`).

### Checksum

SHA-256 of `AgentNotch-0.3.1.dmg`: `07380f3daec0571f859dd61ad1d0ddbcc1ba0c32b60eb80177486d00c76e74be`
