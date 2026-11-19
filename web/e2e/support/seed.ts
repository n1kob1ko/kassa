import { randomBytes, randomUUID, scrypt } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { expect, type Page } from '@playwright/test';
import pg from 'pg';

/**
 * Daten so einspielen, wie ein gekoppeltes Tablet sie sendet (`POST /api/device/sync/push`), für die Seiten mit
 * Umsätzen, Bons und Tagen. `createSite` braucht eine als Anbieter angemeldete Seite (`signInAsProvider`).
 *
 *   const site = await createSite(page, { owner: true });
 *   await pushEntries(page, site, [{ kind: 'receipt', receipt: saleReceipt({ lines: [line(MENU.cola, 2)] }) }]);
 */

const HEADERS = { 'X-Kassa-Request': '1' };
const MENU_FILE = fileURLToPath(new URL('../../../shared/fixtures/menu/inputs/beispiel-imbiss.json', import.meta.url));
const MENU_TEXT = readFileSync(MENU_FILE, 'utf8');

/** Die Artikel der Beispiel-Speisekarte (`beispiel-imbiss.json`), mit denen `createSite` den Betrieb anlegt. */
export const MENU = {
  huhnBowl: { itemId: 'huhn-bowl', name: 'Huhn Bowl', unitPriceCents: 990, vat: '10', unitDepositCents: 0 },
  teigtaschen: { itemId: 'teigtaschen', name: 'Teigtaschen', unitPriceCents: 650, vat: '10', unitDepositCents: 0 },
  cola: { itemId: 'cola', name: 'Cola 0,33 l', unitPriceCents: 290, vat: '20', unitDepositCents: 25 },
} as const;

export type MenuItem = { itemId: string; name: string; unitPriceCents: number; vat: '20' | '10' | '13' | '0' | '19'; unitDepositCents: number };
export type Option = { groupName: string; optionName: string; surchargeCents: number };

/** Die Anmeldedaten des Chefs, wenn `createSite` mit `owner: true` einen angelegt hat. */
export type Owner = { email: string; password: string };

export type Site = {
  businessId: string;
  registerId: string;
  /** Das Gerät, das sendet: Bearer-Schlüssel und Geräte-Kennung. */
  token: string;
  deviceId: string;
  /** Mitarbeiter am Tablet (Chef mit PIN 1234), so wie ihn die Bons nennen. */
  staffName: string;
  owner?: Owner;
};

/** Ein Eintrag des Pakets ohne `seq`: `pushEntries` nummeriert selbst. */
export type Entry = { kind: string; [key: string]: unknown };

async function post<T>(page: Page, url: string, data: unknown): Promise<T> {
  const res = await page.request.post(url, { headers: HEADERS, data });
  expect(res.ok(), `${url}: ${res.status()} ${await res.text()}`).toBe(true);
  return (await res.json()) as T;
}

/** Prüfwert im Format des Servers (`server/src/auth/passwords.ts`), mit den kleinsten erlaubten Kosten. */
function hashPassword(password: string): Promise<string> {
  const salt = randomBytes(16);
  const cost = 1024;
  return new Promise((resolve, reject) => {
    scrypt(password, salt, 32, { N: cost, r: 8, p: 1 }, (err, key) =>
      err ? reject(err) : resolve(`scrypt$${cost}$8$1$${salt.toString('base64')}$${key.toString('base64')}`),
    );
  });
}

/**
 * Ein Chef-Konto für die Verwaltung. Die Schnittstelle legt Chefs (noch) nicht an, darum direkt in der
 * Datenbank des Servers für die Browser-Tests (`KASSA_E2E_DATABASE_URL` aus server.ts).
 */
async function createOwner(businessId: string): Promise<Owner> {
  const url = process.env.KASSA_E2E_DATABASE_URL;
  if (!url) throw new Error('KASSA_E2E_DATABASE_URL fehlt: läuft der Test über "npm run e2e"?');
  const owner = { email: `chef-${randomBytes(4).toString('hex')}@example.com`, password: 'chef-passwort-123' };
  const client = new pg.Client({ connectionString: url });
  await client.connect();
  try {
    await client.query(`insert into users (email, password_hash, role, business_id) values ($1, $2, 'chef', $3)`, [
      owner.email,
      await hashPassword(owner.password),
      businessId,
    ]);
  } finally {
    await client.end();
  }
  return owner;
}

/**
 * Legt einen Betrieb mit der Beispiel-Speisekarte, einem Chef-Mitarbeiter (PIN 1234) und einer gekoppelten Kassa an
 * und gibt zurück, was zum Senden nötig ist. Mit `owner: true` dazu ein Chef-Konto für die Verwaltung.
 */
