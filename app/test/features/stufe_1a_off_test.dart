// Sind alle vier Schalter der Stufe 1a aus (Teil bar, Rest Karte; Trinkgeld;
// Rabatt; freier Betrag), ist kein Tipp und kein Bildschirm anders als in
// 1.10.0. Dieser Test ist von Anfang an grün und bleibt es in jeder späteren
// Aufgabe: Er sucht die Tasten und Schritte, die später hinter den Schaltern
// dazukommen, und findet sie nicht.

import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/data/providers.dart';
import 'package:kassa/domain/feature_access.dart';
import 'package:kassa/features/login/session.dart';
import 'package:material_ui/material_ui.dart';

import '../support/cash_pump.dart';
import '../support/fake_devices.dart';
import '../support/kassa_pump.dart';
import '../support/pump.dart';

/// Tasten, die nur mit einem eingeschalteten Schalter da sein dürfen.
const _newKeys = [
  'discount-button',
  'open-amount-button',
  'receipt-discount',
  'finish-free',
  'split-card-failed',
];

/// Cola und Teigtaschen bonieren, bar öffnen und zurück, mit Karte zahlen:
/// derselbe Weg wie in 1.10.0, ohne neuen Schritt.
Future<void> _sellWithAllOff(WidgetTester t) async {
  final s = await containerOf(t).read(settingsRepositoryProvider).current();
  expect(
    (
      s.splitPaymentEnabled,
      s.cardTipEnabled,
      s.discountAccess,
      s.openAmountAccess,
    ),
    (false, false, FeatureAccess.off, FeatureAccess.off),
  );
  await tapItem(t, 'cola');
  await tapItem(t, 'teigtaschen');
  for (final k in _newKeys) {
    expect(find.byKey(Key(k)), findsNothing, reason: k);
  }
  // Ein Tipp auf die Bon-Zeile tut nichts.
  await t.tap(find.text('Teigtaschen').last);
  await t.pumpAndSettle();
  expect(find.byKey(const Key('discount-sheet')), findsNothing);
  expect(cartOf(t).lines.map((l) => l.quantity), [1, 1]);
  for (final k in _newKeys) {
    expect(find.byKey(Key(k)), findsNothing, reason: k);
  }

  await t.tap(find.byKey(const Key('pay-cash')));
  await t.pumpAndSettle();
  expect(find.byKey(const Key('cash-mode-split')), findsNothing);
  await t.tap(find.byKey(const Key('cash-back')));
  await t.pumpAndSettle();

  // Direkt zum Terminal.
  await t.tap(find.byKey(const Key('pay-card')));
  await t.pump();
  expect(find.byKey(const Key('tip-sheet')), findsNothing);
  await t.pumpAndSettle();
  expect(terminalOf(t).payments.single.amountCents, 965);
  expect(
    await queryRows(
      t,
      'SELECT position, kind, amount_cents, tip_cents FROM payments',
    ),
    [
      {'position': 0, 'kind': 'card', 'amount_cents': 965, 'tip_cents': 0},
    ],
  );
}

void main() {
  testWidgets('alle Schalter aus: keine neue Taste, kein neuer Schritt', (
    t,
  ) async {
    await pumpKassa(
      t,
      overrides: await memoryOverrides(terminal: FakeCardTerminal()),
    );
    await _sellWithAllOff(t);
  });

  testWidgets('alle Schalter aus, Chef angemeldet: auch für ihn keine neue '
      'Taste', (t) async {
    await pumpKassa(
      t,
      overrides: await memoryOverrides(terminal: FakeCardTerminal()),
      pin: '4711',
    );
    expect(containerOf(t).read(sessionProvider)?.isChef, isTrue);
    await _sellWithAllOff(t);
  });
}
