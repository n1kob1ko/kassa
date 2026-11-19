import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/app.dart';
import 'package:kassa/rksv/rksv_secrets.dart';
import 'package:kassa/rksv/rksv_state.dart';
import 'package:material_ui/material_ui.dart';

import '../support/fake_atrust.dart';
import '../support/settings_pump.dart';
import '../support/signature_pump.dart';

// Bildvergleich der Karte "Signatur" gegen die Bilder `s1b-2` und `s1b-7`,
// für die Online-Probe gegen `s2a-01`, `s2a-07`, `s2a-08` und `s2a-09`.
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

  testWidgets('Signatur aus (dunkel)', (t) async {
    await pumpSettings(
      t,
      brightness: Brightness.dark,
      extra: signatureOverrides(),
    );
    await _expectCard(t, 'goldens/signatur_aus_dunkel.png');
  });

  for (final (name, brightness) in [
    ('hell', Brightness.light),
    ('dunkel', Brightness.dark),
  ]) {
    testWidgets('Signatur in der Online-Probe ($name)', (t) async {
      await pumpSettings(
        t,
        brightness: brightness,
        extra: onlineOverrides(FakeAtrust()),
      );
      await seedProbe(t, unit: RksvUnit.atrustTest);
      await _expectCard(t, 'goldens/signatur_online_probe_$name.png');
    });

    testWidgets('Signatur in der Online-Probe, ausgefallen ($name)', (t) async {
      await pumpSettings(
        t,
        brightness: brightness,
        extra: onlineOverrides(FakeAtrust()),
      );
      await seedProbe(
        t,
        unit: RksvUnit.atrustTest,
        outageSince: DateTime(2026, 11, 17, 13, 5),
        outageReason: 'Kein Internet.',
      );
      await _expectCard(t, 'goldens/signatur_online_ausfall_$name.png');
    });

    testWidgets('Signatur in der Online-Probe, abgelehnt ($name)', (t) async {
      final secrets = MemoryRksvSecrets();
      await secrets.writeAtrustRejected(true);
      await pumpSettings(
        t,
        brightness: brightness,
        extra: onlineOverrides(FakeAtrust(), secrets: secrets),
      );
      await seedProbe(t, unit: RksvUnit.atrustTest);
      await _expectCard(t, 'goldens/signatur_online_abgelehnt_$name.png');
    });
  }
}
