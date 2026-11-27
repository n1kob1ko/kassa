import { randomBytes, randomUUID } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { withBusiness } from '../../src/db/tenant.js';
import type { TestApp } from './app.js';
import { send, setTimeZone, type Site } from './admin_data.js';

// Die gemeinsame Datei shared/fixtures/stats/stufe_1b.json: die vier Bons aus Task 6 (bar, Gutschein-Verkauf,
// Gutschein-Zahlung, Pfand zurück) in v: 3 mit dem Tag und den Zahlen, die das Tablet rechnet. Ohne Erwartungen.

export type Stufe1b = {
  now: string;
  timeZone: string;
  categories: { id: string; name: string; position: number }[];
  items: { id: string; name: string; priceCents: number; categoryId: string; taxPercent: number; depositCents: number }[];
  day: Record<string, any>;
  receipts: Record<string, any>[];
  expected: {
    day: Record<string, unknown>;
    overview: Record<string, Record<string, unknown>>;
    months: unknown[];
    summary: Record<string, unknown>;
  };
};

export function readStufe1b(): Stufe1b {
  return JSON.parse(readFileSync(new URL('../../../shared/fixtures/stats/stufe_1b.json', import.meta.url), 'utf8')) as Stufe1b;
}

/** Ein neuer Schlüssel der Seite: er gilt über alle Betriebe, die Datei wird in einem Lauf mehrmals gesendet. */
export const freshToken = () => randomBytes(16).toString('base64url');

/**
 * Schickt Tag und Bons der Datei an den Betrieb, setzt seine Zeitzone und legt Kategorien und Artikel an. Jeder Bon
 * bekommt einen neuen Schlüssel der Seite; sonst bleibt er, wie er in der Datei steht.
 */
export async function sendStufe1b(a: TestApp, s: Site, fx: Stufe1b = readStufe1b()): Promise<Stufe1b> {
  await setTimeZone(a, s.businessId, fx.timeZone);
  await withBusiness(a.db, s.businessId, async (c) => {
    for (const k of fx.categories) {
      await c.query(
        `insert into categories (business_id, id, name, position, change_seq) values ($1, $2, $3, $4, nextval('change_seq'))`,
        [s.businessId, k.id, k.name, k.position],
      );
    }
    for (const [i, it] of fx.items.entries()) {
      await c.query(
        `insert into items (business_id, id, name, price_cents, category_id, tax_percent, deposit_cents, position, change_seq)
         values ($1, $2, $3, $4, $5, $6, $7, $8, nextval('change_seq'))`,
        [s.businessId, it.id, it.name, it.priceCents, it.categoryId, it.taxPercent, it.depositCents, i],
      );
    }
  });
  await send(a, s, [['day', fx.day], ...fx.receipts.map((r): [string, object] => ['receipt', { ...r, publicToken: freshToken() }])]);
  return fx;
}

/** Der Storno-Bon zu einem Bon in v: 3: alle Beträge mit Minus, verkaufte Gutscheine mit negativem Wert. */
export function voidOfV3(r: Record<string, any>, o: Record<string, unknown>): Record<string, any> {
  const neg = (n: number) => (n === 0 ? 0 : -n);
  const gross = (g: Record<string, number>) => Object.fromEntries(Object.entries(g).map(([k, v]) => [k, neg(v)]));
  return {
    ...r,
    kind: 'voided',
    voidsReceiptId: r.id,
    publicToken: freshToken(),
    goodsCents: neg(r.goodsCents),
    depositCents: neg(r.depositCents),
    totalCents: neg(r.totalCents),
    tipCents: neg(r.tipCents),
    discountCents: neg(r.discountCents),
    lines: r.lines.map((l: Record<string, any>) => ({ ...l, quantity: neg(l.quantity), gross: gross(l.gross), discountCents: neg(l.discountCents) })),
    payments: r.payments.map((p: Record<string, any>) => ({
      ...p, amountCents: neg(p.amountCents), givenCents: 0, changeCents: 0, tipCents: neg(p.tipCents),
    })),
    vouchers: r.vouchers.map((v: Record<string, any>) => ({ ...v, valueCents: neg(v.valueCents) })),
    rksv: null,
    ...o,
  };
}

let codes = 10000000;
let numbers = 100;

/**
 * Ein echter Bon in v: 3 (nicht im Übungsmodus, ohne Tag), der einen Gutschein über [valueCents] bar verkauft, nach Bon B
 * der Datei. Code und Nummer zählen im Lauf hoch.
 */
export function voucherSale(valueCents: number, o: Record<string, unknown> = {}) {
  const sold = readStufe1b().receipts[1]!;
  const voucher = { id: randomUUID(), code: String(++codes), valueCents, linePosition: 0 };
  const receipt: Record<string, any> = {
    ...sold,
    id: randomUUID(),
    number: ++numbers,
    businessDayId: null,
    test: false,
    publicToken: freshToken(),
    goodsCents: valueCents,
    totalCents: valueCents,
    lines: [{ ...sold.lines[0], info: `Code ${voucher.code}`, unitPriceCents: valueCents, gross: { ...sold.lines[0].gross, 0: valueCents } }],
    payments: [{ ...sold.payments[0], amountCents: valueCents, givenCents: valueCents, changeCents: 0 }],
    vouchers: [voucher],
    ...o,
  };
  return { receipt, voucher };
}

/** Ein echter Bon in v: 3 über 9,65 €, ganz mit dem Gutschein [voucher] bezahlt, nach Bon C der Datei. */
export function voucherRedeem(voucher: { id: string; code: string }, o: Record<string, unknown> = {}): Record<string, any> {
  const paid = readStufe1b().receipts[2]!;
  return {
    ...paid,
    id: randomUUID(),
    number: ++numbers,
    businessDayId: null,
    test: false,
    publicToken: freshToken(),
    payments: [{ ...paid.payments[0], voucherId: voucher.id, voucherCode: voucher.code, voucherBalanceAfterCents: 35 }],
    ...o,
  };
}
