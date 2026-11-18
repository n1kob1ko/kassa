import { expect, test } from 'vitest';
import { closeDb, openDb } from '../src/db/db.js';

test('Fehler einer Leerlauf-Verbindung: nur die Meldung ins Protokoll, nie die Adresse mit Passwort', async () => {
  const logged: string[] = [];
  const db = openDb(
    { databaseUrl: 'postgres://kassa:besitzer-geheim@127.0.0.1:1/kassa', appDbPassword: 'app-geheim' },
    { onError: (message) => logged.push(message) },
  );
  db.pool.emit(
    'error',
    new Error('Connection terminated unexpectedly (postgres://kassa_app:app-geheim@127.0.0.1:1/kassa)'),
    undefined as never,
  );
  expect(logged).toHaveLength(1);
  expect(logged[0]).toMatch(/Connection terminated unexpectedly/);
  expect(logged[0]).not.toContain('geheim');
  await closeDb(db);
});
