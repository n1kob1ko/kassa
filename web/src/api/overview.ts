import { keepPreviousData, useQuery } from '@tanstack/react-query';
import type { OverviewRange } from '../format';
import { api, ApiError } from './client';

export type { OverviewRange };

/** Ein Balken: Stunde (`"14"`) oder Tag (`"19.11."`), Beginn als Zeitpunkt in UTC, Umsatz in Cent. */
export type Bucket = { label: string; start: string; cents: number };

/** Antwort von `GET /api/admin/businesses/:b/overview`. Der Server rechnet alles in der Zeitzone des Betriebs. */
export type Overview = {
  range: OverviewRange;
  /** Der Betrieb hat noch keinen echten Bon: alle Zahlen sind aus Testbons. */
  testMode: boolean;
  revenueCents: number;
  previousRevenueCents: number;
  receiptCount: number;
  voidCount: number;
  buckets: Bucket[];
  cashCents: number;
  cardCents: number;
  topItems: { name: string; quantity: number; cents: number }[];
  byCategory: { name: string; cents: number }[];
};

/** Wie oft die Seite still nachlädt, solange sie sichtbar ist. */
export const OVERVIEW_REFRESH_MS = 60_000;

export const overviewKey = (b: string, range: OverviewRange) => ['overview', b, range] as const;

/**
 * Die Umsätze eines Zeitraums. Beim Wechsel des Zeitraums bleiben die alten Zahlen stehen, bis die neuen da sind
 * (`isPlaceholderData`). Nachgeladen wird alle 60 Sekunden, nur solange die Seite sichtbar ist; scheitert das,
 * behält die Abfrage die letzten Zahlen (`data` bleibt, `isError` wird wahr).
 */
export function useOverview(b: string, range: OverviewRange) {
  return useQuery<Overview, ApiError>({
    queryKey: overviewKey(b, range),
    queryFn: () => api.get<Overview>(`/api/admin/businesses/${encodeURIComponent(b)}/overview?range=${range}`),
    placeholderData: keepPreviousData,
    refetchInterval: OVERVIEW_REFRESH_MS,
    refetchIntervalInBackground: false,
  });
}
