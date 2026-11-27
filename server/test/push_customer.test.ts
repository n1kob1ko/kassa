import { randomUUID } from 'node:crypto';
import { afterAll, beforeAll, describe, expect, test } from 'vitest';
import { loggerOptions } from '../src/app.js';
import { withBusiness } from '../src/db/tenant.js';
import { testApp, type TestApp } from './support/app.js';
import { createBusiness } from './support/businesses.js';
import { createStaff, fixtureBusiness, pairDevice, pull } from './support/device.js';
import { entry, pushEntries, sampleReceipt } from './support/push.js';
import type { TestUser } from './support/users.js';

let f: TestApp;
let provider: TestUser;
let businessId: string;
let token: string;
let b2: string;
let t2: string;
const deviceId: string = randomUUID();
const logLines: string[] = [];

beforeAll(async () => {
  f = await testApp({}, { logger: loggerOptions({ write: (s: string) => void logLines.push(s) }) });
  ({ provider, businessId } = await fixtureBusiness(f));
  ({ token } = await pairDevice(f.app, provider.cookie, businessId));
  b2 = (await createBusiness(f.app, provider.cookie)).id;
  await createStaff(f.app, provider.cookie, b2, { name: 'Chefin', role: 'chef', pin: '1234' });
  t2 = (await pairDevice(f.app, provider.cookie, b2)).token;
});
afterAll(async () => {
  await f.close();
});

/** Ein Eintrag `customer` in der Form des Tablets (flach, ohne Hülle). */
function customer(seq: number, o: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    seq,
    kind: 'customer',
    id: randomUUID(),
    name: 'Muster GmbH',
    addressLine1: 'Musterweg 1',
    addressLine2: '1010 Wien',
    vatId: 'ATU00000000',
    archived: false,
    updatedAt: '2026-11-18T09:00:00.000Z',
    ...o,
  };
}

/** Ein Eintrag `recipient` in der Form des Tablets. */
function recipient(seq: number, receiptId: string, o: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    seq,
    kind: 'recipient',
    receiptId,
    version: 0,
    customerId: null,
    name: 'Muster GmbH',
    addressLine1: 'Musterweg 1',
    addressLine2: '1010 Wien',
    vatId: null,
    createdAt: '2026-11-18T09:05:00.000Z',
    staffId: 'chefin',
    staffName: 'Chefin',
    ...o,
  };
}

const send = (entries: object[], t = token) => pushEntries(f.app, t, deviceId, entries);
const statuses = (r: { results: { status: string; reason?: string }[] }) => r.results.map((x) => (x.reason ? `${x.status}/${x.reason}` : x.status));
const customerRow = async (biz: string, id: string) =>
  (await withBusiness(f.db, biz, (c) => c.query('select * from customers where id = $1', [id]))).rows[0];
const recipientRows = async (biz: string, receiptId: string) =>
  (await withBusiness(f.db, biz, (c) => c.query('select * from receipt_recipients where receipt_id = $1 order by version', [receiptId]))).rows;
const rejectedAt = (biz: string, at: Date) =>
  withBusiness(f.db, biz, async (c) =>
    (
      await c.query(
        `select content from reports where source = 'server' and kind = 'push_rejected' and at = $1 order by (content->>'seq')::int`,
        [at],
      )
    ).rows.map((r) => r.content),
  );

