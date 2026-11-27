import { createHash } from 'node:crypto';
import type { FastifyBaseLogger, FastifyInstance, FastifyReply, FastifyRequest } from 'fastify';
import type pg from 'pg';
import { loadTimeZone } from '../admin/overview.js';
import { taxLinesOf } from '../admin/tax.js';
import { clientAddress, headerAddress, rateKey } from '../client_address.js';
import type { Db } from '../db/db.js';
import { setBusiness, withSystem } from '../db/tenant.js';
import { MissLimiter } from './miss_limiter.js';
import { isSafeSvg, qrSvg, rksvQrText } from './qr.js';

// Die öffentliche Seite eines Bons: GET /beleg/<Schlüssel>, ohne Anmeldung. Wer den Schlüssel nicht kennt, erfährt
// nichts: jeder falsche, kaputte oder fremde Schlüssel bekommt dieselbe Seite. Fehlversuche sind je Adresse gebremst.

/** Ein Schlüssel: genau 22 Zeichen base64url (128 Bit), wie das Tablet ihn zieht. */
const TOKEN = /^[A-Za-z0-9_-]{22}$/;
const PREFIX = '/beleg/';

/** Höchstens so viele VERSCHIEDENE Fehlversuche je Adresse in WINDOW_MS, danach 429 für den Rest des Fensters. */
export const MAX_FAILURES = 10;
export const WINDOW_MS = 10 * 60 * 1000;

const CONTENT_SECURITY_POLICY =
  "default-src 'none'; style-src 'unsafe-inline'; img-src data:; frame-ancestors 'none'; base-uri 'none'; form-action 'none'";

const VOUCHER_SALE_ITEM_ID = 'voucher-sale';
const DEPOSIT_RETURN_PREFIX = 'deposit-return-';

/** Eine Reihe der Seite: links der Text, rechts der Betrag. `sub` ist eingerückt (Auswahl, "je", Code). */
export type PageRow = { label: string; note?: string; cents?: number; sub?: boolean; strong?: boolean };

/** Alles, was die Seite zeigt, schon ausgewählt und gerechnet. Texte sind roh, renderReceiptPage maskiert sie. */
export type ReceiptPageView = {
  business: { name: string; addressLines: string[]; vatId: string | null };
  /** "STORNO" oder die Bezeichnung eines Sonderbelegs; darunter etwa "zu Bon Nr. 1". */
  title: string | null;
  titleDetail: string | null;
  /** "Storniert am …" bei einem stornierten Bon. */
  voidedAt: string | null;
  invoice: { number: string; name: string; addressLines: string[]; vatId: string | null } | null;
  number: number;
  createdAt: string;
  cashBoxId: string | null;
  lines: PageRow[];
  sums: PageRow[];
  taxes: PageRow[];
  payments: PageRow[];
  /** Der QR-Code der Signatur als <svg>; null ohne Eintrag der Signatur. */
  qr: { svg: string; damaged: boolean } | null;
  footer: string | null;
  test: boolean;
};

// ---------------------------------------------------------------------------------------------------------------
// Darstellung

/** Maskiert Text für HTML, auch in Attributen. */
export function esc(text: string): string {
  return text.replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]!);
}

/** Ein Betrag wie am Papier: `1.234,50`, `-0,75`. */
export function amount(cents: number): string {
  const abs = Math.abs(cents);
  const whole = String(Math.floor(abs / 100)).replace(/\B(?=(\d{3})+(?!\d))/g, '.');
  return `${cents < 0 ? '-' : ''}${whole},${String(abs % 100).padStart(2, '0')}`;
}

