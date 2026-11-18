import type pg from 'pg';

export type AuditEntry = { userId?: string; businessId?: string; action: string; detail?: object };

/**
 * Schreibt einen Eintrag in den Verlauf. Der Dienst darf ihn nur ergänzen.
 * In `detail` gehört nie ein Geheimnis, auch nicht als Prüfwert.
 */
export async function audit(c: pg.ClientBase, entry: AuditEntry, now: Date): Promise<void> {
  await c.query(
    `insert into audit_log (at, user_id, business_id, action, detail) values ($1, $2, $3, $4, $5)`,
    [now, entry.userId ?? null, entry.businessId ?? null, entry.action, JSON.stringify(entry.detail ?? {})],
  );
}
