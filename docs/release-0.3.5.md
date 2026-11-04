## Agent Notch 0.3.5

A small follow-up to 0.3.4: the menu no longer asks for your Mac password, and the hover panel
shows only your agents.

### What's fixed

- **Opening the menu no longer asks for the Mac login password.** The menu read the Keychain every
  time it updated, and because Agent Notch is a non-activating panel the prompt had no focused
  window: the first keystroke went nowhere until you dismissed it and tried again. The menu now
  uses a non-secret flag, polling starts only once the app is active, and disconnecting activates
  the app before it touches the Keychain. A one-time migration adopts connections made before this
  release, so nobody is asked to reconnect.
- **The hover panel lists agents, not deployments.** The expanded notch rendered every production
  Vercel deployment above your sessions (up to a hundred rows of project, state, repository, commit
  and author). That section is gone. The collapsed badge still shows a running build, and the
  notification body still carries the deployment details.

### Also in this release (Worker side, no app change)

- The connection page after authorizing Vercel is a proper page you can close, with a readable
  reason when something fails.
- Disconnecting now asks Vercel to revoke the token as well as deleting the local session.

### Upgrading from 0.3.4

Quit Agent Notch, replace the app in Applications, and reopen it. If macOS asks once for Keychain
access on the first launch, allow it: the app is ad-hoc signed, so a new build has a new identity.
Reconnecting once from the new build removes the prompt for that build.

### Install

1. Download `AgentNotch-0.3.5.dmg`, drag **Agent Notch** to Applications.
2. This build is **not notarized**: the first time, try to open it, then go to
   **System Settings → Privacy & Security**, scroll down to *Security*, click **Open Anyway** and
   confirm.
3. Click **Connect** when the app offers it (or choose **Connect agents…** from the menu bar item).
4. Restart any running Claude Code / Codex / Pi session.
5. Optional: choose **Connect Vercel…** and authorize to see production deployments in the notch.

On macOS 14 the installer needs `jq` (`brew install jq`); macOS 15 and later include it.

### Known limitations

- Not notarized yet (see above).
- Ad-hoc signing: a rebuilt app can ask for Keychain access once. A Developer ID signature would
  remove that.
- The Vercel integration is not listed publicly; connecting uses the Agent Notch integration. If you
  fork the project, deploy your own Worker and register your own integration.
- Disconnecting removes the local credential and asks Vercel to revoke the token; if Vercel rejects
  the revocation (logged as a non-200 `revoke`), remove the integration in Vercel as well.
- Gentle Shell phase poses require explicit `gentle_odd_phase` reports.
- Codex task-list rendering remains untested on real runs.

### Checksum

SHA-256 for `AgentNotch-0.3.5.dmg`:

```text
0aeb00479b7a41e608c0730aecb486fc8bdaac4e1169416fe79fffa23f0f5a99  AgentNotch-0.3.5.dmg
```
