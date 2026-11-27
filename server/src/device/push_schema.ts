import { z } from 'zod';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const BASE64 = /^[A-Za-z0-9+/]+={0,2}$/;

const uuid = z.string().regex(UUID);
/** ISO 8601 in UTC (`2026-11-19T08:00:00.000Z`), gelesen als Date. */
const time = z.iso.datetime().transform((s) => new Date(s));
const cents = z.number().int().min(-2_000_000_000).max(2_000_000_000);
const base64 = z.string().min(1).max(100_000).regex(BASE64);
const text = z.string().max(2000);
const nullableText = text.nullable();
const nullableCents = cents.nullable();

export const MAX_ENTRIES = 100;

/** Höchstens so viele Pfade aus den Fehlern von zod gehen in einen Bericht, jeder höchstens 200 Zeichen. */
const MAX_PATHS = 20;

/** Die Pfade der Fehler (`receipt.totalCents`), ohne die Werte. Nur Namen aus dem Schema und Positionen in Listen. */
export function issuePaths(error: z.ZodError): string[] {
  const paths = error.issues.map((i) => i.path.map(String).join('.').slice(0, 200));
  return [...new Set(paths)].slice(0, MAX_PATHS);
}

/** Ergebnis für einen unlesbaren Eintrag: rejected/invalid, dazu die Pfade für den Bericht (nicht für die Antwort). */
export function invalid(error: z.ZodError): { status: 'rejected'; reason: 'invalid'; paths: string[] } {
  return { status: 'rejected', reason: 'invalid', paths: issuePaths(error) };
}

/** Die Hülle: nur `deviceId` und eine Liste von Einträgen, jeder mit `seq` und `kind`. Der Rest eines Eintrags bleibt roh. */
export const envelopeSchema = z.object({
  deviceId: uuid,
  entries: z
    .array(z.object({ seq: z.number().int().min(0).max(Number.MAX_SAFE_INTEGER), kind: z.string().max(100) }).loose())
    .max(MAX_ENTRIES),
});

export const certificateEntry = z.object({
  certificate: z.object({
    serialHex: z.string().min(1).max(200),
    certificate: base64,
    issuers: z.array(base64).max(20),
  }),
});

export const chainEntry = z.object({
  chain: z.object({
    chain: z.number().int().min(0).max(2_000_000_000),
    mode: z.enum(['probe', 'live']),
    cashBoxId: text,
    zdaId: text,
    certSerial: text,
    startedAt: time,
    endedAt: time.nullable(),
  }),
});

export const dayEntry = z.object({
  day: z.object({
    id: uuid,
    openedAt: time,
    closedAt: time.nullable(),
    openingFloatCents: cents,
    countedCents: nullableCents,
    leftInDrawerCents: nullableCents,
    expectedCents: nullableCents,
    differenceCents: nullableCents,
    closedByName: nullableText,
  }),
});

export const movementEntry = z.object({
  movement: z.object({
    id: uuid,
    businessDayId: uuid,
    kind: z.enum(['deposit', 'withdrawal']),
    amountCents: cents,
    reason: nullableText,
    createdAt: time,
    staffId: text,
    staffName: text,
  }),
});

const rksvSchema = z.object({
  chain: z.number().int().min(0).max(2_000_000_000),
  position: z.number().int().min(0).max(2_000_000_000),
  jws: z.string().min(1).max(100_000),
  damaged: z.boolean(),
  certSerial: text,
});

const lineSchema = z.object({
  position: z.number().int().min(0).max(100_000),
  itemId: text,
  name: text,
  info: nullableText,
  unitPriceCents: cents,
  quantity: z.number().int().min(-1_000_000).max(1_000_000),
  unitDepositCents: cents,
  gross: z.object({ '20': cents, '10': cents, '13': cents, '0': cents, '19': cents }),
  options: z
    .array(z.object({ groupName: text, optionName: text, surchargeCents: cents }))
    .max(200),
});

const paymentSchema = z.object({
  kind: text,
  amountCents: cents,
  givenCents: nullableCents,
  changeCents: nullableCents,
  provider: nullableText,
  providerTxCode: nullableText,
  cardScheme: nullableText,
  cardLast4: nullableText,
});

/** Ein Rabatt: Prozent (1 bis 100) oder `null` bei festem Betrag, der Betrag in Cent und der Grund. */
const discountSchema = z.object({
  percent: z.number().int().min(1).max(100).nullable(),
  amountCents: cents,
  reason: text,
});

/** Eine Zeile in v: 2: wie in v: 1, dazu der ganze Rabatt der Zeile und ihr eigener Rabatt (oder `null`). */
const lineV2Schema = lineSchema.extend({
  discountCents: cents,
  discount: discountSchema.nullable(),
});

/** Eine Zahlung in v: 2: nur bar oder Karte, mit Stelle und Trinkgeld. */
const paymentV2Schema = z.object({
  position: z.number().int().min(0).max(100),
  kind: z.enum(['cash', 'card']),
  amountCents: cents,
  givenCents: nullableCents,
  changeCents: nullableCents,
  tipCents: cents,
  tipStaffId: nullableText,
  tipStaffName: nullableText,
  provider: nullableText,
  providerTxCode: nullableText,
  cardScheme: nullableText,
  cardLast4: nullableText,
});

