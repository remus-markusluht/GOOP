import { createServer } from 'node:http';
import { randomBytes, createHash, createCipheriv, createDecipheriv } from 'node:crypto';
import { mkdir, readFile, rename, writeFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const PORT = Number(process.env.PORT ?? 8787);
const DATA_FILE = resolve(here, process.env.GOOP_DATA_FILE ?? './data/store.json');
const GOOGLE_CLIENT_ID = process.env.GOOGLE_CLIENT_ID;
const GOOGLE_CLIENT_SECRET = process.env.GOOGLE_CLIENT_SECRET;
const GOOGLE_REDIRECT_URI = process.env.GOOGLE_REDIRECT_URI;
const ALLOWED_EMAIL = process.env.GOOP_ALLOWED_EMAIL?.trim().toLowerCase();
const IOS_CALLBACK = process.env.IOS_CALLBACK_URI ?? 'goop://auth/callback';
const scopes = [
  'openid',
  'email',
  'profile',
  'https://www.googleapis.com/auth/googlehealth.activity_and_fitness.readonly',
  'https://www.googleapis.com/auth/googlehealth.sleep.readonly',
  'https://www.googleapis.com/auth/googlehealth.health_metrics_and_measurements.readonly',
].join(' ');

const encryptionKey = process.env.GOOP_TOKEN_ENCRYPTION_KEY
  ? Buffer.from(process.env.GOOP_TOKEN_ENCRYPTION_KEY, 'base64')
  : null;
const store = { accounts: {}, sessions: {} };
const pendingStates = new Map();
const oneTimeCodes = new Map();

function assertConfiguration() {
  const missing = [];
  if (!GOOGLE_CLIENT_ID) missing.push('GOOGLE_CLIENT_ID');
  if (!GOOGLE_CLIENT_SECRET) missing.push('GOOGLE_CLIENT_SECRET');
  if (!GOOGLE_REDIRECT_URI) missing.push('GOOGLE_REDIRECT_URI');
  if (!ALLOWED_EMAIL) missing.push('GOOP_ALLOWED_EMAIL (the only Google account allowed to connect)');
  if (!encryptionKey || encryptionKey.length !== 32) missing.push('GOOP_TOKEN_ENCRYPTION_KEY (base64-encoded 32 bytes)');
  if (!process.env.GOOP_SESSION_PEPPER || process.env.GOOP_SESSION_PEPPER.length < 32) missing.push('GOOP_SESSION_PEPPER (at least 32 characters)');
  if (missing.length) throw new Error(`Missing server configuration: ${missing.join(', ')}`);
}

function randomId(bytes = 32) { return randomBytes(bytes).toString('base64url'); }
function hash(value) { return createHash('sha256').update(value).digest('hex'); }

function seal(value) {
  const iv = randomBytes(12);
  const cipher = createCipheriv('aes-256-gcm', encryptionKey, iv);
  const ciphertext = Buffer.concat([cipher.update(value, 'utf8'), cipher.final()]);
  return { iv: iv.toString('base64'), tag: cipher.getAuthTag().toString('base64'), ciphertext: ciphertext.toString('base64') };
}

function unseal(value) {
  const decipher = createDecipheriv('aes-256-gcm', encryptionKey, Buffer.from(value.iv, 'base64'));
  decipher.setAuthTag(Buffer.from(value.tag, 'base64'));
  return Buffer.concat([decipher.update(Buffer.from(value.ciphertext, 'base64')), decipher.final()]).toString('utf8');
}

async function persist() {
  await mkdir(dirname(DATA_FILE), { recursive: true, mode: 0o700 });
  const temporary = `${DATA_FILE}.tmp`;
  await writeFile(temporary, JSON.stringify(store), { mode: 0o600 });
  await rename(temporary, DATA_FILE);
}

async function loadStore() {
  try {
    const parsed = JSON.parse(await readFile(DATA_FILE, 'utf8'));
    Object.assign(store, parsed);
  } catch (error) {
    if (error.code !== 'ENOENT') throw error;
  }
}

async function jsonBody(request) {
  const chunks = [];
  let bytes = 0;
  for await (const chunk of request) {
    bytes += chunk.length;
    if (bytes > 1024 * 1024) throw Object.assign(new Error('Request body is too large.'), { status: 413 });
    chunks.push(chunk);
  }
  return chunks.length ? JSON.parse(Buffer.concat(chunks).toString('utf8')) : {};
}

function sendJSON(response, status, value) {
  response.writeHead(status, { 'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store', 'x-content-type-options': 'nosniff' });
  response.end(JSON.stringify(value));
}

function sessionFor(request) {
  const token = request.headers.authorization?.match(/^Bearer (.+)$/i)?.[1];
  if (!token) return null;
  const key = hash(`${process.env.GOOP_SESSION_PEPPER}:${token}`);
  const session = store.sessions[key];
  if (!session || session.expiresAt <= Date.now()) {
    if (session) delete store.sessions[key];
    return null;
  }
  session.expiresAt = Date.now() + 30 * 24 * 60 * 60 * 1000;
  return { key, ...session };
}

async function exchangeCode(request, response) {
  const { code } = await jsonBody(request);
  const entry = oneTimeCodes.get(code);
  if (!entry || entry.expiresAt <= Date.now()) return sendJSON(response, 401, { error: 'Sign-in code expired. Please try again.' });
  oneTimeCodes.delete(code);
  const token = randomId(48);
  const key = hash(`${process.env.GOOP_SESSION_PEPPER}:${token}`);
  store.sessions[key] = { sub: entry.sub, expiresAt: Date.now() + 30 * 24 * 60 * 60 * 1000 };
  await persist();
  const account = store.accounts[entry.sub];
  sendJSON(response, 200, { sessionToken: token, user: { name: account.name, email: account.email } });
}

async function startGoogleAuth(response) {
  const state = randomId(24);
  pendingStates.set(state, Date.now() + 5 * 60 * 1000);
  const url = new URL('https://accounts.google.com/o/oauth2/v2/auth');
  url.search = new URLSearchParams({
    client_id: GOOGLE_CLIENT_ID,
    redirect_uri: GOOGLE_REDIRECT_URI,
    response_type: 'code',
    access_type: 'offline',
    include_granted_scopes: 'true',
    prompt: 'consent',
    scope: scopes,
    state,
  }).toString();
  response.writeHead(302, { location: url.toString(), 'cache-control': 'no-store' });
  response.end();
}

async function completeGoogleAuth(url, response) {
  const state = url.searchParams.get('state');
  const expiresAt = state && pendingStates.get(state);
  if (!expiresAt || expiresAt < Date.now()) {
    return sendJSON(response, 400, { error: 'Sign-in state expired. Please restart sign-in.' });
  }
  pendingStates.delete(state);
  const providerError = url.searchParams.get('error');
  if (providerError) return sendJSON(response, 400, { error: 'Google sign-in was cancelled or denied.' });
  const code = url.searchParams.get('code');
  if (!code) return sendJSON(response, 400, { error: 'Google did not return an authorization code.' });

  const tokenResponse = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      code,
      client_id: GOOGLE_CLIENT_ID,
      client_secret: GOOGLE_CLIENT_SECRET,
      redirect_uri: GOOGLE_REDIRECT_URI,
      grant_type: 'authorization_code',
    }),
  });
  const tokens = await tokenResponse.json();
  if (!tokenResponse.ok) throw new Error(`Google token exchange failed (${tokenResponse.status}).`);

  const profileResponse = await fetch('https://openidconnect.googleapis.com/v1/userinfo', {
    headers: { authorization: `Bearer ${tokens.access_token}` },
  });
  const profile = await profileResponse.json();
  if (!profileResponse.ok || !profile.sub || !profile.email) throw new Error('Could not read your Google account profile.');
  if (profile.email.toLowerCase() !== ALLOWED_EMAIL || profile.email_verified !== true) {
    return sendJSON(response, 403, { error: 'This GOOP server is configured for a different Google account.' });
  }

  const previous = store.accounts[profile.sub];
  store.accounts[profile.sub] = {
    sub: profile.sub,
    name: profile.name ?? profile.email,
    email: profile.email,
    refreshToken: tokens.refresh_token ? seal(tokens.refresh_token) : previous?.refreshToken,
    accessToken: seal(tokens.access_token),
    accessTokenExpiresAt: Date.now() + Number(tokens.expires_in ?? 3600) * 1000,
  };
  if (!store.accounts[profile.sub].refreshToken) throw new Error('Google did not issue offline access. Disconnect and retry with consent.');

  const mobileCode = randomId(32);
  oneTimeCodes.set(mobileCode, { sub: profile.sub, expiresAt: Date.now() + 90 * 1000 });
  await persist();
  response.writeHead(302, { location: `${IOS_CALLBACK}?code=${encodeURIComponent(mobileCode)}`, 'cache-control': 'no-store' });
  response.end();
}

