import { expect, test } from 'vitest';
import { backupStale, deviceName, kindLabel, serverKindText } from './reports';

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
});

test('serverKindText: jede Art des Servers in Worten, eine unbekannte unverändert', () => {
  expect(serverKindText('receipt_conflict')).toBe('Bon mit anderem Inhalt unter derselben Kennung');
  expect(serverKindText('receipt_sums')).toBe('Summen eines Bons passen nicht');
  expect(serverKindText('rksv_conflict')).toBe('Eintrag der Signatur weicht ab');
  expect(serverKindText('certificate_conflict')).toBe('Zertifikat mit anderem Inhalt unter derselben Seriennummer');
  expect(serverKindText('chain_conflict')).toBe('Beendete Kette mit anderem Inhalt');
  expect(serverKindText('day_conflict')).toBe('Abgeschlossener Tag mit anderem Inhalt');
  expect(serverKindText('movement_conflict')).toBe('Bargeld-Bewegung mit anderem Inhalt unter derselben Kennung');
  expect(serverKindText('etwas_neues')).toBe('etwas_neues');
});

test('deviceName: Geräte des Geräte-Tests in Worten', () => {
  expect(deviceName('printer')).toBe('Drucker');
  expect(deviceName('drawer')).toBe('Geldlade');
  expect(deviceName('card')).toBe('Kartenleser');
  expect(deviceName('waage')).toBe('waage');
});
