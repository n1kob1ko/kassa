import { useQuery } from '@tanstack/react-query';
import type { Period } from '../period';
import { api, ApiError } from './client';
import type { TaxLine } from './days';

/** Eine Zeile von `GET /api/admin/businesses/:b/months`: ein abgeschlossener Monat, auch ohne Bons. */
export type MonthHead = { month: string; receiptCount: number; revenueCents: number };

export type Months = {
  /** Der Betrieb hat noch keinen echten Beleg: die Zahlen sind aus Testbons. */
  testMode: boolean;
  /** Ab wann es die nächste Monatsabrechnung gibt: der Erste des nächsten Monats, 'JJJJ-MM-TT'. */
  nextAvailable: string;
  /** Neueste zuerst. */
  months: MonthHead[];
};

/** Antwort von `GET .../months/summary`: ein Monat oder mehrere. */
export type PeriodSummary = {
  from: string;
  to: string;
  testMode: boolean;
  receiptCount: number;
  cashReceiptCount: number;
  cardReceiptCount: number;
  voidCount: number;
  /** Summe der Stornos als positive Zahl. */
  voidedCents: number;
  revenueCents: number;
  cashRevenueCents: number;
  cardRevenueCents: number;
  depositCents: number;
  /** Bons mit Rabatt (Storno zählt herunter) und die Summe der Rabatte. */
  discountCount: number;
  discountCents: number;
  /** Trinkgeld auf Karte, nicht im Umsatz. */
  cardTipCents: number;
  /** Karte plus Trinkgeld: was bei SumUp ankommt. */
  cardAccountCents: number;
  /** Trinkgeld auf Karte je Person, nach Name. */
  tipsByStaff: { staffName: string; cents: number }[];
  /** Mit Gutschein bezahlt. */
  voucherPaidCents: number;
  /** Verkaufte Gutscheine: Anzahl und Summe; nicht im Umsatz. */
  voucherSoldCount: number;
  voucherSoldCents: number;
  /** Pfand zurück: Stück und Summe, als positive Zahl. */
  depositReturnCount: number;
  depositReturnCents: number;
  taxLines: TaxLine[];
  /** Bei einem Monat je Tag ('JJJJ-MM-TT'), bei mehreren je Monat ('JJJJ-MM'), aufsteigend. */
  rows: { key: string; receiptCount: number; revenueCents: number }[];
};

const base = (b: string) => `/api/admin/businesses/${encodeURIComponent(b)}/months`;

export const monthsKey = (b: string) => ['months', b] as const;
export const periodKey = (b: string, p: Period | null) => ['period', b, p?.from ?? '', p?.to ?? ''] as const;

export function useMonths(b: string) {
  return useQuery<Months, ApiError>({
    queryKey: monthsKey(b),
    queryFn: () => api.get<Months>(base(b)),
  });
}

/** Die Abrechnung eines Zeitraums. Ohne Zeitraum (keiner offen oder eine unsinnige Adresse) keine Anfrage. */
export function usePeriodSummary(b: string, p: Period | null) {
  return useQuery<PeriodSummary, ApiError>({
    queryKey: periodKey(b, p),
    queryFn: () =>
      api.get<PeriodSummary>(`${base(b)}/summary?from=${encodeURIComponent(p?.from ?? '')}&to=${encodeURIComponent(p?.to ?? '')}`),
    enabled: p !== null,
  });
}
