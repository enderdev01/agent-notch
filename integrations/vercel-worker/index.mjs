const pattern = /^[a-f0-9]{64}$/;
const json = (body, status = 200) => Response.json(body, { status, headers: { 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff' } });
const hex = bytes => Array.from(new Uint8Array(bytes), b => b.toString(16).padStart(2, '0')).join('');
const digest = async value => hex(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(value)));

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
        if (!(await storage.get('challenge')) || Date.now() > (await storage.get('expires')) || await storage.get('token')) return json({ error: 'Expired or completed' }, 400);
        const code = url.searchParams.get('code');
        if (!code || code.length > 1024) return json({ error: 'Invalid code' }, 400);
        const response = await fetch('https://api.vercel.com/v2/oauth/access_token', {
          method: 'POST', redirect: 'error', headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
          body: new URLSearchParams({ client_id: this.env.VERCEL_CLIENT_ID, client_secret: this.env.VERCEL_CLIENT_SECRET, code, redirect_uri: this.env.VERCEL_REDIRECT_URI })
        });
        if (!response.ok) return json({ error: 'Authorization failed' }, 502);
        const result = await response.json();
        if (typeof result.access_token !== 'string' || !result.access_token || typeof result.team_id !== 'string') return json({ error: 'Invalid authorization response' }, 502);
        await storage.put({ token: result.access_token, team: result.team_id });
        return new Response('Connected. Return to Agent Notch.', { headers: { 'Content-Type': 'text/plain; charset=utf-8', 'Cache-Control': 'no-store', 'Referrer-Policy': 'no-referrer', 'X-Content-Type-Options': 'nosniff', 'Content-Security-Policy': "default-src 'none'" } });
      });
    }
    const verifier = request.headers.get('Authorization')?.replace(/^Bearer /, '') ?? '';
    if (!pattern.test(verifier) || await digest(verifier) !== await storage.get('challenge')) return json({ error: 'Unauthorized' }, 401);
    if (url.pathname === '/disconnect' && request.method === 'POST') { await storage.deleteAll(); return json({ ok: true }); }
    if (!await storage.get('claimed') && Date.now() > (await storage.get('expires'))) { await storage.deleteAll(); return json({ error: 'Expired' }, 410); }
    const token = await storage.get('token');
    if (!token) return Date.now() > (await storage.get('expires')) ? json({ error: 'Expired' }, 410) : json({ status: 'pending' });
    if (url.pathname === '/status' && request.method === 'GET') {
      await storage.put('claimed', true);
      await storage.deleteAlarm();
      return json({ status: 'connected' });
    }
    if (url.pathname === '/deployments' && request.method === 'GET') {
      const endpoint = new URL('https://api.vercel.com/v7/deployments');
      endpoint.searchParams.set('teamId', await storage.get('team'));
      endpoint.searchParams.set('target', 'production');
      endpoint.searchParams.set('limit', '100');
      const until = url.searchParams.get('until');
      if (until && /^\d{1,16}$/.test(until)) endpoint.searchParams.set('until', until);
      const result = await fetch(endpoint, { redirect: 'error', headers: { Authorization: `Bearer ${token}` } });
      // An expired or revoked token must ask the app to reconnect, not look like a network failure.
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
}
