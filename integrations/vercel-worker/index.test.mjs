import test from 'node:test';
import assert from 'node:assert/strict';
import worker, { Session } from './index.mjs';

const secret = 'a'.repeat(64);
const challenge = Buffer.from(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(secret))).toString('hex');
const url = 'https://worker.test';
function setup() {
  const values = new Map();
  const storage = {
    async get(k) { return values.get(k); },
    async put(k, v) { if (typeof k === 'object') Object.entries(k).forEach(([a,b]) => values.set(a,b)); else values.set(k,v); },
    async deleteAll() { values.clear(); }, async setAlarm() {}, async deleteAlarm() {}
  };
  const state = { storage, blockConcurrencyWhile: fn => fn() };
  return { session: new Session(state, { VERCEL_CLIENT_ID:'id', VERCEL_CLIENT_SECRET:'secret', VERCEL_REDIRECT_URI:'https://worker.test/callback' }), values };
}
const req = (path, options) => new Request(url + path, options);

test('pairing rejects unauthorized access and callback replay', async () => {
  const { session } = setup();
  assert.equal((await session.fetch(req('/start', {method:'POST', headers:{'X-Pairing-Challenge':challenge}}))).status, 200);
  assert.equal((await session.fetch(req('/start', {method:'POST', headers:{'X-Pairing-Challenge':challenge}}))).status, 409);
  assert.equal((await session.fetch(req('/status', {headers:{Authorization:'Bearer ' + 'b'.repeat(64)}}))).status, 401);
  const oldFetch = globalThis.fetch;
  globalThis.fetch = async () => Response.json({access_token:'private',team_id:'team_123'});
  try {
    assert.equal((await session.fetch(req('/callback?code=example'))).status, 200);
    assert.equal((await session.fetch(req('/callback?code=example'))).status, 400);
    const result = await session.fetch(req('/status', {headers:{Authorization:'Bearer ' + secret}}));
    assert.deepEqual(await result.json(), {status:'connected'});
    assert.equal((await session.fetch(req('/disconnect', {method:'POST',headers:{Authorization:'Bearer ' + secret}}))).status, 200);
    assert.equal((await session.fetch(req('/status', {headers:{Authorization:'Bearer ' + secret}}))).status, 401);
  } finally { globalThis.fetch = oldFetch; }
});

test('expired pairing deletes an unclaimed authorization', async () => {
  const { session, values } = setup();
  await session.fetch(req('/start', {method:'POST', headers:{'X-Pairing-Challenge':challenge}}));
  values.set('expires', Date.now() - 1);
  values.set('token', 'private');
  assert.equal((await session.fetch(req('/status', {headers:{Authorization:'Bearer ' + secret}}))).status, 410);
  assert.equal(values.size, 0);
});

test('deployments proxy scopes Vercel requests and never returns its token', async () => {
  const { session } = setup();
  await session.fetch(req('/start', {method:'POST', headers:{'X-Pairing-Challenge':challenge}}));
  const oldFetch = globalThis.fetch;
  globalThis.fetch = async input => {
    const url = new URL(input);
    if (url.pathname === '/v2/oauth/access_token') return Response.json({access_token:'private-token', team_id:'team_123'});
    assert.equal(url.origin, 'https://api.vercel.com');
    assert.equal(url.searchParams.get('teamId'), 'team_123');
    assert.equal(url.searchParams.get('target'), 'production');
    return Response.json({deployments: [], pagination: {next: null}});
  };
  try {
    await session.fetch(req('/callback?code=example'));
    await session.fetch(req('/status', {headers:{Authorization:'Bearer ' + secret}}));
    const response = await session.fetch(req('/deployments?until=123', {headers:{Authorization:'Bearer ' + secret}}));
    assert.equal(response.status, 200);
    assert.doesNotMatch(await response.text(), /private-token/);
  } finally { globalThis.fetch = oldFetch; }
});


