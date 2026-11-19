import { useInfiniteQuery, useQuery } from '@tanstack/react-query';
import { api, ApiError } from './client';

/** Eine Zeile von `GET /api/admin/reports` (nur für den Anbieter). */
export type Report = {
  id: string;
  businessName: string;
  /** Ohne Kassa (ein Bericht des Servers, der keiner Kassa gehört): `null`. */
  registerName: string | null;
  source: 'device' | 'server';
  /** Vom Tablet `error` oder `device_test`, vom Server etwa `receipt_sums`. */
  kind: string;
  at: string;
  appVersion: string | null;
  deviceModel: string | null;
  /** Wie oft das Tablet denselben Fehler gesehen hat. */
  count: number;
  /** Kommt vom Tablet oder Server: nur als Text zeigen, nie als HTML. */
  content: unknown;
};

export type ReportPage = { reports: Report[]; next: string | null };

/** Der Inhalt eines Fehlers und eines Geräte-Tests, so wie der Server sie speichert. */
export type ErrorContent = { type: string; message: string | null; stack: string };
export type DeviceResult = { device: string; ok: boolean; text: string };

/** Antwort von `GET /api/admin/backups/latest`. */
export type Backup = {
  latest: { day: string; finishedAt: string; size: number } | null;
  /** Nur, wenn der letzte Fehler jünger ist als die letzte gelungene Sicherung. */
  lastError: { at: string; error: string } | null;
};

export const REPORTS_KEY = ['reports'] as const;
export const BACKUP_KEY = ['backup'] as const;

/** Neueste zuerst, 50 pro Seite. `next` geht unverändert als `before` zurück. Scheitert "Mehr laden", bleiben die Seiten. */
export function useReports() {
  return useInfiniteQuery<ReportPage, ApiError, { pages: ReportPage[] }, typeof REPORTS_KEY, string | null>({
    queryKey: REPORTS_KEY,
    queryFn: ({ pageParam }) => api.get<ReportPage>(pageParam ? `/api/admin/reports?before=${encodeURIComponent(pageParam)}` : '/api/admin/reports'),
    initialPageParam: null,
    getNextPageParam: (last) => last.next ?? undefined,
  });
}

export function useBackup() {
  return useQuery<Backup, ApiError>({
    queryKey: BACKUP_KEY,
    queryFn: () => api.get<Backup>('/api/admin/backups/latest'),
  });
}

/** Ab wann eine Sicherung als zu alt gilt: täglich nach 3 Uhr, also mit Spielraum 36 Stunden. */
const STALE_MS = 36 * 60 * 60_000;

export function backupStale(finishedAt: string, now: Date): boolean {
  return now.getTime() - Date.parse(finishedAt) > STALE_MS;
}

/**
 * Wie die Karte der Sicherung steht: `none` ohne Sicherung und ohne Fehler, `ok` mit frischer Sicherung, `warn` bei
 * jedem letzten Fehler und bei einer Sicherung älter als 36 Stunden. `stale` sagt, ob der Satz dazu gehört.
 */
export function backupView(b: Backup, now: Date): { tone: 'none' | 'ok' | 'warn'; stale: boolean } {
  const stale = b.latest !== null && backupStale(b.latest.finishedAt, now);
  if (b.lastError !== null || stale) return { tone: 'warn', stale };
  return { tone: b.latest === null ? 'none' : 'ok', stale: false };
}

/** Die Art eines Berichts in einem Wort, wie in der Liste. */
export function kindLabel(r: Pick<Report, 'source' | 'kind'>): string {
  if (r.source === 'server') return 'Server';
  return r.kind === 'device_test' ? 'Geräte-Test' : 'Fehler';
}

const SERVER_KINDS: Record<string, string> = {
  receipt_conflict: 'Bon mit anderem Inhalt unter derselben Kennung',
  receipt_sums: 'Summen eines Bons passen nicht',
  rksv_conflict: 'Eintrag der Signatur weicht ab',
  certificate_conflict: 'Zertifikat mit anderem Inhalt unter derselben Seriennummer',
  chain_conflict: 'Beendete Kette mit anderem Inhalt',
  day_conflict: 'Abgeschlossener Tag mit anderem Inhalt',
  movement_conflict: 'Bargeld-Bewegung mit anderem Inhalt unter derselben Kennung',
};

/** Was der Server bemerkt hat, in Worten. Eine neue Art, die die Seite noch nicht kennt, steht wie sie heißt. */
export function serverKindText(kind: string): string {
  return SERVER_KINDS[kind] ?? kind;
}

const DEVICES: Record<string, string> = { printer: 'Drucker', drawer: 'Geldlade', card: 'Kartenleser' };

/** Die Geräte des Geräte-Tests in der App. */
export function deviceName(device: string): string {
  return DEVICES[device] ?? device;
}

const isObject = (v: unknown): v is Record<string, unknown> => typeof v === 'object' && v !== null && !Array.isArray(v);

/** Der Fehler aus dem Inhalt eines Berichts vom Tablet, wenn er die erwartete Form hat. */
export function errorOf(content: unknown): ErrorContent | null {
  const e = isObject(content) ? content.error : null;
  if (!isObject(e) || typeof e.type !== 'string' || typeof e.stack !== 'string') return null;
  return { type: e.type, message: typeof e.message === 'string' ? e.message : null, stack: e.stack };
}

/** Die Zeilen eines Geräte-Tests, wenn sie die erwartete Form haben. */
export function devicesOf(content: unknown): DeviceResult[] | null {
  const d = isObject(content) ? content.devices : null;
  if (!Array.isArray(d)) return null;
  return d.filter(
    (x): x is DeviceResult => isObject(x) && typeof x.device === 'string' && typeof x.ok === 'boolean' && typeof x.text === 'string',
  );
}
