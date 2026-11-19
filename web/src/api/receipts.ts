import { keepPreviousData, useInfiniteQuery, useQuery } from '@tanstack/react-query';
import { api, ApiError } from './client';
import { OVERVIEW_REFRESH_MS } from './overview';

export type ReceiptKind = 'sale' | 'voided' | 'start' | 'month' | 'year' | 'zero' | 'collective' | 'closing';

/** Eine Zeile von `GET /api/admin/businesses/:b/receipts`. */
export type ReceiptHead = {
  id: string;
  number: number;
  registerName: string;
  createdAt: string;
  kind: ReceiptKind;
  staffName: string;
  totalCents: number;
  paymentKind: 'cash' | 'card' | null;
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
};

/** Antwort von `GET …/receipts/:id`. Die Signatur selbst (JWS, Zertifikat) kommt nie mit, nur ihr Zustand. */
export type ReceiptDetail = ReceiptHead & {
  goodsCents: number;
  depositCents: number;
  lines: ReceiptLine[];
  payment: {
    kind: string;
    amountCents: number;
    givenCents: number | null;
    changeCents: number | null;
    provider: string | null;
    providerTxCode: string | null;
    cardScheme: string | null;
    cardLast4: string | null;
  } | null;
  voidsReceiptId: string | null;
  voidedByReceiptId: string | null;
  rksv: { cashBoxId: string | null; damaged: boolean; probe: boolean } | null;
};

/** Die Filter der Liste, so wie der Server sie liest. `null` heißt: nicht gefiltert. */
export type ReceiptFilter = { day: string | null; payment: 'cash' | 'card' | null; voidedOnly: boolean };

/** In der Adresse stehen die Filter deutsch (`?tag=2026-11-19&zahlung=karte&stornos=1`), Vorgaben gar nicht. */
const PARAMS = { day: 'tag', payment: 'zahlung', voided: 'stornos' } as const;
const PAYMENT_WORDS = { cash: 'bar', card: 'karte' } as const;

export function filterFromParams(params: URLSearchParams): ReceiptFilter {
  const day = params.get(PARAMS.day);
  const word = params.get(PARAMS.payment);
  const payment = word === PAYMENT_WORDS.cash ? 'cash' : word === PAYMENT_WORDS.card ? 'card' : null;
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
