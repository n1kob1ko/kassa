import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/core/clock.dart';
import 'package:kassa/data/providers.dart';
import 'package:kassa/domain/cart.dart';
import 'package:kassa/features/kassa/cart_controller.dart';
import 'package:kassa/features/kassa/sale_service.dart';
import 'package:kassa/features/login/session.dart';
import 'package:kassa/features/setup/pairing_view.dart';
import 'package:kassa/ui/primary_button.dart';
import 'package:material_ui/material_ui.dart';

import '../support/demo_fixtures.dart';
import '../support/fake_server.dart';
import '../support/kassa_pump.dart';
import '../support/pump.dart';
import '../support/server_pump.dart';

const _questionTitle = 'Mit dem Server verbinden?';
const _questionText =
    'Die Speisekarte und die Mitarbeiter kommen danach vom Server. '
    'Die Bons auf diesem Tablet bleiben. Ein offener Bon wird geleert, '
    'und du meldest dich neu an.';
const _failedLine =
    'Der letzte Abgleich hat nicht geklappt. '
    'Die Kassa versucht es von selbst wieder.';

FixedClock _clock(WidgetTester t) =>
    containerOf(t).read(clockProvider) as FixedClock;

Future<void> _later(WidgetTester t, Duration d) async {
  _clock(t).value = _clock(t).value.add(d);
  await t.pump(const Duration(minutes: 1));
  await t.pumpAndSettle();
}

Future<void> _tapAndSettle(WidgetTester t, String key) async {
  // Die Karte steht unten, das Tablet scrollt dorthin.
  await t.ensureVisible(find.byKey(Key(key)));
  await t.pumpAndSettle();
  await t.tap(find.byKey(Key(key)));
  await t.pumpAndSettle();
}

Future<void> _enterCode(WidgetTester t) async {
  await tapKeys(t, FakeServer.code.split('').join(' '));
  await t.tap(find.byKey(const Key('pair-submit')));
  await t.pumpAndSettle();
}

