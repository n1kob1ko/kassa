import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/app.dart';
import 'package:kassa/rksv/rksv_secrets.dart';
import 'package:material_ui/material_ui.dart';

import '../support/fake_card_reader.dart';
import '../support/settings_pump.dart';
import '../support/signature_pump.dart';

// Bildvergleich der Wahl "Womit signiert die Kassa?", der "Angaben für
// FinanzOnline" mit der Signaturkarte und des Blatts "Kassen-ID ändern". Alle
// Werte sind erfunden. Neu erzeugen mit
// `flutter test --update-goldens test/golden/signer_choice_golden_test.dart`.

Finder _key(String key) => find.byKey(Key(key));

Future<void> _tap(WidgetTester t, String key) async {
  await t.ensureVisible(_key(key));
  await t.pumpAndSettle();
  await t.tap(_key(key));
  await t.pumpAndSettle();
}

/// Einstellungen mit der nachgebauten Karte im Leser, gespeicherter PIN und
/// einem PendingSetup, dann "Signatur einrichten".
Future<void> _choice(
  WidgetTester t, {
  Brightness brightness = Brightness.light,
}) async {
  final secrets = MemoryRksvSecrets();
  final card = testSignatureCard();
  await secrets.writeCardPin(
    CardPin(
      kind: card.profile.kind.name,
      numberHex: '0102030405060708',
      pin: card.pin,
    ),
  );
  await secrets.writePendingSetup(
    PendingSetup(
      cashBoxId: 'R4TW9KD2PX',
      aesKey: Uint8List.fromList(List.generate(32, (i) => 255 - 5 * i)),
    ),
  );
  await pumpSettings(
    t,
    brightness: brightness,
    reader: FakeCardReader(card: card),
    extra: signatureOverrides(secrets: secrets),
  );
  await _tap(t, 'rksv-setup');
}

/// Von der Wahl über "Karte und PIN" zu den Angaben.
Future<void> _cardFacts(WidgetTester t) async {
  await _choice(t);
  await _tap(t, 'signer-choice-card');
  await _tap(t, 'card-setup-main');
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
    testWidgets('Womit signiert die Kassa? ($name)', (t) async {
      await _choice(t, brightness: brightness);
      await _expect(t, 'goldens/signatur_wahl_$name.png');
    });
  }

  testWidgets('Angaben für FinanzOnline mit der Karte (hell)', (t) async {
    await _cardFacts(t);
    await _expect(t, 'goldens/angaben_finanzonline_karte_hell.png');
  });

  testWidgets('Kassen-ID ändern (hell)', (t) async {
    await _cardFacts(t);
    await _tap(t, 'setup-cashbox-change');
    await _expect(t, 'goldens/kassen_id_aendern_hell.png');
  });
}
