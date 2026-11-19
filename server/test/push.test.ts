import { randomUUID } from 'node:crypto';
import { afterAll, beforeAll, describe, expect, test } from 'vitest';
import { handlers } from '../src/device/push.js';
import { withBusiness } from '../src/db/tenant.js';
import { testApp, type TestApp } from './support/app.js';
import { createBusiness } from './support/businesses.js';
import { createStaff, fixtureBusiness, pairDevice, syncFixture } from './support/device.js';
import { entry, pushEntries, sampleDay, sampleReceipt } from './support/push.js';
import { authed, type TestUser } from './support/users.js';

let f: TestApp;
let provider: TestUser;
let businessId: string;
let token: string;
let registerId: string;
const deviceId: string = randomUUID();

beforeAll(async () => {
  f = await testApp();
  ({ provider, businessId } = await fixtureBusiness(f));
  ({ token, registerId } = await pairDevice(f.app, provider.cookie, businessId));
});
afterAll(async () => {
  await f.close();
});

const rows = (biz: string, sql: string, params: unknown[] = []) =>
  withBusiness(f.db, biz, async (c) => (await c.query(sql, params)).rows);
const count = async (biz: string, table: string) => Number((await rows(biz, `select count(*)::int as n from ${table}`))[0].n);
const reports = (biz: string, kind: string) => rows(biz, 'select * from reports where kind = $1 and source = $2', [kind, 'server']);
const send = (entries: object[], t = token, d: string = deviceId) => pushEntries(f.app, t, d, entries);
const statuses = (r: { results: { status: string; reason?: string }[] }) => r.results.map((x) => (x.reason ? `${x.status}/${x.reason}` : x.status));

const fixtureRequest = syncFixture('push_request') as { deviceId: string; entries: object[] };

describe('Beispielpaket', () => {
  test('Paket aus push_request.json wird angenommen und liegt am Server', async () => {
    const res = await send(fixtureRequest.entries, token, fixtureRequest.deviceId);
    expect(res.status).toBe(200);
    expect(statuses(res)).toEqual(['accepted', 'accepted', 'accepted', 'accepted', 'accepted', 'rejected/invalid', 'rejected/invalid']);
    expect(res.results.map((r) => r.seq)).toEqual([1, 2, 3, 4, 5, 6, 7]);

    const [receipt] = await rows(businessId, 'select * from receipts');
    expect(receipt).toMatchObject({ number: 1, kind: 'sale', goods_cents: 990, total_cents: 990, payment_kind: 'cash', is_test: true, register_id: registerId });
    expect(receipt.payload.rksv.position).toBe(2);
    const [line] = await rows(businessId, 'select * from receipt_lines');
    expect(line).toMatchObject({ item_id: 'huhn-bowl', quantity: 1, gross10_cents: 990, gross20_cents: 0 });
    expect(line.options).toEqual([{ groupName: 'Größe', optionName: 'Normal', surchargeCents: 0 }]);
    const [day] = await rows(businessId, 'select * from business_days');
    expect(day).toMatchObject({ opening_float_cents: 10000, closed_at: null, device_id: fixtureRequest.deviceId });
    const [movement] = await rows(businessId, 'select * from cash_movements');
    expect(movement).toMatchObject({ kind: 'withdrawal', amount_cents: 2000, reason: 'bank', staff_name: 'Chefin' });
    const [cert] = await rows(businessId, 'select * from rksv_certificates');
    expect(cert).toMatchObject({ serial_hex: '1a2b', device_id: fixtureRequest.deviceId });
    expect(cert.certificate).toEqual(Buffer.from([1, 2, 3, 4, 5, 6]));
    const [chain] = await rows(businessId, 'select * from rksv_chains');
    expect(chain).toMatchObject({ chain: 1, mode: 'probe', cash_box_id: 'KASSA1', ended_at: null });
    const [rksv] = await rows(businessId, 'select * from rksv_entries');
    expect(rksv).toMatchObject({ chain: 1, position: 2, damaged: false, cert_serial: '1a2b' });
    const [reg] = await rows(businessId, 'select device_id from registers where id = $1', [registerId]);
    expect(reg.device_id).toBe(fixtureRequest.deviceId);
  });

  test('dasselbe Paket noch einmal: alles duplicate, nichts doppelt', async () => {
    const tables = ['receipts', 'receipt_lines', 'business_days', 'cash_movements', 'rksv_certificates', 'rksv_chains', 'rksv_entries'];
    const before = await Promise.all(tables.map((t) => count(businessId, t)));
    const res = await send(fixtureRequest.entries, token, fixtureRequest.deviceId);
    expect(res.status).toBe(200);
    // Der offene Tag und die offene Kette werden überschrieben, das ist kein neuer Eintrag.
    expect(statuses(res)).toEqual(['duplicate', 'accepted', 'accepted', 'duplicate', 'duplicate', 'rejected/invalid', 'rejected/invalid']);
    const after = await Promise.all(tables.map((t) => count(businessId, t)));
    expect(after).toEqual(before);
    expect(await count(businessId, 'reports')).toBe(0);
  });
});

