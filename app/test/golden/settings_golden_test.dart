import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/app.dart';
import 'package:kassa/data/settings_repository.dart';
import 'package:kassa/devices/printer.dart';
import 'package:kassa/devices/printer_discovery.dart';
import 'package:material_ui/material_ui.dart';

import '../support/fake_devices.dart';
import '../support/pump.dart' show printerOf;
import '../support/fake_server.dart';
import '../support/server_pump.dart';
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

  // Karte "Server" in den fünf Zuständen. Der Bildausschnitt ist die ganze
  // Einstellungsseite, nach unten gescrollt, damit die Karte zu sehen ist.
  final states = <(String, Future<void> Function(WidgetTester, Brightness))>[
    ('nicht_gekoppelt', (t, b) => pumpUnpaired(t, brightness: b)),
    ('verbunden', (t, b) => pumpPaired(t, brightness: b)),
    (
      'gesperrt',
      (t, b) async {
        final s = await pumpPaired(t, brightness: b);
        s.mode = FakeMode.blocked;
        await t.tap(find.byKey(const Key('server-sync')));
        await t.pumpAndSettle();
      },
    ),
    (
      'unbekannt',
      (t, b) async {
        final s = await pumpPaired(t, brightness: b);
        s.mode = FakeMode.unauthorized;
        await t.tap(find.byKey(const Key('server-sync')));
        await t.pumpAndSettle();
      },
    ),
    (
      'nicht_geladen',
      (t, b) async {
        await pumpPaired(
          t,
          server: FakeServer.beispiel()..breakAfterPages = 1,
          load: false,
          brightness: b,
        );
      },
    ),
  ];
  for (final (state, setUp) in states) {
    for (final (name, brightness) in [
      ('hell', Brightness.light),
      ('dunkel', Brightness.dark),
    ]) {
      testWidgets('Einstellungen, Karte Server, $state ($name)', (t) async {
        await setUp(t, brightness);
        await t.dragUntilVisible(
          find.text('Server'),
          find.byType(SingleChildScrollView).first,
          const Offset(0, -200),
        );
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        await expectLater(
          find.byType(KassaApp),
          matchesGoldenFile('goldens/einstellungen_server_${state}_$name.png'),
        );
      });
    }
  }
}
