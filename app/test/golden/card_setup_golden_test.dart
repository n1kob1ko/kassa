import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/app.dart';
import 'package:kassa/rksv/rksv_secrets.dart';
import 'package:material_ui/material_ui.dart';

import '../support/fake_card_reader.dart';
import '../support/settings_pump.dart';
import '../support/signature_pump.dart';

// Bildvergleich von "Karte und PIN" (aus "Mit Karte ausprobieren"). Neu
// erzeugen mit
// `flutter test --update-goldens test/golden/card_setup_golden_test.dart`.

/// Einstellungen mit der nachgebauten Karte, dann "Mit Karte ausprobieren".
Future<void> _open(
  WidgetTester t, {
  Brightness brightness = Brightness.light,
  MemoryRksvSecrets? secrets,
}) async {
  await pumpSettings(
    t,
    brightness: brightness,
    reader: FakeCardReader(card: testSignatureCard()),
    extra: signatureOverrides(secrets: secrets),
  );
  await t.ensureVisible(find.byKey(const Key('rksv-card-probe-on')));
  await t.pumpAndSettle();
  await t.tap(find.byKey(const Key('rksv-card-probe-on')));
  await t.pumpAndSettle();
}

void main() {
  for (final (name, brightness) in [
    ('hell', Brightness.light),
    ('dunkel', Brightness.dark),
  ]) {
    testWidgets('Karte und PIN, Karte gelesen ($name)', (t) async {
      await _open(t, brightness: brightness);
      expect(t.takeException(), isNull);
      await expectLater(
        find.byType(KassaApp),
        matchesGoldenFile('goldens/karte_und_pin_$name.png'),
      );
    });
  }

  testWidgets('Karte und PIN, schon gespeichert (hell)', (t) async {
    final secrets = MemoryRksvSecrets();
    final card = testSignatureCard();
    await secrets.writeCardPin(
      CardPin(
        kind: card.profile.kind.name,
        numberHex: '0102030405060708',
        pin: card.pin,
      ),
    );
    await _open(t, secrets: secrets);
    expect(t.takeException(), isNull);
    await expectLater(
      find.byType(KassaApp),
      matchesGoldenFile('goldens/karte_und_pin_gespeichert_hell.png'),
    );
  });
}