export async function createSite(page: Page, opts: { name?: string; registerName?: string; owner?: boolean } = {}): Promise<Site> {
  const menuFile = opts.name ? MENU_TEXT.replace(/Beispiel-Imbiss/g, opts.name) : MENU_TEXT;
  const businessId = (await post<{ business: { id: string } }>(page, '/api/admin/businesses', { menuFile })).business.id;
  const staffName = 'Chefin';
  await post(page, `/api/admin/businesses/${businessId}/staff`, { name: staffName, role: 'chef', pin: '1234' });
  const { code } = await post<{ code: string }>(page, `/api/admin/businesses/${businessId}/pairing-codes`, {
    name: opts.registerName ?? 'Theke',
  });
  const paired = await post<{ token: string; registerId: string }>(page, '/api/device/pair', {
    code,
    previousBusinessId: null,
    appVersion: '1.5.0',
    deviceModel: 'Redmi Pad Pro',
  });
  const site: Site = { businessId, registerId: paired.registerId, token: paired.token, deviceId: randomUUID(), staffName };
  if (opts.owner) site.owner = await createOwner(businessId);
  return site;
}

let seq = 0;

/**
 * Sendet Einträge wie das Tablet (`{ kind: 'receipt', receipt }`, `{ kind: 'day', day }`, `{ kind: 'cash_movement',
 * movement }`, `{ kind: 'report', report }` …). Bricht ab, sobald ein Ergebnis nicht `accepted` ist, mit allen Ergebnissen.
 */
export async function pushEntries(page: Page, site: Pick<Site, 'token' | 'deviceId'>, entries: Entry[]): Promise<void> {
  const numbered = entries.map((e) => ({ seq: ++seq, ...e }));
  const res = await page.request.post('/api/device/sync/push', {
    headers: { Authorization: `Bearer ${site.token}` },
    data: { deviceId: site.deviceId, entries: numbered },
  });
  const text = await res.text();
  expect(res.status(), `Senden: ${text}`).toBe(200);
  const { results } = JSON.parse(text) as { results: { seq: number; status: string; reason?: string }[] };
  const bad = results.filter((r) => r.status !== 'accepted');
  expect(bad, `Senden: nicht angenommen: ${JSON.stringify(bad)}`).toEqual([]);
  expect(results).toHaveLength(entries.length);
}

/** Eine Bon-Zeile aus einem Artikel der Speisekarte. Aufpreise der Optionen zählen zum Stückpreis. */
export function line(item: MenuItem, quantity = 1, options: Option[] = []) {
  const unitPriceCents = item.unitPriceCents + options.reduce((s, o) => s + o.surchargeCents, 0);
  const gross = { '20': 0, '10': 0, '13': 0, '0': 0, '19': 0 };
  gross[item.vat] = unitPriceCents * quantity;
  return {
    itemId: item.itemId,
    name: item.name,
    info: null,
    unitPriceCents,
    quantity,
    unitDepositCents: item.unitDepositCents,
    gross,
    options,
  };
}

type Line = ReturnType<typeof line>;

let receiptNumber = 0;

/**
 * Ein Verkaufsbon mit stimmigen Summen. `payment` ist `'cash'` (passend gegeben) oder `'card'` (SumUp, VISA).
 * `createdAt` ist eine Zeit, am besten einige Minuten vor jetzt (der Server rechnet mit der echten Uhr).
 */
export function saleReceipt(opts: {
  lines: Line[];
  createdAt?: Date;
  payment?: 'cash' | 'card';
  staffName?: string;
  businessDayId?: string;
  test?: boolean;
  number?: number;
  /** Bar: gegebener Betrag (Rückgeld ist der Rest). Ohne: passend gegeben. */
  givenCents?: number;
  /** Eintrag im Protokoll der Signatur (`signature(...)`), ohne: `null`. */
  rksv?: ReturnType<typeof signature> | null;
}) {
  const goodsCents = opts.lines.reduce((s, l) => s + l.unitPriceCents * l.quantity, 0);
  const depositCents = opts.lines.reduce((s, l) => s + l.unitDepositCents * l.quantity, 0);
  const totalCents = goodsCents + depositCents;
  const card = opts.payment === 'card';
  return {
    v: 1,
    id: randomUUID(),
    number: opts.number ?? ++receiptNumber,
    createdAt: (opts.createdAt ?? new Date(Date.now() - 60_000)).toISOString(),
    staffId: 'chefin',
    staffName: opts.staffName ?? 'Chefin',
    businessDayId: opts.businessDayId ?? randomUUID(),
    kind: 'sale',
    voidsReceiptId: null as string | null,
    goodsCents,
    depositCents,
    totalCents,
    test: opts.test ?? true,
    lines: opts.lines.map((l, position) => ({ position, ...l })),
    payment: card
      ? { kind: 'card', amountCents: totalCents, givenCents: 0, changeCents: 0, provider: 'sumup', providerTxCode: `T${receiptNumber}`, cardScheme: 'VISA', cardLast4: '4242' }
      : {
          kind: 'cash',
          amountCents: totalCents,
          givenCents: opts.givenCents ?? totalCents,
          changeCents: (opts.givenCents ?? totalCents) - totalCents,
          provider: null,
          providerTxCode: null,
          cardScheme: null,
          cardLast4: null,
        },
    rksv: opts.rksv ?? null,
  };
}

