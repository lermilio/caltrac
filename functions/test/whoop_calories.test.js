const test = require('node:test');
const assert = require('node:assert/strict');
const { createWhoopService } = require('../whoop_calories');

class HttpsError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

const NOW = Date.parse('2026-11-10T16:00:00Z');
const request = {
  userId: 'test-user',
  start: '2026-11-10T00:00:00.000Z',
  end: '2026-11-11T00:00:00.000Z',
};
const validTokens = {
  access_token: 'old-access', refresh_token: 'old-refresh', expires_at: NOW + 3_600_000,
};
const cycles = {
  data: { records: [
    { start: '2026-11-10T01:00:00Z', score: { kilojoule: 4184 } },
    { start: '2026-11-10T12:00:00Z', score: { kilojoule: 2092 } },
    { start: '2026-11-09T01:00:00Z', score: { kilojoule: 4184 } },
    { start: '2026-11-10T15:00:00Z' },
    { score: { kilojoule: 4184 } },
  ] },
};
function httpError(status) {
  return Object.assign(new Error(`HTTP ${status}`), { response: { status } });
}

// All credentials and records here are dummy values. No Firebase or HTTP library is loaded.
function harness({
  tokens = validTokens,
  daily = { extra_cals: 125, protein: 80 },
  responses = [cycles],
  refreshResponse = { data: { access_token: 'new-access', refresh_token: 'new-refresh', expires_in: 7200 } },
  refreshError,
  saveError,
} = {}) {
  let tokenDoc = structuredClone(tokens);
  let dailyDoc = structuredClone(daily);
  const events = [];
  const gets = [];
  const posts = [];
  const tokenWrites = [];
  const dailyWrites = [];
  const integrationRef = {
    async get() {
      events.push('read tokens');
      return { exists: tokenDoc !== null, data: () => structuredClone(tokenDoc) };
    },
    async set(value, options) {
      events.push('save tokens');
      tokenWrites.push({ value, options });
      tokenDoc = { ...tokenDoc, ...value };
    },
  };
  const dailyRef = {
    async get() {
      events.push('read daily log');
      return { exists: dailyDoc !== null, data: () => structuredClone(dailyDoc) };
    },
    async set(value, options) {
      events.push('save daily log');
      if (saveError) throw saveError;
      dailyWrites.push({ value, options });
      dailyDoc = { ...dailyDoc, ...value };
    },
  };
  const db = {
    collection(name) {
      assert.equal(name, 'users');
      return { doc(userId) {
        assert.equal(userId, 'test-user');
        return { collection(child) {
          return { doc(id) {
            if (child === 'integrations') {
              assert.equal(id, 'whoop');
              return integrationRef;
            }
            assert.equal(child, 'dailyLogs');
            assert.equal(id, '2026-11-10');
            return dailyRef;
          } };
        } };
      } };
    },
  };
  const http = {
    async get(url, options) {
      events.push('request cycles');
      gets.push({ url, ...options });
      assert.ok(gets.length <= responses.length, 'Unexpected extra WHOOP request');
      const response = responses[gets.length - 1];
      if (response instanceof Error) throw response;
      return response;
    },
    async post(url, body, options) {
      events.push('refresh token');
      posts.push({ url, body: Object.fromEntries(body), ...options });
      if (refreshError) throw refreshError;
      return refreshResponse;
    },
  };
  const service = createWhoopService({
    db, http,
    getClientCredentials: () => ({ id: 'dummy-client', secret: 'dummy-secret' }),
    serverTimestamp: () => 'server-timestamp',
    HttpsError,
    now: () => NOW,
  });
  return {
    ...service, events, gets, posts, tokenWrites, dailyWrites,
    readDaily: () => structuredClone(dailyDoc),
  };
}

test('an unexpired token is reused without requesting a refresh', async () => {
  const h = harness();
  assert.equal(await h.getFreshAccessToken('test-user'), 'old-access');
  assert.equal(h.posts.length, 0);
  assert.equal(h.tokenWrites.length, 0);
});

test('forced refresh bypasses expiry and saves the rotated tokens before returning', async () => {
  const h = harness();
  assert.equal(await h.getFreshAccessToken('test-user', { forceRefresh: true }), 'new-access');
  assert.deepEqual(h.posts, [{
    url: 'https://api.prod.whoop.com/oauth/oauth2/token',
    body: {
      grant_type: 'refresh_token', refresh_token: 'old-refresh',
      client_id: 'dummy-client', client_secret: 'dummy-secret',
    },
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
  }]);
  assert.deepEqual(h.tokenWrites, [{
    value: {
      access_token: 'new-access', refresh_token: 'new-refresh',
      expires_at: NOW + 7_200_000, updated_at: 'server-timestamp',
    },
    options: { merge: true },
  }]);
});

test('expired tokens and tokens within the 60-second buffer refresh normally', async () => {
  for (const expires_at of [NOW - 1, NOW + 60_000]) {
    const h = harness({ tokens: { ...validTokens, expires_at } });
    assert.equal(await h.getFreshAccessToken('test-user'), 'new-access');
    assert.equal(h.posts.length, 1);
  }
});

test('refresh retains the old refresh token when WHOOP does not rotate it', async () => {
  const h = harness({ refreshResponse: { data: { access_token: 'new-access' } } });
  await h.getFreshAccessToken('test-user', { forceRefresh: true });
  assert.equal(h.tokenWrites[0].value.refresh_token, 'old-refresh');
  assert.equal(h.tokenWrites[0].value.expires_at, NOW + 3_600_000);
});

