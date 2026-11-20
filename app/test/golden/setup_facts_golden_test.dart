import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/app.dart';
import 'package:kassa/features/login/session.dart';
import 'package:kassa/features/shell/shell_screen.dart';
import 'package:kassa/rksv/rksv_providers.dart';
import 'package:kassa/rksv/rksv_secrets.dart';
import 'package:material_ui/material_ui.dart';

import '../support/fake_atrust.dart';
import '../support/kassa_pump.dart' show containerOf;
import '../support/settings_pump.dart';
import '../support/signature_pump.dart';

// Bildvergleich von "Angaben für FinanzOnline" gegen die Bilder `s2b-06` und
// `s2b-12` (dunkel) und der Nachfrage "Jetzt in Betrieb nehmen?" gegen
// `s2b-07` (mit laufender Probe). Alle Werte sind erfunden. Neu erzeugen mit
// `flutter test --update-goldens test/golden/setup_facts_golden_test.dart`.

Finder _key(String key) => find.byKey(Key(key));

Future<void> _tap(WidgetTester t, String key) async {
  await t.tap(_key(key));
  await t.pumpAndSettle();
}

Future<void> _open(
  WidgetTester t, {
  Brightness brightness = Brightness.light,
  bool probe = false,
}) async {
  final secrets = MemoryRksvSecrets();
  await secrets.writeAtrustCredentials(
    const AtrustCredentials('u-beispiel', 'geheim-beispiel'),
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
    extra: onlineOverrides(
      FakeAtrust(validFrom: DateTime.utc(2024, 1, 1)),
      secrets: secrets,
    ),
  );
  if (probe) {
    final c = containerOf(t);
    await c
        .read(rksvServiceProvider)
        .enableProbe(staff: c.read(sessionProvider)!);
    await t.pumpAndSettle();
  }
  openCredentials(t.element(_key('area-settings')));
  await t.pumpAndSettle();
  await _tap(t, 'credentials-continue');
  await _tap(t, 'connection-continue');
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
    testWidgets('Angaben für FinanzOnline ($name)', (t) async {
      await _open(t, brightness: brightness);
      await _expect(t, 'goldens/angaben_finanzonline_$name.png');
    });
  }

  testWidgets('Nachfrage "Jetzt in Betrieb nehmen?" mit laufender Probe '
      '(hell)', (t) async {
    await _open(t, probe: true);
    await _tap(t, 'setup-go-live');
    await _expect(t, 'goldens/in_betrieb_frage_hell.png');
  });
}