describe('Annahme', () => {
  let b2: string;
  let t2: string;
  beforeAll(async () => {
    b2 = (await createBusiness(f.app, provider.cookie)).id;
    await createStaff(f.app, provider.cookie, b2, { name: 'Chefin', role: 'chef', pin: '1234' });
    t2 = (await pairDevice(f.app, provider.cookie, b2)).token;
  });

  test('gleicher Bon mit anderem Betrag: rejected/conflict, Server behält seine Fassung, Bericht receipt_conflict', async () => {
    const r = sampleReceipt();
    expect(statuses(await send([entry(1, 'receipt', r)]))).toEqual(['accepted']);
    const changed = { ...r, goodsCents: 1000, totalCents: 1000 };
    expect(statuses(await send([entry(1, 'receipt', changed)]))).toEqual(['rejected/conflict']);
    const [row] = await rows(businessId, 'select total_cents from receipts where id = $1', [r.id]);
    expect(row.total_cents).toBe(990);
    const found = await reports(businessId, 'receipt_conflict');
    expect(found).toHaveLength(1);
    expect(JSON.stringify(found[0].content)).not.toContain('Huhn');
  });

  test('Bon mit unbekanntem Tag wird angenommen', async () => {
    expect(statuses(await send([entry(1, 'receipt', sampleReceipt({ businessDayId: randomUUID() }))]))).toEqual(['accepted']);
  });

  test('Summen passen nicht: angenommen, Bericht receipt_sums', async () => {
    const before = (await reports(businessId, 'receipt_sums')).length;
    const bad = sampleReceipt({ totalCents: 1500 });
    expect(statuses(await send([entry(1, 'receipt', bad)]))).toEqual(['accepted']);
    const found = await reports(businessId, 'receipt_sums');
    expect(found).toHaveLength(before + 1);
    expect(found[0].content.problems).toEqual(['goods_plus_deposit', 'payment']);
    // Ein passender Bon erzeugt keinen Bericht.
    await send([entry(1, 'receipt', sampleReceipt())]);
    expect(await reports(businessId, 'receipt_sums')).toHaveLength(before + 1);
    // Zeilen, die nicht zur Warensumme passen.
    await send([entry(1, 'receipt', sampleReceipt({ goodsCents: 500, totalCents: 500, payment: null, kind: 'zero' }))]);
    expect(await reports(businessId, 'receipt_sums')).toHaveLength(before + 2);
  });

  test('offener Tag wird überschrieben, abgeschlossener ist endgültig', async () => {
    const day = sampleDay();
    expect(statuses(await send([entry(1, 'day', day)]))).toEqual(['accepted']);
    const changed = { ...day, openingFloatCents: 12000 };
    expect(statuses(await send([entry(1, 'day', changed)]))).toEqual(['accepted']);
    expect((await rows(businessId, 'select opening_float_cents from business_days where id = $1', [day.id]))[0].opening_float_cents).toBe(12000);

    const closed = { ...changed, closedAt: '2026-11-19T18:00:00.000Z', countedCents: 15000, leftInDrawerCents: 5000, expectedCents: 15000, differenceCents: 0, closedByName: 'Chefin' };
    expect(statuses(await send([entry(1, 'day', closed)]))).toEqual(['accepted']);
    expect(statuses(await send([entry(1, 'day', closed)]))).toEqual(['duplicate']);
    // Ein später ankommender älterer, offener Stand ändert nichts.
    expect(statuses(await send([entry(1, 'day', day)]))).toEqual(['rejected/conflict']);
    const [row] = await rows(businessId, 'select closed_at, counted_cents from business_days where id = $1', [day.id]);
    expect(row.counted_cents).toBe(15000);
    expect(row.closed_at).not.toBeNull();
    expect(await reports(businessId, 'day_conflict')).toHaveLength(1);
  });

  test('gleiche Kennung mit anderer Zeit: Bon, abgeschlossener Tag, beendete Kette und Bewegung sind rejected/conflict', async () => {
    const dev = randomUUID();
    const r = sampleReceipt();
    expect(statuses(await send([entry(1, 'receipt', r)]))).toEqual(['accepted']);
    expect(statuses(await send([entry(1, 'receipt', { ...r, createdAt: '2026-11-19T08:06:00.000Z' })]))).toEqual(['rejected/conflict']);
    expect(statuses(await send([entry(1, 'receipt', { ...r, createdAt: '2026-11-19T08:05:00Z' })]))).toEqual(['duplicate']);

    const closed = sampleDay({ closedAt: '2026-11-19T18:00:00.000Z', countedCents: 1, leftInDrawerCents: 1, expectedCents: 1, differenceCents: 0, closedByName: 'C' });
    expect(statuses(await send([entry(1, 'day', closed)]))).toEqual(['accepted']);
    const before = (await reports(businessId, 'day_conflict')).length;
    expect(statuses(await send([entry(1, 'day', { ...closed, closedAt: '2026-11-19T18:30:00.000Z' })]))).toEqual(['rejected/conflict']);
    expect(await reports(businessId, 'day_conflict')).toHaveLength(before + 1);
    expect(statuses(await send([entry(1, 'day', { ...closed, openedAt: '2026-11-19T07:00:00.000Z' })]))).toEqual(['rejected/conflict']);

    const chain = { chain: 5, mode: 'live', cashBoxId: 'K', zdaId: 'AT0', certSerial: 'ff', startedAt: '2026-11-19T07:00:00.000Z', endedAt: '2026-11-19T20:00:00.000Z' };
    expect(statuses(await send([entry(1, 'rksv_chain', chain)], token, dev))).toEqual(['accepted']);
    expect(statuses(await send([entry(1, 'rksv_chain', { ...chain, endedAt: '2026-11-19T21:00:00.000Z' })], token, dev))).toEqual(['rejected/conflict']);

    const mv = { id: randomUUID(), businessDayId: randomUUID(), kind: 'deposit', amountCents: 500, reason: null, createdAt: '2026-11-19T09:00:00.000Z', staffId: 's', staffName: 'S' };
    expect(statuses(await send([entry(1, 'cash_movement', mv)]))).toEqual(['accepted']);
    expect(statuses(await send([entry(1, 'cash_movement', { ...mv, createdAt: '2026-11-19T09:01:00.000Z' })]))).toEqual(['rejected/conflict']);
  });

  test('offener Tag und offene Kette wandern mit der neuen Kassa', async () => {
    const dev = randomUUID();
    const second = await pairDevice(f.app, provider.cookie, businessId);
    const day = sampleDay();
    const chain = { chain: 6, mode: 'probe', cashBoxId: 'K', zdaId: 'AT0', certSerial: 'aa', startedAt: '2026-11-19T07:00:00.000Z', endedAt: null };
    await send([entry(1, 'day', day), entry(2, 'rksv_chain', chain)], token, dev);
    expect((await rows(businessId, 'select register_id from business_days where id = $1', [day.id]))[0].register_id).toBe(registerId);
    await send([entry(1, 'day', day), entry(2, 'rksv_chain', chain)], second.token, dev);
    expect((await rows(businessId, 'select register_id from business_days where id = $1', [day.id]))[0].register_id).toBe(second.registerId);
    expect((await rows(businessId, 'select register_id from rksv_chains where device_id = $1', [dev]))[0].register_id).toBe(second.registerId);
  });

  test('Kette: offen wird überschrieben, beendet ist endgültig; Zertifikat und Bewegung nur anlegen', async () => {
    const dev = randomUUID();
    const chain = { chain: 1, mode: 'live', cashBoxId: 'K', zdaId: 'AT0', certSerial: 'ff', startedAt: '2026-11-19T07:00:00.000Z', endedAt: null };
    expect(statuses(await send([entry(1, 'rksv_chain', chain)], token, dev))).toEqual(['accepted']);
    const ended = { ...chain, endedAt: '2026-11-19T20:00:00.000Z' };
    expect(statuses(await send([entry(1, 'rksv_chain', ended)], token, dev))).toEqual(['accepted']);
    expect(statuses(await send([entry(1, 'rksv_chain', ended)], token, dev))).toEqual(['duplicate']);
    expect(statuses(await send([entry(1, 'rksv_chain', chain)], token, dev))).toEqual(['rejected/conflict']);

    const cert = { serialHex: 'ee', certificate: 'AQID', issuers: [] };
    expect(statuses(await send([entry(1, 'rksv_certificate', cert)], token, dev))).toEqual(['accepted']);
    expect(statuses(await send([entry(1, 'rksv_certificate', cert)], token, dev))).toEqual(['duplicate']);
    expect(statuses(await send([entry(1, 'rksv_certificate', { ...cert, certificate: 'BAUG' })], token, dev))).toEqual(['rejected/conflict']);

    const mv = { id: randomUUID(), businessDayId: randomUUID(), kind: 'deposit', amountCents: 500, reason: null, createdAt: '2026-11-19T09:00:00.000Z', staffId: 's', staffName: 'S' };
    expect(statuses(await send([entry(1, 'cash_movement', mv)]))).toEqual(['accepted']);
    expect(statuses(await send([entry(1, 'cash_movement', mv)]))).toEqual(['duplicate']);
    expect(statuses(await send([entry(1, 'cash_movement', { ...mv, amountCents: 600 })]))).toEqual(['rejected/conflict']);
  });

  test('ein unlesbarer Eintrag in der Mitte: rejected/invalid, die anderen accepted', async () => {
    const res = await send([
      entry(1, 'receipt', sampleReceipt()),
      entry(2, 'receipt', { ...sampleReceipt(), totalCents: 'viel' }),
      { seq: 3, kind: 'unbekannt' },
      entry(4, 'receipt', sampleReceipt()),
    ]);
    expect(statuses(res)).toEqual(['accepted', 'rejected/invalid', 'rejected/invalid', 'accepted']);
  });

  test('ein Eintrag scheitert unerwartet: error, die anderen accepted', async () => {
    const original = handlers.day!;
    handlers.day = async () => {
      throw new Error('kaputt');
    };
    try {
      const res = await send([entry(1, 'receipt', sampleReceipt()), entry(2, 'day', sampleDay()), entry(3, 'receipt', sampleReceipt())]);
      expect(res.results).toEqual([{ seq: 1, status: 'accepted' }, { seq: 2, status: 'error' }, { seq: 3, status: 'accepted' }]);
    } finally {
      handlers.day = original;
    }
  });

  test('Bon kam ohne rksv, kommt später mit: duplicate und Eintrag nachgetragen', async () => {
    const dev = randomUUID();
    const r = sampleReceipt();
    expect(statuses(await send([entry(1, 'receipt', r)], token, dev))).toEqual(['accepted']);
    const withRksv = { ...r, rksv: { chain: 7, position: 1, jws: 'a.b.c', damaged: false, certSerial: 'aa' } };
    expect(statuses(await send([entry(1, 'receipt', withRksv)], token, dev))).toEqual(['duplicate']);
    const [e] = await rows(businessId, 'select * from rksv_entries where receipt_id = $1', [r.id]);
    expect(e).toMatchObject({ chain: 7, position: 1, jws: 'a.b.c' });
    // Noch einmal: nichts doppelt, kein Bericht.
    const conflicts = (await reports(businessId, 'rksv_conflict')).length;
    expect(statuses(await send([entry(1, 'receipt', withRksv)], token, dev))).toEqual(['duplicate']);
    expect(await reports(businessId, 'rksv_conflict')).toHaveLength(conflicts);
  });

  test('Eintrag der Signatur steht schon anders da: Bon-Ergebnis bleibt, Bericht rksv_conflict', async () => {
    const dev = randomUUID();
    const a = sampleReceipt({ rksv: { chain: 9, position: 1, jws: 'x.y.z', damaged: false, certSerial: 'aa' } });
    const b = sampleReceipt({ rksv: { chain: 9, position: 1, jws: 'q.r.s', damaged: false, certSerial: 'aa' } });
    expect(statuses(await send([entry(1, 'receipt', a)], token, dev))).toEqual(['accepted']);
    expect(statuses(await send([entry(1, 'receipt', b)], token, dev))).toEqual(['accepted']);
    expect(await reports(businessId, 'rksv_conflict')).toHaveLength(1);
    expect(await rows(businessId, 'select 1 from receipts where id = $1', [b.id])).toHaveLength(1);
  });

  test('Kette läuft nach neuem Koppeln unter neuer Kassa weiter: ein Protokoll pro deviceId', async () => {
    const dev = randomUUID();
    const conflicts = (await reports(businessId, 'rksv_conflict')).length;
    const second = await pairDevice(f.app, provider.cookie, businessId);
    const chain = { chain: 3, mode: 'probe', cashBoxId: 'K', zdaId: 'AT0', certSerial: 'aa', startedAt: '2026-11-19T07:00:00.000Z', endedAt: null };
    const mk = (position: number) => sampleReceipt({ number: position, rksv: { chain: 3, position, jws: `j.${position}.s`, damaged: false, certSerial: 'aa' } });
    expect(statuses(await send([entry(1, 'rksv_chain', chain), entry(2, 'receipt', mk(1)), entry(3, 'receipt', mk(2))], token, dev))).toEqual(['accepted', 'accepted', 'accepted']);
    expect(statuses(await send([entry(1, 'rksv_chain', chain), entry(2, 'receipt', mk(3))], second.token, dev))).toEqual(['accepted', 'accepted']);
    expect(await rows(businessId, 'select position, register_id from rksv_entries where device_id = $1 and chain = 3 order by position', [dev])).toEqual([
      { position: 1, register_id: registerId },
      { position: 2, register_id: registerId },
      { position: 3, register_id: second.registerId },
    ]);
    expect(await rows(businessId, 'select 1 from rksv_chains where device_id = $1', [dev])).toHaveLength(1);
    expect(await reports(businessId, 'rksv_conflict')).toHaveLength(conflicts);
  });

  test('zweiter Betrieb sieht nichts', async () => {
    const r = sampleReceipt();
    expect(statuses(await send([entry(1, 'receipt', r)]))).toEqual(['accepted']);
    const before = await count(businessId, 'receipts');
    expect(statuses(await pushEntries(f.app, t2, deviceId, [entry(1, 'receipt', { ...r, totalCents: 777, goodsCents: 777 })]))).toEqual(['accepted']);
    expect(await count(businessId, 'receipts')).toBe(before);
    expect((await rows(businessId, 'select total_cents from receipts where id = $1', [r.id]))[0].total_cents).toBe(990);
    expect(await rows(b2, 'select total_cents from receipts')).toEqual([{ total_cents: 777 }]);
  });
});

