import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/app.dart';
import 'package:kassa/core/clock.dart';
import 'package:kassa/data/providers.dart';
import 'package:material_ui/material_ui.dart';

import '../support/fake_atrust.dart';
import '../support/kassa_pump.dart' show containerOf;
import '../support/settings_pump.dart';
import '../support/signature_pump.dart';

// Bildvergleich des Blatts "Mit A-Trust ausprobieren?" und des Bildschirms
// "Verbindung prüfen" gegen die Bilder `s2a-02`, `s2a-04`, `s2a-05` und
// `s2a-12`. Neu erzeugen mit
// `flutter test --update-goldens test/golden/connection_check_golden_test.dart`.

/// Jede Anfrage an A-Trust dauert 0,2 Sekunden auf der Uhr der Kassa.
void _slowRequests(WidgetTester t, FakeAtrust fake) {
  final clock = containerOf(t).read(clockProvider) as FixedClock;
  fake.onRequest = (_) =>
      clock.value = clock.value.add(const Duration(milliseconds: 200));
}

/// Ohne Scrollen: Die Zeile steht ganz oben im Bild, wie in `s2a-02`.
Future<void> _tap(WidgetTester t, String key) async {
  await t.tap(find.byKey(Key(key)));
  await t.pumpAndSettle();
}

Future<void> _expect(WidgetTester t, String file) async {
  expect(t.takeException(), isNull);
  await expectLater(find.byType(KassaApp), matchesGoldenFile(file));
}

void main() {
  testWidgets('Mit A-Trust ausprobieren, Frage (hell)', (t) async {
    await pumpSettings(t, extra: onlineOverrides(FakeAtrust()));
    await _tap(t, 'rksv-online-probe-on');
    await _expect(t, 'goldens/online_probe_frage_hell.png');
  });

  for (final (name, brightness) in [
    ('hell', Brightness.light),
    ('dunkel', Brightness.dark),
  ]) {
    testWidgets('Verbindung prüfen, vier Haken mit Starttaste ($name)', (
      t,
    ) async {
      final fake = FakeAtrust();
      await pumpSettings(
        t,
        brightness: brightness,
        extra: onlineOverrides(fake),
      );
      _slowRequests(t, fake);
      await _tap(t, 'rksv-online-probe-on');
      await _tap(t, 'rksv-question-confirm');
      await _expect(t, 'goldens/verbindung_vier_haken_$name.png');
    });

    testWidgets('Verbindung prüfen, kein Internet ($name)', (t) async {
      final fake = FakeAtrust()..offline = true;
      await pumpSettings(
        t,
        brightness: brightness,
        extra: onlineOverrides(fake),
      );
      await _tap(t, 'rksv-online-probe-on');
      await _tap(t, 'rksv-question-confirm');
      await _expect(t, 'goldens/verbindung_kein_internet_$name.png');
    });
  }

  testWidgets('Mit A-Trust ausprobieren, Frage (dunkel)', (t) async {
    await pumpSettings(
      t,
      brightness: Brightness.dark,
      extra: onlineOverrides(FakeAtrust()),
    );
    await _tap(t, 'rksv-online-probe-on');
    await _expect(t, 'goldens/online_probe_frage_dunkel.png');
  });
}
