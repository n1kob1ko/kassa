import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/app.dart';
import 'package:kassa/rksv/card/card_signer.dart';
import 'package:kassa/rksv/rksv_secrets.dart';
import 'package:kassa/rksv/rksv_state.dart';
import 'package:material_ui/material_ui.dart';

import '../support/fake_atrust.dart';
import '../support/settings_pump.dart';
import '../support/signature_pump.dart';

// Bildvergleich der Karte "Signatur" gegen die Bilder `s1b-2` und `s1b-7`,
// für die Online-Probe gegen `s2a-01`, `s2a-07`, `s2a-08` und `s2a-09`, für
// den echten Betrieb gegen `s2b-08`, `s2b-09` und `s2b-11` (die Bilder sind
// 960 dp hoch wie die Entwürfe, weil die Karte dort mehr Zeilen hat). Dazu
// die Karten-Probe und der Betrieb mit der Signaturkarte.
// Neu erzeugen mit
// `flutter test --update-goldens test/golden/signature_panel_golden_test.dart`.

Future<void> _expectCard(
  WidgetTester t,
  String file, {
  double height = 800,
}) async {
  // Die Karte steht ohne Scrollen ganz im Bild.
  final card = t.getRect(find.byKey(const Key('signature-card')));
  expect(card.bottom, lessThanOrEqualTo(height));
  expect(t.takeException(), isNull);
  await expectLater(find.byType(KassaApp), matchesGoldenFile(file));
}

/// Einstellungen 1280 x 960 dp wie die Entwürfe `s2b-08` bis `s2b-11`: für
/// Karten, die mit der Zeile "Signatur einrichten" nicht mehr in 800 dp
/// passen.
const _tall = Size(1280, 960);

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
        size: _tall,
        brightness: brightness,
        extra: signatureOverrides(),
      );
      await seedProbe(t, tasks: twoTasks);
      await _expectCard(t, 'goldens/signatur_probe_$name.png', height: 960);
    });
  }

  testWidgets('Signatur in der Probe, ausgefallen (hell)', (t) async {
    await pumpSettings(t, size: _tall, extra: signatureOverrides());
    await seedProbe(
      t,
      tasks: [twoTasks.first],
      outageSince: DateTime(2026, 11, 17, 10, 30),
    );
    await _expectCard(t, 'goldens/signatur_ausfall_hell.png', height: 960);
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
        size: _tall,
        brightness: brightness,
        extra: onlineOverrides(FakeAtrust(), secrets: secrets),
      );
      await seedProbe(t, unit: RksvUnit.atrustTest);
      await _expectCard(
        t,
        'goldens/signatur_online_abgelehnt_$name.png',
        height: 960,
      );
    });
  }

  for (final (name, brightness) in [
    ('hell', Brightness.light),
    ('dunkel', Brightness.dark),
  ]) {
    testWidgets('Signatur in Betrieb mit zwei Aufgaben ($name)', (t) async {
      await pumpSettings(
        t,
        size: _tall,
        brightness: brightness,
        extra: onlineOverrides(FakeAtrust()),
      );
      await seedLive(t, tasks: liveTasks);
      await _expectCard(
        t,
        'goldens/signatur_in_betrieb_$name.png',
        height: 960,
      );
    });
  }

  testWidgets('Signatur in Betrieb, ausgefallen (hell)', (t) async {
    await pumpSettings(t, size: _tall, extra: onlineOverrides(FakeAtrust()));
    await seedLive(
      t,
      outageSince: DateTime(2026, 11, 17, 13, 5),
      outageReason: 'Kein Internet.',
    );
    await _expectCard(
      t,
      'goldens/signatur_in_betrieb_ausfall_hell.png',
      height: 960,
    );
  });

  testWidgets('Signatur in Betrieb, abgelehnt (hell)', (t) async {
    final secrets = MemoryRksvSecrets();
    await secrets.writeAtrustRejected(true, live: true);
    await pumpSettings(
      t,
      size: _tall,
      extra: onlineOverrides(FakeAtrust(), secrets: secrets),
    );
    await seedLive(
      t,
      outageSince: DateTime(2026, 11, 17, 13, 5),
      outageReason: 'A-Trust hat die Zugangsdaten abgelehnt.',
    );
    await _expectCard(
      t,
      'goldens/signatur_in_betrieb_abgelehnt_hell.png',
      height: 960,
    );
  });

  testWidgets('Signatur außer Betrieb mit zwei Aufgaben (hell)', (t) async {
    await pumpSettings(t, size: _tall, extra: onlineOverrides(FakeAtrust()));
    await seedLive(t, tasks: decommissionTasks, decommissioned: true);
    await _expectCard(
      t,
      'goldens/signatur_ausser_betrieb_hell.png',
      height: 960,
    );
  });

  for (final (name, brightness) in [
    ('hell', Brightness.light),
    ('dunkel', Brightness.dark),
  ]) {
    testWidgets('Signatur in Betrieb mit Karte, abgelehnte PIN ($name)', (
      t,
    ) async {
      final secrets = MemoryRksvSecrets();
      await secrets.writeCardPinStatus(const CardPinStatus(rejected: true));
      await pumpSettings(
        t,
        size: _tall,
        brightness: brightness,
        extra: signatureOverrides(secrets: secrets),
      );
      await seedLive(t, unit: RksvUnit.card, tasks: [liveTasks.first]);
      expect(
        find.text(
          const CardSignException(CardSignProblem.pinRejected).sentence,
        ),
        findsOneWidget,
      );
      await _expectCard(
        t,
        'goldens/signatur_karte_in_betrieb_$name.png',
        height: 960,
      );
    });
  }

  testWidgets('Signatur in der Karten-Probe, ausgefallen (hell)', (t) async {
    await pumpSettings(t, size: _tall, extra: signatureOverrides());
    await seedProbe(
      t,
      unit: RksvUnit.cardTest,
      outageSince: DateTime(2026, 11, 17, 13, 5),
      outageReason: const CardSignException(CardSignProblem.noCard).sentence,
    );
    await _expectCard(t, 'goldens/signatur_karte_probe_hell.png', height: 960);
  });
}
