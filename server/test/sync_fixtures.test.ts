// Die Beispieldateien in shared/fixtures/sync sind echte Antworten dieses Servers. Die Tablet-App testet gegen sie.
// Neu schreiben: KASSA_WRITE_FIXTURES=1 npx vitest run test/sync_fixtures.test.ts
import { afterAll, beforeAll, expect, test } from 'vitest';
import { testApp, type TestApp } from './support/app.js';
import { createBusiness } from './support/businesses.js';
import {
  changedMenu,
  createPairingCode,
  expectSyncFixture,
  fixtureBusiness,
  normalize,
  pull,
  reimport,
  syncFixture,
} from './support/device.js';
import { authed, type TestUser } from './support/users.js';

const CODE = 48201937;

let f: TestApp;
let provider: TestUser;
let businessId: string;
beforeAll(async () => {
  let draw = CODE;
  // Der erste Code ist der aus pair_request.json, alle weiteren zählen hoch.
  f = await testApp({ randomCode: () => draw++ });
  ({ provider, businessId } = await fixtureBusiness(f));
});
afterAll(async () => {
  await f.close();
});

const pairReq = (payload: object, ip = '10.1.0.1') =>
  f.app.inject({ method: 'POST', url: '/api/device/pair', payload, remoteAddress: ip });
const error = (res: { statusCode: number; json(): unknown }) => ({ status: res.statusCode, body: normalize(res.json()) });

test('Koppeln, ganzes und geändertes Holen und Fehler wie in shared/fixtures/sync', async () => {
  const request = { code: String(CODE), previousBusinessId: null, appVersion: '1.2.0', deviceModel: 'Redmi Pad Pro' };
  expect(await createPairingCode(f.app, provider.cookie, businessId)).toBe(String(CODE));
  expectSyncFixture('pair_request', request);
  const paired = await pairReq(syncFixture('pair_request') as object);
  expect(paired.statusCode).toBe(200);
  expectSyncFixture('pair_response', normalize(paired.json()));
  const { token, registerId } = paired.json();

  const full = await pull(f.app, token, '?since=0');
  expect(full.statusCode).toBe(200);
  expectSyncFixture('pull_full', normalize(full.json()));

  await reimport(f.app, provider.cookie, businessId, changedMenu());
  const delta = await pull(f.app, token, `?since=${full.json().next}`);
  expect(delta.statusCode).toBe(200);
  expectSyncFixture('pull_delta', normalize(delta.json()));

  // Fehler
  const invalidCode = await pairReq(request);
  expect(invalidCode.statusCode).toBe(404);

  const other = (await createBusiness(f.app, provider.cookie)).id;
  const otherBusiness = await pairReq({ ...request, code: await createPairingCode(f.app, provider.cookie, businessId), previousBusinessId: other });
  expect(otherBusiness.statusCode).toBe(409);

  for (let i = 0; i < 10; i++) expect((await pairReq({ ...request, code: '00000000' }, '10.1.0.2')).statusCode).toBe(404);
  const tooMany = await pairReq(request, '10.1.0.2');
  expect(tooMany.statusCode).toBe(429);

  const unauthorized = await pull(f.app, 'kein-gueltiger-schluessel', '?since=0');
  expect(unauthorized.statusCode).toBe(401);

  const sinceInvalid = await pull(f.app, token, '?since=abc');
  expect(sinceInvalid.statusCode).toBe(422);
  const limitInvalid = await pull(f.app, token, '?since=0&limit=0');
  expect(limitInvalid.statusCode).toBe(422);

  const blockRes = await f.app.inject({
    method: 'POST',
    url: `/api/admin/businesses/${businessId}/registers/${registerId}/block`,
    headers: authed(provider.cookie),
    payload: {},
  });
  expect(blockRes.statusCode).toBe(200);
  const blocked = await pull(f.app, token, '?since=0');
  expect(blocked.statusCode).toBe(403);

  expectSyncFixture('errors', {
    invalid_code: error(invalidCode),
    too_many_attempts: error(tooMany),
    other_business: error(otherBusiness),
    unauthorized: error(unauthorized),
    register_blocked: error(blocked),
    since_invalid: error(sinceInvalid),
    limit_invalid: error(limitInvalid),
  });
});
