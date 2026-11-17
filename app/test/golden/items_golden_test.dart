import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/app.dart';
import 'package:kassa/data/providers.dart';
import 'package:material_ui/material_ui.dart';

import '../support/items_pump.dart';
import '../support/kassa_pump.dart';
import '../support/pump.dart';

// Bildvergleich des Bereichs Artikel gegen den freigegebenen Entwurf. Neu
// erzeugen mit `flutter test --update-goldens test/golden/items_golden_test.dart`.

/// Bowls: der zweite Artikel ist außer Verkauf, Favoriten und Marken stehen.
Future<void> _bowls(
  WidgetTester t, {
  Brightness brightness = Brightness.light,
}) async {
  await pumpItems(t, brightness: brightness);
  final repo = containerOf(t).read(catalogRepositoryProvider);
  await repo.updateItem('huhn-bowl', favorite: true);
  await repo.updateItem('tofu-bowl', favorite: true, inSale: false);
  await t.pumpAndSettle();
}

void main() {
  testWidgets('Artikel, Bowls mit gewähltem ersten Artikel (hell)', (t) async {
    await _bowls(t);
    expect(t.takeException(), isNull);
    await expectLater(
      find.byType(KassaApp),
      matchesGoldenFile('goldens/artikel_liste_hell.png'),
    );
  });

  testWidgets('Artikel, Preis ändern (hell)', (t) async {
    await _bowls(t);
    await t.tap(find.byKey(const Key('edit-price')));
    await t.pumpAndSettle();
    await tapKeys(t, '1 2 , 5');
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    await expectLater(
      find.byType(KassaApp),
      matchesGoldenFile('goldens/artikel_preis_aendern_hell.png'),
    );
  });

  testWidgets('Artikel, Getränke mit Pfand (dunkel)', (t) async {
    await _bowls(t, brightness: Brightness.dark);
    await selectCategory(t, 'getraenke');
    expect(t.takeException(), isNull);
    await expectLater(
      find.byType(KassaApp),
      matchesGoldenFile('goldens/artikel_liste_dunkel.png'),
    );
  });
}