// Farben fest aus web/src/styles/tokens.css (hell und dunkel), Schrift des Systems: die Seite lädt nichts nach.
const STYLE = `
:root{color-scheme:light dark;--ground:#f3f4f6;--card:#ffffff;--ink:#14171a;--ink2:#5b6470;--line:#e2e5e9;--red:#b42318}
@media screen and (prefers-color-scheme:dark){:root{--ground:#0e1012;--card:#191c20;--ink:#f2f4f6;--ink2:#a3acb6;--line:#2c3138;--red:#ff8a80}}
*{box-sizing:border-box}
html{-webkit-text-size-adjust:100%;text-size-adjust:100%}
body{margin:0;background:var(--ground);color:var(--ink);font:15px/1.45 system-ui,-apple-system,"Segoe UI",Roboto,"Helvetica Neue",Arial,sans-serif}
main{max-width:400px;margin:16px auto;padding:20px 16px;background:var(--card);border-radius:20px;overflow-wrap:anywhere}
@media (max-width:432px){main{margin:16px;}}
h1{font-size:20px;line-height:1.25;margin:0 0 4px;text-align:center;font-weight:700}
h2{font-size:inherit;margin:0}
p{margin:0}
.center{text-align:center}
.muted{color:var(--ink2)}
.head{text-align:center;padding-bottom:12px;border-bottom:1px dashed var(--line)}
.block{padding:12px 0;border-bottom:1px dashed var(--line)}
.flag{text-align:center;font-weight:700;letter-spacing:.04em}
.red{color:var(--red)}
.meta{display:flex;justify-content:space-between;gap:8px;flex-wrap:wrap}
table{width:100%;border-collapse:collapse;font-variant-numeric:tabular-nums}
th{font-weight:400;text-align:left;padding:2px 8px 2px 0;vertical-align:top}
td{text-align:right;white-space:nowrap;padding:2px 0;vertical-align:top}
tr.sub th,tr.sub td{color:var(--ink2);font-size:14px}
tr.sub th{padding-left:16px}
tr.strong th,tr.strong td{font-weight:700;font-size:18px;padding-top:6px}
.note{display:block;padding-left:16px;color:var(--ink2);font-size:14px}
.sr{position:absolute;width:1px;height:1px;overflow:hidden;clip:rect(0 0 0 0);white-space:nowrap}
.qr{margin:16px auto 0;text-align:center}
.qr svg{display:block;width:100%;max-width:240px;height:auto;margin:0 auto;background:#ffffff;border-radius:8px}
.qr figcaption{margin-top:6px}
.to{padding-left:16px}
.footer{white-space:pre-line;text-align:center;padding-top:12px}
.test{text-align:center;font-weight:700;padding-top:12px}
.message{text-align:center;padding:24px 0}
.message h1{margin-bottom:8px}
@media print{
:root{color-scheme:light;--ground:#ffffff;--card:#ffffff;--ink:#000000;--ink2:#000000;--line:#000000;--red:#000000}
html,body{background:#ffffff;color:#000000}
main{margin:0 auto;padding:0;border-radius:0;max-width:none;background:none}
.qr svg{max-width:45mm}
}`;

function document(title: string, body: string): string {
  return `<!doctype html>
<html lang="de">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex,nofollow">
<meta name="referrer" content="no-referrer">
<meta name="color-scheme" content="light dark">
<title>${esc(title)}</title>
<style>${STYLE}</style>
</head>
<body>
<main>
${body}
</main>
</body>
</html>
`;
}

function rows(caption: string, list: PageRow[]): string {
  if (list.length === 0) return '';
  const tr = list
    .map((r) => {
      const cls = [r.sub ? 'sub' : '', r.strong ? 'strong' : ''].filter(Boolean).join(' ');
      const note = r.note ? ` <span class="note">${esc(r.note)}</span>` : '';
      const value = r.cents === undefined ? '' : amount(r.cents);
      return `<tr${cls ? ` class="${cls}"` : ''}><th scope="row">${esc(r.label)}${note}</th><td>${value}</td></tr>`;
    })
    .join('\n');
  return `<section class="block"><table>\n<caption class="sr">${esc(caption)}</caption>\n${tr}\n</table></section>`;
}