export type Receipt = ReturnType<typeof saleReceipt>;

/**
 * Ein Eintrag im Protokoll der Signatur für `saleReceipt({ rksv })`. Ohne Kette am Server (`rksv_chain`) gilt er als
 * Probe; `damaged: true` heißt "Signatur ausgefallen". Die JWS ist ein Platzhalter, die Verwaltung zeigt sie nie.
 */
export function signature(opts: { chain?: number; position: number; damaged?: boolean }) {
  return { chain: opts.chain ?? 1, position: opts.position, jws: 'eyJhbGciOiJFUzI1NiJ9.e30.platzhalter', damaged: opts.damaged ?? false, certSerial: '1a2b' };
}

/** Der Storno-Bon zu einem Verkauf, so wie die App ihn schreibt: Mengen und Beträge negativ, gleiche Zahlungsart. */
export function voidReceipt(sale: Receipt, opts: { createdAt?: Date; number?: number; staffName?: string } = {}): Receipt {
  const negate = (gross: Record<string, number>) => Object.fromEntries(Object.entries(gross).map(([k, v]) => [k, -v])) as typeof sale.lines[number]['gross'];
  return {
    ...sale,
    id: randomUUID(),
    number: opts.number ?? ++receiptNumber,
    createdAt: (opts.createdAt ?? new Date(Date.parse(sale.createdAt) + 30_000)).toISOString(),
    staffName: opts.staffName ?? sale.staffName,
    kind: 'voided',
    voidsReceiptId: sale.id,
    goodsCents: -sale.goodsCents,
    depositCents: -sale.depositCents,
    totalCents: -sale.totalCents,
    lines: sale.lines.map((l) => ({ ...l, quantity: -l.quantity, gross: negate(l.gross) })),
    payment: { ...sale.payment, amountCents: -sale.totalCents, givenCents: 0, changeCents: 0 },
    rksv: null,
  };
}

export type SpecialKind = 'start' | 'month' | 'year' | 'zero' | 'collective' | 'closing';

/** Ein Sonderbeleg (Startbeleg, Nullbeleg …): Betrag 0, ohne Zeilen, ohne Zahlung, ohne Tag. */
export function specialReceipt(kind: SpecialKind, opts: { createdAt?: Date; number?: number; test?: boolean } = {}) {
  return {
    v: 1,
    id: randomUUID(),
    number: opts.number ?? ++receiptNumber,
    createdAt: (opts.createdAt ?? new Date(Date.now() - 60_000)).toISOString(),
    staffId: 'chefin',
    staffName: 'Chefin',
    businessDayId: null,
    kind,
    voidsReceiptId: null,
    goodsCents: 0,
    depositCents: 0,
    totalCents: 0,
    test: opts.test ?? true,
    lines: [],
    payment: null,
    rksv: null,
  };
}

export type Day = {
  id: string;
  openedAt: string;
  closedAt: string | null;
  openingFloatCents: number;
  countedCents: number | null;
  leftInDrawerCents: number | null;
  expectedCents: number | null;
  differenceCents: number | null;
  closedByName: string | null;
};

/** Ein offener Tag (Eintrag `{ kind: 'day', day }`), Wechselgeld 100 Euro, wenn nichts anderes gesagt ist. */
export function openDay(opts: { openedAt?: Date; openingFloatCents?: number } = {}): Day {
  return {
    id: randomUUID(),
    openedAt: (opts.openedAt ?? new Date(Date.now() - 60 * 60_000)).toISOString(),
    closedAt: null,
    openingFloatCents: opts.openingFloatCents ?? 10_000,
    countedCents: null,
    leftInDrawerCents: null,
    expectedCents: null,
    differenceCents: null,
    closedByName: null,
  };
}

/** Derselbe Tag abgeschlossen: die Differenz ist gezählt minus erwartet. Nochmal senden, wie das Tablet es tut. */
export function closeDay(
  day: Day,
  opts: { closedAt?: Date; expectedCents: number; countedCents: number; leftInDrawerCents?: number; closedByName?: string },
): Day {
  return {
    ...day,
    closedAt: (opts.closedAt ?? new Date(Date.now() - 60_000)).toISOString(),
    expectedCents: opts.expectedCents,
    countedCents: opts.countedCents,
    differenceCents: opts.countedCents - opts.expectedCents,
    leftInDrawerCents: opts.leftInDrawerCents ?? day.openingFloatCents,
    closedByName: opts.closedByName ?? 'Chefin',
  };
}

