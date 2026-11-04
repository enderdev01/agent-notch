# Vercel privacy wording (proposal)

The app currently promises, in all three READMEs and in `CONTRIBUTING.md`, that it never sends
anything anywhere. Connecting Vercel necessarily breaks that promise for users who opt in, so the
wording has to change *with* the feature, not after it. This is the proposed change; it is not
applied yet because it changes a public promise.

## README.md

Replace the opening sentence of the "Privacy" section:

> It runs locally, listens only on `127.0.0.1`, and never sends anything anywhere.

with:

> It runs locally and listens only on `127.0.0.1`. It never sends your agent activity anywhere.
> The only outbound request the app can make is the optional Vercel connection described below,
> and only after you start it yourself.

Then add, after the Vercel feature section:

> ### Vercel (optional)
>
> Agent Notch can show production deployments from the Vercel projects your integration can see.
> It is off until you choose **Connect Vercel…**: before that, the app makes no network requests
> and the menu item is hidden.
>
> When you connect, the app keeps a device credential in the Keychain and talks only to the
> Agent Notch Worker. The Worker holds the integration's client secret and exchanges it for a
> Vercel token scoped to reading deployments; that token never reaches your Mac. The app asks for
> deployment read access only, and sends no prompts, code, session data or file paths.
>
> **Disconnect** removes the local credential. To revoke the integration's access as well,
> remove it in Vercel; the confirmation dialog says so.
>
> Deployment notifications are off by default and, when enabled, arrive silently (no sound, no
> banner that interrupts).

## CONTRIBUTING.md

Replace:

> The server must stay loopback-only and the app must not make network requests.

with:

> The server must stay loopback-only. The app makes no network requests except the optional
> Vercel connection, which must stay off by default, hidden until configured, started only by an
> explicit user action, and documented in the README of every language.

## Notes

- The Spanish and German READMEs must carry the same wording; translate after the English text is
  approved so the promise does not drift between languages.
- If the integration is never finished, this change should not land: the current promise is true
  today and should stay that way.
- `SECURITY.md` should point at `docs/vercel-security-review.md` once the review is independent.