/** Die Seite eines Bons als reines HTML. Jeder Text geht durch esc(); das SVG nur, wenn isSafeSvg es erlaubt. */
export function renderReceiptPage(view: ReceiptPageView): string {
  const b = view.business;
  const out: string[] = [];
  const head = [`<h1>${esc(b.name)}</h1>`];
  for (const line of b.addressLines) head.push(`<p>${esc(line)}</p>`);
  if (b.vatId) head.push(`<p>UID ${esc(b.vatId)}</p>`);
  out.push(`<header class="head">\n${head.join('\n')}\n</header>`);

  const flags: string[] = [];
  if (view.title) flags.push(`<p class="flag red">${esc(view.title)}</p>`);
  if (view.titleDetail) flags.push(`<p class="center">${esc(view.titleDetail)}</p>`);
  if (view.voidedAt) flags.push(`<p class="flag red">Storniert am ${esc(view.voidedAt)}</p>`);
  if (flags.length > 0) out.push(`<section class="block">\n${flags.join('\n')}\n</section>`);

  const inv = view.invoice;
  if (inv) {
    const to = [inv.name, ...inv.addressLines, ...(inv.vatId ? [`UID ${inv.vatId}`] : [])].map((l) => `<p>${esc(l)}</p>`);
    out.push(
      `<section class="block" aria-labelledby="rechnung">\n<h2 id="rechnung" class="flag">RECHNUNG</h2>\n` +
        `<p class="center">Rechnung Nr. ${esc(inv.number)}</p>\n<p>An:</p>\n<div class="to">${to.join('')}</div>\n</section>`,
    );
  }

  const meta = [`<p class="meta"><span>Bon Nr. ${esc(String(view.number))}</span><span>${esc(view.createdAt)}</span></p>`];
  if (view.cashBoxId) meta.push(`<p class="muted">Kassen-ID: ${esc(view.cashBoxId)}</p>`);
  out.push(`<section class="block">\n${meta.join('\n')}\n</section>`);

  out.push(rows('Artikel', view.lines));
  out.push(rows('Summe', view.sums));
  out.push(rows('Steuer', view.taxes));
  out.push(rows('Zahlung', view.payments));

  if (view.qr && isSafeSvg(view.qr.svg)) {
    const svg = view.qr.svg.replace(/^<svg /, '<svg role="img" aria-label="QR-Code der Signatur" ');
    if (isSafeSvg(svg)) {
      const caption = view.qr.damaged ? '\n<figcaption class="muted">Sicherheitseinrichtung ausgefallen</figcaption>' : '';
      out.push(`<figure class="qr">\n${svg}${caption}\n</figure>`);
    }
  }
  if (view.footer) out.push(`<p class="footer">${esc(view.footer)}</p>`);
  if (view.test) out.push('<p class="test">TESTBON, keine gültige Rechnung</p>');

  return document(`Bon ${String(view.number)} · ${b.name}`, out.filter(Boolean).join('\n'));
}

function messagePage(title: string, heading: string, text: string): string {
  return document(title, `<section class="message">\n<h1>${esc(heading)}</h1>\n<p class="muted">${esc(text)}</p>\n</section>`);
}

/** Immer dieselbe Seite, für jeden Schlüssel, den es nicht gibt (auch kaputt, fremd oder fast richtig). */
export const NOT_FOUND_PAGE = messagePage(
  'Bon nicht gefunden',
  'Diesen Bon gibt es nicht.',
  'Ein neuer Bon ist vielleicht noch nicht da. Bitte in ein paar Minuten noch einmal versuchen.',
);
export const TOO_MANY_PAGE = messagePage('Zu viele Versuche', 'Zu viele Versuche.', 'Bitte in ein paar Minuten noch einmal versuchen.');
const ERROR_PAGE = messagePage('Fehler', 'Das hat nicht geklappt.', 'Bitte später noch einmal versuchen.');

// ---------------------------------------------------------------------------------------------------------------
// Daten

type Discount = { percent?: number | null; amountCents?: number; reason?: string } | null;
type PayloadPayment = {
  position?: number;
  kind?: string;
  amountCents?: number;
  givenCents?: number;
  changeCents?: number;
  tipCents?: number;
  cardScheme?: string | null;
  cardLast4?: string | null;
  providerTxCode?: string | null;
  voucherCode?: string | null;
  voucherBalanceAfterCents?: number | null;
};

export type ReceiptData = {
  business: { name: string; address_lines: string[]; vat_id: string | null; receipt_footer: string | null };
  receipt: {
    number: number;
    kind: string;
    is_test: boolean;
    goods_cents: number;
    deposit_cents: number;
    total_cents: number;
    discount_cents: number;
    created_text: string;
    voided_text: string | null;
    voids_number: number | null;
    payments: PayloadPayment[] | null;
    payment: PayloadPayment | null;
    vouchers: { code?: string; linePosition?: number }[] | null;
    discount: Discount;
  };
  lines: {
    position: number;
    item_id: string;
    name: string;
    info: string | null;
    unit_price_cents: number;
    quantity: number;
    unit_deposit_cents: number;
    options: { optionName?: string; surchargeCents?: number }[];
    discount_cents: number;
    discount: Discount;
    gross20_cents: number;
    gross10_cents: number;
    gross13_cents: number;
    gross0_cents: number;
    gross19_cents: number;
  }[];
  rksv: { jws: string; damaged: boolean; cash_box_id: string | null; mode: string | null } | null;
  recipient: { name: string; address_line1: string; address_line2: string; vat_id: string | null } | null;
};