describe('Anfrage', () => {
  const post = (payload: unknown, auth: string | null = `Bearer ${token}`) =>
    f.app.inject({ method: 'POST', url: '/api/device/sync/push', headers: auth ? { authorization: auth } : {}, payload: payload as object });

  test('101 Einträge: 422 push_invalid', async () => {
    const entries = Array.from({ length: 101 }, (_, i) => ({ seq: i + 1, kind: 'day' }));
    const res = await post({ deviceId, entries });
    expect(res.statusCode).toBe(422);
    expect(res.json().error.code).toBe('push_invalid');
    expect((await post({ entries: [] })).statusCode).toBe(422);
    expect((await post({ deviceId, entries: {} })).statusCode).toBe(422);
    expect((await post({ deviceId, entries: [{ kind: 'day' }] })).statusCode).toBe(422);
    expect((await post({ deviceId, entries: [{ seq: 1 }] })).statusCode).toBe(422);
    const empty = await post({ deviceId, entries: [] });
    expect(empty.statusCode).toBe(200);
    expect(empty.json()).toEqual({ results: [] });
  });

  test('über 2 MB: 413', async () => {
    const res = await post({ deviceId, entries: [{ seq: 1, kind: 'day', pad: 'x'.repeat(2 * 1024 * 1024) }] });
    expect(res.statusCode).toBe(413);
    expect(res.json().error.code).toBe('payload_too_large');
  });

  test('ohne Schlüssel 401, gesperrt 403', async () => {
    expect((await post({ deviceId, entries: [] }, null)).statusCode).toBe(401);
    const other = await pairDevice(f.app, provider.cookie, businessId);
    const block = await f.app.inject({
      method: 'POST',
      url: `/api/admin/businesses/${businessId}/registers/${other.registerId}/block`,
      headers: authed(provider.cookie),
      payload: {},
    });
    expect(block.statusCode).toBe(200);
    const res = await post({ deviceId, entries: [] }, `Bearer ${other.token}`);
    expect(res.statusCode).toBe(403);
    expect(res.json().error.code).toBe('register_blocked');
  });
});
