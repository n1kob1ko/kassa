import type { FastifyInstance, FastifyReply } from 'fastify';
import { z } from 'zod';
import { audit } from '../audit.js';
import { isUuid } from '../auth/guards.js';
import { randomToken, sha256 } from '../auth/secrets.js';
import { clientAddress, rateKey } from '../client_address.js';
import { setBusiness, withSystem } from '../db/tenant.js';
import { ApiError } from '../errors.js';
import { SlidingWindow } from '../rate_limit.js';

const CODE = /^[0-9]{8}$/;
const MAX_ATTEMPTS = 10;
const ATTEMPT_WINDOW_MS = 15 * 60 * 1000;
/** Falsche Codes über alle Adressen zusammen: Raten mit vielen Adressen soll nicht gelingen. */
const MAX_ATTEMPTS_ALL = 200;
const ALL = 'all';
const MAX_TEXT = 100;

const optionalText = z.string().max(MAX_TEXT).nullable().optional();
const pairBody = z.object({
  code: z.unknown().optional(),
  previousBusinessId: z.string().refine(isUuid).nullable().optional(),
  appVersion: optionalText,
  deviceModel: optionalText,
});

const invalidCode = () => new ApiError(404, 'invalid_code', 'Der Code stimmt nicht oder ist abgelaufen.');

type Paired = { registerId: string; registerName: string; businessId: string; businessName: string };

/** POST /api/device/pair: ein Tablet löst einen Kopplungscode ein und bekommt seinen Geräte-Schlüssel. */
export function installPairRoutes(app: FastifyInstance): void {
  const { config, db, now } = app.deps;
  // Pro App eine eigene Zählung, damit Tests sich nicht gegenseitig sperren.
  const failures = new SlidingWindow(MAX_ATTEMPTS, ATTEMPT_WINDOW_MS);
  const failuresAll = new SlidingWindow(MAX_ATTEMPTS_ALL, ATTEMPT_WINDOW_MS, { maxKeys: 1 });

  /** Prüft die Anfrage und koppelt. Ein falscher Code wirft `wrongCode()`, alles andere zählt nicht als Fehlversuch. */
  async function attempt(rawBody: unknown, at: Date, wrongCode: () => ApiError): Promise<Paired & { token: string }> {
    const parsed = pairBody.safeParse(rawBody);
    if (!parsed.success) throw new ApiError(400, 'bad_request', 'Die Anfrage ist nicht in Ordnung.');
    const body = parsed.data;
    const previous = body.previousBusinessId?.toLowerCase() ?? null;
    if (typeof body.code !== 'string' || !CODE.test(body.code)) throw wrongCode();
    const code = body.code;

    const token = randomToken();
    const paired = await withSystem(db, async (c): Promise<Paired | null> => {
      // Löst den Code ein. Jeder Fehler danach rollt das zurück, der Code gilt dann weiter.
      const claim = (
        await c.query<{ business_id: string; register_name: string }>(
          'select business_id, register_name from claim_pairing_code($1, $2)',
          [sha256(code), at],
        )
      ).rows[0];
      if (!claim) return null;
      const businessId = claim.business_id;
      if (previous !== null && previous !== businessId) {
        throw new ApiError(
          409,
          'other_business',
          'Dieses Tablet war schon mit einem anderen Betrieb gekoppelt. Lösche die App-Daten, um es mit diesem Betrieb zu koppeln.',
        );
      }
      await setBusiness(c, businessId);
      const business = (await c.query<{ name: string }>('select name from businesses where id = $1', [businessId])).rows[0]!;
      const registerId = (
        await c.query<{ id: string }>(
          `insert into registers (business_id, name, token_hash, paired_at, last_seen_at, app_version, device_model)
           values ($1, $2, $3, $4, $4, $5, $6) returning id`,
          [businessId, claim.register_name, sha256(token), at, body.appVersion ?? null, body.deviceModel ?? null],
        )
      ).rows[0]!.id;
      await audit(
        c,
        { businessId, action: 'register.pair', detail: { registerId, name: claim.register_name, deviceModel: body.deviceModel ?? null } },
        at,
      );
      return { registerId, registerName: claim.register_name, businessId, businessName: business.name };
    });
    if (!paired) throw wrongCode();
    return { ...paired, token };
  }

  app.post('/api/device/pair', async (req, reply) => {
    const at = now();
    const ip = rateKey(clientAddress(req, config));
    // Vor jeder Arbeit an der Datenbank je einen Platz pro Adresse (Netz) und über alle reservieren, damit auch
    // gleichzeitige Anfragen die Grenzen halten. Nur ein falscher Code behält seine Plätze.
    // Eine abgewiesene Anfrage hält keinen Platz, die Sperre speist sich also nicht selbst.
    if (!failures.hit(ip, at)) throw tooMany(reply, failures.retryAfterMs(ip, at));
    if (!failuresAll.hit(ALL, at)) {
      failures.release(ip, at);
      throw tooMany(reply, failuresAll.retryAfterMs(ALL, at));
    }
    let wrong = false;
    try {
      return await attempt(req.body, at, () => {
        wrong = true;
        return invalidCode();
      });
    } finally {
      // Gekoppelt, anderer Betrieb, falsche Anfrage: Die Plätze gehen zurück.
      if (!wrong) {
        failures.release(ip, at);
        failuresAll.release(ALL, at);
      }
    }
  });
}

function tooMany(reply: FastifyReply, retryAfterMs: number): ApiError {
  const seconds = Math.max(Math.ceil(retryAfterMs / 1000), 1);
  const minutes = Math.ceil(seconds / 60);
  reply.header('retry-after', String(seconds));
  return new ApiError(
    429,
    'too_many_attempts',
    `Zu viele Versuche. Bitte in ${minutes} ${minutes === 1 ? 'Minute' : 'Minuten'} nochmal.`,
    { retryAfterSeconds: seconds },
  );
}