const SPECIAL_TITLES: Record<string, string> = {
  start: 'STARTBELEG',
  month: 'MONATSBELEG',
  year: 'JAHRESBELEG',
  zero: 'NULLBELEG',
  collective: 'SAMMELBELEG',
  closing: 'SCHLUSSBELEG',
};

const REASONS: Record<string, string> = {
  regular: 'Stammgast',
  staff: 'Mitarbeiter',
  complaint: 'Reklamation',
  promotion: 'Aktion',
  invitation: 'Einladung',
};

/** "Rabatt 10 % Stammgast" oder bei festem Betrag "Rabatt Stammgast", wie ReceiptDiscount.label am Tablet. */
/** "Rabatt 10 % Aktion" wie am Papier; ein unbekannter Grund steht, wie er kam. */
export function discountLabel(d: Discount): string {
  const reason = d?.reason ?? '';
  const name = Object.hasOwn(REASONS, reason) ? REASONS[reason]! : reason;
  const p = d?.percent;
  return (p === null || p === undefined ? `Rabatt ${name}` : `Rabatt ${p} % ${name}`).trimEnd();
}

/** Der Betrag eines Rabatts mit dem Vorzeichen der Rabatt-Summe ([total], beim Storno unter 0); ohne Rabatt 0. */
function signedAmount(d: Discount, total: number): number {
  const cents = Math.abs(Number(d?.amountCents ?? 0));
  return total < 0 ? -cents : cents;
}

/** Nur die letzten vier Ziffern eines Gutschein-Codes; ein kurzer Code ganz verdeckt. */
function maskedCode(code: string | null | undefined): string {
  const c = code ?? '';
  return c.length >= 8 ? `•••• ${c.slice(-4)}` : '••••';
}

function optionText(o: { optionName?: string; surchargeCents?: number }): string {
  const s = o.surchargeCents ?? 0;
  const name = o.optionName ?? '';
  return s === 0 ? name : `${name} (${s > 0 ? '+' : ''}${amount(s)})`;
}