/** Eine Bargeld-Bewegung (`{ kind: 'cash_movement', movement }`): Grund `bank`, `purchase`, `change` oder `other`. */
export function cashMovement(
  day: Pick<Day, 'id'>,
  opts: { kind: 'deposit' | 'withdrawal'; amountCents: number; reason?: string; createdAt?: Date; staffName?: string },
) {
  return {
    id: randomUUID(),
    businessDayId: day.id,
    kind: opts.kind,
    amountCents: opts.amountCents,
    reason: opts.reason ?? 'bank',
    createdAt: (opts.createdAt ?? new Date(Date.now() - 30 * 60_000)).toISOString(),
    staffId: 'chefin',
    staffName: opts.staffName ?? 'Chefin',
  };
}

/** Beginn des Kalendertags von `at` in der Zeitzone `zone` (Wien wie jeder neue Betrieb), als Zeitpunkt. */
export function startOfLocalDay(at: Date, zone = 'Europe/Vienna'): Date {
  const parts = Object.fromEntries(
    new Intl.DateTimeFormat('en-US', { timeZone: zone, hourCycle: 'h23', year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', second: '2-digit' })
      .formatToParts(at)
      .map((p) => [p.type, p.value]),
  );
  const asUtc = Date.UTC(+parts.year!, +parts.month! - 1, +parts.day!, +parts.hour!, +parts.minute!, +parts.second!);
  const offset = asUtc - Math.floor(at.getTime() / 1000) * 1000;
  return new Date(Date.UTC(+parts.year!, +parts.month! - 1, +parts.day!) - offset);
}

/**
 * `count` Zeitpunkte, die sicher im heutigen Kalendertag (Wien) und vor jetzt liegen: im Abstand von einer Minute
 * vor jetzt, kurz nach Mitternacht aber dicht nach Tagesbeginn.
 */
export function earlierToday(count: number, now = new Date()): Date[] {
  const dayStart = startOfLocalDay(now).getTime();
  return Array.from({ length: count }, (_, i) => new Date(Math.max(now.getTime() - (count - i) * 60_000, dayStart + i + 1)));
}

/** Die Kette der Signatur (`{ kind: 'rksv_chain', chain }`): `live` heißt echt signiert, `probe` Probe. */
export function signatureChain(opts: { chain?: number; mode: 'probe' | 'live'; startedAt?: Date }) {
  return {
    chain: opts.chain ?? 1,
    mode: opts.mode,
    cashBoxId: 'KASSA1',
    zdaId: 'AT0',
    certSerial: '1a2b',
    startedAt: (opts.startedAt ?? new Date(Date.now() - 24 * 60 * 60_000)).toISOString(),
    endedAt: null,
  };
}

/** Ein Fehlerbericht des Tablets (`{ kind: 'report', report }`), wie die App ihn schreibt. */
export function errorReport(opts: { type?: string; message?: string | null; stack?: string; count?: number; at?: Date; appVersion?: string } = {}) {
  return {
    id: randomUUID(),
    kind: 'error',
    at: (opts.at ?? new Date(Date.now() - 5 * 60_000)).toISOString(),
    appVersion: opts.appVersion ?? '1.5.0',
    androidVersion: '14',
    deviceModel: 'Redmi Pad Pro',
    count: opts.count ?? 1,
    error: {
      type: opts.type ?? 'RangeError',
      message: opts.message === undefined ? 'Index außerhalb der Liste' : opts.message,
      stack: opts.stack ?? '#0      List.[] (dart:core-patch/growable_array.dart:264:36)\n#1      BonView.build (package:kassa/features/bons/bon_view.dart:88:21)',
    },
    devices: null,
  };
}

/** Ein Bericht des Geräte-Tests: je Gerät (`printer`, `drawer`, `card`) in Ordnung oder nicht, mit dem Text der App. */
export function deviceTestReport(devices: { device: string; ok: boolean; text: string }[], opts: { at?: Date } = {}) {
  return {
    id: randomUUID(),
    kind: 'device_test',
    at: (opts.at ?? new Date(Date.now() - 5 * 60_000)).toISOString(),
    appVersion: '1.5.0',
    androidVersion: '14',
    deviceModel: 'Redmi Pad Pro',
    count: 1,
    error: null,
    devices,
  };
}

/** Das Zertifikat der Signatur (`{ kind: 'rksv_certificate', certificate }`) zur Seriennummer von `signature(...)`. */
export function signatureCertificate() {
  return { serialHex: '1a2b', certificate: 'AAAA', issuers: [] as string[] };
}
