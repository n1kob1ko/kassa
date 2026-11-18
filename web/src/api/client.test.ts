import { afterEach, beforeEach, expect, test, vi } from 'vitest';
import { api, ApiError, setUnauthorizedHandler } from './client';

type Call = { url: string; init: RequestInit };
let calls: Call[];
let respond: () => Response | Promise<Response>;

function json(status: number, body: unknown, headers: Record<string, string> = {}): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json; charset=utf-8', ...headers },
  });
}

let redirects: number;
beforeEach(() => {
  calls = [];
  redirects = 0;
  respond = () => json(200, { ok: true });
  vi.stubGlobal('fetch', async (url: string, init: RequestInit) => {
    calls.push({ url, init });
    return respond();
  });
  vi.stubGlobal('location', { pathname: '/betriebe' });
  setUnauthorizedHandler(() => {
    redirects += 1;
  });
});
afterEach(() => {
  vi.unstubAllGlobals();
});

function header(call: Call, name: string): string | null {
  return new Headers(call.init.headers).get(name);
}

test('POST trägt X-Kassa-Request und Content-Type JSON', async () => {
  respond = () => json(201, { user: { id: 'u1' } });
  const result = await api.post<{ user: { id: string } }>('/api/auth/login', { email: 'beispiel@example.com' });

  expect(result).toEqual({ user: { id: 'u1' } });
  expect(calls).toHaveLength(1);
  const call = calls[0]!;
  expect(call.url).toBe('/api/auth/login');
  expect(call.init.method).toBe('POST');
  expect(call.init.credentials).toBe('same-origin');
  expect(header(call, 'X-Kassa-Request')).toBe('1');
  expect(header(call, 'Content-Type')).toBe('application/json');
  expect(JSON.parse(call.init.body as string)).toEqual({ email: 'beispiel@example.com' });
});

test('GET, PATCH und DELETE tragen X-Kassa-Request, nur mit Inhalt gibt es Content-Type', async () => {
  await api.get('/api/auth/me');
  await api.patch('/api/admin/x', { name: 'Beispiel-Imbiss' });
  respond = () => new Response(null, { status: 204 });
  const deleted = await api.del('/api/admin/x');
  await api.post('/api/auth/logout');

  expect(calls.map((c) => c.init.method)).toEqual(['GET', 'PATCH', 'DELETE', 'POST']);
  for (const call of calls) {
    expect(header(call, 'X-Kassa-Request')).toBe('1');
    expect(call.init.credentials).toBe('same-origin');
  }
  expect(header(calls[0]!, 'Content-Type')).toBeNull();
  expect(header(calls[1]!, 'Content-Type')).toBe('application/json');
  expect(calls[3]!.init.body).toBeUndefined();
  expect(header(calls[3]!, 'Content-Type')).toBeNull();
  expect(deleted).toBeUndefined();
});

test('Fehlerantwort wird zu ApiError mit code, message, problems', async () => {
  respond = () =>
    json(422, {
      error: { code: 'menu_invalid', message: 'Die Speisekarte hat Fehler.' },
      problems: ['Zeile 3: Preis fehlt.'],
    });
  const err = await api.post('/api/admin/businesses', {}).catch((e: unknown) => e);

  expect(err).toBeInstanceOf(ApiError);
  expect(err).toMatchObject({
    status: 422,
    code: 'menu_invalid',
    message: 'Die Speisekarte hat Fehler.',
    problems: ['Zeile 3: Preis fehlt.'],
  });
  expect((err as ApiError).retryAfterSeconds).toBeUndefined();
});

test('429 liefert die Wartezeit in Sekunden', async () => {
  respond = () =>
    json(
      429,
      { error: { code: 'too_many_attempts', message: 'Zu viele Versuche.' }, retryAfterSeconds: 120 },
      { 'retry-after': '120' },
    );
  const err = (await api.post('/api/auth/login', {}).catch((e: unknown) => e)) as ApiError;
  expect(err.code).toBe('too_many_attempts');
  expect(err.retryAfterSeconds).toBe(120);

  respond = () => json(429, { error: { code: 'too_many_attempts', message: 'x' } }, { 'retry-after': '61' });
  const fromHeader = (await api.post('/api/auth/login', {}).catch((e: unknown) => e)) as ApiError;
  expect(fromHeader.retryAfterSeconds).toBe(61);
});

test('eine Antwort ohne Fehlerform und ein Netzfehler werden zu einem ApiError mit deutschem Satz', async () => {
  respond = () => new Response('<html>Bad Gateway</html>', { status: 502, headers: { 'content-type': 'text/html' } });
  const gateway = (await api.get('/api/auth/me').catch((e: unknown) => e)) as ApiError;
  expect(gateway).toBeInstanceOf(ApiError);
  expect(gateway).toMatchObject({ status: 502, code: 'internal' });
  expect(gateway.message).toBe('Das hat nicht geklappt. Bitte nochmal versuchen.');

  respond = () => {
    throw new TypeError('Failed to fetch');
  };
  const offline = (await api.get('/api/auth/me').catch((e: unknown) => e)) as ApiError;
  expect(offline).toBeInstanceOf(ApiError);
  expect(offline).toMatchObject({ status: 0, code: 'network' });
  expect(offline.message).toMatch(/Keine Verbindung/);
});

test('401 außerhalb der Anmeldeseiten führt zur Anmeldung, auf den Anmeldeseiten nicht', async () => {
  respond = () => json(401, { error: { code: 'unauthorized', message: 'Bitte melde dich an.' } });

  const err = (await api.get('/api/auth/me').catch((e: unknown) => e)) as ApiError;
  expect(err.status).toBe(401);
  expect(redirects).toBe(1);

  for (const pathname of ['/anmelden', '/einrichten']) {
    vi.stubGlobal('location', { pathname });
    await api.post('/api/auth/login', {}).catch(() => undefined);
  }
  expect(redirects).toBe(1);
});
