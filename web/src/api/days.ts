import { useQuery } from '@tanstack/react-query';
import { api, ApiError } from './client';
import { OVERVIEW_REFRESH_MS } from './overview';

/** Eine Zeile von `GET /api/admin/businesses/:b/days` (höchstens 100, neueste zuerst). */
export type DayHead = {
  id: string;
  registerName: string;
  openedAt: string;
  /** `null`: der Tag ist noch offen. */
  closedAt: string | null;
  expectedCents: number | null;
  countedCents: number | null;
  /** Gezählt minus erwartet. */
  differenceCents: number | null;
  closedByName: string | null;
  /** Verkäufe minus Stornos des Tages, wie im Detail. */
  revenueCents: number;
};

export type CashMovement = {
  kind: 'deposit' | 'withdrawal';
  amountCents: number;
  reason: string | null;
  createdAt: string;
  staffName: string;
};

/** Steuer eines Satzes (Prozent), aus der Summe brutto gerechnet; Sätze ohne Betrag fehlen. */
export type TaxLine = { percent: number; grossCents: number; netCents: number; taxCents: number };

export type DayDetail = DayHead & {
  openingFloatCents: number;
  leftInDrawerCents: number | null;
  movements: CashMovement[];
  receiptCount: number;
  cashCents: number;
  cardCents: number;
  cashReceiptCount: number;
  cardReceiptCount: number;
  voidCount: number;
  /** Summe der Stornos als positive Zahl. */
  voidedCents: number;
  depositCents: number;
  taxLines: TaxLine[];
};

export const daysKey = (b: string) => ['days', b] as const;
export const dayKey = (b: string, id: string) => ['day', b, id] as const;

/** Die Tage. Wie die Umsätze wird alle 60 Sekunden still nachgeladen, solange die Seite sichtbar ist. */
export function useDays(b: string) {
  return useQuery<DayHead[], ApiError>({
    queryKey: daysKey(b),
    queryFn: async () => (await api.get<{ days: DayHead[] }>(`/api/admin/businesses/${encodeURIComponent(b)}/days`)).days,
    refetchInterval: OVERVIEW_REFRESH_MS,
    refetchIntervalInBackground: false,
  });
}

export function useDay(b: string, id: string | null) {
  return useQuery<DayDetail, ApiError>({
    queryKey: dayKey(b, id ?? ''),
    queryFn: () => api.get<DayDetail>(`/api/admin/businesses/${encodeURIComponent(b)}/days/${encodeURIComponent(id ?? '')}`),
    enabled: id !== null,
  });
}
