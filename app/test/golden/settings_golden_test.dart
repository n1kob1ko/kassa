import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/app.dart';
import 'package:kassa/data/settings_repository.dart';
import 'package:kassa/devices/printer.dart';
import 'package:kassa/devices/printer_discovery.dart';
import 'package:material_ui/material_ui.dart';

import '../support/fake_devices.dart';
import '../support/pump.dart' show printerOf;
import '../support/settings_pump.dart';

// Bildvergleich der Einstellungen gegen den freigegebenen Entwurf. Neu
// erzeugen mit `flutter test --update-goldens test/golden/settings_golden_test.dart`.

void main() {
  testWidgets('Einstellungen (hell)', (t) async {
    await pumpSettings(t);
    expect(t.takeException(), isNull);
    await expectLater(
      find.byType(KassaApp),
      matchesGoldenFile('goldens/einstellungen_hell.png'),
    );
  });

  testWidgets('Einstellungen (dunkel)', (t) async {
    await pumpSettings(t, brightness: Brightness.dark);
    expect(t.takeException(), isNull);
    await expectLater(
      find.byType(KassaApp),
      matchesGoldenFile('goldens/einstellungen_dunkel.png'),
    );
  });

  testWidgets('Einstellungen, Speisekarte neu einspielen, Rückfrage (hell)', (
    t,
  ) async {
    await pumpSettings(t, pickedFile: demoOhneTeigtaschen());
    await t.tap(find.byKey(const Key('reimport')));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    await expectLater(
      find.byType(KassaApp),
      matchesGoldenFile('goldens/einstellungen_neu_einspielen_hell.png'),
    );
  });

  for (final (name, brightness) in [
    ('hell', Brightness.light),
    ('dunkel', Brightness.dark),
  ]) {
    testWidgets('Einstellungen, Bondrucker einrichten ($name)', (t) async {
      await pumpSettings(
        t,
        brightness: brightness,
        discovery: FakeDiscovery(
          foundNetwork: [
            const FoundPrinter(
              kind: PrinterKind.network,
              name: 'Drucker 192.168.1.50',
              address: '192.168.1.50:9100',
            ),
          ],
        ),
      );
      await t.tap(find.byKey(const Key('printer-row')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('printer-found-192.168.1.50:9100')));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await expectLater(
        find.byType(KassaApp),
        matchesGoldenFile('goldens/einstellungen_drucker_$name.png'),
      );
    });
  }

  for (final (name, brightness) in [
    ('hell', Brightness.light),
    ('dunkel', Brightness.dark),
  ]) {
    testWidgets('Geräte testen, ein Ergebnis in Ordnung, eines mit Problem '
        '($name)', (t) async {
      await pumpSettings(t, brightness: brightness);
      await t.tap(find.byKey(const Key('open-device-test')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('test-printer')));
      await t.pumpAndSettle();
      printerOf(t).next = const PrintOutcome.failed(PrintProblem.unreachable);
      await t.tap(find.byKey(const Key('test-drawer')));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await expectLater(
        find.byType(KassaApp),
        matchesGoldenFile('goldens/geraete_testen_$name.png'),
      );
    });
  }
}
