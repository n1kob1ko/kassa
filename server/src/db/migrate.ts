import { readdir, readFile } from 'node:fs/promises';
import pg from 'pg';

const MIGRATIONS_DIR = new URL('../../migrations/', import.meta.url);
const LOCK_KEY = 7417;

/**
 * Die Funktionen für Geräte-Schlüssel und Kopplungscode laufen mit den Rechten des Besitzers.
 * FORCE ROW LEVEL SECURITY verbirgt ihnen sonst jede Zeile, darum muss der Besitzer die Sperre umgehen dürfen.
 */
async function assertOwnerBypassesRls(client: pg.Client): Promise<void> {
  const r = await client.query<{ rolname: string; rolsuper: boolean; rolbypassrls: boolean }>(
    'select rolname, rolsuper, rolbypassrls from pg_roles where rolname = current_user',
  );
  const role = r.rows[0]!;
  if (!role.rolsuper && !role.rolbypassrls) {
    throw new Error(
      `Database role "${role.rolname}" must be a superuser or have BYPASSRLS: it owns the tables, ` +
        'and the SECURITY DEFINER lookup functions run as the owner under FORCE ROW LEVEL SECURITY.',
    );
  }
}

/** kassa_app darf die Sperre nie umgehen, auch wenn die Rolle schon vorher anders angelegt war. */
export async function restrictAppRole(client: pg.ClientBase): Promise<void> {
  const r = await client.query<{ rolsuper: boolean; rolbypassrls: boolean }>(
    `select rolsuper, rolbypassrls from pg_roles where rolname = 'kassa_app'`,
  );
  const role = r.rows[0];
  if (role && (role.rolsuper || role.rolbypassrls)) {
    await client.query('alter role kassa_app nosuperuser nobypassrls');
  }
}

/**
 * Wendet server/migrations/*.sql in Namensreihenfolge an, jede in einer Transaktion.
 * Gibt die Namen zurück, die dabei neu angewendet wurden.
 */
export async function migrate(ownerUrl: string, opts: { appPassword: string }): Promise<string[]> {
  const client = new pg.Client({ connectionString: ownerUrl });
  await client.connect();
  const applied: string[] = [];
  try {
    await assertOwnerBypassesRls(client);
    await client.query('select pg_advisory_lock($1)', [LOCK_KEY]);
    try {
      await client.query(
        `create table if not exists schema_migrations (
           name text primary key,
           applied_at timestamptz not null default now()
         )`,
      );
      const done = new Set(
        (await client.query<{ name: string }>('select name from schema_migrations')).rows.map((r) => r.name),
      );
      const files = (await readdir(MIGRATIONS_DIR)).filter((f) => f.endsWith('.sql')).sort();
      for (const name of files) {
        if (done.has(name)) continue;
        const sql = await readFile(new URL(name, MIGRATIONS_DIR), 'utf8');
        await client.query('begin');
        try {
          await client.query(sql);
          await client.query('insert into schema_migrations (name) values ($1)', [name]);
          await client.query('commit');
        } catch (err) {
          await client.query('rollback');
          throw err;
        }
        applied.push(name);
      }
      // Das Passwort kommt aus der Umgebung, darum wird es als Text eingesetzt und nicht verkettet.
      const stmt = await client.query<{ stmt: string }>(`select format('alter role kassa_app password %L', $1::text) as stmt`, [
        opts.appPassword,
      ]);
      await client.query(stmt.rows[0]!.stmt);
      await restrictAppRole(client);
    } finally {
      await client.query('select pg_advisory_unlock($1)', [LOCK_KEY]);
    }
  } finally {
    await client.end();
  }
  return applied;
}
