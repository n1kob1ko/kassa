// Sind die vier Schalter der Stufe 1b in ihrer Vorgabe (Pfand zurück aus,
// Gutschein aus, Rechnung an Firma aus, Kundenbon "Immer drucken"), ist kein
// Tipp und kein Bildschirm anders als in 1.11.0 mit denselben Einstellungen,
// auch wenn alle vier Schalter der Stufe 1a an sind. Der Test nennt schon
// jetzt alle Schlüssel, die die Aufgaben der Funktionen hinter den Schaltern
// dazubringen, und bleibt in jeder späteren Aufgabe grün.

import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/core/app_language.dart';
import 'package:kassa/data/providers.dart';
import 'package:kassa/domain/feature_access.dart';
import 'package:kassa/features/login/session.dart';
import 'package:material_ui/material_ui.dart';

import '../support/cash_pump.dart';
import '../support/kassa_pump.dart';

/// Tasten und Flächen, die nur mit einem Schalter der Stufe 1b da sein
/// dürfen.
const _newKeys = [
  'more-button',
  'deposit-return-button',
  'voucher-button',
  'pay-voucher',
  'finish-voucher',
  'pay-out',
  'invoice-button',
  'invoice-hint',
  'receipt-qr',
  'receipt-qr-wait',
  'print-receipt-now',
  'detail-receipt-qr',
];

void _expectNoNewKey(String where) {
  for (final k in _newKeys) {
    expect(find.byKey(Key(k)), findsNothing, reason: '$where: $k');
  }
}

/// Die Vorgaben der Stufe 1b prüfen und alle vier Schalter der Stufe 1a
/// einschalten.
Future<void> _allOffWith1aOn(WidgetTester t) async {
  final s = await containerOf(t).read(settingsRepositoryProvider).current();
  expect(
    (s.depositReturnAccess, s.voucherEnabled, s.invoiceEnabled, s.receiptMode),
    (FeatureAccess.off, false, false, ReceiptMode.alwaysPrint),
  );
  await setSettings(
    t,
    (s) => s.copyWith(
      splitPaymentEnabled: true,
      cardTipEnabled: true,
      discountAccess: FeatureAccess.all,
      openAmountAccess: FeatureAccess.all,
    ),
  );
}

/// Kassa mit gefülltem Bon, bar verkauft, "Verkauf fertig", dann der Bon im
/// Detail unter "Bons": überall keiner der neuen Schlüssel.
Future<void> _sellAndLook(WidgetTester t) async {
  await _allOffWith1aOn(t);

  await tapItem(t, 'cola');
  await tapItem(t, 'teigtaschen');
  await t.pumpAndSettle();
  expect(cartOf(t).lines, hasLength(2));
  // Die Taste aus 1a steht allein im Kopf der Bon-Spalte, wie in 1.11.0.
  expect(find.byKey(const Key('open-amount-button')), findsOneWidget);
  _expectNoNewKey('Kassa');

  await t.tap(find.byKey(const Key('pay-cash')));
  await t.pumpAndSettle();
  _expectNoNewKey('Bar');
  await t.tap(find.byKey(const Key('finish-sale')));
  await t.pumpAndSettle();
  expect(find.byKey(const Key('next-customer')), findsOneWidget);
  _expectNoNewKey('Verkauf fertig');
  expect(
    await queryRows(t, 'SELECT position, kind, amount_cents FROM payments'),
    [
      {'position': 0, 'kind': 'cash', 'amount_cents': 965},
    ],
  );

  await t.tap(find.byKey(const Key('next-customer')));
  await t.pumpAndSettle();
  _expectNoNewKey('Kassa leer');

  await t.tap(find.byKey(const Key('tab-Bons')));
  await t.pumpAndSettle();
  await t.tap(find.byKey(const Key('receipt-1')));
  await t.pumpAndSettle();
  expect(find.byKey(const Key('detail-total')), findsOneWidget);
  _expectNoNewKey('Bon-Detail');
}

void main() {
  testWidgets('alles aus: keiner der neuen Schlüssel an der Kassa, auf '
      '"Verkauf fertig" und im Bon-Detail', (t) async {
    await pumpKassa(t);
    expect(containerOf(t).read(sessionProvider)?.isChef, isFalse);
    await _sellAndLook(t);
  });

  testWidgets('alles aus, Chef angemeldet: auch für ihn keiner der neuen '
      'Schlüssel', (t) async {
    await pumpKassa(t, pin: '4711');
    expect(containerOf(t).read(sessionProvider)?.isChef, isTrue);
    await _sellAndLook(t);
  });
}
