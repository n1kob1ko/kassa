import { afterAll, beforeAll, expect, test } from 'vitest';
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
