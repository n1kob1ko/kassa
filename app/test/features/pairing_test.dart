import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/app.dart';
import 'package:kassa/app_sync_providers.dart';
import 'package:kassa/data/providers.dart';
import 'package:kassa/features/login/session.dart';
import 'package:kassa/ui/code_boxes.dart';
import 'package:kassa/sync/server_api.dart';
import 'package:kassa/sync/token_store.dart';
import 'package:material_ui/material_ui.dart';

import '../support/fake_server.dart';
import '../support/pump.dart';

const _staffId = '33333333-3333-4333-8333-333333333333';

/// Der Beispiel-Imbiss ohne Mitarbeiter (die Chefin der Vorlage ist archiviert).
FakeServer _serverWithoutStaff() {
  final s = FakeServer.beispiel();
  s.archive('staff', '<uuid>');
  return s;
}

Future<List<Override>> _overrides(
  FakeServer server, {
  bool hasServer = true,
  bool seeded = false,
  String? file,
  MemoryTokenStore? tokens,
}) async => [
  ...await memoryOverrides(seeded: seeded, pickedFile: file),
  hasServerProvider.overrideWithValue(hasServer),
  tokenStoreProvider.overrideWithValue(tokens ?? MemoryTokenStore()),
  serverApiProvider.overrideWithValue(
    ServerApi(
      baseUrl: 'https://kassa.example',
      client: server,
      appVersion: '1',
    ),
  ),
];

Future<FakeServer> _start(
  WidgetTester t, {
  FakeServer? server,
  bool hasServer = true,
  bool seeded = false,
  String? file,
  MemoryTokenStore? tokens,
}) async {
  final s = server ?? FakeServer.beispiel();
  await pumpApp(
    t,
    const KassaApp(),
    overrides: await _overrides(
      s,
      hasServer: hasServer,
      seeded: seeded,
      file: file,
      tokens: tokens,
    ),
  );
  await t.pumpAndSettle();
  return s;
}

ProviderContainer _container(WidgetTester t) =>
    ProviderScope.containerOf(t.element(find.byType(KassaApp)));

String _typed(WidgetTester t) =>
    t.widget<CodeBoxes>(find.byType(CodeBoxes)).value;

Future<void> _openCodeEntry(WidgetTester t) async {
  await t.tap(find.byKey(const Key('setup-pair')));
  await t.pumpAndSettle();
}

Future<void> _enterAndSubmit(WidgetTester t, String code) async {
  await tapKeys(t, code.split('').join(' '));
  await t.tap(find.byKey(const Key('pair-submit')));
  await t.pumpAndSettle();
}

