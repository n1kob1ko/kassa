import type { FastifyInstance } from 'fastify';
import type pg from 'pg';
import { audit } from '../audit.js';
import { isUuid, requireBusinessAccess } from '../auth/guards.js';
import { withBusiness } from '../db/tenant.js';
import { ApiError } from '../errors.js';

const notFound = () => new ApiError(404, 'not_found', 'Das gibt es nicht.');

type Group = { Signaturzertifikat: string; Zertifizierungsstellen: string[]; 'Belege-kompakt': string[] };

/**
 * Das Protokoll einer Kette in der Form des Finanzministeriums, wie `buildDepExport` in der App:
 * eine Gruppe je zusammenhängender Folge von Einträgen mit derselben Seriennummer, Einträge in Reihenfolge.
 * `null`, wenn es die Kette für das Gerät nicht gibt. Nur Zertifikate und JWS, nie ein Schlüssel.
 */
export async function buildDep(c: pg.PoolClient, deviceId: string, chain: number): Promise<{ 'Belege-Gruppe': Group[] } | null> {
  const exists = await c.query('select 1 from rksv_chains where device_id = $1 and chain = $2', [deviceId, chain]);
  if (exists.rowCount === 0) return null;
  const entries = (
    await c.query<{ jws: string; cert_serial: string }>(
      'select jws, cert_serial from rksv_entries where device_id = $1 and chain = $2 order by position',
      [deviceId, chain],
    )
  ).rows;
  const serials = [...new Set(entries.map((e) => e.cert_serial))];
  const certificates = new Map(
    (
      await c.query<{ serial_hex: string; certificate: Buffer; issuers: string[] }>(
        'select serial_hex, certificate, issuers from rksv_certificates where device_id = $1 and serial_hex = any($2)',
        [deviceId, serials],
      )
    ).rows.map((r) => [r.serial_hex, r]),
  );
  const groups: Group[] = [];
  let serial: string | undefined;
  let compact: string[] = [];
  for (const e of entries) {
    if (e.cert_serial !== serial) {
      serial = e.cert_serial;
      const cert = certificates.get(serial);
      if (!cert) throw new Error(`Zertifikat ${serial} fehlt in rksv_certificates.`);
      compact = [];
      groups.push({
        Signaturzertifikat: cert.certificate.toString('base64'),
        Zertifizierungsstellen: cert.issuers,
        'Belege-kompakt': compact,
      });
    }
    compact.push(e.jws);
  }
  return { 'Belege-Gruppe': groups };
}

/** Adresse für die Protokoll-Datei einer Kette. Nach installAuth aufrufen. */
export function installDepRoutes(app: FastifyInstance): void {
  const { db, now } = app.deps;

  app.get<{ Params: { b: string; r: string }; Querystring: { chain?: unknown } }>(
    '/api/admin/businesses/:b/registers/:r/dep',
    async (req, reply) => {
      const user = await requireBusinessAccess(req, req.params.b);
      const businessId = req.params.b.toLowerCase();
      const raw = req.query.chain;
      if (typeof raw !== 'string' || !/^[1-9][0-9]{0,8}$/.test(raw)) {
        throw new ApiError(422, 'chain_invalid', 'Die Kette muss eine ganze Zahl ab 1 sein.');
      }
      const chain = Number(raw);
      if (!isUuid(req.params.r)) throw notFound();
      const registerId = req.params.r.toLowerCase();
      const at = now();
      const found = await withBusiness(db, businessId, async (c) => {
        const reg = (await c.query<{ device_id: string | null }>('select device_id from registers where id = $1', [registerId])).rows[0];
        if (!reg?.device_id) return null;
        const head = (await c.query<{ cash_box_id: string }>('select cash_box_id from rksv_chains where device_id = $1 and chain = $2', [reg.device_id, chain])).rows[0];
        if (!head) return null;
        const file = await buildDep(c, reg.device_id, chain);
        if (!file) return null;
        // Nur die Kennung, nie der Inhalt der Datei.
        await audit(c, { userId: user.id, businessId, action: 'rksv.dep_download', detail: { registerId, chain, cashBoxId: head.cash_box_id } }, at);
        return { file, cashBoxId: head.cash_box_id };
      });
      if (!found) throw notFound();
      // Die Kennung kommt vom Tablet: Nur Zeichen, die in einem Dateinamen und einer Kopfzeile sicher sind.
      const safe = found.cashBoxId.replace(/[^A-Za-z0-9._-]/g, '_');
      return reply
        .type('application/json; charset=utf-8')
        .header('content-disposition', `attachment; filename="kassa-protokoll-${safe}-kette-${chain}.json"`)
        .send(JSON.stringify(found.file));
    },
  );
}
