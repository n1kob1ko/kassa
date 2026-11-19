import { connect, type Socket } from 'node:net';
import { afterAll, beforeAll, describe, expect, test } from 'vitest';
import { ApiError } from '../src/errors.js';
import { testApp } from './support/app.js';

let t: Awaited<ReturnType<typeof testApp>>;
beforeAll(async () => {
  t = await testApp();
  t.app.get('/api/test/boom', async () => {
    throw new Error('geheimes Detail mit Passwort');
  });
  t.app.post('/api/test/echo', async (req) => req.body);
  t.app.get('/api/test/gesperrt', async () => {
    throw new ApiError(403, 'forbidden', 'Das darfst du nicht.', { hint: 'x' });
  });
});
afterAll(() => t.close());

test('GET /healthz antwortet 200 {ok:true}', async () => {
  const res = await t.app.inject({ method: 'GET', url: '/healthz' });
  expect(res.statusCode).toBe(200);
  expect(res.json()).toEqual({ ok: true });
});

test('unbekannte Adresse unter /api antwortet 404 mit code not_found', async () => {
  const res = await t.app.inject({ method: 'GET', url: '/api/gibt-es-nicht' });
  expect(res.statusCode).toBe(404);
  expect(res.json().error.code).toBe('not_found');
  expect(typeof res.json().error.message).toBe('string');
});

test('ein geworfener Fehler wird 500 internal ohne Einzelheiten', async () => {
  const res = await t.app.inject({ method: 'GET', url: '/api/test/boom' });
  expect(res.statusCode).toBe(500);
  expect(res.json()).toEqual({
    error: { code: 'internal', message: 'Das hat nicht geklappt. Bitte nochmal versuchen.' },
  });
  expect(res.body).not.toContain('Passwort');
});

test('ein ApiError erzeugt die Fehlerform mit seinem Status und Code', async () => {
  const res = await t.app.inject({ method: 'GET', url: '/api/test/gesperrt' });
  expect(res.statusCode).toBe(403);
  expect(res.json()).toEqual({ error: { code: 'forbidden', message: 'Das darfst du nicht.' }, hint: 'x' });
});

test('eine Anfrage über 1 MB wird mit 413 abgelehnt', async () => {
  const res = await t.app.inject({
    method: 'POST',
    url: '/api/test/echo',
    payload: { text: 'x'.repeat(1024 * 1024 + 10) },
  });
  expect(res.statusCode).toBe(413);
  expect(res.json().error.code).toBe('payload_too_large');
});

test('ungültiges JSON ist 400 bad_request', async () => {
  const res = await t.app.inject({
    method: 'POST',
    url: '/api/test/echo',
    headers: { 'content-type': 'application/json' },
    payload: '{kaputt',
  });
  expect(res.statusCode).toBe(400);
  expect(res.json().error.code).toBe('bad_request');
});

describe('Zeitgrenzen', () => {
  let s: Awaited<ReturnType<typeof testApp>>;
  let port: number;
  const sockets: Socket[] = [];
  beforeAll(async () => {
    s = await testApp({}, { timeouts: { headersMs: 400, idleMs: 300, requestMs: 4000 } });
    s.app.post('/api/test/echo', async (req) => ({ size: JSON.stringify(req.body).length }));
    await s.app.listen({ host: '127.0.0.1', port: 0 });
    port = (s.app.server.address() as { port: number }).port;
  });
  afterAll(async () => {
    for (const k of sockets) k.destroy();
    await s.close();
  });

  const open = async (): Promise<{ sock: Socket; closed: Promise<void>; received: () => string }> => {
    const sock = connect(port, '127.0.0.1');
    sockets.push(sock);
    sock.on('error', () => {});
    let data = '';
    sock.on('data', (d) => (data += d.toString()));
    const closed = new Promise<void>((resolve) => sock.on('close', () => resolve()));
    await new Promise<void>((resolve) => sock.on('connect', () => resolve()));
    return { sock, closed, received: () => data };
  };
  const head = (length: number) =>
    `POST /api/test/echo HTTP/1.1\r\nHost: x\r\nContent-Type: application/json\r\nContent-Length: ${length}\r\n\r\n`;
  const within = (p: Promise<void>, ms: number) =>
    Promise.race([p.then(() => true), new Promise<boolean>((r) => setTimeout(() => r(false), ms))]);

  test('eine Anfrage, die ihren Körper nie beendet, bekommt ihre Verbindung geschlossen', async () => {
    const { sock, closed } = await open();
    sock.write(head(1000) + '{"a":');
    expect(await within(closed, 3000)).toBe(true);
  });

  test('Kopfzeilen, die nie fertig werden, bekommen ihre Verbindung geschlossen', async () => {
    const { sock, closed } = await open();
    sock.write('POST /api/test/echo HTTP/1.1\r\nHost: x\r\n');
    expect(await within(closed, 3000)).toBe(true);
  });

  test('ein langsamer, aber stetiger Upload innerhalb der Gesamtzeit wird nicht abgeschnitten', async () => {
    const { sock, closed, received } = await open();
    const body = JSON.stringify({ t: 'x'.repeat(30) });
    sock.write(head(body.length));
    // Der Körper dauert insgesamt länger als die Ruhegrenze, aber nie schweigt die Verbindung so lange.
    for (const ch of body) {
      sock.write(ch);
      await new Promise((r) => setTimeout(r, 40));
    }
    await new Promise((r) => setTimeout(r, 100));
    expect(received()).toMatch(/^HTTP\/1\.1 200/);
    expect(received()).toContain('"size"');
    sock.end();
    await closed;
  });
});