void main() {
  testWidgets(
    'erster Start zeigt beide Wege, "Mit Code koppeln" öffnet die Code-Eingabe',
    (t) async {
      await _start(t);
      expect(find.text('Kassa einrichten'), findsOneWidget);
      expect(
        find.text(
          'Verbinde dieses Tablet mit deinem Betrieb. '
          'Speisekarte und Mitarbeiter kommen dann von selbst.',
        ),
        findsOneWidget,
      );
      expect(find.text('Mit Code koppeln'), findsOneWidget);
      expect(find.text('Acht Ziffern aus der Verwaltung'), findsOneWidget);
      expect(find.text('Speisekarte aus Datei einspielen'), findsOneWidget);
      expect(find.text('Ohne Server, wie bisher'), findsOneWidget);
      expect(find.byKey(const Key('setup-file')), findsOneWidget);
      await _openCodeEntry(t);
      expect(find.text('Kopplungscode eingeben'), findsOneWidget);
      expect(
        find.text('Den Code findest du in der Verwaltung unter Kassen.'),
        findsOneWidget,
      );
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(EditableText), findsNothing);
    },
  );

  testWidgets('ohne Server ist die Taste aus und der Hinweis steht da', (
    t,
  ) async {
    await _start(t, hasServer: false);
    expect(find.text('Diese Version hat keinen Server.'), findsOneWidget);
    await t.tap(find.byKey(const Key('setup-pair')), warnIfMissed: false);
    await t.pumpAndSettle();
    expect(find.text('Kopplungscode eingeben'), findsNothing);
    expect(find.text('Kassa einrichten'), findsOneWidget);
  });

  testWidgets(
    '"Koppeln" ist erst bei 8 Ziffern aktiv, die 9. Ziffer wird nicht angenommen',
    (t) async {
      await _start(t);
      await _openCodeEntry(t);
      final submit = find.byKey(const Key('pair-submit'));
      await tapKeys(t, '4 8 2 0 1 9 3');
      await t.tap(submit, warnIfMissed: false);
      await t.pumpAndSettle();
      expect(find.text('Kopplungscode eingeben'), findsOneWidget);
      await tapKeys(t, '7 5');
      expect(_typed(t), '48201937');
      await t.tap(submit);
      await t.pumpAndSettle();
      expect(find.text('Kopplungscode eingeben'), findsNothing);
    },
  );

  testWidgets('falscher Code zeigt den Satz und leert die Felder', (t) async {
    await _start(t);
    await _openCodeEntry(t);
    await _enterAndSubmit(t, '11111111');
    expect(
      find.text('Der Code stimmt nicht oder ist abgelaufen.'),
      findsOneWidget,
    );
    expect(_typed(t), '');
    // Neue Ziffer nimmt den Fehler weg.
    await tapKeys(t, '1');
    expect(
      find.text('Der Code stimmt nicht oder ist abgelaufen.'),
      findsNothing,
    );
  });

  for (final (mode, sentence) in [
    (FakeMode.offline, 'Keine Verbindung zum Internet.'),
    (FakeMode.garbage, 'Das hat nicht geklappt. Bitte nochmal versuchen.'),
    (FakeMode.blocked, 'Das hat nicht geklappt. Bitte nochmal versuchen.'),
  ]) {
    testWidgets('Fehler $mode zeigt "$sentence"', (t) async {
      final server = await _start(t);
      server.mode = mode;
      await _openCodeEntry(t);
      await _enterAndSubmit(t, FakeServer.code);
      expect(find.text(sentence), findsOneWidget);
      expect(_typed(t), '');
    });
  }

  testWidgets(
    'richtiger Code: "Verbunden mit Beispiel-Imbiss", dann die Anmeldung mit PIN, PIN 1234 meldet an',
    (t) async {
      final server = await _start(t);
      await _openCodeEntry(t);
      await tapKeys(t, '4 8 2 0 1 9 3 7');
      await t.tap(find.byKey(const Key('pair-submit')));
      // Das Laden hängt hier an der ersten Seite: vorher steht der Text da.
      await t.pump();
      await t.pumpAndSettle();
      expect(server.pairRequests.single['code'], FakeServer.code);
      expect(find.text('PIN eingeben'), findsOneWidget);
      await typePin(t, '1234');
      await t.pumpAndSettle();
      expect(_container(t).read(sessionProvider), isNotNull);
      expect(find.text('PIN eingeben'), findsNothing);
    },
  );

  testWidgets(
    '"Verbunden mit …" und Fortschritt stehen, solange geladen wird',
    (t) async {
      final server = FakeServer.beispiel();
      final gate = _Gate();
      server.beforeNextPage = gate.wait;
      await _start(t, server: server);
      await _openCodeEntry(t);
      await tapKeys(t, '4 8 2 0 1 9 3 7');
      await t.tap(find.byKey(const Key('pair-submit')));
      await t.pump();
      await t.pump();
      await t.pump();
      expect(find.text('Verbunden mit Beispiel-Imbiss'), findsOneWidget);
      expect(find.text('Dieses Tablet ist jetzt Kassa 1.'), findsOneWidget);
      expect(find.text('Speisekarte wird geladen'), findsOneWidget);
      gate.open();
      await t.pumpAndSettle();
      expect(find.text('PIN eingeben'), findsOneWidget);
    },
  );

  testWidgets('Laden scheitert: "Nochmal versuchen" gelingt ohne neuen Code', (
    t,
  ) async {
    final server = FakeServer.beispiel()..breakAfterPages = 1;
    await _start(t, server: server);
    await _openCodeEntry(t);
    await _enterAndSubmit(t, FakeServer.code);
    expect(
      find.text('Die Speisekarte konnte nicht geladen werden.'),
      findsOneWidget,
    );
    expect(find.text('Verbunden mit Beispiel-Imbiss'), findsOneWidget);
    server.breakAfterPages = null;
    await t.tap(find.byKey(const Key('pair-retry')));
    await t.pumpAndSettle();
    expect(server.pairRequests, hasLength(1));
    expect(find.text('PIN eingeben'), findsOneWidget);
  });

  testWidgets(
    'Betrieb ohne Mitarbeiter: Hinweis, nach "Nochmal prüfen" mit Mitarbeiter erscheint die PIN',
    (t) async {
      final server = _serverWithoutStaff();
      await _start(t, server: server);
      await _openCodeEntry(t);
      await _enterAndSubmit(t, FakeServer.code);
      expect(
        find.text(
          'Lege in der Verwaltung zuerst einen Mitarbeiter mit PIN an.',
        ),
        findsOneWidget,
      );
      // Noch immer keiner: der Hinweis bleibt.
      await t.tap(find.byKey(const Key('pair-recheck')));
      await t.pumpAndSettle();
      expect(find.text('PIN eingeben'), findsNothing);
      expect(
        find.text(
          'Lege in der Verwaltung zuerst einen Mitarbeiter mit PIN an.',
        ),
        findsOneWidget,
      );
      server.upsert(
        'staff',
        FakeServer.staffRow(
          id: _staffId,
          name: 'Anna',
          pin: '1234',
          role: 'chef',
        ),
      );
      await t.tap(find.byKey(const Key('pair-recheck')));
      await t.pumpAndSettle();
      expect(find.text('PIN eingeben'), findsOneWidget);
    },
  );

  testWidgets(
    'App startet mit Kassa, aber ohne geladene Speisekarte: lädt von selbst weiter',
    (t) async {
      final server = FakeServer.beispiel()..breakAfterPages = 1;
      final overrides = await _overrides(server);
      await pumpApp(t, const KassaApp(), overrides: overrides);
      await t.pumpAndSettle();
      await _openCodeEntry(t);
      await _enterAndSubmit(t, FakeServer.code);
      expect(
        find.text('Die Speisekarte konnte nicht geladen werden.'),
        findsOneWidget,
      );
      // Neustart mit demselben Speicher: Kassa da, Speisekarte nicht.
      server.breakAfterPages = null;
      await t.pumpWidget(const SizedBox());
      await pumpApp(t, const KassaApp(), overrides: overrides);
      await t.pumpAndSettle();
      expect(find.text('PIN eingeben'), findsOneWidget);
      expect(server.pairRequests, hasLength(1));
    },
  );

  testWidgets(
    'Betrieb mit nur einer Person der Rolle "staff": der Hinweis bleibt, keine PIN',
    (t) async {
      final server = _serverWithoutStaff();
      await _start(t, server: server);
      await _openCodeEntry(t);
      await _enterAndSubmit(t, FakeServer.code);
      server.upsert(
        'staff',
        FakeServer.staffRow(
          id: _staffId,
          name: 'Anna',
          pin: '1234',
          role: 'staff',
        ),
      );
      await t.tap(find.byKey(const Key('pair-recheck')));
      await t.pumpAndSettle();
      expect(find.text('PIN eingeben'), findsNothing);
      expect(
        find.text(
          'Lege in der Verwaltung zuerst einen Mitarbeiter mit PIN an.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('pair-recheck')), findsOneWidget);
    },
  );

  for (final (code, sentence) in [
    ('too_many_attempts', 'Zu viele Versuche. Bitte in 15 Minuten nochmal.'),
    ('other_business', 'Dieses Tablet gehört zu einem anderen Betrieb.'),
    ('unauthorized', 'Das hat nicht geklappt. Bitte nochmal versuchen.'),
    ('register_blocked', 'Das hat nicht geklappt. Bitte nochmal versuchen.'),
  ]) {
    testWidgets('Servercode $code zeigt "$sentence"', (t) async {
      final server = await _start(t);
      server.pairErrorCode = code;
      await _openCodeEntry(t);
      await _enterAndSubmit(t, FakeServer.code);
      expect(find.text(sentence), findsOneWidget);
      expect(_typed(t), '');
    });
  }

  testWidgets(
    '"Mit neuem Code koppeln" öffnet die Code-Eingabe, auch nach dem Neustart',
    (t) async {
      final server = FakeServer.beispiel()..breakAfterPages = 1;
      final overrides = await _overrides(server);
      await pumpApp(t, const KassaApp(), overrides: overrides);
      await t.pumpAndSettle();
      await _openCodeEntry(t);
      await _enterAndSubmit(t, FakeServer.code);
      // Neustart: die Kassa ist gekoppelt, das Laden scheitert wieder.
      await t.pumpWidget(const SizedBox());
      await pumpApp(t, const KassaApp(), overrides: overrides);
      await t.pumpAndSettle();
      expect(
        find.text('Die Speisekarte konnte nicht geladen werden.'),
        findsOneWidget,
      );
      await t.tap(find.byKey(const Key('pair-new')));
      await t.pumpAndSettle();
      expect(find.text('Kopplungscode eingeben'), findsOneWidget);
      expect(find.text('Kassa einrichten'), findsNothing);
    },
  );

  testWidgets(
    '"Zurück" führt zum ersten Bildschirm, der Weg über die Datei geht wie bisher',
    (t) async {
      await _start(
        t,
        file:
            '{"betrieb":"Test-Bude","kategorien":[{"id":"k","name":"Essen"}],'
            '"artikel":[{"id":"a","name":"Brot","kategorie":"k","preis_cent":250,"mwst":10}]}',
      );
      await _openCodeEntry(t);
      await t.tap(find.byKey(const Key('pair-back')));
      await t.pumpAndSettle();
      expect(find.text('Kassa einrichten'), findsOneWidget);
      await t.tap(find.byKey(const Key('setup-file')));
      await t.pumpAndSettle();
      expect(find.text('Speisekarte gelesen'), findsOneWidget);
      await t.tap(find.text('Weiter zur Chef-PIN'));
      await t.pumpAndSettle();
      expect(find.text('Chef-PIN festlegen'), findsOneWidget);
    },
  );
}

class _Gate {
  final _c = Completer<void>();
  Future<void> wait() => _c.future;
  void open() => _c.complete();
}
