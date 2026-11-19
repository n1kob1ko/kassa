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

export const RECEIPT_KINDS = ['sale', 'voided', 'start', 'month', 'year', 'zero', 'collective', 'closing'] as const;

export const receiptEntry = z.object({
  receipt: z.object({
    v: z.literal(1),
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
    lines: z.array(lineSchema).max(2000),
    payment: paymentSchema.nullable(),
    rksv: rksvSchema.nullable(),
  }),
});

export type ParsedReceipt = z.infer<typeof receiptEntry>['receipt'];