async function getAccessToken(account) {
  if (account.accessTokenExpiresAt > Date.now() + 60_000) return unseal(account.accessToken);
  const refreshToken = unseal(account.refreshToken);
  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      client_id: GOOGLE_CLIENT_ID,
      client_secret: GOOGLE_CLIENT_SECRET,
      refresh_token: refreshToken,
      grant_type: 'refresh_token',
    }),
  });
  const tokens = await response.json();
  if (!response.ok) throw new Error('Google health-data authorization expired. Please sign in again.');
  account.accessToken = seal(tokens.access_token);
  account.accessTokenExpiresAt = Date.now() + Number(tokens.expires_in ?? 3600) * 1000;
  await persist();
  return tokens.access_token;
}

async function listDataPoints(accessToken, dataType, startFilter = null) {
  const all = [];
  let pageToken = '';
  do {
    const endpoint = new URL(`https://health.googleapis.com/v4/users/me/dataTypes/${dataType}/dataPoints`);
    endpoint.searchParams.set('pageSize', '10000');
    if (pageToken) endpoint.searchParams.set('pageToken', pageToken);
    if (startFilter) endpoint.searchParams.set('filter', startFilter);
    const response = await fetch(endpoint, { headers: { authorization: `Bearer ${accessToken}`, accept: 'application/json' } });
    const result = await response.json();
    if (!response.ok) {
      const message = result.error?.message ?? `Google Health API request failed (${response.status}).`;
      throw new Error(message);
    }
    all.push(...(result.dataPoints ?? []));
    pageToken = result.nextPageToken ?? '';
  } while (pageToken && all.length < 50000);
  return all;
}