export const RECEIPT_KINDS = ['sale', 'voided', 'start', 'month', 'year', 'zero', 'collective', 'closing'] as const;

/** Was v: 1 und v: 2 gleich haben. */
const receiptBase = {
  id: uuid,
  number: z.number().int().min(0).max(2_000_000_000),
  createdAt: time,
  staffId: text,
  staffName: text,
  businessDayId: uuid.nullable(),
  kind: z.enum(RECEIPT_KINDS),
  voidsReceiptId: uuid.nullable(),
  goodsCents: cents,
  depositCents: cents,
  totalCents: cents,
  test: z.boolean(),
  rksv: rksvSchema.nullable(),
};

/** Bon von Tablets bis 1.10.0: eine Zahlung oder keine. */
const receiptV1 = z.object({
  v: z.literal(1),
  ...receiptBase,
  lines: z.array(lineSchema).max(2000),
  payment: paymentSchema.nullable(),
});

/** Bon ab 1.11.0: Zahlungen als Liste, Trinkgeld und Rabatte. `goodsCents` ist der Warenwert nach Rabatt. */
const receiptV2 = z.object({
  v: z.literal(2),
  ...receiptBase,
  tipCents: cents,
  discountCents: cents,
  discount: discountSchema.nullable(),
  lines: z.array(lineV2Schema).max(2000),
  payments: z.array(paymentV2Schema).max(20),
});

/** Der Code eines Gutscheins: 8 Ziffern. */
const voucherCode = z.string().regex(/^[0-9]{8}$/);

/** Eine Zahlung in v: 3: wie in v: 2, dazu die Art Gutschein mit Kennung, Code und Restguthaben nach dieser Zahlung. */
const paymentV3Schema = paymentV2Schema
  .extend({
    kind: z.enum(['cash', 'card', 'voucher']),
    voucherId: uuid.nullable(),
    voucherCode: voucherCode.nullable(),
    voucherBalanceAfterCents: nullableCents,
  })
  // Ohne Gutschein lässt sich die Bewegung nicht anlegen.
  .refine((p) => p.kind !== 'voucher' || (p.voucherId !== null && p.voucherCode !== null), {
    message: 'Eine Gutschein-Zahlung braucht Kennung und Code',
    path: ['voucherId'],
  });

/** Ein verkaufter Gutschein am Bon; beim Storno mit negativem Wert. */
const soldVoucherSchema = z.object({
  id: uuid,
  code: voucherCode,
  valueCents: cents,
  linePosition: z.number().int().min(0).max(100_000),
});

/** Bon ab 1.12.0: wie v: 2, dazu der Schlüssel der öffentlichen Seite, verkaufte Gutscheine und Gutschein-Zahlungen. */
const receiptV3 = receiptV2.extend({
  v: z.literal(3),
  publicToken: z.string().regex(/^[A-Za-z0-9_-]{22}$/).nullable(),
  vouchers: z.array(soldVoucherSchema).max(2000),
  payments: z.array(paymentV3Schema).max(20),
});

export const receiptEntry = z.object({
  receipt: z.discriminatedUnion('v', [receiptV1, receiptV2, receiptV3]),
});

export type ParsedReceiptV1 = z.infer<typeof receiptV1>;
export type ParsedReceiptV2 = z.infer<typeof receiptV2>;
export type ParsedReceiptV3 = z.infer<typeof receiptV3>;
export type ParsedReceipt = ParsedReceiptV1 | ParsedReceiptV2 | ParsedReceiptV3;

/** Die Kennung der Gutschein-Zeile und der Anfang der Kennungen von "Pfand zurück", wie am Tablet (`cart.dart`). */
export const VOUCHER_SALE_ITEM_ID = 'voucher-sale';
export const DEPOSIT_RETURN_ITEM_PREFIX = 'deposit-return-';

const sum = (values: number[]) => values.reduce((s, n) => s + n, 0);

