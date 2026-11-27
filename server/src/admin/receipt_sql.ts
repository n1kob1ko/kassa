// SQL-Stücke über die Spalten von receipts, die Übersicht, Monate, Tage und Bons gemeinsam brauchen. Ein eigenes
// Modul, damit months.ts und overview.ts einander nicht im Kreis laden.

/**
 * Ob ein Bon bar bzw. mit Karte bezahlt hat, aus den Spalten von receipts (mit Vorsatz `p`, etwa `r.`). `mixed` ohne
 * Gutschein ist bar und Karte (v: 2); mit Gutschein (v: 3) zählt die Art, die einen Betrag hat. Wie `paymentKind` am Tablet.
 */
export const hasCash = (p = '') =>
  `(${p}payment_kind = 'cash' or (${p}payment_kind = 'mixed' and (${p}voucher_cents = 0 or ${p}cash_cents <> 0)))`;
export const hasCard = (p = '') =>
  `(${p}payment_kind = 'card' or (${p}payment_kind = 'mixed' and (${p}voucher_cents = 0 or ${p}card_cents <> 0)))`;

/** Umsatz eines Bons: die Summe ohne verkaufte Gutscheine (Spalten von receipts mit Vorsatz `p`). */
export const revenueOf = (p = '') => `(${p}total_cents - ${p}voucher_sale_cents)`;
