import { randomUUID } from 'node:crypto';
import { afterAll, beforeAll, describe, expect, test } from 'vitest';
import { loggerOptions } from '../src/app.js';
import { withBusiness } from '../src/db/tenant.js';
import { testApp, type TestApp } from './support/app.js';
import { fixtureBusiness, pairDevice } from './support/device.js';
import { entry, pushEntries } from './support/push.js';
import type { TestUser } from './support/users.js';

let f: TestApp;
let provider: TestUser;
let businessId: string;
let token: string;
let registerId: string;
const deviceId: string = randomUUID();
const logLines: string[] = [];

beforeAll(async () => {
  f = await testApp({}, { logger: loggerOptions({ write: (s: string) => void logLines.push(s) }) });
  ({ provider, businessId } = await fixtureBusiness(f));
  ({ token, registerId } = await pairDevice(f.app, provider.cookie, businessId));
});
afterAll(async () => {
  await f.close();
});

const stored = (biz: string, reg: string) =>
  withBusiness(f.db, biz, async (c) => (await c.query(`select * from reports where source = 'device' and register_id = $1 order by received_at, id`, [reg])).rows);
const errorReport = (overrides: Record<string, unknown> = {}) => ({
  id: randomUUID(),
  kind: 'error',
  at: '2026-11-18T09:59:00.000Z',
  appVersion: '1.5.0',
  androidVersion: '14',
  deviceModel: 'Redmi Pad Pro',
  count: 3,
  error: { type: 'RangeError', message: null, stack: 'at foo (bar.dart:1)' },
  devices: null,
  ...overrides,
});
const send = (reports: object[], t = token) =>
  pushEntries(f.app, t, deviceId, reports.map((r, i) => entry(i + 1, 'report', r)));

describe('report', () => {
  test('Bericht liegt mit festen Feldern am Server und im Protokoll', async () => {
    const r = errorReport();
    const res = await send([r]);
    expect(res.results).toEqual([{ seq: 1, status: 'accepted' }]);
    const rows = await stored(businessId, registerId);
    expect(rows).toHaveLength(1);
    expect(rows[0]).toMatchObject({
      id: r.id, kind: 'error', source: 'device', app_version: '1.5.0', android_version: '14', device_model: 'Redmi Pad Pro', count: 3,
      content: { error: { type: 'RangeError', message: null, stack: 'at foo (bar.dart:1)' }, devices: null },
    });
    expect(rows[0].at.toISOString()).toBe('2026-11-18T09:59:00.000Z');
    const line = logLines.map((l) => JSON.parse(l)).find((l) => l.msg === 'bericht');
    expect(line).toMatchObject({ businessId, registerId, report: 'error', appVersion: '1.5.0', errorType: 'RangeError' });
    expect(JSON.stringify(line)).not.toContain('bar.dart');
    expect(JSON.stringify(line)).not.toContain(token);

    // Noch einmal gesendet: duplicate, nichts doppelt.
    const again = await send([r]);
    expect(again.results).toEqual([{ seq: 1, status: 'duplicate' }]);
    expect(await stored(businessId, registerId)).toHaveLength(1);
  });

  test('Gerätetest wird mit der Liste der Geräte gespeichert', async () => {
    const r = errorReport({ kind: 'device_test', error: null, devices: [{ device: 'printer', ok: true, text: 'Drucker bereit' }] });
    expect((await send([r])).results[0]!.status).toBe('accepted');
    const row = (await stored(businessId, registerId)).find((x) => x.id === r.id);
    expect(row).toMatchObject({ kind: 'device_test', content: { error: null, devices: [{ device: 'printer', ok: true, text: 'Drucker bereit' }] } });
  });

  test('der 51. Bericht des Tages wird angenommen und nicht gespeichert', async () => {
    // Eine zweite Kassa desselben Betriebs, damit die Zahl der anderen Tests nicht mitzählt.
    const paired = await pairDevice(f.app, provider.cookie, businessId);
    const reports = Array.from({ length: 51 }, () => errorReport());
    const first = await send(reports.slice(0, 50), paired.token);
    expect(first.results.every((x) => x.status === 'accepted')).toBe(true);
    const last = await send([reports[50]!], paired.token);
    expect(last.results).toEqual([{ seq: 1, status: 'accepted' }]);
    expect(await stored(businessId, paired.registerId)).toHaveLength(50);

    // Am nächsten Tag zählt wieder von vorn.
    f.now.value = new Date(f.now.value.getTime() + 24 * 3600 * 1000);
    await send([errorReport()], paired.token);
    expect(await stored(businessId, paired.registerId)).toHaveLength(51);
    f.now.value = new Date('2026-11-18T10:00:00Z');
  });

  test('Bericht mit unbekanntem Feld "receipt": das Feld wird nicht gespeichert', async () => {
    const r = errorReport({ receipt: { number: 1, totalCents: 990 }, extra: 'x' });
    expect((await send([r])).results[0]!.status).toBe('accepted');
    const row = (await stored(businessId, registerId)).find((x) => x.id === r.id);
    expect(JSON.stringify(row)).not.toContain('receipt');
    expect(JSON.stringify(row)).not.toContain('990');
    expect(row.content).toEqual({ error: { type: 'RangeError', message: null, stack: 'at foo (bar.dart:1)' }, devices: null });
  });

  test('unlesbarer Bericht: rejected/invalid', async () => {
    const tooLong = errorReport({ error: { type: 'X', message: 'a'.repeat(501), stack: 's' } });
    const noError = errorReport({ error: null });
    const res = await send([tooLong, noError, errorReport({ kind: 'anderes' })]);
    expect(res.results.map((x) => `${x.status}/${x.reason}`)).toEqual(['rejected/invalid', 'rejected/invalid', 'rejected/invalid']);
  });
});
