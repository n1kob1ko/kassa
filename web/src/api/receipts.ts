import { keepPreviousData, useInfiniteQuery, useQuery } from '@tanstack/react-query';
import { paymentKindsText } from '../pages/receipt_payments';
import { api, ApiError } from './client';
import { OVERVIEW_REFRESH_MS } from './overview';

export type ReceiptKind = 'sale' | 'voided' | 'start' | 'month' | 'year' | 'zero' | 'collective' | 'closing';

/** Die Arten einer Zahlung. */
export type PaymentKind = 'voucher' | 'cash' | 'card';

/** Eine Zeile von `GET /api/admin/businesses/:b/receipts`. */
export type ReceiptHead = {
  id: string;
  number: number;
  registerName: string;
  createdAt: string;
  kind: ReceiptKind;
  staffName: string;
  totalCents: number;
  /** `mixed`: mehr als eine Art (bar und Karte, oder Gutschein und bar oder Karte). Alle Arten in `paymentKinds`. */
  paymentKind: PaymentKind | 'mixed' | null;
  /** Mit Gutschein bezahlt; 0 bei Bons vor App 1.12.0. */
  voucherCents: number;
  /** Alle Arten der Zahlungen, in der Reihenfolge Gutschein, bar, Karte; ohne Zahlung leer. */
  paymentKinds: PaymentKind[];
  test: boolean;
  /** Ein Verkauf, den ein Storno-Bon storniert hat. */
  voided: boolean;
};

export type ReceiptPage = { receipts: ReceiptHead[]; next: string | null };

export type ReceiptLine = {
  position: number;
  itemId: string;
  name: string;
  info: string | null;
  unitPriceCents: number;
  quantity: number;
  unitDepositCents: number;
  options: { groupName: string; optionName: string; surchargeCents: number }[];
  /** Gesamter Rabatt der Zeile (eigener plus Anteil am Bon-Rabatt), positiv. */
  discountCents: number;
  /** Der eigene Rabatt der Zeile. */
  discount: Discount | null;
};

/** Ein Rabatt: in Prozent (`percent`) oder als Betrag (`percent` ist `null`), immer mit Grund. */
export type Discount = { percent: number | null; amountCents: number; reason: string };

export type Payment = {
  position: number;
  kind: string;
  amountCents: number;
  givenCents: number | null;
  changeCents: number | null;
  /** Trinkgeld, nur bei Karte; nicht im Betrag. */
  tipCents: number;
  tipStaffName: string | null;
  provider: string | null;
  providerTxCode: string | null;
  cardScheme: string | null;
  cardLast4: string | null;
  /** Bei einer Gutschein-Zahlung: der Code (8 Ziffern) und was danach am Gutschein blieb. */
  voucherCode: string | null;
  voucherBalanceAfterCents: number | null;
};

/** Ein auf dem Bon verkaufter Gutschein; am Storno-Bon mit negativem Wert. */
export type SoldVoucher = { code: string; valueCents: number; linePosition: number };

/** Antwort von `GET …/receipts/:id`. Die Signatur selbst (JWS, Zertifikat) kommt nie mit, nur ihr Zustand. */
export type ReceiptDetail = ReceiptHead & {
  goodsCents: number;
  depositCents: number;
  lines: ReceiptLine[];
  /** Nach Stelle; ein Bon aus App 1.10.0 hat eine Zahlung an Stelle 0. */
  payments: Payment[];
  /** Die verkauften Gutscheine, nach Zeile. */
  vouchers: SoldVoucher[];
  tipCents: number;
  /** Summe aller Rabatte des Bons, positiv. */
  discountCents: number;
  /** Der Rabatt auf den ganzen Bon. */
  discount: Discount | null;
  voidsReceiptId: string | null;
  voidedByReceiptId: string | null;
  rksv: { cashBoxId: string | null; damaged: boolean; probe: boolean } | null;
  /** Der Empfänger der Rechnung, die letzte Fassung. Fehlt, wenn der Bon keinen hat. */
  recipient?: ReceiptRecipient;
};

/** Der Empfänger der Rechnung zu einem Bon: eine Kopie von Name, Adresse und UID, wie sie auf der Rechnung steht. */
export type ReceiptRecipient = {
  name: string;
  addressLine1: string;
  addressLine2: string;
  vatId: string | null;
  /** Fassung ab 0; jede Korrektur am Tablet ist eine neue. */
  version: number;
  createdAt: string;
  staffName: string;
};

/**
 * Die Zahlungsart in Worten; ohne Zahlung (Sonderbeleg) leer. Die Seiten nutzen `paymentKindsText` mit allen Arten des
 * Bons; dies bleibt für die eine Spalte `paymentKind` und gibt dieselben Wörter ("mixed" aus 1.11.0 ist bar und Karte).
 */