/** Baut aus den gelesenen Zeilen, was die Seite zeigt: Reihenfolge und Wortlaut wie am Papier (receipt_layout.dart). */
export function buildView(d: ReceiptData, qr: ReceiptPageView['qr']): ReceiptPageView {
  const r = d.receipt;
  const soldCodes = new Map<number, string | undefined>((r.vouchers ?? []).map((v) => [Number(v.linePosition), v.code]));

  const lines: PageRow[] = [];
  let depositReturnCents = 0;
  let voucherSaleCents = 0;
  const gross: Record<number, number> = { 20: 0, 10: 0, 13: 0, 0: 0, 19: 0 };
  for (const l of d.lines) {
    gross[20]! += l.gross20_cents;
    gross[10]! += l.gross10_cents;
    gross[13]! += l.gross13_cents;
    gross[0]! += l.gross0_cents;
    gross[19]! += l.gross19_cents;
    const manyTimes = l.quantity > 1 || l.quantity < -1;
    if (l.item_id.startsWith(DEPOSIT_RETURN_PREFIX)) {
      // "Pfand zurück": der Betrag ist das Pfand der Zeile, nicht der Warenwert 0.
      const cents = l.unit_deposit_cents * l.quantity;
      depositReturnCents += cents;
      lines.push({ label: `${l.quantity} x ${l.name}`, cents });
      if (manyTimes) lines.push({ label: `je ${amount(l.unit_deposit_cents)}`, sub: true });
      continue;
    }
    const goods = l.unit_price_cents * l.quantity;
    if (l.item_id === VOUCHER_SALE_ITEM_ID) {
      // Der Code steht am Tablet auch in `info`: hier nie, nur die letzten vier Ziffern.
      voucherSaleCents += goods;
      lines.push({ label: `${l.quantity} x Gutschein`, cents: goods });
      lines.push({ label: `Code ${maskedCode(soldCodes.get(l.position))}`, sub: true });
      continue;
    }
    const label = l.info === null || l.info === '' ? l.name : `${l.name} ${l.info}`;
    lines.push({ label: `${l.quantity} x ${label}`, cents: goods });
    if (manyTimes) lines.push({ label: `je ${amount(l.unit_price_cents)}`, sub: true });
    for (const o of l.options ?? []) lines.push({ label: optionText(o), sub: true });
    // Nur der eigene Rabatt der Zeile, wie am Papier. discount_cents trägt dazu den Anteil am Bon-Rabatt.
    const own = signedAmount(l.discount, l.discount_cents);
    if (own !== 0) lines.push({ label: discountLabel(l.discount), cents: -own, sub: true });
  }

  const sums: PageRow[] = [];
  const special = SPECIAL_TITLES[r.kind] ?? null;
  // Der Rabatt auf den ganzen Bon, wie am Papier; beim Storno mit Minus.
  const receiptDiscountCents = signedAmount(r.discount, r.discount_cents);
  if (receiptDiscountCents !== 0) {
    sums.push({ label: 'Zwischensumme', cents: r.goods_cents + receiptDiscountCents });
    sums.push({ label: discountLabel(r.discount), cents: -receiptDiscountCents });
  }
  // Nur das verlangte Pfand, wie am Papier; das zurückgegebene steht einmal, bei seinen Zeilen.
  const depositAskedCents = r.deposit_cents - depositReturnCents;
  if (depositAskedCents !== 0) sums.push({ label: 'Pfand', cents: depositAskedCents });
  sums.push({ label: 'SUMME EUR', cents: r.total_cents, strong: true });

  const taxes: PageRow[] = taxLinesOf(gross).map((t) => ({
    label: `${t.percent} % MwSt ${amount(t.taxCents)}`,
    note: `Netto ${amount(t.netCents)}`,
    cents: t.grossCents,
  }));
  // Wie am Papier: der Betrag steht schon in der Zeile zum Satz 0, eingerückt als "davon".
  if (voucherSaleCents !== 0) taxes.push({ label: 'davon Gutschein (kein Umsatz)', cents: voucherSaleCents, sub: true });

  // v: 2 und v: 3 bringen `payments`, v: 1 eine Zahlung `payment` (oder keine).
  const list = Array.isArray(r.payments) ? [...r.payments] : r.payment ? [{ ...r.payment, position: 0 }] : [];
  list.sort((x, y) => Number(x.position) - Number(y.position));
  const payments: PageRow[] = [];
  // Eine Auszahlung (Summe unter 0, beim Storno darüber) heißt wie am Papier "Bar ausbezahlt", mit dem Betrag ohne
  // Minus (beim Storno mit), ohne "Gegeben" und "Rückgeld".
  const payout = r.kind === 'voided' ? r.total_cents > 0 : r.kind === 'sale' && r.total_cents < 0;
  // "Gegeben" und "Rückgeld" wie am Papier (givenChangePayment am Tablet): die einzige Zahlung, oder bei einem Verkauf
  // die eine Bar-Zahlung, neben der nur Gutscheine bezahlen. Wie am Bildschirm in "Bons" nur bei einem Betrag über 0.
  const cashCount = list.filter((p) => p.kind === 'cash').length;
  const givenShown =
    !payout &&
    cashCount === 1 &&
    (list.length === 1 || (r.kind === 'sale' && list.every((p) => p.kind === 'cash' || p.kind === 'voucher')));
  for (const p of list) {
    const cents = Number(p.amountCents ?? 0);
    if (p.kind === 'cash' && payout) {
      payments.push({ label: 'Bar ausbezahlt', cents: -cents });
    } else if (p.kind === 'cash') {
      payments.push({ label: 'Bar', cents });
      const given = Number(p.givenCents ?? cents);
      if (givenShown && cents > 0 && given !== cents) {
        payments.push({ label: 'Gegeben', cents: given });
        payments.push({ label: 'Rückgeld', cents: Number(p.changeCents ?? 0) });
      }
    } else if (p.kind === 'card') {
      const tip = Number(p.tipCents ?? 0);
      payments.push({ label: 'Karte', cents: cents + tip });
      if (tip !== 0) payments.push({ label: 'davon Trinkgeld', cents: tip, sub: true });
      // Nur Art und die letzten vier Ziffern, wie am Papier.
      const last4 = p.cardLast4 ?? '';
      if (/^\d{4}$/.test(last4)) {
        const scheme = (p.cardScheme ?? '').trim();
        payments.push({ label: scheme === '' ? `**** ${last4}` : `${scheme} **** ${last4}`, sub: true });
      }
      const tx = (p.providerTxCode ?? '').trim();
      if (tx !== '') payments.push({ label: `Beleg ${tx}`, sub: true });
    } else if (p.kind === 'voucher') {
      payments.push({ label: `Gutschein ${maskedCode(p.voucherCode)}`, cents });
      if (typeof p.voucherBalanceAfterCents === 'number') {
        payments.push({ label: 'Restguthaben', cents: p.voucherBalanceAfterCents, sub: true });
      }
    }
  }

  const cashBoxId = d.rksv?.cash_box_id ?? null;
  const rec = d.recipient;
  const footer = d.business.receipt_footer?.trim() ?? '';
  return {
    business: { name: d.business.name, addressLines: d.business.address_lines ?? [], vatId: d.business.vat_id || null },
    title: r.kind === 'voided' ? 'STORNO' : special,
    titleDetail: r.kind === 'voided' && r.voids_number !== null ? `zu Bon Nr. ${r.voids_number}` : null,
    voidedAt: r.voided_text,
    invoice: rec
      ? {
          number: cashBoxId ? `${cashBoxId} / ${r.number}` : String(r.number),
          name: rec.name,
          addressLines: [rec.address_line1, rec.address_line2].filter((l) => l !== ''),
          vatId: rec.vat_id || null,
        }
      : null,
    number: r.number,
    createdAt: r.created_text,
    cashBoxId,
    lines,
    sums,
    taxes,
    payments,
    qr,
    footer: footer === '' ? null : footer,
    // Wie am Papier: ein Testbon, ein Bon ohne Eintrag im Protokoll und einer mit der Probe-Signatur.
    test: r.is_test || d.rksv === null || d.rksv.mode !== 'live',
  };
}

