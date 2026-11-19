import { expect, test } from 'vitest';
import { backupStale, backupView, deviceName, kindLabel, pushRejectedFacts, serverKindText } from './reports';

const NOW = new Date('2026-11-19T10:00:00.000Z');
const HOUR = 60 * 60_000;

test('backupStale: erst über 36 Stunden ist die Sicherung zu alt', () => {
  expect(backupStale(new Date(NOW.getTime() - 2 * HOUR).toISOString(), NOW)).toBe(false);
  expect(backupStale(new Date(NOW.getTime() - 36 * HOUR).toISOString(), NOW)).toBe(false);
  expect(backupStale(new Date(NOW.getTime() - 36 * HOUR - 1).toISOString(), NOW)).toBe(true);
  expect(backupStale(new Date(NOW.getTime() - 5 * 24 * HOUR).toISOString(), NOW)).toBe(true);
});

test('kindLabel: Fehler, Geräte-Test, Server', () => {
  expect(kindLabel({ source: 'device', kind: 'error' })).toBe('Fehler');
  expect(kindLabel({ source: 'device', kind: 'device_test' })).toBe('Geräte-Test');
  expect(kindLabel({ source: 'server', kind: 'receipt_sums' })).toBe('Server');
  expect(kindLabel({ source: 'server', kind: 'error' })).toBe('Server');
  expect(kindLabel({ source: 'server', kind: 'push_rejected' })).toBe('Eintrag abgelehnt');
});

test('pushRejectedFacts: Art, Nummer, Grund, Felder und Code der Datenbank in Worten', () => {
  expect(pushRejectedFacts({ entryKind: 'receipt', seq: 12, reason: 'invalid', paths: ['receipt.totalCents', 'receipt.lines.0.position'] })).toEqual([
    { label: 'Art', value: 'Bon' },
    { label: 'Nummer in der Sendung', value: '12' },
    { label: 'Grund', value: 'nicht lesbar' },
    { label: 'Felder', value: 'receipt.totalCents, receipt.lines.0.position' },
  ]);
  expect(pushRejectedFacts({ entryKind: 'item_change', seq: 3, reason: 'unknown_item' })).toEqual([
    { label: 'Art', value: 'Artikel-Änderung' },
    { label: 'Nummer in der Sendung', value: '3' },
    { label: 'Grund', value: 'den Artikel gibt es am Server nicht' },
  ]);
  expect(pushRejectedFacts({ entryKind: 'day', seq: 4, reason: 'invalid', sqlState: '23505' })).toContainEqual({
    label: 'Die Datenbank lehnte ab',
    value: 'Code 23505',
  });
  // Eine Art, die die Seite nicht kennt, steht wie sie heißt; leere Pfade fallen weg.
  expect(pushRejectedFacts({ entryKind: 'neu', seq: 1, reason: 'invalid', paths: [] })).toEqual([
    { label: 'Art', value: 'neu' },
    { label: 'Nummer in der Sendung', value: '1' },
    { label: 'Grund', value: 'nicht lesbar' },
  ]);
  expect(pushRejectedFacts({ receiptId: 'x' })).toBeNull();
  expect(pushRejectedFacts(null)).toBeNull();
});

test('serverKindText: jede Art des Servers in Worten, eine unbekannte unverändert', () => {
  expect(serverKindText('receipt_conflict')).toBe('Bon mit anderem Inhalt unter derselben Kennung');
  expect(serverKindText('receipt_sums')).toBe('Summen eines Bons passen nicht');
  expect(serverKindText('rksv_conflict')).toBe('Eintrag der Signatur weicht ab');
  expect(serverKindText('certificate_conflict')).toBe('Zertifikat mit anderem Inhalt unter derselben Seriennummer');
  expect(serverKindText('chain_conflict')).toBe('Beendete Kette mit anderem Inhalt');
  expect(serverKindText('day_conflict')).toBe('Abgeschlossener Tag mit anderem Inhalt');
  expect(serverKindText('movement_conflict')).toBe('Bargeld-Bewegung mit anderem Inhalt unter derselben Kennung');
  expect(serverKindText('push_rejected')).toBe('Der Server hat einen Eintrag vom Tablet nicht angenommen');
  expect(serverKindText('etwas_neues')).toBe('etwas_neues');
});

test('deviceName: Geräte des Geräte-Tests in Worten', () => {
  expect(deviceName('printer')).toBe('Drucker');
  expect(deviceName('drawer')).toBe('Geldlade');
  expect(deviceName('card')).toBe('Kartenleser');
  expect(deviceName('waage')).toBe('waage');
});

test('backupView: ein letzter Fehler warnt immer, eine alte Sicherung auch', () => {
  const fresh = { day: '2026-11-19', finishedAt: new Date(NOW.getTime() - 7 * HOUR).toISOString(), size: 1 };
  const old = { day: '2026-11-17', finishedAt: new Date(NOW.getTime() - 55 * HOUR).toISOString(), size: 1 };
  const lastError = { at: new Date(NOW.getTime() - 6 * HOUR).toISOString(), error: 'pg_dump: Fehler' };
  expect(backupView({ latest: null, lastError: null }, NOW)).toEqual({ tone: 'none', stale: false });
  expect(backupView({ latest: null, lastError }, NOW)).toEqual({ tone: 'warn', stale: false });
  expect(backupView({ latest: fresh, lastError: null }, NOW)).toEqual({ tone: 'ok', stale: false });
  expect(backupView({ latest: fresh, lastError }, NOW)).toEqual({ tone: 'warn', stale: false });
  expect(backupView({ latest: old, lastError }, NOW)).toEqual({ tone: 'warn', stale: true });
  // Ohne Fehler, aber zu alt: ebenfalls Warnung (wie bisher).
  expect(backupView({ latest: old, lastError: null }, NOW)).toEqual({ tone: 'warn', stale: true });
});