test('missing access token triggers refresh even when stored expiry looks valid', async () => {
  const h = harness({ tokens: { ...validTokens, access_token: null } });
  assert.equal(await h.getFreshAccessToken('test-user'), 'new-access');
  assert.equal(h.posts.length, 1);
});

test('normal success filters dates, converts kJ, adds extra calories, and merges once', async () => {
  const h = harness();
  assert.deepEqual(await h.fetchWhoopCalories(request), { whoop_cals: 1500, calories_out: 1625 });
  assert.equal(h.gets.length, 1);
  assert.equal(h.posts.length, 0);
  assert.equal(h.dailyWrites.length, 1);
  assert.deepEqual(h.dailyWrites[0].options, { merge: true });
  assert.equal(h.readDaily().extra_cals, 125);
  assert.equal(h.readDaily().protein, 80);
});

test('401 forces refresh despite valid expiry, then processes the retry response once', async () => {
  const h = harness({ responses: [httpError(401), cycles] });
  assert.deepEqual(await h.fetchWhoopCalories(request), { whoop_cals: 1500, calories_out: 1625 });
  assert.deepEqual(h.gets.map((call) => call.headers.Authorization), ['Bearer old-access', 'Bearer new-access']);
  for (const call of h.gets) {
    assert.equal(call.url, 'https://api.prod.whoop.com/developer/v2/cycle');
    assert.deepEqual(call.params, { start: request.start, end: request.end });
  }
  assert.equal(h.posts.length, 1);
  assert.equal(h.dailyWrites.length, 1);
  assert.deepEqual(h.events, [
    'read tokens', 'request cycles', 'read tokens', 'refresh token',
    'save tokens', 'request cycles', 'read daily log', 'save daily log',
  ]);
});

test('a second 401 stops after one retry and does not write calorie data', async () => {
  const h = harness({ responses: [httpError(401), httpError(401)] });
  await assert.rejects(h.fetchWhoopCalories(request), { code: 'internal', message: 'WHOOP API fetch failed.' });
  assert.equal(h.gets.length, 2);
  assert.equal(h.posts.length, 1);
  assert.equal(h.dailyWrites.length, 0);
});

test('a non-401 failure does not refresh or retry', async () => {
  for (const error of [httpError(403), httpError(429), httpError(500), new Error('Network unavailable')]) {
    const h = harness({ responses: [error] });
    await assert.rejects(h.fetchWhoopCalories(request), { code: 'internal' });
    assert.equal(h.gets.length, 1);
    assert.equal(h.posts.length, 0);
    assert.equal(h.dailyWrites.length, 0);
  }
});

test('missing token document asks for reauthorization before requesting cycles', async () => {
  const h = harness({ tokens: null });
  await assert.rejects(h.fetchWhoopCalories(request), { code: 'failed-precondition', message: 'reauth_required' });
  assert.equal(h.gets.length, 0);
  assert.equal(h.posts.length, 0);
  assert.equal(h.dailyWrites.length, 0);
});

test('401 with no refresh token asks for reauthorization without retrying', async () => {
  const h = harness({ tokens: { ...validTokens, refresh_token: null }, responses: [httpError(401)] });
  await assert.rejects(h.fetchWhoopCalories(request), { code: 'failed-precondition', message: 'reauth_required' });
  assert.equal(h.gets.length, 1);
  assert.equal(h.posts.length, 0);
  assert.equal(h.dailyWrites.length, 0);
});

test('a rejected refresh after 401 preserves the reauthorization error', async () => {
  const h = harness({ responses: [httpError(401)], refreshError: httpError(400) });
  await assert.rejects(h.fetchWhoopCalories(request), { code: 'failed-precondition', message: 'reauth_required' });
  assert.equal(h.gets.length, 1);
  assert.equal(h.posts.length, 1);
  assert.equal(h.tokenWrites.length, 0);
  assert.equal(h.dailyWrites.length, 0);
});

test('a refresh response without an access token cannot overwrite the stored tokens', async () => {
  const h = harness({ refreshResponse: { data: {} } });
  await assert.rejects(h.getFreshAccessToken('test-user', { forceRefresh: true }), { code: 'failed-precondition' });
  assert.equal(h.tokenWrites.length, 0);
});

test('daily-log write failure surfaces an error and does not trigger another WHOOP request', async () => {
  const h = harness({ saveError: new Error('Write failed') });
  await assert.rejects(h.fetchWhoopCalories(request), { code: 'internal' });
  assert.equal(h.gets.length, 1);
  assert.equal(h.posts.length, 0);
  assert.equal(h.dailyWrites.length, 0);
});

test('an absent daily log and empty WHOOP records produce zero calories', async () => {
  const h = harness({ daily: null, responses: [{ data: { records: [] } }] });
  assert.deepEqual(await h.fetchWhoopCalories(request), { whoop_cals: 0, calories_out: 0 });
  assert.equal(h.dailyWrites.length, 1);
});

test('nested callable data remains supported', async () => {
  const h = harness();
  assert.deepEqual(await h.fetchWhoopCalories({ data: request }), { whoop_cals: 1500, calories_out: 1625 });
});

test('missing arguments fail before reading tokens or calling WHOOP', async () => {
  for (const data of [null, {}, { ...request, userId: '' }, { ...request, start: '' }, { ...request, end: '' }]) {
    const h = harness();
    await assert.rejects(h.fetchWhoopCalories(data), { code: 'invalid-argument' });
    assert.deepEqual(h.events, []);
  }
});