/**
 * Liest den Bon zum Schlüssel. Erst der Treffer in receipt_links (ohne Betrieb, die Tabelle hat bewusst keinen
 * Zeilen-Schutz), dann alles Weitere in derselben Transaktion mit dem Betrieb des Treffers: der Zeilen-Schutz gilt,
 * und jede Abfrage nennt den Betrieb zusätzlich selbst. Kein Treffer: null.
 */
async function loadReceipt(db: Db, token: string, log: FastifyBaseLogger): Promise<ReceiptData | null> {
  return withSystem(db, async (c: pg.PoolClient) => {
    const link = (
      await c.query<{ business_id: string; receipt_id: string }>(
        'select business_id, receipt_id from receipt_links where token = $1',
        [token],
      )
    ).rows[0];
    if (!link) return null;
    const b = link.business_id;
    const id = link.receipt_id;
    await setBusiness(c, b);
    const tz = await loadTimeZone(c, b, log);
    const business = (
      await c.query<ReceiptData['business']>('select name, address_lines, vat_id, receipt_footer from businesses where id = $1', [b])
    ).rows[0];
    const receipt = (
      await c.query<ReceiptData['receipt']>(
        `select r.number, r.kind, r.is_test, r.goods_cents, r.deposit_cents, r.total_cents, r.discount_cents,
                to_char(r.created_at at time zone $3, 'DD.MM.YYYY HH24:MI') as created_text,
                (select to_char(v.created_at at time zone $3, 'DD.MM.YYYY HH24:MI') from receipts v
                  where v.business_id = r.business_id and v.voids_receipt_id = r.id and v.kind = 'voided'
                  order by v.created_at, v.id limit 1) as voided_text,
                (select o.number from receipts o where o.business_id = r.business_id and o.id = r.voids_receipt_id) as voids_number,
                r.payload->'payments' as payments, r.payload->'payment' as payment, r.payload->'vouchers' as vouchers,
                r.payload->'discount' as discount
           from receipts r where r.business_id = $1 and r.id = $2`,
        [b, id, tz],
      )
    ).rows[0];
    if (!business || !receipt) return null;
    const lines = (
      await c.query<ReceiptData['lines'][number]>(
        `select position, item_id, name, info, unit_price_cents, quantity, unit_deposit_cents, options, discount_cents, discount,
                gross20_cents, gross10_cents, gross13_cents, gross0_cents, gross19_cents
           from receipt_lines where business_id = $1 and receipt_id = $2 order by position`,
        [b, id],
      )
    ).rows;
    const rksv =
      (
        await c.query<NonNullable<ReceiptData['rksv']>>(
          `select e.jws, e.damaged, h.cash_box_id, h.mode
             from rksv_entries e
             left join rksv_chains h on h.business_id = e.business_id and h.device_id = e.device_id and h.chain = e.chain
            where e.business_id = $1 and e.receipt_id = $2
            order by e.chain, e.position limit 1`,
          [b, id],
        )
      ).rows[0] ?? null;
    const recipient =
      (
        await c.query<NonNullable<ReceiptData['recipient']>>(
          `select name, address_line1, address_line2, vat_id from receipt_recipients
            where business_id = $1 and receipt_id = $2 order by version desc limit 1`,
          [b, id],
        )
      ).rows[0] ?? null;
    return { business, receipt, lines, rksv, recipient };
  });
}

