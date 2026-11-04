const pattern = /^[a-f0-9]{64}$/;
const json = (body, status = 200) => Response.json(body, { status, headers: { 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff' } });
const hex = bytes => Array.from(new Uint8Array(bytes), b => b.toString(16).padStart(2, '0')).join('');
const digest = async value => hex(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(value)));
// Workers only accepts "follow" or "manual" (Node also takes "error", which the edge rejects at runtime).
const noRedirects = { redirect: 'manual' };
const redirected = response => response.type === 'opaqueredirect' || (response.status >= 300 && response.status < 400);

// Browser-facing page for the callback. Every string is static: no user input is interpolated, so no escaping is needed.
const page = (status, title, message) => new Response(`<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>${title} · Agent Notch</title>
<style>
:root { color-scheme: dark }
body { margin:0; min-height:100vh; display:grid; place-items:center; background:#0a0a0b; color:#f5f5f7;
  font:16px/1.5 -apple-system, BlinkMacSystemFont, "SF Pro Text", system-ui, sans-serif }
main { max-width:26rem; padding:2.5rem 2rem; text-align:center }
.mark { width:3rem; height:3rem; margin:0 auto 1.25rem; border-radius:50%; display:grid; place-items:center;
  font-size:1.5rem; font-weight:600; background:${status < 400 ? '#12351f' : '#3a1417'}; color:${status < 400 ? '#4ade80' : '#f87171'} }
h1 { font-size:1.35rem; margin:0 0 .5rem; letter-spacing:-.01em }
p { margin:0 0 1.5rem; color:#a1a1aa }
.brand { font-size:.75rem; letter-spacing:.08em; text-transform:uppercase; color:#52525b }
</style></head>
<body><main>
<div class="mark">${status < 400 ? '✓' : '!'}</div>
<h1>${title}</h1>
<p>${message}</p>
<p class="brand">Agent Notch</p>
</main></body></html>`, { status, headers: { 'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': 'no-store', 'Referrer-Policy': 'no-referrer', 'X-Content-Type-Options': 'nosniff', 'Content-Security-Policy': "default-src 'none'; style-src 'unsafe-inline'" } });

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const state = url.searchParams.get('state') ?? '';
    if (!pattern.test(state)) return json({ error: 'Invalid state' }, 400);
    if (!['/start', '/callback', '/status', '/deployments', '/disconnect'].includes(url.pathname)) return json({ error: 'Not found' }, 404);
    const ip = request.headers.get('CF-Connecting-IP');
    if (!ip || !(await env.RATE_LIMITER.limit({ key: ip })).success) return json({ error: 'Rate limited' }, 429);
    return env.SESSIONS.get(env.SESSIONS.idFromName(state)).fetch(request);
  }
};

// A separate object per unguessable state keeps a device's Vercel token isolated.
export class Session {
  constructor(state, env) { this.state = state; this.env = env; }