export function paymentKindText(kind: ReceiptHead['paymentKind']): string {
  if (kind === null) return '';
  return paymentKindsText(kind === 'mixed' ? ['cash', 'card'] : [kind]);
}

/** Gründe eines Rabatts wie in der App; ein unbekannter Grund steht, wie er kommt. */
const DISCOUNT_REASONS: Record<string, string> = {
  regular: 'Stammgast',
  staff: 'Mitarbeiter',
  complaint: 'Reklamation',
  promotion: 'Aktion',
  invitation: 'Einladung',
};

/** "Rabatt 10 % Aktion", "Rabatt Mitarbeiter". */
export function discountText(d: { percent: number | null; reason: string }): string {
  const reason = DISCOUNT_REASONS[d.reason] ?? d.reason;
  return d.percent === null ? `Rabatt ${reason}` : `Rabatt ${d.percent} % ${reason}`;
}

/** Die Filter der Liste, so wie der Server sie liest. `null` heißt: nicht gefiltert. */
export type ReceiptFilter = { day: string | null; payment: PaymentKind | null; voidedOnly: boolean };

/** In der Adresse stehen die Filter deutsch (`?tag=2026-11-19&zahlung=karte&stornos=1`), Vorgaben gar nicht. */
const PARAMS = { day: 'tag', payment: 'zahlung', voided: 'stornos' } as const;
const PAYMENT_WORDS = { cash: 'bar', card: 'karte', voucher: 'gutschein' } as const;

export function filterFromParams(params: URLSearchParams): ReceiptFilter {
  const day = params.get(PARAMS.day);
  const word = params.get(PARAMS.payment);
  const payment = (Object.keys(PAYMENT_WORDS) as PaymentKind[]).find((k) => PAYMENT_WORDS[k] === word) ?? null;
  return {
    day: day !== null && /^\d{4}-\d{2}-\d{2}$/.test(day) ? day : null,
    payment,
    voidedOnly: params.get(PARAMS.voided) === '1',
  };
}

/** Die Filter in die Adresse; andere Parameter bleiben stehen. */
export function filterToParams(f: ReceiptFilter, current: URLSearchParams): URLSearchParams {
  const next = new URLSearchParams(current);
  for (const key of Object.values(PARAMS)) next.delete(key);
  if (f.day) next.set(PARAMS.day, f.day);
  if (f.payment) next.set(PARAMS.payment, PAYMENT_WORDS[f.payment]);
  if (f.voidedOnly) next.set(PARAMS.voided, '1');
  return next;
}

export const isFiltered = (f: ReceiptFilter) => f.day !== null || f.payment !== null || f.voidedOnly;

export const receiptsKey = (b: string, f: ReceiptFilter) => ['receipts', b, f.day, f.payment, f.voidedOnly] as const;
export const receiptKey = (b: string, id: string) => ['receipt', b, id] as const;

function listPath(b: string, f: ReceiptFilter, before: string | null): string {
  const q = new URLSearchParams();
  if (f.day) q.set('day', f.day);
  if (f.payment) q.set('payment', f.payment);
  if (f.voidedOnly) q.set('voided', '1');
  // Die Kennung der nächsten Seite geht unverändert zurück.
  if (before) q.set('before', before);
  const query = q.toString();
  return `/api/admin/businesses/${encodeURIComponent(b)}/receipts${query ? `?${query}` : ''}`;
}

/**
 * Bons in Seiten zu 50, neueste zuerst. Beim Wechsel des Filters bleibt die alte Liste stehen, bis die neue da ist
 * (`isPlaceholderData`). Scheitert "Mehr laden", bleiben die geladenen Seiten (`isFetchNextPageError`). Wie die
 * Umsätze wird alle 60 Sekunden still nachgeladen, solange die Seite sichtbar ist; die geladenen Seiten bleiben.
 */
export function useReceipts(b: string, f: ReceiptFilter) {
  return useInfiniteQuery<ReceiptPage, ApiError, { pages: ReceiptPage[] }, ReturnType<typeof receiptsKey>, string | null>({
    queryKey: receiptsKey(b, f),
    queryFn: ({ pageParam }) => api.get<ReceiptPage>(listPath(b, f, pageParam)),
    initialPageParam: null,
    getNextPageParam: (last) => last.next ?? undefined,
    placeholderData: keepPreviousData,
    refetchInterval: OVERVIEW_REFRESH_MS,
    refetchIntervalInBackground: false,
  });
}

export function useReceipt(b: string, id: string | null) {
  return useQuery<ReceiptDetail, ApiError>({
    queryKey: receiptKey(b, id ?? ''),
    queryFn: () =>
      api.get<ReceiptDetail>(`/api/admin/businesses/${encodeURIComponent(b)}/receipts/${encodeURIComponent(id ?? '')}`),
    enabled: id !== null,
  });
}