/** Der QR-Code zum JWS, nur wenn er sicher eingebettet werden kann. Ein unlesbares JWS gibt keinen QR-Code. */
/** Der QR-Code der Signatur; null ohne Signatur, bei einem kaputten Text oder wenn kein QR-Code entsteht. */
export async function qrOf(rksv: ReceiptData['rksv']): Promise<ReceiptPageView['qr']> {
  if (!rksv) return null;
  let text: string;
  try {
    text = rksvQrText(rksv.jws);
  } catch {
    return null;
  }
  let svg: string;
  try {
    svg = await qrSvg(text);
  } catch {
    // Etwa ein Text, zu lang für einen QR-Code: die Seite kommt ohne ihn, nicht als Fehler.
    return null;
  }
  return isSafeSvg(svg) ? { svg, damaged: rksv.damaged } : null;
}

const PAGE_PATH = /^\/+beleg(\/|$)/i;

/**
 * Ob die Adresse zur Seite eines Bons gehört: `/beleg` in jeder Schreibweise, auch mit mehreren Schrägstrichen davor,
 * roh oder einmal dekodiert (`/%42ELEG/x`, `/beleg%2Fx`). Abfrage und Fragment zählen nicht. Lässt sich der Pfad nicht
 * dekodieren, zählt nur die rohe Form.
 */