  async fetch(request) {
    const url = new URL(request.url);
    const storage = this.state.storage;
    if (url.pathname === '/start' && request.method === 'POST') {
      const challenge = request.headers.get('X-Pairing-Challenge') ?? '';
      if (!pattern.test(challenge)) return json({ error: 'Invalid challenge' }, 400);
      return this.state.blockConcurrencyWhile(async () => {
        if (await storage.get('challenge')) return json({ error: 'Already started' }, 409);
        await storage.put({ challenge, expires: Date.now() + 10 * 60_000 });
        await storage.setAlarm(Date.now() + 10 * 60_000);
        return json({ ok: true });
      });
    }
    if (url.pathname === '/callback' && request.method === 'GET') {
      return this.state.blockConcurrencyWhile(async () => {
        try {
          if (!(await storage.get('challenge')) || Date.now() > (await storage.get('expires')) || await storage.get('token'))
            return page(400, 'This connection expired', 'Start again from Agent Notch: choose Connect Vercel… and authorize.');
          const code = url.searchParams.get('code');
          if (!code || code.length > 1024) return page(400, 'Vercel did not send an authorization code', 'Start again from Agent Notch.');
          // Log presence, never values: a missing secret is the most common cause of a failed exchange.
          console.log('callback', { hasCode: Boolean(code), clientId: Boolean(this.env.VERCEL_CLIENT_ID), clientSecret: Boolean(this.env.VERCEL_CLIENT_SECRET), redirectUri: this.env.VERCEL_REDIRECT_URI ?? null });
          const response = await fetch('https://api.vercel.com/v2/oauth/access_token', {
            ...noRedirects, method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
            body: new URLSearchParams({ client_id: this.env.VERCEL_CLIENT_ID, client_secret: this.env.VERCEL_CLIENT_SECRET, code, redirect_uri: this.env.VERCEL_REDIRECT_URI })
          });
          console.log('token exchange', response.status);
          if (redirected(response)) return page(502, 'Vercel rejected the connection', 'Check that the redirect URL matches the integration settings, then try again from Agent Notch.');
          if (!response.ok) return page(502, 'Vercel rejected the connection', 'Check that the client ID, secret and redirect URL match, then try again from Agent Notch.');
          let result;
          try { result = JSON.parse(await response.text()); } catch { return page(502, 'Unexpected response from Vercel', 'Try again from Agent Notch.'); }
          // A personal account installs with team_id null; only a team install has an id to scope requests with.
          if (typeof result?.access_token !== 'string' || !result.access_token) return page(502, 'Unexpected response from Vercel', 'Try again from Agent Notch.');
          await storage.put({ token: result.access_token, team: typeof result.team_id === 'string' ? result.team_id : '' });
          return page(200, 'Agent Notch is connected', 'You can close this tab and return to the app. Deployments appear in the notch while they run.');
        } catch (error) {
          // Never surface a 1101 here: the browser should show a short reason and the log keeps the stack.
          console.log('callback failed', error?.stack ?? String(error));
          return page(502, 'The connection could not be completed', 'Try again from Agent Notch. If it keeps failing, check the Worker logs.');
        }
      });
    }
    const verifier = request.headers.get('Authorization')?.replace(/^Bearer /, '') ?? '';
    if (!pattern.test(verifier) || await digest(verifier) !== await storage.get('challenge')) return json({ error: 'Unauthorized' }, 401);
    if (url.pathname === '/disconnect' && request.method === 'POST') {
      const token = await storage.get('token');
      await storage.deleteAll();
      if (typeof token === 'string' && token) await this.revoke(token);
      return json({ ok: true });
    }
    if (!await storage.get('claimed') && Date.now() > (await storage.get('expires'))) { await storage.deleteAll(); return json({ error: 'Expired' }, 410); }
    const token = await storage.get('token');
    if (!token) return Date.now() > (await storage.get('expires')) ? json({ error: 'Expired' }, 410) : json({ status: 'pending' });
    if (url.pathname === '/status' && request.method === 'GET') {
      await storage.put('claimed', true);
      await storage.deleteAlarm();
      return json({ status: 'connected' });
    }
    if (url.pathname === '/deployments' && request.method === 'GET') {
      const endpoint = new URL('https://api.vercel.com/v6/deployments');
      const team = await storage.get('team');
      if (typeof team === 'string' && team) endpoint.searchParams.set('teamId', team);
      endpoint.searchParams.set('target', 'production');
      endpoint.searchParams.set('limit', '100');
      const until = url.searchParams.get('until');
      if (until && /^\d{1,16}$/.test(until)) endpoint.searchParams.set('until', until);
      const result = await fetch(endpoint, { ...noRedirects, headers: { Authorization: `Bearer ${token}` } });
      // An expired or revoked token must ask the app to reconnect, not look like a network failure.
      if (redirected(result)) return json({ error: 'Vercel request failed' }, 502);
      if (result.status === 401) return json({ error: 'Expired' }, 401);
      if (!result.ok) return json({ error: 'Vercel request failed' }, result.status === 429 ? 429 : 502);
      const page = await result.json();
      if (!Array.isArray(page.deployments)) return json({ error: 'Invalid Vercel response' }, 502);
      const keys = ['githubRepo', 'githubCommitSha', 'githubCommitAuthorName', 'gitlabProjectName', 'gitlabCommitSha', 'gitlabCommitAuthorName', 'bitbucketRepoName', 'bitbucketCommitSha', 'bitbucketCommitAuthorName'];
      const deployments = page.deployments.map(({ uid, name, state, meta }) => ({
        uid, name, state,
        meta: Object.fromEntries(keys.filter(key => typeof meta?.[key] === 'string').map(key => [key, meta[key]]))
      }));
      return json({ deployments, pagination: { next: page.pagination?.next ?? null } });
    }
    return json({ error: 'Not found' }, 404);
  }

  async alarm() { if (!await this.state.storage.get('claimed')) await this.state.storage.deleteAll(); }

  /// Best effort: revokes the Vercel token when the user disconnects. A failure here must never keep the local session alive.
  async revoke(token) {
    try {
      const basic = btoa(`${this.env.VERCEL_CLIENT_ID}:${this.env.VERCEL_CLIENT_SECRET}`);
      const response = await fetch('https://api.vercel.com/login/oauth/token/revoke', {
        ...noRedirects, method: 'POST',
        headers: { Authorization: `Basic ${basic}`, 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({ token })
      });
      console.log('revoke', response.status);
    } catch (error) {
      console.log('revoke failed', String(error));
    }
  }
}