test('an expired Vercel token asks the client to reconnect and the callback is hardened', async () => {
  const { session } = setup();
  await session.fetch(req('/start', {method:'POST', headers:{'X-Pairing-Challenge':challenge}}));
  const oldFetch = globalThis.fetch;
  globalThis.fetch = async input => {
    const url = new URL(input);
    if (url.pathname === '/v2/oauth/access_token') return Response.json({access_token:'private-token', team_id:'team_123'});
    return new Response('unauthorized', {status: 401});
  };
  try {
    const callback = await session.fetch(req('/callback?code=example'));
    assert.equal(callback.headers.get('X-Content-Type-Options'), 'nosniff');
    await session.fetch(req('/status', {headers:{Authorization:'Bearer ' + secret}}));
    const response = await session.fetch(req('/deployments', {headers:{Authorization:'Bearer ' + secret}}));
    assert.equal(response.status, 401);
    assert.deepEqual(await response.json(), {error: 'Expired'});
  } finally { globalThis.fetch = oldFetch; }
});

test('router rejects invalid state and rate-limited clients', async () => {
  assert.equal((await worker.fetch(req('/status?state=no'), {})).status, 400);
  const env = { RATE_LIMITER: { limit: async () => ({ success: false }) } };
  const limited = req('/status?state=' + 'a'.repeat(64), {headers:{'CF-Connecting-IP':'192.0.2.1'}});
  assert.equal((await worker.fetch(limited, env)).status, 429);
});

test('simulated installation stays isolated across devices and does not leak metadata', async () => {
  const devices = new Map();
  const env = {
    RATE_LIMITER: { limit: async () => ({ success: true }) },
    SESSIONS: {
      idFromName: id => id,
      get(id) {
        if (!devices.has(id)) devices.set(id, setup().session);
        return devices.get(id);
      }
    }
  };
  const stateA = '1'.repeat(64), stateB = '2'.repeat(64);
  const call = (path, state, options = {}) => worker.fetch(req(`${path}?state=${state}`, {
    ...options, headers: {'CF-Connecting-IP':'192.0.2.1', ...options.headers}
  }), env);
  const previousFetch = globalThis.fetch;
  globalThis.fetch = async (input, options) => {
    assert.equal(options.redirect, 'error');
    if (new URL(input).pathname === '/v2/oauth/access_token') return Response.json({access_token:'server-secret',team_id:'team_123'});
    assert.equal(options.headers.Authorization, 'Bearer server-secret');
    return Response.json({deployments:[{uid:'dpl_1',name:'demo',state:'BUILDING',meta:{githubRepo:'repo',privateField:'sensitive'},secret:'sensitive'}],pagination:{next:null}});
  };
  try {
    assert.equal((await call('/start', stateA, {method:'POST', headers:{'X-Pairing-Challenge':challenge}})).status, 200);
    assert.equal((await call('/start', stateB, {method:'POST', headers:{'X-Pairing-Challenge':'b'.repeat(64)}})).status, 200);
    assert.equal((await call('/status', stateB, {headers:{Authorization:'Bearer ' + secret}})).status, 401);
    const callback = req(`/callback?state=${stateA}&code=example`, {headers:{'CF-Connecting-IP':'192.0.2.1'}});
    assert.equal((await worker.fetch(callback, env)).status, 200);
    assert.deepEqual(await (await call('/status', stateA, {headers:{Authorization:'Bearer ' + secret}})).json(), {status:'connected'});
    const data = await (await call('/deployments', stateA, {headers:{Authorization:'Bearer ' + secret}})).text();
    assert.match(data, /dpl_1/);
    assert.doesNotMatch(data, /server-secret|sensitive/);
    assert.equal((await call('/disconnect', stateA, {method:'POST', headers:{Authorization:'Bearer ' + secret}})).status, 200);
    assert.equal((await call('/status', stateA, {headers:{Authorization:'Bearer ' + secret}})).status, 401);
  } finally { globalThis.fetch = previousFetch; }
});