function localDate(timestamp, offset) {
  const seconds = Number.parseFloat(String(offset ?? '0').replace(/s$/, '')) || 0;
  const date = new Date(new Date(timestamp).getTime() + seconds * 1000);
  return date.toISOString().slice(0, 10);
}

function newDay(date) {
  return { date, steps: null, activeZoneMinutes: null, restingHeartRate: null, hrvMilliseconds: null, sleep: null };
}

function add(map, date) {
  if (!map.has(date)) map.set(date, newDay(date));
  return map.get(date);
}

async function makeSnapshot(account) {
  const accessToken = await getAccessToken(account);
  const from = new Date(Date.now() - 34 * 86400000).toISOString().slice(0, 10);
  const stepFilter = `steps.interval.start_time >= "${from}T00:00:00Z"`;
  const azmFilter = `active_zone_minutes.interval.start_time >= "${from}T00:00:00Z"`;
  const sleepFilter = `sleep.interval.civil_end_time >= "${from}"`;
  const [steps, azm, rhr, hrv, sleep] = await Promise.all([
    listDataPoints(accessToken, 'steps', stepFilter),
    listDataPoints(accessToken, 'active-zone-minutes', azmFilter),
    listDataPoints(accessToken, 'daily-resting-heart-rate'),
    listDataPoints(accessToken, 'daily-heart-rate-variability'),
    listDataPoints(accessToken, 'sleep', sleepFilter),
  ]);

  const days = new Map();
  for (const point of steps) {
    const data = point.steps;
    if (!data?.interval?.startTime) continue;
    const date = localDate(data.interval.startTime, data.interval.startUtcOffset);
    if (date < from) continue;
    const day = add(days, date);
    day.steps = (day.steps ?? 0) + Number(data.count ?? 0);
  }
  for (const point of azm) {
    const data = point.activeZoneMinutes;
    if (!data?.interval?.startTime) continue;
    const date = localDate(data.interval.startTime, data.interval.startUtcOffset);
    if (date < from) continue;
    const day = add(days, date);
    day.activeZoneMinutes = (day.activeZoneMinutes ?? 0) + Number(data.activeZoneMinutes ?? 0);
  }
  for (const point of rhr) {
    const data = point.dailyRestingHeartRate;
    const date = data?.date ? `${data.date.year}-${String(data.date.month).padStart(2, '0')}-${String(data.date.day).padStart(2, '0')}` : null;
    if (!date || date < from) continue;
    add(days, date).restingHeartRate = Number(data.beatsPerMinute);
  }
  for (const point of hrv) {
    const data = point.dailyHeartRateVariability;
    const date = data?.date ? `${data.date.year}-${String(data.date.month).padStart(2, '0')}-${String(data.date.day).padStart(2, '0')}` : null;
    if (!date || date < from) continue;
    add(days, date).hrvMilliseconds = Number(data.averageHeartRateVariabilityMilliseconds ?? data.deepSleepRootMeanSquareOfSuccessiveDifferencesMilliseconds) || null;
  }
  for (const point of sleep) {
    const data = point.sleep;
    if (!data?.interval?.endTime) continue;
    const date = localDate(data.interval.endTime, data.interval.endUtcOffset);
    if (date < from) continue;
    const day = add(days, date);
    const summary = data.summary ?? {};
    const stageMinutes = Object.fromEntries((summary.stagesSummary ?? []).map(stage => [stage.type, Number(stage.minutes)]));
    const sleepEntry = {
      startTime: data.interval.startTime,
      endTime: data.interval.endTime,
      minutesAsleep: Number(summary.minutesAsleep) || null,
      minutesInBed: Number(summary.minutesInSleepPeriod) || null,
      deepMinutes: stageMinutes.DEEP ?? null,
      remMinutes: stageMinutes.REM ?? null,
      lightMinutes: stageMinutes.LIGHT ?? null,
      awakeMinutes: Number(summary.minutesAwake) || stageMinutes.AWAKE || null,
    };
    if (!day.sleep || (sleepEntry.minutesAsleep ?? 0) > (day.sleep.minutesAsleep ?? 0)) day.sleep = sleepEntry;
  }
  return {
    user: { name: account.name, email: account.email },
    generatedAt: new Date().toISOString(),
    days: [...days.values()].sort((left, right) => right.date.localeCompare(left.date)),
  };
}

