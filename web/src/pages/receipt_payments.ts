import type { PaymentKind } from '../api/receipts';
import { codeGroups } from '../format';

/** Die Arten in der Reihenfolge der Zahlungen am Bon: Gutscheine, bar, Karte zuletzt. */
const ORDER: PaymentKind[] = ['voucher', 'cash', 'card'];
const TEXTS: Record<PaymentKind, string> = { voucher: 'Gutschein', cash: 'Bar', card: 'Karte' };

/** Die Zahlungsart eines Bons aus allen Arten seiner Zahlungen: "Gutschein + Bar", "Bar + Karte"; ohne Zahlung leer. */
export function paymentKindsText(kinds: readonly PaymentKind[]): string {
  return ORDER.filter((k) => kinds.includes(k))
    .map((k) => TEXTS[k])
    .join(' + ');
}

/** Der Code eines Gutscheins zum Lesen: "1234 5678". */
export function voucherCodeText(code: string): string {
  return codeGroups(code);
}
