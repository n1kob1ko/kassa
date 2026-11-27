import { randomUUID } from 'node:crypto';
import { afterAll, beforeAll, beforeEach, describe, expect, test } from 'vitest';
import { handlers } from '../src/device/push.js';
import { withBusiness } from '../src/db/tenant.js';
import { testApp, type TestApp } from './support/app.js';
import { createBusiness } from './support/businesses.js';
import { createStaff, fixtureBusiness, pairDevice, syncFixture } from './support/device.js';
import { asV2, entry, pushEntries, reportKinds, sampleDay, sampleReceipt, sampleReceiptV2 } from './support/push.js';
import { authed, type TestUser } from './support/users.js';
import { randomBytes } from 'node:crypto';
import { withSystem } from '../src/db/tenant.js';
import { asV3, receiptV3 } from './support/push.js';

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
    expect(statuses(res)).toEqual(['accepted', 'accepted', 'accepted', 'accepted', 'accepted', 'accepted', 'accepted']);
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
    expect(statuses(res)).toEqual(['duplicate', 'accepted', 'accepted', 'duplicate', 'duplicate', 'accepted', 'duplicate']);
    const after = await Promise.all(tables.map((t) => count(businessId, t)));
    expect(after).toEqual(before);
    // Der Bericht des Tablets steht einmal da, der Server schreibt keinen eigenen.
    expect(await rows(businessId, "select source from reports")).toEqual([{ source: 'device' }]);
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

  test('Bon mit einem unbekannten Feld: angenommen, das Original steht so da, wie es kam', async () => {
    const r = sampleReceipt({
      tip: { cents: 50, note: 'danke' },
      payment: { ...sampleReceipt().payment, terminal: 'T1' },
    });
    expect(statuses(await send([entry(1, 'receipt', r)]))).toEqual(['accepted']);
    const [row] = await rows(businessId, 'select payload from receipts where id = $1', [r.id]);
    expect(row.payload.tip).toEqual({ cents: 50, note: 'danke' });
    expect(row.payload.payment.terminal).toBe('T1');
    expect(row.payload).toEqual(r);
    // Noch einmal: duplicate, der Prüfwert hängt nur an den bekannten Feldern.
    expect(statuses(await send([entry(1, 'receipt', r)]))).toEqual(['duplicate']);
    expect(statuses(await send([entry(1, 'receipt', { ...r, tip: undefined })]))).toEqual(['duplicate']);
    // Die Verwaltung zeigt den Bon wie jeden anderen.
    const detail = await f.app.inject({ method: 'GET', url: `/api/admin/businesses/${businessId}/receipts/${r.id}`, headers: authed(provider.cookie) });
    expect(detail.statusCode).toBe(200);
    expect(detail.json()).toMatchObject({ id: r.id, totalCents: 990, payments: [{ kind: 'cash', amountCents: 990 }] });
    expect(detail.json().payments[0].terminal).toBeUndefined();
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

describe('Bon v: 1 und v: 2', () => {
  // Jeder Test in einem eigenen Betrieb: so zählen nur seine Berichte.
  let a: string;
  let t: string;
  beforeEach(async () => {
    a = (await createBusiness(f.app, provider.cookie)).id;
    await createStaff(f.app, provider.cookie, a, { name: 'Chefin', role: 'chef', pin: '1234' });
    t = (await pairDevice(f.app, provider.cookie, a)).token;
  });
  const push = (entries: object[]) => pushEntries(f.app, t, deviceId, entries);
  const columns = 'select payment_kind, cash_cents, card_cents, tip_cents, discount_cents from receipts';

  test('v: 2 mit zwei Zahlungen, Trinkgeld und Rabatt: angenommen, die Spalten stimmen', async () => {
    const res = await push([entry(1, 'receipt', sampleReceiptV2())]);
    expect(res.results).toEqual([{ seq: 1, status: 'accepted' }]);
    const [row] = await rows(a, columns);
    expect(row).toEqual({ payment_kind: 'mixed', cash_cents: 1000, card_cents: 536, tip_cents: 64, discount_cents: 284 });
    const lines = await rows(a, 'select discount_cents, discount from receipt_lines order by position');
    expect(lines).toEqual([
      { discount_cents: 58, discount: null },
      { discount_cents: 226, discount: { percent: 10, amountCents: 119, reason: 'regular' } },
    ]);
    expect(await reportKinds(f, a)).toEqual([]);
  });

  test('v: 1 von einem Tablet mit 1.10.0: angenommen, bar steht in cash_cents', async () => {
    expect(statuses(await push([entry(1, 'receipt', sampleReceipt())]))).toEqual(['accepted']); // Barverkauf 9,90
    const [row] = await rows(a, columns);
    expect(row).toEqual({ payment_kind: 'cash', cash_cents: 990, card_cents: 0, tip_cents: 0, discount_cents: 0 });
    const lines = await rows(a, 'select discount_cents, discount from receipt_lines');
    expect(lines).toEqual([{ discount_cents: 0, discount: null }]);
  });

  test('derselbe Bon erst als v: 1, dann als v: 2: duplicate, kein Bericht', async () => {
    const r = sampleReceipt();
    await push([entry(1, 'receipt', r)]);
    const res = await push([entry(2, 'receipt', asV2(r))]);
    expect(res.results).toEqual([{ seq: 2, status: 'duplicate' }]);
    expect(await reportKinds(f, a)).toEqual([]);
  });

  test('Bons, wie 1.10.0 sie sendet, und nach dem Update als v: 2 (echte Sendungen der App): duplicate, kein Bericht', async () => {
    // Beide Dateien schreibt die App: v1 der Code von 1.10.0, as_v2 der heutige aus derselben Datenbank.
    const v1 = syncFixture('receipt_1_10_0_v1') as { entries: { seq: number }[] };
    const v2 = syncFixture('receipt_1_10_0_as_v2') as { entries: { seq: number }[] };
    expect((await push(v1.entries)).results).toEqual(v1.entries.map((e) => ({ seq: e.seq, status: 'accepted' })));
    expect((await push(v2.entries)).results).toEqual(v2.entries.map((e) => ({ seq: e.seq, status: 'duplicate' })));
    expect(await reportKinds(f, a)).toEqual([]);
    expect(await count(a, 'receipts')).toBe(2);
  });

  test('v: 2 mit anderem Betrag als der gespeicherte v: 1: rejected/conflict', async () => {
    const r = sampleReceipt();
    await push([entry(1, 'receipt', r)]);
    const v2 = asV2(r);
    const changed = { ...v2, goodsCents: 1000, totalCents: 1000, payments: [{ ...v2.payments[0], amountCents: 1000 }] };
    expect(statuses(await push([entry(2, 'receipt', changed)]))).toEqual(['rejected/conflict']);
    expect(await reportKinds(f, a)).toEqual(['receipt_conflict']);
    expect((await rows(a, 'select total_cents from receipts where id = $1', [r.id]))[0].total_cents).toBe(990);
  });

  test('v: 2, Summen passen nicht: angenommen, Bericht receipt_sums nennt payments, tip, discount und card_last', async () => {
    const good = sampleReceiptV2();
    const [cash, card] = good.payments;
    // Karte zuerst, zwei Karten, Zahlungen 10 Cent zu wenig, Trinkgeld der Zahlungen 64 statt 70, Zeilen-Rabatt 284 statt 300.
    const bad = sampleReceiptV2({
      tipCents: 70,
      discountCents: 300,
      payments: [
        { ...card, position: 0, amountCents: 500 },
        { ...card, position: 1, amountCents: 26, tipCents: 0, tipStaffId: null, tipStaffName: null },
        { ...cash, position: 2 },
      ],
    });
    expect(statuses(await push([entry(1, 'receipt', bad)]))).toEqual(['accepted']);
    const found = await rows(a, "select content from reports where kind = 'receipt_sums'");
    expect(found).toHaveLength(1);
    expect(found[0].content).toEqual({ receiptId: bad.id, number: bad.number, problems: ['payments', 'tip', 'discount', 'card_last'] });
  });

  test('v: 2, eine Karte, aber nicht an letzter Stelle: angenommen, Bericht receipt_sums nennt nur card_last', async () => {
    const good = sampleReceiptV2();
    const [cash, card] = good.payments;
    const bad = sampleReceiptV2({ payments: [{ ...card, position: 0 }, { ...cash, position: 1 }] });
    expect(statuses(await push([entry(1, 'receipt', bad)]))).toEqual(['accepted']);
    const found = await rows(a, "select content from reports where kind = 'receipt_sums'");
    expect(found).toHaveLength(1);
    expect(found[0].content).toEqual({ receiptId: bad.id, number: bad.number, problems: ['card_last'] });
  });

  test('v: 2, Storno passt: kein Bericht; Storno mit falscher Zahlung: payments', async () => {
    const neg = (p: Record<string, any>) => ({ ...p, amountCents: -p.amountCents, givenCents: 0, changeCents: 0, tipCents: -p.tipCents });
    const r = sampleReceiptV2();
    const voided = (payments: object[]) =>
      sampleReceiptV2({
        kind: 'voided',
        voidsReceiptId: r.id,
        goodsCents: -r.goodsCents,
        depositCents: -r.depositCents,
        totalCents: -r.totalCents,
        tipCents: -r.tipCents,
        discountCents: -r.discountCents,
        lines: r.lines.map((l: Record<string, any>) => ({
          ...l,
          quantity: -l.quantity,
          discountCents: -l.discountCents,
          gross: Object.fromEntries(Object.entries(l.gross as Record<string, number>).map(([k, v]) => [k, -v])),
        })),
        payments,
      });
    expect(statuses(await push([entry(1, 'receipt', voided(r.payments.map(neg)))]))).toEqual(['accepted']);
    expect(await reportKinds(f, a)).toEqual([]);
    const [cash, card] = r.payments.map(neg);
    expect(statuses(await push([entry(2, 'receipt', voided([cash, { ...card, amountCents: -500 }]))]))).toEqual(['accepted']);
    const found = await rows(a, "select content from reports where kind = 'receipt_sums'");
    expect(found.map((x) => x.content.problems)).toEqual([['payments']]);
  });

  test('v: 2 ohne Zahlung (Sonderbeleg): payment_kind null, beide Spalten 0', async () => {
    const zero = sampleReceiptV2({
      kind: 'zero', businessDayId: null, goodsCents: 0, depositCents: 0, totalCents: 0, tipCents: 0, discountCents: 0,
      discount: null, lines: [], payments: [],
    });
    expect(statuses(await push([entry(1, 'receipt', zero)]))).toEqual(['accepted']);
    expect(await rows(a, columns)).toEqual([{ payment_kind: null, cash_cents: 0, card_cents: 0, tip_cents: 0, discount_cents: 0 }]);
    expect(await reportKinds(f, a)).toEqual([]);
  });

  test('v: 3: rejected/invalid', async () => {
    const res = await push([entry(1, 'receipt', { ...sampleReceiptV2(), v: 3 })]);
    expect(statuses(res)).toEqual(['rejected/invalid']);
    expect(await count(a, 'receipts')).toBe(0);
  });

  test('v: 2 mit falscher Zahlungsart, 21 Zahlungen, Stelle 101 oder Prozent 0: rejected/invalid', async () => {
    const r = sampleReceiptV2();
    const [cash] = r.payments;
    const bad = [
      sampleReceiptV2({ payments: [{ ...cash, kind: 'voucher' }] }),
      sampleReceiptV2({ payments: Array.from({ length: 21 }, (_, i) => ({ ...cash, position: i, amountCents: 1 })) }),
      sampleReceiptV2({ payments: [{ ...cash, position: 101 }] }),
      sampleReceiptV2({ discount: { ...r.discount, percent: 0 } }),
      sampleReceiptV2({ discount: { ...r.discount, percent: 101 } }),
      sampleReceiptV2({ payment: r.payments[0], payments: undefined }),
    ];
    const res = await push(bad.map((b, i) => entry(i + 1, 'receipt', b)));
    expect(statuses(res)).toEqual(bad.map(() => 'rejected/invalid'));
    // Fester Betrag ohne Prozent ist erlaubt.
    expect(statuses(await push([entry(9, 'receipt', sampleReceiptV2({ discount: { ...r.discount, percent: null } }))]))).toEqual(['accepted']);
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

  test('2 MB ohne Schlüssel: 401, bevor der Inhalt gelesen wird', async () => {
    const big = { deviceId, entries: [{ seq: 1, kind: 'day', pad: 'x'.repeat(2 * 1024 * 1024) }] };
    const res = await post(big, null);
    expect(res.statusCode).toBe(401);
    expect(res.json().error.code).toBe('unauthorized');
    expect((await post(big, 'Bearer ' + 'a'.repeat(43))).statusCode).toBe(401);
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

describe('Bon v: 3', () => {
  // Jeder Test in einem eigenen Betrieb: so zählen nur seine Bons, Gutscheine und Berichte.
  let a: string;
  let t: string;
  let reg: string;
  beforeEach(async () => {
    a = (await createBusiness(f.app, provider.cookie)).id;
    await createStaff(f.app, provider.cookie, a, { name: 'Chefin', role: 'chef', pin: '1234' });
    ({ token: t, registerId: reg } = await pairDevice(f.app, provider.cookie, a));
  });
  const push = (entries: object[]) => pushEntries(f.app, t, deviceId, entries);
  /** Der Schlüssel der Seite gilt über alle Betriebe: jeder Test bekommt eigene. */
  const newToken = () => randomBytes(16).toString('base64url');
  const v3 = (seq: number, overrides: Record<string, unknown> = {}) => receiptV3(seq, { publicToken: newToken(), ...overrides });
  const columns = (id: string) =>
    rows(a, 'select payment_kind, cash_cents, card_cents, voucher_cents, voucher_sale_cents, deposit_return_cents, total_cents from receipts where id = $1', [id]);
  const movements = () =>
    rows(a, 'select voucher_id, receipt_id, kind, amount_cents, change_seq from voucher_movements order by change_seq');
  const VOUCHER = '3b000000-0000-4000-8000-0000000000a1';
  const TABLES = ['receipts', 'receipt_lines', 'receipt_links', 'vouchers', 'voucher_movements'];
  /** Wie count, aber receipt_links hat keinen Zeilen-Schutz: dort zählen nur die Zeilen von [biz]. */
  const countOf = async (biz: string, table: string) =>
    table === 'receipt_links'
      ? Number((await rows(biz, 'select count(*)::int as n from receipt_links where business_id = $1', [biz]))[0].n)
      : count(biz, table);

  test('v: 3 mit Gutschein-Verkauf: Gutschein, Bewegung sale, voucher_sale_cents; noch einmal gesendet: duplicate, nichts doppelt', async () => {
    const r = v3(1);
    expect(statuses(await push([entry(1, 'receipt', r)]))).toEqual(['accepted']);
    expect(await columns(r.id)).toEqual([
      { payment_kind: 'cash', cash_cents: 2845, card_cents: 0, voucher_cents: 0, voucher_sale_cents: 2500, deposit_return_cents: 0, total_cents: 2845 },
    ]);
    const [voucher] = await rows(a, 'select * from vouchers');
    expect(voucher).toMatchObject({
      business_id: a, id: VOUCHER, code: '12345678', value_cents: 2500, is_test: true, sold_receipt_id: r.id, register_id: reg,
    });
    expect(voucher.created_at.toISOString()).toBe('2026-11-27T09:00:00.000Z');
    expect(Number(voucher.change_seq)).toBeGreaterThan(0);
    const moved = await movements();
    expect(moved.map(({ change_seq, ...m }) => m)).toEqual([{ voucher_id: VOUCHER, receipt_id: r.id, kind: 'sale', amount_cents: 2500 }]);
    expect(Number(moved[0].change_seq)).toBeGreaterThan(0);

    const before = await Promise.all(TABLES.map((x) => countOf(a, x)));
    expect(before).toEqual([1, 2, 1, 1, 1]);
    expect((await push([entry(2, 'receipt', r)])).results).toEqual([{ seq: 2, status: 'duplicate' }]);
    expect(await Promise.all(TABLES.map((x) => countOf(a, x)))).toEqual(before);
    expect(await reportKinds(f, a)).toEqual([]);
  });

  test('v: 3 mit Gutschein-Zahlung und Rest bar: payment_kind mixed, voucher_cents 500, Bewegung redeem -500', async () => {
    // Der Verkauf des Gutscheins ist am Server noch nicht da: der Bon gilt trotzdem, das Tablet hat ihn signiert.
    const r = v3(2);
    expect(statuses(await push([entry(1, 'receipt', r)]))).toEqual(['accepted']);
    expect(await columns(r.id)).toEqual([
      { payment_kind: 'mixed', cash_cents: 490, card_cents: 0, voucher_cents: 500, voucher_sale_cents: 0, deposit_return_cents: 0, total_cents: 990 },
    ]);
    expect((await movements()).map(({ change_seq, ...m }) => m)).toEqual([
      { voucher_id: VOUCHER, receipt_id: r.id, kind: 'redeem', amount_cents: -500 },
    ]);
    expect(await count(a, 'vouchers')).toBe(0);
    expect(await reportKinds(f, a)).toEqual([]);

    // Nur mit Gutschein bezahlt: payment_kind voucher.
    const only = v3(2, {
      id: randomUUID(),
      payments: [{ ...r.payments[0], amountCents: 990, givenCents: 990, voucherBalanceAfterCents: 1510 }],
    });
    expect(statuses(await push([entry(2, 'receipt', only)]))).toEqual(['accepted']);
    expect((await columns(only.id))[0]).toMatchObject({ payment_kind: 'voucher', cash_cents: 0, voucher_cents: 990 });
    expect(await reportKinds(f, a)).toEqual([]);
  });

  test('v: 3 Storno: Bewegungen void_redeem und void_sale mit umgekehrtem Vorzeichen', async () => {
    const [sale, redeem, voidRedeem, voidSale] = [v3(1), v3(2), v3(3), v3(5)];
    const res = await push([sale, redeem, voidRedeem, voidSale].map((r, i) => entry(i + 1, 'receipt', r)));
    expect(statuses(res)).toEqual(['accepted', 'accepted', 'accepted', 'accepted']);
    expect((await movements()).map(({ change_seq, ...m }) => m)).toEqual([
      { voucher_id: VOUCHER, receipt_id: sale.id, kind: 'sale', amount_cents: 2500 },
      { voucher_id: VOUCHER, receipt_id: redeem.id, kind: 'redeem', amount_cents: -500 },
      { voucher_id: VOUCHER, receipt_id: voidRedeem.id, kind: 'void_redeem', amount_cents: 500 },
      { voucher_id: VOUCHER, receipt_id: voidSale.id, kind: 'void_sale', amount_cents: -2500 },
    ]);
    // Ein Gutschein, mit seinem Wert vom Verkauf; das Storno legt keinen an.
    expect(await rows(a, 'select id, value_cents, sold_receipt_id from vouchers')).toEqual([
      { id: VOUCHER, value_cents: 2500, sold_receipt_id: sale.id },
    ]);
    expect(await columns(voidRedeem.id)).toEqual([
      { payment_kind: 'mixed', cash_cents: -490, card_cents: 0, voucher_cents: -500, voucher_sale_cents: 0, deposit_return_cents: 0, total_cents: -990 },
    ]);
    expect((await columns(voidSale.id))[0]).toMatchObject({ payment_kind: 'cash', cash_cents: -2845, voucher_sale_cents: -2500 });
    expect(await reportKinds(f, a)).toEqual([]);
  });

  test('v: 3 nur Pfand zurück: total_cents -75, deposit_return_cents -75, cash_cents -75', async () => {
    const r = v3(4);
    expect(statuses(await push([entry(1, 'receipt', r)]))).toEqual(['accepted']);
    expect(await columns(r.id)).toEqual([
      { payment_kind: 'cash', cash_cents: -75, card_cents: 0, voucher_cents: 0, voucher_sale_cents: 0, deposit_return_cents: -75, total_cents: -75 },
    ]);
    expect(await count(a, 'voucher_movements')).toBe(0);
    expect(await reportKinds(f, a)).toEqual([]);
  });

  test('v: 3 mit publicToken: Zeile in receipt_links; derselbe Schlüssel bei einem zweiten Bon ist invalid', async () => {
    const r = v3(1);
    expect(statuses(await push([entry(1, 'receipt', r)]))).toEqual(['accepted']);
    expect(await rows(a, 'select token, business_id, receipt_id from receipt_links where business_id = $1', [a])).toEqual([
      { token: r.publicToken, business_id: a, receipt_id: r.id },
    ]);
    expect((await rows(a, 'select public_token from receipts where id = $1', [r.id]))[0].public_token).toBe(r.publicToken);
    // Die Seite sucht ohne Betrieb: die Zeile ist auch ohne gesetzten Betrieb zu finden.
    const found = await withSystem(f.db, async (c) => (await c.query('select receipt_id from receipt_links where token = $1', [r.publicToken])).rows);
    expect(found).toEqual([{ receipt_id: r.id }]);

    const second = v3(4, { id: randomUUID(), publicToken: r.publicToken });
    expect(statuses(await push([entry(2, 'receipt', second)]))).toEqual(['rejected/invalid']);
    expect(await count(a, 'receipts')).toBe(1);
    expect(await countOf(a, 'receipt_links')).toBe(1);
    // Auch in einem anderen Betrieb.
    const b = (await createBusiness(f.app, provider.cookie)).id;
    await createStaff(f.app, provider.cookie, b, { name: 'Chefin', role: 'chef', pin: '1234' });
    const tb = (await pairDevice(f.app, provider.cookie, b)).token;
    expect(statuses(await pushEntries(f.app, tb, deviceId, [entry(1, 'receipt', v3(4, { publicToken: r.publicToken }))]))).toEqual(['rejected/invalid']);
    expect(await count(b, 'receipts')).toBe(0);
    expect(await withSystem(f.db, async (c) => (await c.query('select receipt_id from receipt_links where token = $1', [r.publicToken])).rows)).toEqual(found);
  });

  test('receipt_1_11_0_v2.json, dann receipt_1_11_0_as_v3.json: duplicate, kein Bericht', async () => {
    // Beide Dateien schreibt die App: v2 der Code von 1.11.0, as_v3 der heutige aus derselben Datenbank.
    const v2 = syncFixture('receipt_1_11_0_v2') as { entries: { seq: number; receipt: { v: number } }[] };
    const as3 = syncFixture('receipt_1_11_0_as_v3') as { entries: { seq: number; receipt: { v: number } }[] };
    expect(v2.entries.map((e) => e.receipt.v)).toEqual([2]);
    expect(as3.entries.map((e) => e.receipt.v)).toEqual([3]);
    expect((await push(v2.entries)).results).toEqual(v2.entries.map((e) => ({ seq: e.seq, status: 'accepted' })));
    expect((await push(as3.entries)).results).toEqual(as3.entries.map((e) => ({ seq: e.seq, status: 'duplicate' })));
    expect(await reportKinds(f, a)).toEqual([]);
    expect(await count(a, 'receipts')).toBe(1);
  });

  test('receipt_1_10_0_v1.json, dann derselbe Bon als v: 3: duplicate, kein Bericht', async () => {
    const v1 = syncFixture('receipt_1_10_0_v1') as { entries: { seq: number; kind: string; receipt: Record<string, any> }[] };
    expect((await push(v1.entries)).results).toEqual(v1.entries.map((e) => ({ seq: e.seq, status: 'accepted' })));
    const again = v1.entries.map((e) => ({ ...e, receipt: asV3(asV2(e.receipt)) }));
    expect((await push(again)).results).toEqual(again.map((e) => ({ seq: e.seq, status: 'duplicate' })));
    expect(await reportKinds(f, a)).toEqual([]);
    expect(await count(a, 'receipts')).toBe(2);
    // Mit anderem Betrag ist es ein Konflikt, wie bei v: 2.
    const r = again[0]!.receipt;
    const changed = { ...r, goodsCents: r.goodsCents + 1, totalCents: r.totalCents + 1 };
    expect(statuses(await push([entry(9, 'receipt', changed)]))).toEqual(['rejected/conflict']);
  });

  test('v: 3 mit bar vor Gutschein, mit Karte unter 0, mit Gutschein-Zeile und Gutschein-Zahlung: invalid', async () => {
    const redeem = v3(2);
    const [voucherPay, cashPay] = redeem.payments;
    const payout = v3(4);
    const sale = v3(1);
    const voided = v3(3);
    const [voidVoucher, voidCash] = voided.payments;
    const card = { ...payout.payments[0], kind: 'card', provider: 'demo' };
    const bad = [
      // Bar vor Gutschein.
      { ...redeem, payments: [{ ...cashPay, position: 0 }, { ...voucherPay, position: 1 }] },
      // Zwei Bar-Zahlungen.
      { ...redeem, payments: [voucherPay, { ...cashPay, amountCents: 245 }, { ...cashPay, position: 2, amountCents: 245 }] },
      // Karte unter 0 im Verkauf.
      { ...payout, payments: [card] },
      // Bar unter 0 bei einer Summe über 0.
      { ...redeem, payments: [{ ...voucherPay, amountCents: 1000, givenCents: 1000 }, { ...cashPay, amountCents: -10, givenCents: 0, changeCents: 0 }] },
      // Gutschein-Zeile und Gutschein-Zahlung.
      { ...sale, payments: [{ ...voucherPay, amountCents: 2845, givenCents: 2845, voucherBalanceAfterCents: 0 }] },
      // Storno gespiegelt: Bar über 0.
      { ...voided, payments: [{ ...voidVoucher, amountCents: -1000 }, { ...voidCash, amountCents: 10 }] },
      // Storno gespiegelt: Bar vor Gutschein.
      { ...voided, payments: [{ ...voidCash, position: 0 }, { ...voidVoucher, position: 1 }] },
      // Gutschein-Zahlung ohne Gutschein.
      { ...redeem, payments: [{ ...voucherPay, voucherId: null }, cashPay] },
      // Gutschein mit Code, der keine 8 Ziffern hat.
      { ...sale, vouchers: [{ ...sale.vouchers[0], code: '1234' }] },
    ];
    const res = await push(bad.map((b, i) => entry(i + 1, 'receipt', b)));
    expect(statuses(res)).toEqual(bad.map(() => 'rejected/invalid'));
    for (const x of TABLES) expect(await countOf(a, x), x).toBe(0);
    expect(await reportKinds(f, a)).toEqual(bad.map(() => 'push_rejected'));
    // Dieselben Bons, richtig: angenommen.
    expect(statuses(await push([redeem, payout, sale, voided].map((r, i) => entry(20 + i, 'receipt', r))))).toEqual([
      'accepted', 'accepted', 'accepted', 'accepted',
    ]);
  });

  test('v: 1 und v: 2 werden weiter angenommen, voucher_cents bleibt 0', async () => {
    const r1 = sampleReceipt();
    const r2 = sampleReceiptV2();
    expect(statuses(await push([entry(1, 'receipt', r1), entry(2, 'receipt', r2)]))).toEqual(['accepted', 'accepted']);
    const got = await rows(a, 'select voucher_cents, voucher_sale_cents, deposit_return_cents, public_token from receipts');
    expect(got).toEqual([
      { voucher_cents: 0, voucher_sale_cents: 0, deposit_return_cents: 0, public_token: null },
      { voucher_cents: 0, voucher_sale_cents: 0, deposit_return_cents: 0, public_token: null },
    ]);
    for (const x of ['receipt_links', 'vouchers', 'voucher_movements']) expect(await countOf(a, x), x).toBe(0);
    expect(await reportKinds(f, a)).toEqual([]);
  });

  test('push_request_v3.json wird ganz angenommen, ohne Bericht', async () => {
    // Die Schlüssel der Seiten aus der Datei kommen in dieser Testdatei nur hier vor.
    const request = syncFixture('push_request_v3') as { entries: { seq: number }[] };
    expect((await push(request.entries)).results).toEqual(request.entries.map((e) => ({ seq: e.seq, status: 'accepted' })));
    expect(await reportKinds(f, a)).toEqual([]);
    expect(await countOf(a, 'receipt_links')).toBe(5);
    const balance = await rows(a, 'select sum(amount_cents)::int as cents from voucher_movements where voucher_id = $1', [VOUCHER]);
    expect(balance).toEqual([{ cents: 0 }]);
  });
});
