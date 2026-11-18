import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/app.dart';
import 'package:kassa/core/clock.dart';
import 'package:kassa/data/database.dart';
import 'package:kassa/data/providers.dart';
import 'package:kassa/domain/cart.dart';
import 'package:material_ui/material_ui.dart';

import '../support/demo_fixtures.dart';
import '../support/kassa_pump.dart';
import '../support/pump.dart';

// Bildvergleich der Frage zur unklaren Kartenzahlung: Wahl mit langem Bon
// (vier Zeilen und "und 3 weitere"), die Bestätigung und ein Bon, der sich
// nicht mehr zusammenstellen lässt. Neu erzeugen mit
// `flutter test --update-goldens test/golden/unclear_card_golden_test.dart`.

final _long = const Cart.empty()
    .add(cola)
    .add(cola)
    .add(teigtaschen)
    .add(huhnBowl, options: [xxl, nudeln])
    .add(huhnBowl, options: [normal, reis])
    .add(leitungswasser)
    .add(catalog.item('pommes'))
    .add(catalog.item('mochi'));

Future<List<Override>> _open(Cart cart) async {
  final clock = FixedClock(DateTime(2026, 11, 17, 12, 4));
  final overrides = await memoryOverrides(clock: clock);
  final c = ProviderContainer(overrides: overrides);
  try {
    final anna = (await c.read(staffRepositoryProvider).all()).firstWhere(
      (s) => s.name == 'Anna',
    );
    await c
        .read(cardPaymentRepositoryProvider)
        .begin(paymentId: 'p1', cart: cart, staff: anna);
  } finally {
    c.dispose();
  }
  return overrides;
}

void main() {
  for (final (name, brightness) in [
    ('hell', Brightness.light),
    ('dunkel', Brightness.dark),
  ]) {
    testWidgets('Frage zur unklaren Kartenzahlung ($name)', (t) async {
      await pumpKassa(t, brightness: brightness, overrides: await _open(_long));
      expect(t.takeException(), isNull);
      await expectLater(
        find.byType(KassaApp),
        matchesGoldenFile('goldens/karte_unklar_$name.png'),
      );
    });
  }

  testWidgets('Bestätigung "Ja" (dunkel)', (t) async {
    await pumpKassa(
      t,
      brightness: Brightness.dark,
      overrides: await _open(_long),
    );
    await t.tap(find.byKey(const Key('unclear-paid')));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    await expectLater(
      find.byType(KassaApp),
      matchesGoldenFile('goldens/karte_unklar_bestaetigen_dunkel.png'),
    );
  });

  testWidgets('Bon nicht mehr baubar (hell)', (t) async {
    await pumpKassa(t, overrides: await _open(_long));
    final db = containerOf(t).read(databaseProvider);
    await db
        .update(db.pendingCardPaymentRows)
        .write(
          PendingCardPaymentRowsCompanion(
            cartJson: Value(
              jsonEncode({
                'lines': [
                  {
                    'lineId': 'a',
                    'itemId': 'gibt-es-nicht',
                    'quantity': 1,
                    'optionIds': <String>[],
                  },
                ],
              }),
            ),
          ),
        );
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    await expectLater(
      find.byType(KassaApp),
      matchesGoldenFile('goldens/karte_unklar_unlesbar_hell.png'),
    );
  });
}