void main() {
  testWidgets(
    'nicht gekoppelt: Taste da, Rückfrage erscheint, "Abbrechen" ändert nichts',
    (t) async {
      final server = await pumpUnpaired(t);
      expect(find.text('Server'), findsOneWidget);
      expect(find.text('Nicht mit dem Server verbunden.'), findsOneWidget);
      for (final pill in [
        'Verbunden',
        'Gesperrt',
        'Unbekannt',
        'Nicht geladen',
      ]) {
        expect(find.text(pill), findsNothing);
      }
      await _tapAndSettle(t, 'server-pair');
      expect(find.text(_questionTitle), findsOneWidget);
      expect(find.text(_questionText), findsOneWidget);
      expect(find.text('Verbinden'), findsOneWidget);
      await _tapAndSettle(t, 'cancel-pair-question');
      expect(find.text(_questionTitle), findsNothing);
      expect(find.text('Nicht mit dem Server verbunden.'), findsOneWidget);
      expect(find.byType(PairingView), findsNothing);
      expect(server.pairRequests, isEmpty);
      expect(find.byType(TextField), findsNothing);
    },
  );

  testWidgets('ohne Server in dieser Version: Satz, keine Taste', (t) async {
    await pumpUnpaired(t, hasServer: false);
    expect(find.text('Diese Version hat keinen Server.'), findsOneWidget);
    expect(find.byKey(const Key('server-pair')), findsNothing);
    expect(find.byKey(const Key('server-sync')), findsNothing);
    expect(find.byKey(const Key('reimport')), findsOneWidget);
  });

  testWidgets(
    '"Verbinden" und richtiger Code: neue Speisekarte, abgemeldet, offener Bon leer, alte Bons noch da',
    (t) async {
      final server = await pumpUnpaired(t);
      final c = containerOf(t);
      final staff = (await c.read(staffRepositoryProvider).all()).first;
      await c
          .read(receiptRepositoryProvider)
          .finalizeCashSale(
            saleId: 'alt-1',
            cart: const Cart.empty().add(cola),
            givenCents: 1000,
            staff: staff,
          );
      c.read(cartProvider.notifier).add(cola);
      await t.pump();
      expect(c.read(cartProvider).isEmpty, isFalse);

      await _tapAndSettle(t, 'server-pair');
      await _tapAndSettle(t, 'confirm-pair-question');
      expect(find.text('Kopplungscode eingeben'), findsOneWidget);
      await _enterCode(t);

      expect(server.pairRequests.single['code'], FakeServer.code);
      expect(find.text('PIN eingeben'), findsOneWidget);
      // Der Bildschirm zum Koppeln bleibt nicht über der Anmeldung stehen.
      expect(find.byType(PairingView), findsNothing);
      expect(find.text('Kopplungscode eingeben'), findsNothing);
      expect(c.read(sessionProvider), isNull);
      expect(c.read(cartProvider).isEmpty, isTrue);
      expect(await c.read(receiptRepositoryProvider).find('alt-1'), isNotNull);
      await typePin(t, '1234');
      await t.pumpAndSettle();
      expect(c.read(sessionProvider), isNotNull);
    },
  );

  testWidgets('"Zurück" im Code-Bildschirm kehrt zu den Einstellungen zurück', (
    t,
  ) async {
    await pumpUnpaired(t);
    await _tapAndSettle(t, 'server-pair');
    await _tapAndSettle(t, 'confirm-pair-question');
    await _tapAndSettle(t, 'pair-back');
    expect(find.byType(PairingView), findsNothing);
    expect(find.text('Nicht mit dem Server verbunden.'), findsOneWidget);
  });

  testWidgets(
    'gekoppelt: Betrieb, Kassa und "Zuletzt abgeglichen vor 2 Minuten"',
    (t) async {
      await pumpPaired(t);
      expect(
        find.text('Verbunden mit Beispiel-Imbiss als Kassa 1'),
        findsOneWidget,
      );
      expect(find.text('Verbunden'), findsOneWidget);
      expect(find.byKey(const Key('server-sync')), findsOneWidget);
      expect(find.text('Jetzt abgleichen'), findsOneWidget);
      expect(find.text('Zuletzt abgeglichen gerade eben'), findsOneWidget);
      await _later(t, const Duration(minutes: 2));
      expect(find.text('Zuletzt abgeglichen vor 2 Minuten'), findsOneWidget);
      await _later(t, const Duration(hours: 1));
      expect(find.text('Zuletzt abgeglichen vor 1 Stunde'), findsOneWidget);
      expect(find.text(_failedLine), findsNothing);
    },
  );

  testWidgets('"Jetzt abgleichen" holt und zeigt danach "gerade eben"', (
    t,
  ) async {
    final server = await pumpPaired(t);
    await _later(t, const Duration(minutes: 2));
    expect(find.text('Zuletzt abgeglichen vor 2 Minuten'), findsOneWidget);
    final pulls = server.pullRequests.length;
    await _tapAndSettle(t, 'server-sync');
    expect(server.pullRequests.length, greaterThan(pulls));
    expect(find.text('Zuletzt abgeglichen gerade eben'), findsOneWidget);
  });

  testWidgets(
    'gescheiterter Abgleich zeigt den Hinweis, die Kassa bleibt bedienbar',
    (t) async {
      final server = await pumpPaired(t);
      server.mode = FakeMode.offline;
      await _tapAndSettle(t, 'server-sync');
      expect(find.text(_failedLine), findsOneWidget);
      expect(find.text('Verbunden'), findsOneWidget);
      expect(find.byKey(const Key('server-sync')), findsOneWidget);
      expect(find.text('Gesperrt'), findsNothing);
      // Die Kassa geht weiter: ein Bon lässt sich anlegen.
      containerOf(t).read(cartProvider.notifier).add(cola);
      await t.pump();
      expect(containerOf(t).read(cartProvider).isEmpty, isFalse);
      // Kommt das Netz zurück, verschwindet der Hinweis.
      server.mode = FakeMode.online;
      await _tapAndSettle(t, 'server-sync');
      expect(find.text(_failedLine), findsNothing);
    },
  );

  testWidgets('gesperrt zeigt beide Sätze und "Nochmal prüfen"', (t) async {
    final server = await pumpPaired(t);
    server.mode = FakeMode.blocked;
    await _tapAndSettle(t, 'server-sync');
    expect(find.text('Gesperrt'), findsOneWidget);
    expect(
      find.text('Diese Kassa wurde in der Verwaltung gesperrt.'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Bonieren geht weiter. Abgeglichen wird erst wieder, wenn die Sperre aufgehoben ist.',
      ),
      findsOneWidget,
    );
    for (final key in [
      'server-sync',
      'server-pair',
      'server-repair',
      'server-load',
    ]) {
      expect(find.byKey(Key(key)), findsNothing);
    }
    expect(find.text(_failedLine), findsNothing);
    final recheck = t.widget<PrimaryButton>(
      find.byKey(const Key('server-recheck')),
    );
    expect(recheck.label, 'Nochmal prüfen');
    expect(recheck.filled, isFalse);

    // Noch gesperrt: bleibt so, mit Taste.
    final pulls = server.pullRequests.length;
    await _tapAndSettle(t, 'server-recheck');
    expect(server.pullRequests.length, greaterThan(pulls));
    expect(find.text('Gesperrt'), findsOneWidget);

    // Sperre aufgehoben: während des Prüfens läuft der Ring, danach verbunden.
    server.mode = FakeMode.online;
    final gate = Completer<void>();
    server.beforeNextPage = () => gate.future;
    await t.ensureVisible(find.byKey(const Key('server-recheck')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('server-recheck')));
    await t.pump();
    expect(
      find.descendant(
        of: find.byKey(const Key('server-recheck')),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    expect(
      t
          .widget<PrimaryButton>(find.byKey(const Key('server-recheck')))
          .onPressed,
      isNull,
    );
    gate.complete();
    await t.pumpAndSettle();
    expect(find.text('Gesperrt'), findsNothing);
    expect(find.text('Verbunden'), findsOneWidget);
    expect(find.byKey(const Key('server-recheck')), findsNothing);
  });

  testWidgets(
    'unauthorized zeigt "Neu koppeln", das den Weg des Koppelns geht',
    (t) async {
      final server = await pumpPaired(t);
      server.mode = FakeMode.unauthorized;
      await _tapAndSettle(t, 'server-sync');
      expect(find.text('Unbekannt'), findsOneWidget);
      expect(
        find.text('Der Server kennt diese Kassa nicht mehr.'),
        findsOneWidget,
      );
      expect(find.text(_failedLine), findsNothing);
      server.mode = FakeMode.online;
      await _tapAndSettle(t, 'server-repair');
      expect(find.text(_questionTitle), findsOneWidget);
      await _tapAndSettle(t, 'confirm-pair-question');
      await _enterCode(t);
      expect(server.pairRequests, hasLength(2));
      expect(find.text('PIN eingeben'), findsOneWidget);
      expect(find.byType(PairingView), findsNothing);
    },
  );

  testWidgets(
    'Kassa da, Speisekarte nicht geladen: "Speisekarte laden" holt sie ohne neuen Code',
    (t) async {
      final server = FakeServer.beispiel()..breakAfterPages = 1;
      await pumpPaired(t, server: server, load: false);
      expect(find.text('Nicht geladen'), findsOneWidget);
      expect(
        find.text(
          'Die Verbindung steht. Die Speisekarte ist noch nicht geladen.',
        ),
        findsOneWidget,
      );
      // Scheitert wieder: Satz, Taste bleibt.
      await _tapAndSettle(t, 'server-load');
      expect(find.text('Speisekarte vom Server laden?'), findsOneWidget);
      expect(find.text(_questionTitle), findsNothing);
      expect(find.text('Laden'), findsOneWidget);
      expect(find.text('Verbinden'), findsNothing);
      await _tapAndSettle(t, 'confirm-pair-question');
      expect(
        find.text('Die Speisekarte konnte nicht geladen werden.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('server-load')), findsOneWidget);
      server.breakAfterPages = null;
      await _tapAndSettle(t, 'server-load');
      await _tapAndSettle(t, 'confirm-pair-question');
      expect(server.pairRequests, hasLength(1));
      expect(find.text('PIN eingeben'), findsOneWidget);
    },
  );

  testWidgets(
    'gekoppelt: statt "Speisekarte neu einspielen" steht "Die Speisekarte kommt vom Server."',
    (t) async {
      await pumpPaired(t);
      expect(find.text('Die Speisekarte kommt vom Server.'), findsOneWidget);
      expect(find.byKey(const Key('reimport')), findsNothing);
    },
  );

  testWidgets('nicht gekoppelt bleibt "Speisekarte neu einspielen" mit Taste', (
    t,
  ) async {
    await pumpUnpaired(t);
    expect(find.byKey(const Key('reimport')), findsOneWidget);
    expect(find.text('Die Speisekarte kommt vom Server.'), findsNothing);
  });

  testWidgets(
    'während einer Kartenzahlung ist "Mit Server verbinden" gesperrt',
    (t) async {
      await pumpUnpaired(t);
      containerOf(t).read(activeCardPaymentProvider.notifier).set('zahlung-1');
      await t.pumpAndSettle();
      final button = t.widget<PrimaryButton>(
        find.byKey(const Key('server-pair')),
      );
      expect(button.onPressed, isNull);
      await t.tap(find.byKey(const Key('server-pair')), warnIfMissed: false);
      await t.pumpAndSettle();
      expect(find.text(_questionTitle), findsNothing);
      containerOf(t).read(activeCardPaymentProvider.notifier).set(null);
      await t.pumpAndSettle();
      await _tapAndSettle(t, 'server-pair');
      expect(find.text(_questionTitle), findsOneWidget);
    },
  );

  testWidgets(
    'beginnt eine Kartenzahlung bei offener Rückfrage, öffnet "Verbinden" nichts',
    (t) async {
      await pumpUnpaired(t);
      await _tapAndSettle(t, 'server-pair');
      containerOf(t).read(activeCardPaymentProvider.notifier).set('zahlung-1');
      await t.pumpAndSettle();
      await _tapAndSettle(t, 'confirm-pair-question');
      expect(find.byType(PairingView), findsNothing);
      expect(find.text('Kopplungscode eingeben'), findsNothing);
      expect(find.text(_questionTitle), findsNothing);
      expect(find.text('Nicht mit dem Server verbunden.'), findsOneWidget);
    },
  );

  testWidgets(
    'Speisekarte laden ohne gültigen Schlüssel: "Der Server kennt diese Kassa nicht mehr." mit "Neu koppeln"',
    (t) async {
      final server = FakeServer.beispiel()..breakAfterPages = 0;
      await pumpPaired(t, server: server, load: false);
      server.breakAfterPages = null;
      await containerOf(t).read(tokenStoreProvider).clear();
      await _tapAndSettle(t, 'server-load');
      await _tapAndSettle(t, 'confirm-pair-question');
      expect(find.text('Unbekannt'), findsOneWidget);
      expect(
        find.text('Der Server kennt diese Kassa nicht mehr.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('server-load')), findsNothing);
      await _tapAndSettle(t, 'server-repair');
      await _tapAndSettle(t, 'confirm-pair-question');
      await _enterCode(t);
      expect(server.pairRequests, hasLength(2));
      expect(find.text('PIN eingeben'), findsOneWidget);
    },
  );

  testWidgets(
    'Speisekarte laden, der Server lehnt den Schlüssel ab: ebenfalls "Neu koppeln"',
    (t) async {
      final server = FakeServer.beispiel()..breakAfterPages = 0;
      await pumpPaired(t, server: server, load: false);
      server
        ..breakAfterPages = null
        ..mode = FakeMode.unauthorized;
      await _tapAndSettle(t, 'server-load');
      await _tapAndSettle(t, 'confirm-pair-question');
      expect(
        find.text('Der Server kennt diese Kassa nicht mehr.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('server-repair')), findsOneWidget);
    },
  );

  group('Betrieb am Server ohne Chef', () {
    const noChef =
        'Lege in der Verwaltung zuerst einen Mitarbeiter mit PIN an.';

    Future<FakeServer> pairWithoutChef(WidgetTester t) async {
      final server = await pumpUnpaired(t);
      server.archive('staff', '<uuid>');
      final c = containerOf(t);
      final staff = (await c.read(staffRepositoryProvider).all()).first;
      await c
          .read(receiptRepositoryProvider)
          .finalizeCashSale(
            saleId: 'alt-1',
            cart: const Cart.empty().add(cola),
            givenCents: 1000,
            staff: staff,
          );
      c.read(cartProvider.notifier).add(cola);
      await t.pump();
      await _tapAndSettle(t, 'server-pair');
      await _tapAndSettle(t, 'confirm-pair-question');
      await _enterCode(t);
      return server;
    }

    testWidgets(
      'eingerichtetes Tablet: Hinweis, "Zurück zur Kassa", bonieren und alte PIN gehen weiter',
      (t) async {
        await pairWithoutChef(t);
        final c = containerOf(t);
        expect(find.byType(PairingView), findsOneWidget);
        expect(find.text(noChef), findsOneWidget);
        expect(find.byKey(const Key('pair-recheck')), findsOneWidget);
        final close = t.widget<PrimaryButton>(
          find.byKey(const Key('pair-close')),
        );
        expect(close.label, 'Zurück zur Kassa');
        expect(close.filled, isFalse);

        await _tapAndSettle(t, 'pair-close');
        expect(find.byType(PairingView), findsNothing);
        expect(find.text('Nicht geladen'), findsOneWidget);
        expect(c.read(sessionProvider), isNotNull);
        expect(c.read(cartProvider).isEmpty, isFalse);
        expect(
          await c.read(receiptRepositoryProvider).find('alt-1'),
          isNotNull,
        );
        final names = (await c.read(staffRepositoryProvider).all()).map(
          (s) => s.name,
        );
        expect(names, isNot(contains('Chefin')));

        // Die alte PIN meldet weiter an.
        c.read(sessionProvider.notifier).logout();
        await t.pumpAndSettle();
        expect(find.text('PIN eingeben'), findsOneWidget);
        await typePin(t, '4711');
        await t.pumpAndSettle();
        expect(c.read(sessionProvider), isNotNull);
        expect(c.read(cartProvider).isEmpty, isFalse);
      },
    );

    testWidgets(
      '"Speisekarte laden" in den Einstellungen zeigt denselben Satz und ändert nichts',
      (t) async {
        await pairWithoutChef(t);
        await _tapAndSettle(t, 'pair-close');
        await _tapAndSettle(t, 'server-load');
        await _tapAndSettle(t, 'confirm-pair-question');
        expect(find.text('Nicht geladen'), findsOneWidget);
        expect(find.text(noChef), findsOneWidget);
        expect(
          find.text('Die Speisekarte konnte nicht geladen werden.'),
          findsNothing,
        );
        expect(find.byKey(const Key('server-load')), findsOneWidget);
        expect(containerOf(t).read(sessionProvider), isNotNull);
      },
    );

    testWidgets(
      'Chef in der Verwaltung angelegt: "Nochmal prüfen" lädt die Speisekarte',
      (t) async {
        final server = await pairWithoutChef(t);
        server.upsert(
          'staff',
          FakeServer.staffRow(
            id: 'neue-chefin',
            name: 'Neue Chefin',
            pin: '2468',
            role: 'chef',
          ),
        );
        await _tapAndSettle(t, 'pair-recheck');
        expect(find.byType(PairingView), findsNothing);
        expect(find.text('PIN eingeben'), findsOneWidget);
        expect(containerOf(t).read(cartProvider).isEmpty, isTrue);
        await typePin(t, '2468');
        await t.pumpAndSettle();
        expect(containerOf(t).read(sessionProvider)?.name, 'Neue Chefin');
      },
    );
  });
}
