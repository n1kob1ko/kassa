import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/app.dart';
import 'package:kassa/core/clock.dart';
import 'package:kassa/data/providers.dart';
import 'package:material_ui/material_ui.dart';

import '../support/fake_card_reader.dart';
import '../support/kassa_pump.dart' show containerOf;
import '../support/pump.dart' show typePin;
import '../support/settings_pump.dart';

// Bildvergleich von "Karte prüfen" gegen die Bilder aus Task 0. Neu erzeugen
// mit `flutter test --update-goldens test/golden/card_check_golden_test.dart`.

Future<void> _run(WidgetTester t) async {
  await t.tap(find.byKey(const Key('card-check-run')));
  await t.pumpAndSettle();
}

Future<void> _openPin(WidgetTester t) async {
  await t.tap(find.byKey(const Key('card-check-pin')));
  await t.pumpAndSettle();
}

/// Jeder Austausch mit dem Leser dauert 50 ms, damit die Dauer der
/// Probe-Unterschrift nicht 0 ist.
void _slowExchanges(WidgetTester t, FakeCardReader reader) {
  final clock = containerOf(t).read(clockProvider) as FixedClock;
  reader.onExchange = (_) =>
      clock.value = clock.value.add(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('Einstellungen mit der Karte "Signatur" (hell)', (t) async {
    await pumpSettings(t);
    // Die Karte steht ohne Scrollen ganz im Bild.
    final card = t.getRect(find.byKey(const Key('signature-card')));
    expect(card.bottom, lessThanOrEqualTo(800));
    expect(t.takeException(), isNull);
    await expectLater(
      find.byType(KassaApp),
      matchesGoldenFile('goldens/einstellungen_signatur_hell.png'),
    );
  });

  testWidgets('Karte prüfen, vor dem Start (hell)', (t) async {
    await pumpCardCheck(t);
    expect(t.takeException(), isNull);
    await expectLater(
      find.byType(KassaApp),
      matchesGoldenFile('goldens/karte_pruefen_start_hell.png'),
    );
  });

  testWidgets('Karte prüfen, PIN eingeben (hell)', (t) async {
    await pumpCardCheck(t);
    await _run(t);
    await _openPin(t);
    await typePin(t, '1234');
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    await expectLater(
      find.byType(KassaApp),
      matchesGoldenFile('goldens/karte_pruefen_pin_hell.png'),
    );
  });

  for (final (name, brightness) in [
    ('hell', Brightness.light),
    ('dunkel', Brightness.dark),
  ]) {
    testWidgets('Karte prüfen, alles gut ($name)', (t) async {
      final reader = await pumpCardCheck(t, brightness: brightness);
      _slowExchanges(t, reader);
      await _run(t);
      await _openPin(t);
      await typePin(t, '123456');
      await t.tap(find.byKey(const Key('card-pin-submit')));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await expectLater(
        find.byType(KassaApp),
        matchesGoldenFile('goldens/karte_pruefen_gut_$name.png'),
      );
    });
  }

  testWidgets('Karte prüfen, keine Karte im Leser (hell)', (t) async {
    await pumpCardCheck(t, noCard: true);
    await _run(t);
    expect(t.takeException(), isNull);
    await expectLater(
      find.byType(KassaApp),
      matchesGoldenFile('goldens/karte_pruefen_keine_karte_hell.png'),
    );
  });
}
