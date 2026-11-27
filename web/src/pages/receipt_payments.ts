import { codeGroups } from '../format';

// Die Zahlungsart in Worten steht bei der API der Bons (api/receipts.ts), damit die API nichts aus den Seiten lädt.
export { paymentKindsText } from '../api/receipts';

/** Der Code eines Gutscheins zum Lesen: "1234 5678". */
export function voucherCodeText(code: string): string {
  return codeGroups(code);
}
