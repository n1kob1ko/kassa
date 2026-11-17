import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/app.dart';
import 'package:material_ui/material_ui.dart';

import '../support/kassa_pump.dart';

// Bildvergleich des Kassenbildschirms gegen den freigegebenen Entwurf. Neu
// erzeugen mit `flutter test --update-goldens test/golden/kassa_golden_test.dart`.

/// Kassa mit drei Zeilen am Bon: eine Bowl mit Auswahl, zwei Cola, Teigtaschen.
Future<void> _threeLines(
  WidgetTester t, {
  Size size = const Size(1280, 800),
  Brightness brightness = Brightness.light,
  bool images = false,
}) async {
  await pumpKassa(t, size: size, brightness: brightness);
  if (images) {
    await t.tap(find.byKey(const Key('segment-Mit Bildern')));
    await t.pump();
  }
  await t.tap(find.byKey(const Key('item-huhn-bowl')));
  await t.pump();
  await t.tap(find.byKey(const Key('opt-bowl/1/0')));
  await t.tap(find.byKey(const Key('opt-bowl/0/1')));
  await t.pump();
  await t.tap(find.byKey(const Key('add-to-cart')));
  await t.pump();
  await tapItem(t, 'cola');
  await tapItem(t, 'cola');
  await tapItem(t, 'teigtaschen');
  await t.pumpAndSettle();
}

Future<void> _builder(
  WidgetTester t, {
  Size size = const Size(1280, 800),
  Brightness brightness = Brightness.light,
}) async {
  await pumpKassa(t, size: size, brightness: brightness);
  await tapItem(t, 'huhn-bowl');
  await t.pumpAndSettle();
}

void main() {
  for (final (name, file, size, brightness) in [
    ('hell', 'kassa_hell', const Size(1280, 800), Brightness.light),
    ('dunkel', 'kassa_dunkel', const Size(1280, 800), Brightness.dark),
    ('klein', 'kassa_klein', const Size(960, 600), Brightness.light),
  ]) {
    testWidgets('Kassa mit drei Zeilen ($name)', (t) async {
      await _threeLines(t, size: size, brightness: brightness);
      expect(t.takeException(), isNull);
      await expectLater(
        find.byType(KassaApp),
        matchesGoldenFile('goldens/$file.png'),
      );
    });

    testWidgets('Zusammenstellen der Bowl ($name)', (t) async {
      await _builder(t, size: size, brightness: brightness);
      expect(t.takeException(), isNull);
      await expectLater(
        find.byType(KassaApp),
        matchesGoldenFile('goldens/${file.replaceFirst('kassa', 'bowl')}.png'),
      );
    });
  }

  testWidgets('Kassa mit Bildern (hell)', (t) async {
    await _threeLines(t, images: true);
    expect(t.takeException(), isNull);
    await expectLater(
      find.byType(KassaApp),
      matchesGoldenFile('goldens/kassa_bilder_hell.png'),
    );
  });
}
