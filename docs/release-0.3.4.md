## Agent Notch 0.3.4

Production deployments from Vercel can now appear in the notch, quietly and only if you connect
them.

### What's new

- **Vercel deployments (optional).** Choose **Connect Vercel…** in the menu bar, authorize the
  integration, and the notch starts showing your production deployments. While a build runs you get
  a small Vercel badge with a state dot when the notch is otherwise idle; project, repository,
  commit and author are in the expanded list, one hover away. It stays completely off, and hidden,
  until you connect.
- **Silent by default.** Deployment notifications are off unless you enable them, and when enabled
  they are passive: no sound, no interrupting banner.
- **A quiet notch.** A deployment never resizes or shifts the notch. The collapsed width comes from
  agent activity only.

### What changed

- The collapsed `n/m` step strip is gone. Step progress is still in the expanded list, so the
  collapsed notch no longer grows to show it. If you relied on it, this is the one visible
  regression in this release.
- Notifications about a deployment that finished while the app was closed are no longer announced;
  only transitions observed while it runs notify.
- The app no longer sends anything anywhere without your action: the single outbound request it can
  make is the Vercel connection you start yourself. The privacy section of the README says exactly
  what leaves the Mac and what does not.

### What's fixed

- Connecting a personal Vercel account works: the token exchange returns no team, and the Worker no
  longer rejects it.
- A redirect from the authorization endpoint is refused instead of leaving an opaque Cloudflare
  error page.
- An expired or revoked Vercel token now asks you to reconnect instead of showing a generic network
  failure.

### Upgrading from 0.3.3

Quit Agent Notch, replace the app in Applications, and reopen it. The hook bridge, the installer and
the Pi extension are unchanged. Vercel stays disconnected until you connect it.

### Install

1. Download `AgentNotch-0.3.4.dmg`, drag **Agent Notch** to Applications.
2. This build is **not notarized**: the first time, try to open it, then go to
   **System Settings → Privacy & Security**, scroll down to *Security*, click **Open Anyway** and
   confirm.
3. Click **Connect** when the app offers it (or choose **Connect agents…** from the menu bar item).
4. Restart any running Claude Code / Codex / Pi session.
5. Optional: choose **Connect Vercel…** and authorize. Only production deployments of the projects
   your integration can see are read.

On macOS 14 the installer needs `jq` (`brew install jq`); macOS 15 and later include it.

### Known limitations

- Not notarized yet (see above).
- The Vercel integration is not listed publicly. Connecting uses the Agent Notch integration; if you
  fork the project, deploy your own Worker and register your own integration
  (`integrations/vercel-worker/README.md`).
- Disconnecting removes the local credential but does not revoke the token in Vercel; remove the
  integration in Vercel for that.
- Gentle Shell phase poses require explicit `gentle_odd_phase` reports.
- Codex task-list rendering remains untested on real runs.

### Checksum

SHA-256 for `AgentNotch-0.3.4.dmg`:

```text
7f385526d10f80269676023e711c2a5830eb9fae79884d5a1528934146337876  AgentNotch-0.3.4.dmg
```