export function isReceiptPagePath(url: string): boolean {
  const raw = url.split(/[?#]/)[0]!;
  if (PAGE_PATH.test(raw)) return true;
  try {
    return PAGE_PATH.test(decodeURIComponent(raw));
  } catch {
    return false;
  }
}

/** Der Schlüssel aus dem Pfad, roh (ohne Dekodieren) und nur in der genauen Form `/beleg/<22 Zeichen>`; sonst null. */
function tokenOf(path: string): string | null {
  if (!path.startsWith(PREFIX)) return null;
  const token = path.slice(PREFIX.length);
  return TOKEN.test(token) ? token : null;
}

/** Ein kurzer Prüfwert eines Fehlversuchs (64 Bit): damit zählt derselbe falsche Schlüssel nur einmal. Nie der Schlüssel. */
function missHash(path: string): string {
  return createHash('sha256').update(path).digest('base64url').slice(0, 11);
}

/** Liest den Bon zum Schlüssel; null, wenn es ihn nicht gibt. */
export type ReceiptLoader = (db: Db, token: string, log: FastifyBaseLogger) => Promise<ReceiptData | null>;

export type ReceiptPageOptions = {
  /** Höchstens so viele Adressen merkt sich die Bremse (Vorgabe 50 000); Tests setzen eine kleine Zahl. */
  maxAddresses?: number;
  /** Umhüllt das Lesen des Bons; Tests zählen damit die Abfragen. */
  wrapLoader?: (load: ReceiptLoader) => ReceiptLoader;
};

export type ReceiptPage = {
  /** Antwort auf eine Adresse unter /beleg mit kaputter Prozent-Kodierung (FST_ERR_BAD_URL): wie ein Fehlversuch. */
  answerBadUrl(req: FastifyRequest, reply: FastifyReply): Promise<FastifyReply>;
};

/**
 * Die Seite eines Bons unter /beleg/<Schlüssel>. Ein Hook vor allem anderen nimmt jede Anfrage, deren Pfad mit /beleg
 * beginnt (jede Schreibweise, jede Methode), bevor ein Körper gelesen wird: /beleg/… bekommt nie die Verwaltung.
 * Vor registerWeb aufrufen.
 */
export function installReceiptPage(app: FastifyInstance, opts: ReceiptPageOptions = {}): ReceiptPage {
  const { db, now, config } = app.deps;
  const https = config.publicUrl.startsWith('https://');
  // Je App eine Zählung, begrenzt (siehe MissLimiter).
  const misses = new MissLimiter(MAX_FAILURES, WINDOW_MS, opts.maxAddresses);
  const load: ReceiptLoader = opts.wrapLoader ? opts.wrapLoader(loadReceipt) : loadReceipt;

  /** Jede Antwort unter /beleg trägt dieselben Kopfzeilen, gesetzt hier (der Hook der Verwaltung lässt /beleg aus). */
  function sendPage(reply: FastifyReply, status: number, html: string): FastifyReply {
    reply.header('cache-control', 'no-store');
    reply.header('x-robots-tag', 'noindex, nofollow');
    reply.header('referrer-policy', 'no-referrer');
    reply.header('content-security-policy', CONTENT_SECURITY_POLICY);
    reply.header('x-content-type-options', 'nosniff');
    reply.header('x-frame-options', 'DENY');
    if (https) reply.header('strict-transport-security', 'max-age=31536000');
    reply.removeHeader('set-cookie');
    return reply.code(status).type('text/html; charset=utf-8').send(html);
  }

  /** Wann zuletzt die Zeile "CLIENT_IP_HEADER fehlt" geschrieben wurde (einmal je Fenster). */
  let warnedAt: number | null = null;

  async function answer(req: FastifyRequest, reply: FastifyReply, badUrl: boolean): Promise<FastifyReply> {
    const at = now();
    const address = rateKey(clientAddress(req, config));
    // Hinter einem Proxy (https) ist die Adresse der Verbindung die des Proxys, also aller Kunden zusammen: gebremst
    // wird nur eine Adresse aus der vertrauten Kopfzeile. Sonst nie 429 wegen der Bremse, dafür je Fenster eine
    // Fehlerzeile (ohne Schlüssel und ohne Pfad).
    const limited = !https || headerAddress(req, config) !== null;
    if (!limited && (warnedAt === null || at.getTime() - warnedAt >= WINDOW_MS)) {
      warnedAt = at.getTime();
      app.log.error(
        'Seite eines Bons: CLIENT_IP_HEADER fehlt oder die Anfrage trägt keine Adresse darin; die Bremse gegen Durchprobieren ist aus',
      );
    }
    // Gesperrt ist nur eine Adresse, die selbst MAX_FAILURES verschiedene Fehlversuche hat; dann jede Methode, jeder Schlüssel.
    const wait = limited ? misses.blockedMs(address, at) : 0;
    if (wait > 0) {
      reply.header('retry-after', String(Math.max(Math.ceil(wait / 1000), 1)));
      return sendPage(reply, 429, TOO_MANY_PAGE);
    }
    // Andere Methoden verraten nichts (immer dieselbe Seite) und zählen darum nicht.
    if (!badUrl && req.method !== 'GET' && req.method !== 'HEAD') return sendPage(reply, 404, NOT_FOUND_PAGE);
    const path = req.url.split('?')[0]!;
    const hash = missHash(path);
    // Vor dem Nachsehen einen Platz reservieren: gleichzeitige Anfragen zählen mit, mehr als MAX_FAILURES verschiedene
    // Schlüssel je Adresse fragen nie die Datenbank. Der Platz endet im finally: Treffer und Fehler geben ihn zurück,
    // ein Fehlversuch wird gespeichert.
    if (limited && !misses.reserve(address, hash, at)) {
      reply.header('retry-after', String(Math.max(Math.ceil(misses.blockedMs(address, at) / 1000), 1)));
      return sendPage(reply, 429, TOO_MANY_PAGE);
    }
    let missed = false;
    try {
      // Ein kaputter Schlüssel fragt die Datenbank nicht, bekommt aber dieselbe Antwort wie ein unbekannter.
      const token = badUrl ? null : tokenOf(path);
      const data = token === null ? null : await load(db, token, req.log);
      if (data === null) {
        missed = true;
        return sendPage(reply, 404, NOT_FOUND_PAGE);
      }
      return sendPage(reply, 200, renderReceiptPage(buildView(data, await qrOf(data.rksv))));
    } catch (err) {
      // Nur der Fehler, nie die Adresse (sie trägt den Schlüssel).
      req.log.error({ err }, 'Seite eines Bons nicht gebaut');
      return sendPage(reply, 500, ERROR_PAGE);
    } finally {
      if (limited) {
        if (missed) misses.record(address, hash, at);
        else misses.release(address, hash);
      }
    }
  }

  app.addHook('onRequest', async (req, reply) => {
    if (!isReceiptPagePath(req.url)) return;
    return answer(req, reply, false);
  });

  return { answerBadUrl: (req, reply) => answer(req, reply, true) };
}
