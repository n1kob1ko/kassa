import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/app.dart';
import 'package:kassa/data/outbox_repository.dart';
import 'package:kassa/data/providers.dart';
import 'package:kassa/data/settings_repository.dart';
import 'package:kassa/devices/printer.dart';
import 'package:kassa/devices/printer_discovery.dart';
import 'package:material_ui/material_ui.dart';

import '../support/fake_devices.dart';
import '../support/pump.dart' show printerOf, tapKeys;
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
        await t.ensureVisible(find.byKey(const Key('server-sync')));
        await t.pumpAndSettle();
        await t.tap(find.byKey(const Key('server-sync')));
        await t.pumpAndSettle();
      },
    ),
    (
      'unbekannt',
      (t, b) async {
        final s = await pumpPaired(t, brightness: b);
        s.mode = FakeMode.unauthorized;
        await t.ensureVisible(find.byKey(const Key('server-sync')));
        await t.pumpAndSettle();
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

  // Aus den Einstellungen gekoppelt, der Betrieb am Server hat keinen Chef:
  // Hinweis, "Nochmal prüfen" und "Zurück zur Kassa".
  for (final (name, brightness) in [
    ('hell', Brightness.light),
    ('dunkel', Brightness.dark),
  ]) {
    testWidgets('Koppeln aus den Einstellungen, kein Chef am Server ($name)', (
      t,
    ) async {
      final server = await pumpUnpaired(t, brightness: brightness);
      server.archive('staff', '<uuid>');
      await t.ensureVisible(find.byKey(const Key('server-pair')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('server-pair')));
      await t.pumpAndSettle();
      await t.ensureVisible(find.byKey(const Key('confirm-pair-question')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('confirm-pair-question')));
      await t.pumpAndSettle();
      await tapKeys(t, FakeServer.code.split('').join(' '));
      await t.tap(find.byKey(const Key('pair-submit')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('pair-close')), findsOneWidget);
      expect(t.takeException(), isNull);
      await expectLater(
        find.byType(KassaApp),
        matchesGoldenFile('goldens/koppeln_kein_chef_am_server_$name.png'),
      );
    });
  }

  // Karte "Server" mit wartenden und abgelehnten Einträgen, auch bei größter
  // Schrift. Zusätzlich die Rückfrage vor dem Koppeln.
  Override counts(int pending, int rejected) =>
      outboxCountsProvider.overrideWith(
        (ref) =>
            Stream.value(OutboxCounts(pending: pending, rejected: rejected)),
      );
  final waiting = <(String, int, int)>[
    ('wartend', 3, 0),
    ('abgelehnt_1', 0, 1),
    ('abgelehnt_2', 0, 2),
    ('wartend_und_abgelehnt', 3, 2),
  ];
  for (final (state, pending, rejected) in waiting) {
    for (final (name, brightness, scale) in [
      ('hell', Brightness.light, 1.0),
      ('dunkel', Brightness.dark, 1.0),
      ('hell_gross', Brightness.light, 1.3),
      ('dunkel_gross', Brightness.dark, 1.3),
    ]) {
      testWidgets('Einstellungen, Karte Server, $state ($name)', (t) async {
        await pumpPaired(
          t,
          brightness: brightness,
          textScale: scale,
          extra: [counts(pending, rejected)],
        );
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

  for (final (name, brightness, scale) in [
    ('hell', Brightness.light, 1.0),
    ('dunkel', Brightness.dark, 1.0),
    ('hell_gross', Brightness.light, 1.3),
    ('dunkel_gross', Brightness.dark, 1.3),
  ]) {
    testWidgets('Einstellungen, Rückfrage vor dem Koppeln ($name)', (t) async {
      await pumpSettings(
        t,
        brightness: brightness,
        textScale: scale,
        extra: serverOverrides(FakeServer.beispiel()),
      );
      await t.ensureVisible(find.byKey(const Key('server-pair')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('server-pair')));
      await t.pumpAndSettle();
      await t.dragUntilVisible(
        find.byKey(const Key('confirm-pair-question')),
        find.byType(SingleChildScrollView).first,
        const Offset(0, -200),
      );
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await expectLater(
        find.byType(KassaApp),
        matchesGoldenFile('goldens/einstellungen_server_rueckfrage_$name.png'),
      );
    });
  }
}