async function handler(request, response) {
  const url = new URL(request.url, `http://${request.headers.host ?? 'localhost'}`);
  try {
    if (request.method === 'GET' && url.pathname === '/healthz') return sendJSON(response, 200, { ok: true });
    if (request.method === 'GET' && url.pathname === '/auth/google/start') return await startGoogleAuth(response);
    if (request.method === 'GET' && url.pathname === '/auth/google/callback') return await completeGoogleAuth(url, response);
    if (request.method === 'POST' && url.pathname === '/auth/exchange') return await exchangeCode(request, response);

    const session = sessionFor(request);
    if (request.method === 'POST' && url.pathname === '/v1/logout') {
      if (!session) return sendJSON(response, 401, { error: 'Sign-in expired.' });
      delete store.sessions[session.key];
      await persist();
      return sendJSON(response, 200, { ok: true });
    }
    if (request.method === 'GET' && url.pathname === '/v1/snapshot') {
      if (!session) return sendJSON(response, 401, { error: 'Sign-in expired.' });
      const account = store.accounts[session.sub];
      if (!account) return sendJSON(response, 401, { error: 'Google Health account is no longer connected.' });
      await persist();
      return sendJSON(response, 200, await makeSnapshot(account));
    }
    return sendJSON(response, 404, { error: 'Route not found.' });
  } catch (error) {
    console.error(error.message);
    return sendJSON(response, error.status ?? 500, { error: error.status ? error.message : 'GOOP server request failed.' });
  }
}

assertConfiguration();
await loadStore();
createServer(handler).listen(PORT, () => console.log(`GOOP server listening on port ${PORT}`));
