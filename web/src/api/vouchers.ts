import { useQuery } from '@tanstack/react-query';
import { api, ApiError } from './client';

/** Zustand aus den Bewegungen, nach derselben Regel wie am Tablet und am Server. */
export type VoucherState = 'active' | 'empty' | 'voided' | 'overdrawn';

/** Ein Gutschein, wie `GET …/vouchers` ihn liefert: voller Code, Guthaben aus allen Bewegungen. */
export type Voucher = {
  id: string;
  code: string;
  createdAt: string;
  valueCents: number;
  balanceCents: number;
  state: VoucherState;
  /** Ein Übungs-Gutschein von einem Übungs-Bon: in keiner Summe. */
  isTest: boolean;
};

export type VoucherMovementKind = 'sale' | 'redeem' | 'void_sale' | 'void_redeem';

/** Eine Bewegung mit dem Bon, zu dem sie gehört. */
export type VoucherMovement = {
  kind: VoucherMovementKind;
  /** Mit Vorzeichen: Verkauf über 0, Einlösung unter 0. */
  amountCents: number;
  createdAt: string;
  receiptId: string;
  receiptNumber: number;
  registerName: string;
};

export type VoucherDetail = Voucher & { movements: VoucherMovement[] };

/** Antwort von `GET …/vouchers`: oben die Summe der offenen Guthaben (ohne Übungs-Gutscheine), neueste zuerst. */
export type VoucherList = { openCents: number; vouchers: Voucher[] };

const STATE_TEXTS: Record<VoucherState, string> = {
  active: 'Gültig',
  empty: 'Aufgebraucht',
  voided: 'Storniert',
  overdrawn: 'Überzogen',
};

/** Der Zustand als Wort: "Gültig", "Aufgebraucht", "Storniert", "Überzogen". */
export function voucherStateText(state: VoucherState): string {
  return STATE_TEXTS[state];
}

const MOVEMENT_TEXTS: Record<VoucherMovementKind, string> = {
  sale: 'Verkauf',
  redeem: 'Eingelöst',
  void_sale: 'Storno des Verkaufs',
  void_redeem: 'Storno der Einlösung',
};

/** Die Art einer Bewegung als Wort. */
export function movementKindText(kind: VoucherMovementKind): string {
  return MOVEMENT_TEXTS[kind];
}

/** Echte und Übungs-Gutscheine getrennt, jeweils in der Reihenfolge des Servers. */
export function splitVouchers(list: Voucher[]): { real: Voucher[]; practice: Voucher[] } {
  return { real: list.filter((v) => !v.isTest), practice: list.filter((v) => v.isTest) };
}

const base = (b: string) => `/api/admin/businesses/${encodeURIComponent(b)}/vouchers`;
export const vouchersKey = (b: string) => ['vouchers', b] as const;
export const voucherKey = (b: string, id: string) => ['voucher', b, id] as const;

export function useVouchers(b: string) {
  return useQuery<VoucherList, ApiError>({
    queryKey: vouchersKey(b),
    queryFn: () => api.get<VoucherList>(base(b)),
  });
}

/** Ein Gutschein mit seinen Bewegungen. Ohne Kennung keine Anfrage. */
export function useVoucher(b: string, id: string | null) {
  return useQuery<VoucherDetail, ApiError>({
    queryKey: voucherKey(b, id ?? ''),
    queryFn: () => api.get<VoucherDetail>(`${base(b)}/${encodeURIComponent(id ?? '')}`),
    enabled: id !== null,
  });
}
