import { expect, test } from 'vitest';
import { discountText, filterFromParams, filterToParams, paymentKindText, type ReceiptFilter } from './receipts';

const none: ReceiptFilter = { day: null, payment: null, voidedOnly: false };

test('filterFromParams: deutsche Parameter der Adresse, Unlesbares gilt als nicht gesetzt', () => {
  expect(filterFromParams(new URLSearchParams(''))).toEqual(none);
  expect(filterFromParams(new URLSearchParams('tag=2026-11-19&zahlung=karte&stornos=1'))).toEqual({
    day: '2026-11-19',
    payment: 'card',
    voidedOnly: true,
  });
  expect(filterFromParams(new URLSearchParams('zahlung=bar'))).toEqual({ ...none, payment: 'cash' });
  expect(filterFromParams(new URLSearchParams('tag=gestern&zahlung=scheck&stornos=ja'))).toEqual(none);
});

test('filterToParams: Vorgaben stehen nicht in der Adresse, andere Parameter bleiben', () => {
  expect(filterToParams(none, new URLSearchParams('')).toString()).toBe('');
  expect(filterToParams({ day: '2026-11-19', payment: 'card', voidedOnly: true }, new URLSearchParams('')).toString()).toBe(
    'tag=2026-11-19&zahlung=karte&stornos=1',
  );
  expect(filterToParams({ ...none, payment: 'cash' }, new URLSearchParams('tag=2026-11-01&x=1')).toString()).toBe(
    'x=1&zahlung=bar',
  );
});

test('paymentKindText und discountText', () => {
  expect([paymentKindText('cash'), paymentKindText('card'), paymentKindText('mixed'), paymentKindText(null)]).toEqual(['Bar', 'Karte', 'Bar + Karte', '']);
  expect(discountText({ percent: 10, reason: 'promotion' })).toBe('Rabatt 10 % Aktion');
  expect(discountText({ percent: null, reason: 'staff' })).toBe('Rabatt Mitarbeiter');
  expect(discountText({ percent: null, reason: 'xyz' })).toBe('Rabatt xyz');
});

test('Filter Gutschein: in der Adresse "zahlung=gutschein"', () => {
  expect(filterFromParams(new URLSearchParams('zahlung=gutschein'))).toEqual({ ...none, payment: 'voucher' });
  expect(filterToParams({ ...none, payment: 'voucher' }, new URLSearchParams('')).toString()).toBe('zahlung=gutschein');
  expect(paymentKindText('voucher')).toBe('Gutschein');
});