/** Zahlungsart und Summen für die Spalten von `receipts`. Bons v: 1 und v: 2 haben keine Gutscheine und kein Pfand zurück. */
export function paymentColumns(r: ParsedReceipt): {
  paymentKind: 'cash' | 'card' | 'voucher' | 'mixed' | null;
  cashCents: number;
  cardCents: number;
  tipCents: number;
  discountCents: number;
  voucherCents: number;
  voucherSaleCents: number;
  depositReturnCents: number;
} {
  const none = { voucherCents: 0, voucherSaleCents: 0, depositReturnCents: 0 };
  if (r.v === 1) {
    // Wie Migration 0004 für alte Bons: bar ist alles bar, jede andere Art alles Karte.
    if (r.payment === null) return { paymentKind: null, cashCents: 0, cardCents: 0, tipCents: 0, discountCents: 0, ...none };
    const cash = r.payment.kind === 'cash';
    return {
      paymentKind: cash ? 'cash' : 'card',
      cashCents: cash ? r.totalCents : 0,
      cardCents: cash ? 0 : r.totalCents,
      tipCents: 0,
      discountCents: 0,
      ...none,
    };
  }
  const payments: { kind: string; amountCents: number }[] = r.payments;
  const of = (kind: string) => payments.filter((p) => p.kind === kind);
  const kinds = (['cash', 'card', 'voucher'] as const).filter((k) => of(k).length > 0);
  const lines = r.lines;
  return {
    paymentKind: kinds.length > 1 ? 'mixed' : (kinds[0] ?? null),
    cashCents: sum(of('cash').map((p) => p.amountCents)),
    cardCents: sum(of('card').map((p) => p.amountCents)),
    tipCents: r.tipCents,
    discountCents: r.discountCents,
    ...(r.v === 2
      ? none
      : {
          voucherCents: sum(of('voucher').map((p) => p.amountCents)),
          voucherSaleCents: sum(lines.filter((l) => l.itemId === VOUCHER_SALE_ITEM_ID).map((l) => l.unitPriceCents * l.quantity)),
          depositReturnCents: sum(
            lines.filter((l) => l.itemId.startsWith(DEPOSIT_RETURN_ITEM_PREFIX)).map((l) => l.unitDepositCents * l.quantity),
          ),
        }),
  };
}

/**
 * Die festen Regeln eines Bons v: 3, die der Server prüft (wie `receipt_rules.dart` am Tablet): Reihenfolge der Zahlungen
 * (Gutscheine, höchstens eine Bar-Zahlung, höchstens eine Karte zuletzt), eine Zahlung unter 0 nur bar, nur bei einer Summe
 * unter 0 und als einzige Zahlung (beim Storno gespiegelt), Gutschein-Zeile nie mit Gutschein-Zahlung. Gibt die Namen der
 * verletzten Regeln zurück; das Guthaben prüft der Server nicht.
 */
export function ruleViolations(r: ParsedReceiptV3): string[] {
  const payments = [...r.payments].sort((a, b) => a.position - b.position);
  const rank = { voucher: 0, cash: 1, card: 2 } as const;
  const violations: string[] = [];
  const ordered = payments.every((p, i) => i === 0 || rank[payments[i - 1]!.kind] <= rank[p.kind]);
  const count = (kind: string) => payments.filter((p) => p.kind === kind).length;
  if (!ordered || count('cash') > 1 || count('card') > 1) violations.push('payment_order');
  const sign = r.kind === 'voided' ? -1 : 1;
  const negativeOk = payments.every(
    (p) => p.amountCents * sign >= 0 || (p.kind === 'cash' && r.totalCents * sign < 0 && payments.length === 1),
  );
  if (!negativeOk) violations.push('negative_only_cash');
  if (r.lines.some((l) => l.itemId === VOUCHER_SALE_ITEM_ID) && count('voucher') > 0) violations.push('voucher_not_with_sale');
  return violations;
}

/**
 * Ein v3-Bon in der Form von v2, wenn er sich so schreiben lässt (kein Schlüssel der Seite, keine verkauften Gutscheine,
 * keine Gutschein-Zahlung, keine Gutschein-Felder), sonst null.
 */
export function asV2(r: ParsedReceiptV3): ParsedReceiptV2 | null {
  if (r.publicToken !== null || r.vouchers.length > 0) return null;
  if (r.payments.some((p) => p.kind === 'voucher' || p.voucherId !== null || p.voucherCode !== null || p.voucherBalanceAfterCents !== null)) {
    return null;
  }
  // Ohne die Felder, die v: 2 nicht kennt; was übrig bleibt, ist genau ein gelesener v2-Bon.
  const { publicToken, vouchers, payments, ...base } = r;
  return {
    ...base,
    v: 2,
    payments: payments.map(({ voucherId, voucherCode, voucherBalanceAfterCents, kind, ...p }) => ({
      ...p,
      kind: kind as 'cash' | 'card',
    })),
  };
}

/** Ein v2-Bon in der Form von v1, wenn er sich so schreiben lässt (höchstens eine Zahlung, kein Trinkgeld, kein Rabatt), sonst null. */
export function asV1(r: ParsedReceiptV2): ParsedReceiptV1 | null {
  if (r.payments.length > 1 || r.tipCents !== 0 || r.payments.some((p) => p.tipCents !== 0)) return null;
  if (r.discountCents !== 0 || r.discount !== null || r.lines.some((l) => l.discountCents !== 0 || l.discount !== null)) return null;
  // Ohne die Felder, die v: 1 nicht kennt; was übrig bleibt, ist genau ein gelesener v1-Bon.
  const { tipCents, discountCents, discount, lines, payments, ...base } = r;
  const p = payments[0];
  return {
    ...base,
    v: 1,
    lines: lines.map(({ discountCents, discount, ...line }) => line),
    payment: p
      ? {
          kind: p.kind,
          amountCents: p.amountCents,
          givenCents: p.givenCents,
          changeCents: p.changeCents,
          provider: p.provider,
          providerTxCode: p.providerTxCode,
          cardScheme: p.cardScheme,
          cardLast4: p.cardLast4,
        }
      : null,
  };
}