describe('customer', () => {
  test('customer: angelegt, geändert mit neuerem updatedAt, ältere Fassung ist duplicate; change_seq steigt', async () => {
    f.now.value = new Date('2026-11-18T10:00:00.000Z');
    const first = customer(1, { name: '  Muster GmbH ', vatId: '' });
    const id = first.id as string;
    expect(statuses(await send([first]))).toEqual(['accepted']);
    const created = await customerRow(businessId, id);
    expect(created).toMatchObject({ name: 'Muster GmbH', address_line1: 'Musterweg 1', address_line2: '1010 Wien', vat_id: null, archived: false });
    expect(created.updated_at.toISOString()).toBe('2026-11-18T09:00:00.000Z');
    const seq0 = Number(created.change_seq);

    // Dasselbe Paket noch einmal: duplicate, nichts ändert sich.
    expect(statuses(await send([first]))).toEqual(['duplicate']);
    expect(await customerRow(businessId, id)).toEqual(created);

    // Neuer: gewinnt, change_seq steigt.
    const newer = customer(2, { id, addressLine1: 'Musterweg 2', vatId: 'ATU00000000', updatedAt: '2026-11-18T09:30:00.000Z' });
    expect(statuses(await send([newer]))).toEqual(['accepted']);
    const changed = await customerRow(businessId, id);
    expect(changed).toMatchObject({ address_line1: 'Musterweg 2', vat_id: 'ATU00000000' });
    expect(changed.updated_at.toISOString()).toBe('2026-11-18T09:30:00.000Z');
    expect(Number(changed.change_seq)).toBeGreaterThan(seq0);

    // Älter mit anderem Inhalt: duplicate, die Werte bleiben, die Nummer steigt, damit das Tablet den Stand des Servers holt.
    const older = customer(3, { id, name: 'Alte GmbH', updatedAt: '2026-11-18T09:10:00.000Z' });
    expect(statuses(await send([older]))).toEqual(['duplicate']);
    const kept = await customerRow(businessId, id);
    expect(kept).toEqual({ ...changed, change_seq: kept.change_seq });
    expect(Number(kept.change_seq)).toBeGreaterThan(Number(changed.change_seq));
    const pulled = await pull(f.app, token, `?since=${changed.change_seq}`);
    expect(pulled.json().customers).toEqual([
      { id, name: 'Muster GmbH', addressLine1: 'Musterweg 2', addressLine2: '1010 Wien', vatId: 'ATU00000000', archived: false },
    ]);

    // Eine Uhr in der Zukunft zählt als jetzt.
    const future = customer(4, { id, name: 'Zukunft GmbH', updatedAt: '2027-01-01T00:00:00.000Z' });
    expect(statuses(await send([future]))).toEqual(['accepted']);
    expect((await customerRow(businessId, id)).updated_at.toISOString()).toBe('2026-11-18T10:00:00.000Z');
  });

  test('customer: Pflichtfelder und Längen wie am Tablet, sonst invalid', async () => {
    const bad = [
      customer(1, { name: '   ' }),
      customer(2, { addressLine1: '' }),
      customer(3, { addressLine2: 'x'.repeat(81) }),
      customer(4, { vatId: 'A'.repeat(21) }),
      customer(5, { id: 'keine-uuid' }),
      customer(6, { updatedAt: 'gestern' }),
      customer(7, { archived: 'nein' }),
    ];
    expect(statuses(await send(bad))).toEqual(Array(7).fill('rejected/invalid'));
    const ok = customer(8, { name: 'x'.repeat(80), addressLine1: ` ${'y'.repeat(80)} `, vatId: 'A'.repeat(20) });
    expect(statuses(await send([ok]))).toEqual(['accepted']);
    // Ohne UID geht es auch (der Kunde hat keinen Bon).
    expect(statuses(await send([customer(9, { vatId: null })]))).toEqual(['accepted']);
  });

  test('customer: ein anderer Betrieb mit derselben Kennung hat seinen eigenen Kunden', async () => {
    const mine = customer(1);
    expect(statuses(await send([mine]))).toEqual(['accepted']);
    const theirs = { ...mine, name: 'Fremd GmbH', updatedAt: '2026-11-18T09:59:00.000Z' };
    expect(statuses(await send([theirs], t2))).toEqual(['accepted']);
    expect((await customerRow(businessId, mine.id as string)).name).toBe('Muster GmbH');
    expect((await customerRow(b2, mine.id as string)).name).toBe('Fremd GmbH');
  });
});

