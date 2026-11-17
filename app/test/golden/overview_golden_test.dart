import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/app.dart';
import 'package:kassa/domain/cart.dart';
import 'package:material_ui/material_ui.dart';

import '../support/demo_fixtures.dart';
import '../support/overview_pump.dart';

// Bildvergleich des Bereichs Übersicht gegen den freigegebenen Entwurf. Neu
// erzeugen mit `flutter test --update-goldens test/golden/overview_golden_test.dart`.

Cart _cart(int variant) {
  switch (variant % 4) {
    case 0:
      return bowlCart();
    case 1:
      return const Cart.empty().add(teigtaschen).add(cola);
    case 2:
      return const Cart.empty()
          .add(catalog.item('pommes'))
          .add(catalog.item('edamame'))
          .add(catalog.item('mochi'));
    default:
      return const Cart.empty().add(cola).add(cola);
  }
}

List<OverviewSale> _daySales() {
  const hours = [11, 11, 12, 12, 12, 13, 13, 14, 16, 17, 17, 17, 18];
  return [
    // Vorwoche, für den Vergleich.
    OverviewSale(DateTime(2026, 11, 10, 11, 30), cart: bowlCart()),
    OverviewSale(DateTime(2026, 11, 10, 12, 30), cart: bowlCart()),
    for (var i = 0; i < hours.length; i++)
      OverviewSale(today(hours[i], 5 + i), cart: _cart(i), voided: i == 4),
  ];
}

void main() {
  testWidgets('Übersicht heute (hell)', (t) async {
    await pumpOverviewWithSales(t, sales: _daySales(), now: today(19, 30));
    expect(t.takeException(), isNull);
    await expectLater(
      find.byType(KassaApp),
      matchesGoldenFile('goldens/uebersicht_heute_hell.png'),
    );
  });

  testWidgets('Übersicht 7 Tage (dunkel)', (t) async {
    final sales = [
      for (var d = 4; d >= 0; d--)
        for (var i = 0; i < 2 + d % 3; i++)
          OverviewSale(DateTime(2026, 11, 17 - d, 12 + i), cart: _cart(d + i)),
      for (var i = 0; i < 3; i++)
        OverviewSale(DateTime(2026, 11, 8, 12 + i), cart: _cart(i)),
    ]..sort((a, b) => a.at.compareTo(b.at));
    await pumpOverviewWithSales(
      t,
      sales: sales,
      now: today(19, 30),
      brightness: Brightness.dark,
      openRange: 'days7',
    );
    expect(t.takeException(), isNull);
    await expectLater(
      find.byType(KassaApp),
      matchesGoldenFile('goldens/uebersicht_7_tage_dunkel.png'),
    );
  });

  testWidgets('Übersicht ohne Bons (hell)', (t) async {
    await pumpOverviewWithSales(t, sales: []);
    expect(t.takeException(), isNull);
    await expectLater(
      find.byType(KassaApp),
      matchesGoldenFile('goldens/uebersicht_leer_hell.png'),
    );
  });
}
