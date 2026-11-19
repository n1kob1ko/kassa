import { randomUUID } from 'node:crypto';
import type { FastifyInstance } from 'fastify';

export type PushResult = { seq: number; status: string; reason?: string };

/** Sendet ein Paket und gibt Status und Ergebnisse zurück. */
export async function pushEntries(
  app: FastifyInstance,
  token: string,
  deviceId: string,
  entries: object[],
): Promise<{ status: number; results: PushResult[] }> {
  const res = await app.inject({
    method: 'POST',
    url: '/api/device/sync/push',
    headers: { authorization: `Bearer ${token}` },
    payload: { deviceId, entries },
  });
  return { status: res.statusCode, results: res.statusCode === 200 ? res.json().results : [] };
}

/** Ein Bon (der Inhalt von `receipt`): Barverkauf über 9,90 Euro ohne Eintrag der Signatur. */
export function sampleReceipt(overrides: Record<string, unknown> = {}): Record<string, any> {
  return {
    v: 1,
    id: randomUUID(),
    number: 1,
    createdAt: '2026-11-19T08:05:00.000Z',
    staffId: 'chefin',
    staffName: 'Chefin',
    businessDayId: randomUUID(),
    kind: 'sale',
    voidsReceiptId: null,
    goodsCents: 990,
    depositCents: 0,
    totalCents: 990,
    test: true,
    lines: [
      {
        position: 0,
        itemId: 'huhn-bowl',
        name: 'Huhn Bowl',
        info: null,
        unitPriceCents: 990,
        quantity: 1,
        unitDepositCents: 0,
        gross: { '20': 0, '10': 990, '13': 0, '0': 0, '19': 0 },
        options: [{ groupName: 'Größe', optionName: 'Normal', surchargeCents: 0 }],
      },
    ],
    payment: { kind: 'cash', amountCents: 990, givenCents: 1000, changeCents: 10, provider: null, providerTxCode: null, cardScheme: null, cardLast4: null },
    rksv: null,
    ...overrides,
  };
}

/** Ein offener Tag (der Inhalt von `day`). */
export function sampleDay(overrides: Record<string, unknown> = {}): Record<string, any> {
  return {
    id: randomUUID(),
    openedAt: '2026-11-19T08:00:00.000Z',
    closedAt: null,
    openingFloatCents: 10000,
    countedCents: null,
    leftInDrawerCents: null,
    expectedCents: null,
    differenceCents: null,
    closedByName: null,
    ...overrides,
  };
}

/** Ein Eintrag des Pakets: `entry(5, 'receipt', sampleReceipt())`. */
export function entry(seq: number, kind: string, value: object): object {
  const key = { rksv_certificate: 'certificate', rksv_chain: 'chain', cash_movement: 'movement' }[kind] ?? kind;
  return { seq, kind, [key]: value };
}
