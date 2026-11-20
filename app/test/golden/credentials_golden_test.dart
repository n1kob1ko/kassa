import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/app.dart';
import 'package:kassa/features/shell/shell_screen.dart';
import 'package:kassa/rksv/rksv_secrets.dart';
import 'package:material_ui/material_ui.dart';

import '../support/fake_atrust.dart';
import '../support/settings_pump.dart';
import '../support/signature_pump.dart';

// Bildvergleich des Bildschirms "Zugangsdaten von A-Trust" gegen die Bilder
// `s2b-02` (leer) und `s2b-04` (gespeichert). Neu erzeugen mit
// `flutter test --update-goldens test/golden/credentials_golden_test.dart`.

Future<void> _open(
  WidgetTester t, {
  Brightness brightness = Brightness.light,
  MemoryRksvSecrets? secrets,
}) async {
  await pumpSettings(
    t,
    brightness: brightness,
    extra: onlineOverrides(FakeAtrust(), secrets: secrets),
  );
  openCredentials(t.element(find.byKey(const Key('area-settings'))));
  await t.pumpAndSettle();
}

Future<void> _expect(WidgetTester t, String file) async {
  expect(t.takeException(), isNull);
  await expectLater(find.byType(KassaApp), matchesGoldenFile(file));
}

void main() {
  for (final (name, brightness) in [
    ('hell', Brightness.light),
    ('dunkel', Brightness.dark),
  ]) {
    testWidgets('Zugangsdaten, leer ($name)', (t) async {
      await _open(t, brightness: brightness);
      await _expect(t, 'goldens/zugangsdaten_leer_$name.png');
    });
  }

  testWidgets('Zugangsdaten, gespeichert (hell)', (t) async {
    final secrets = MemoryRksvSecrets();
    await secrets.writeAtrustCredentials(
      const AtrustCredentials('u-beispiel', 'geheim-beispiel'),
    );
    await _open(t, secrets: secrets);
    await _expect(t, 'goldens/zugangsdaten_gespeichert_hell.png');
  });
}
