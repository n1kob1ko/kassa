import { randomBytes } from 'node:crypto';
import type { Db } from '../../src/db/db.js';
import { withBusiness } from '../../src/db/tenant.js';

export type RegisterFields = {
  name?: string;
  pairedAt?: Date;
  lastSeenAt?: Date | null;
  appVersion?: string | null;
  deviceModel?: string | null;
  blockedAt?: Date | null;
  /** Der Prüfwert des Geräte-Schlüssels. Ohne Angabe ein zufälliger. */
  tokenHash?: Buffer;
};

/** Legt direkt per SQL eine Kasse für einen Betrieb an (ohne Kopplung) und gibt ihre Kennung zurück. */
export function insertRegister(db: Db, businessId: string, f: RegisterFields = {}): Promise<string> {
  return withBusiness(db, businessId, async (c) => {
    const r = await c.query<{ id: string }>(
      `insert into registers (business_id, name, token_hash, paired_at, last_seen_at, app_version, device_model, blocked_at)
       values ($1, $2, $3, coalesce($4, now()), $5, $6, $7, $8) returning id`,
      [
        businessId,
        f.name ?? 'Kassa 1',
        f.tokenHash ?? randomBytes(32),
        f.pairedAt ?? null,
        f.lastSeenAt ?? null,
        f.appVersion ?? null,
        f.deviceModel ?? null,
        f.blockedAt ?? null,
      ],
    );
    return r.rows[0]!.id;
  });
}

/** Legt direkt per SQL einen Mitarbeiter an (ohne echten PIN-Prüfwert) und gibt seine Kennung zurück. */
export function insertStaff(
  db: Db,
  businessId: string,
  f: { name?: string; role?: 'chef' | 'staff'; archived?: boolean } = {},
): Promise<string> {
  return withBusiness(db, businessId, async (c) => {
    const r = await c.query<{ id: string }>(
      `insert into staff (business_id, name, role, pin_salt, pin_hash, archived, change_seq)
       values ($1, $2, $3, 'aa', 'bb', $4, nextval('change_seq')) returning id`,
      [businessId, f.name ?? 'Chefin', f.role ?? 'chef', f.archived ?? false],
    );
    return r.rows[0]!.id;
  });
}
