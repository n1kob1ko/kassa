import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/app.dart';
import 'package:material_ui/material_ui.dart';

import '../support/settings_pump.dart';
import '../support/signature_pump.dart';

// Bildvergleich der Karte "Signatur" gegen die Bilder `s1b-2` und `s1b-7`.
// Neu erzeugen mit
// `flutter test --update-goldens test/golden/signature_panel_golden_test.dart`.

Future<void> _expectCard(WidgetTester t, String file) async {
  // Die Karte steht ohne Scrollen ganz im Bild.
  final card = t.getRect(find.byKey(const Key('signature-card')));
  expect(card.bottom, lessThanOrEqualTo(800));
  expect(t.takeException(), isNull);
  await expectLater(find.byType(KassaApp), matchesGoldenFile(file));
}

void main() {
  testWidgets('Signatur aus (hell)', (t) async {
    await pumpSettings(t, extra: signatureOverrides());
    await _expectCard(t, 'goldens/signatur_aus_hell.png');
  });

  for (final (name, brightness) in [
    ('hell', Brightness.light),
    ('dunkel', Brightness.dark),
  ]) {
    testWidgets('Signatur in der Probe mit zwei Aufgaben ($name)', (t) async {
      await pumpSettings(
        t,
        brightness: brightness,
        extra: signatureOverrides(),
      );
      await seedProbe(t, tasks: twoTasks);
      await _expectCard(t, 'goldens/signatur_probe_$name.png');
    });
  }

  testWidgets('Signatur in der Probe, ausgefallen (hell)', (t) async {
    await pumpSettings(t, extra: signatureOverrides());
    await seedProbe(
      t,
      tasks: [twoTasks.first],
      outageSince: DateTime(2026, 11, 17, 10, 30),
    );
    await _expectCard(t, 'goldens/signatur_ausfall_hell.png');
  });
}