describe('recipient', () => {
  test('recipient: angefügt, noch einmal ist duplicate, unbekannter Bon und fehlender Name sind invalid; receipts bleibt unverändert', async () => {
    const bon = sampleReceipt();
    expect(statuses(await send([entry(1, 'receipt', bon)]))).toEqual(['accepted']);
    const receiptBefore = (await withBusiness(f.db, businessId, (c) => c.query('select * from receipts where id = $1', [bon.id]))).rows;
    const linesBefore = (await withBusiness(f.db, businessId, (c) => c.query('select * from receipt_lines where receipt_id = $1', [bon.id]))).rows;

    const customerId = randomUUID();
    const v0 = recipient(2, bon.id, { customerId, name: ' Muster GmbH ', vatId: ' ATU00000000 ' });
    const v1 = recipient(3, bon.id, { version: 1, addressLine1: 'Musterweg 2', vatId: '' });
    expect(statuses(await send([v0, v1]))).toEqual(['accepted', 'accepted']);
    expect(statuses(await send([v0]))).toEqual(['duplicate']);

    const rows = await recipientRows(businessId, bon.id);
    expect(rows.map((r) => ({ ...r, created_at: r.created_at.toISOString() }))).toEqual([
      {
        business_id: businessId, receipt_id: bon.id, version: 0, customer_id: customerId, name: 'Muster GmbH',
        address_line1: 'Musterweg 1', address_line2: '1010 Wien', vat_id: 'ATU00000000',
        created_at: '2026-11-18T09:05:00.000Z', staff_id: 'chefin', staff_name: 'Chefin',
      },
      {
        business_id: businessId, receipt_id: bon.id, version: 1, customer_id: null, name: 'Muster GmbH',
        address_line1: 'Musterweg 2', address_line2: '1010 Wien', vat_id: null,
        created_at: '2026-11-18T09:05:00.000Z', staff_id: 'chefin', staff_name: 'Chefin',
      },
    ]);

    const unknown = recipient(4, randomUUID());
    const noName = recipient(5, bon.id, { version: 2, name: '' });
    const tooLong = recipient(6, bon.id, { version: 2, addressLine2: 'x'.repeat(81) });
    const badVersion = recipient(7, bon.id, { version: -1 });
    expect(statuses(await send([unknown, noName, tooLong, badVersion]))).toEqual(Array(4).fill('rejected/invalid'));
    expect(await recipientRows(businessId, bon.id)).toHaveLength(2);

    // Der Bon eines anderen Betriebs ist für diese Kassa unbekannt.
    expect(statuses(await send([recipient(8, bon.id, { version: 5 })], t2))).toEqual(['rejected/invalid']);
    expect(await recipientRows(b2, bon.id)).toEqual([]);

    // Der Bon und seine Zeilen bleiben, wie sie waren.
    expect((await withBusiness(f.db, businessId, (c) => c.query('select * from receipts where id = $1', [bon.id]))).rows).toEqual(receiptBefore);
    expect((await withBusiness(f.db, businessId, (c) => c.query('select * from receipt_lines where receipt_id = $1', [bon.id]))).rows).toEqual(linesBefore);
  });

  test('recipient: über 10.000,00 € ist die UID Pflicht, genau 10.000,00 € nicht', async () => {
    const big = (cents: number) =>
      sampleReceipt({
        goodsCents: cents,
        totalCents: cents,
        lines: [{ ...sampleReceipt().lines[0], unitPriceCents: cents, gross: { '20': 0, '10': cents, '13': 0, '0': 0, '19': 0 } }],
        payment: { ...sampleReceipt().payment, amountCents: cents, givenCents: cents, changeCents: 0 },
      });
    const above = big(1_000_001);
    const exact = big(1_000_000);
    expect(statuses(await send([entry(1, 'receipt', above), entry(2, 'receipt', exact)]))).toEqual(['accepted', 'accepted']);
    expect(statuses(await send([recipient(3, above.id), recipient(4, exact.id)]))).toEqual(['rejected/invalid', 'accepted']);
    expect(statuses(await send([recipient(5, above.id, { vatId: 'ATU00000000' })]))).toEqual(['accepted']);
  });

  test('abgelehnte Kunden und Empfänger: Bericht und Protokoll nennen nur Art, Nummer und Felder, nie Name, Adresse oder UID', async () => {
    const at = new Date('2026-11-18T11:11:00.000Z');
    f.now.value = at;
    logLines.length = 0;
    const secret = { name: 'Geheim GmbH'.padEnd(90, 'x'), addressLine1: 'Geheimweg 7', addressLine2: '9999 Geheimstadt', vatId: 'ATU99999999' };
    const res = await send([customer(1, secret), recipient(2, randomUUID(), { ...secret, name: 'Geheim GmbH' })]);
    expect(statuses(res)).toEqual(['rejected/invalid', 'rejected/invalid']);
    const found = await rejectedAt(businessId, at);
    expect(found).toEqual([
      { entryKind: 'customer', seq: 1, reason: 'invalid', paths: ['name'] },
      { entryKind: 'recipient', seq: 2, reason: 'invalid', paths: ['receiptId'] },
    ]);
    expect(logLines.length).toBeGreaterThan(0);
    const all = JSON.stringify(found) + logLines.join('\n');
    for (const word of ['Geheim', 'ATU99999999']) expect(all).not.toContain(word);
  });
});
