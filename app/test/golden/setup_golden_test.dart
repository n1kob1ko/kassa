import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/app.dart';
import 'package:material_ui/material_ui.dart';

import '../support/pump.dart';

// Bildvergleich der Einrichtung und Anmeldung gegen die freigegebenen
// Bildschirme. Neu erzeugen mit
// `flutter test --update-goldens test/golden/setup_golden_test.dart`.

Future<void> _start(
  WidgetTester t, {
  required bool seeded,
  Size size = const Size(1280, 800),
  Brightness brightness = Brightness.light,
  double textScale = 1.0,
}) async {
  await pumpApp(
    t,
    const KassaApp(),
    overrides: await memoryOverrides(seeded: seeded),
    size: size,
    brightness: brightness,
    textScale: textScale,
  );
  await t.pumpAndSettle();
}

Future<void> _toChefPin(WidgetTester t) async {
  await t.tap(find.text('Mit Beispieldaten starten'));
  await t.pumpAndSettle();
  await tapKeys(t, '4 7');
  await t.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('Startbild der Einrichtung (hell)', (t) async {
    await _start(t, seeded: false);
    expect(t.takeException(), isNull);
    await expectLater(
      find.byType(KassaApp),
      matchesGoldenFile('goldens/einrichtung_start.png'),
    );
  });

  testWidgets('Chef-PIN festlegen (hell)', (t) async {
    await _start(t, seeded: false);
    await _toChefPin(t);
    expect(t.takeException(), isNull);
    await expectLater(
      find.byType(KassaApp),
      matchesGoldenFile('goldens/chef_pin_festlegen.png'),
    );
  });

  testWidgets('Anmeldung (hell)', (t) async {
    await _start(t, seeded: true);
    await tapKeys(t, '1 2');
    await t.pump(const Duration(milliseconds: 300));
    expect(t.takeException(), isNull);
    await expectLater(
      find.byType(KassaApp),
      matchesGoldenFile('goldens/anmeldung.png'),
    );
  });

  for (final (name, size, brightness, scale) in [
    ('klein mit Textskala 1,3', const Size(960, 600), Brightness.light, 1.3),
    ('dunkel', const Size(1280, 800), Brightness.dark, 1.0),
    ('dunkel, klein', const Size(960, 600), Brightness.dark, 1.3),
  ]) {
    testWidgets('kein Überlauf: $name', (t) async {
      await _start(
        t,
        seeded: false,
        size: size,
        brightness: brightness,
        textScale: scale,
      );
      expect(t.takeException(), isNull);
      await _toChefPin(t);
      expect(find.text('Chef-PIN festlegen'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('kein Überlauf der Anmeldung: $name', (t) async {
      await _start(
        t,
        seeded: true,
        size: size,
        brightness: brightness,
        textScale: scale,
      );
      expect(find.text('PIN eingeben'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }
}
