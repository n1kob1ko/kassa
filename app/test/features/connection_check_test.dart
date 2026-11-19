// Die Online-Probe in den Einstellungen: die Zeilen der Karte "Signatur", das
// Blatt "Mit A-Trust ausprobieren?" und der Bildschirm "Verbindung prüfen",
// gegen den nachgebauten Dienst von A-Trust über die Provider.

import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/data/database.dart';
import 'package:kassa/data/providers.dart';
import 'package:kassa/data/settings_repository.dart';
import 'package:kassa/features/login/session.dart';
import 'package:kassa/features/settings/signature_panel.dart';
import 'package:kassa/rksv/online/connection_check.dart';
import 'package:kassa/rksv/online/online_providers.dart';
import 'package:kassa/rksv/rksv_secrets.dart';
import 'package:kassa/rksv/rksv_state.dart';
import 'package:kassa/ui/pressable.dart';
import 'package:material_ui/material_ui.dart';

import '../support/cash_pump.dart' show queryRows, setUpPrinter;
import '../support/fake_atrust.dart';
import '../support/kassa_pump.dart' show containerOf;
import '../support/pump.dart';
import '../support/settings_pump.dart';
import '../support/signature_pump.dart';

const _zda = 'GET /u123456789/ZDA';
const _certificate = 'GET /u123456789/Certificate';
const _login = 'PUT /Session/u123456789';
const _sign = 'POST /Session/<id>/Sign/Hash';

const _onlineHelp =
    'Die Bons werden über das Testsystem von A-Trust signiert. Braucht '
    'Internet. Sie bleiben Testbons.';
const _question = 'Mit A-Trust ausprobieren?';
const _questionText =
    'Jeder Bon wird dann über das Internet vom Testsystem von A-Trust '
    'signiert. Die Bons bleiben Testbons. Ältere Bons kannst du danach nicht '
    'mehr stornieren.';
const _onlineSubline =
    'Signatur vom Testsystem von A-Trust, nicht für den echten Betrieb.';
const _rejected = 'A-Trust hat die Zugangsdaten abgelehnt.';
const _stale = 'Das geht gerade nicht. Bitte die Einstellungen neu öffnen.';

Finder _key(String key) => find.byKey(Key(key));

Finder _inCard(Finder f) =>
    find.descendant(of: _key('signature-card'), matching: f);

Finder _inScreen(Finder f) =>
    find.descendant(of: _key('connection-check'), matching: f);

Future<void> _tap(WidgetTester t, String key) async {
  await t.ensureVisible(_key(key));
  await t.pumpAndSettle();
  await t.tap(_key(key));
  await t.pumpAndSettle();
}

/// Ist die Taste mit [key] eingeschaltet?
bool _enabled(WidgetTester t, String key) {
  final pressable = t.widget<Pressable>(
    find.descendant(of: _key(key), matching: find.byType(Pressable)).first,
  );
  return pressable.onTap != null;
}

/// Die Anfragen an A-Trust, die Sitzung ersetzt durch `<id>`.
List<String> _requests(FakeAtrust fake) => [
  for (final r in fake.requests)
    r.replaceFirst(RegExp(r'^POST /Session/[^/]+/'), 'POST /Session/<id>/'),
];

/// Einstellungen als Chef mit [fake] als A-Trust.
Future<void> _settings(
  WidgetTester t,
  FakeAtrust fake, {
  MemoryRksvSecrets? secrets,
  bool printer = false,
  FakeShareSheet? share,
}) async {
  await pumpSettings(
    t,
    extra: onlineOverrides(fake, secrets: secrets),
    share: share,
  );
  if (printer) await setUpPrinter(t);
}

/// "Mit A-Trust ausprobieren", "Weiter": der Bildschirm läuft durch.
Future<void> _openFromQuestion(WidgetTester t) async {
  await _tap(t, 'rksv-online-probe-on');
  await _tap(t, 'rksv-question-confirm');
}

Future<RksvState> _state(WidgetTester t) =>
    containerOf(t).read(rksvRepositoryProvider).current();

Future<List<String>> _kinds(WidgetTester t) async => [
  for (final r in await queryRows(
    t,
    "SELECT kind FROM receipts WHERE kind != 'sale' ORDER BY number",
  ))
    r['kind']! as String,
];

Future<int> _chains(WidgetTester t) async =>
    (await queryRows(t, 'SELECT chain FROM rksv_chains')).length;

ConnectionCheck _check(WidgetTester t) =>
    containerOf(t).read(connectionCheckProvider);

void main() {
  group('Karte "Signatur"', () {
    testWidgets('aus: Zeile "Mit A-Trust ausprobieren" unter "Zum '
        'Ausprobieren einschalten"', (t) async {
      final fake = FakeAtrust();
      await _settings(t, fake);
      expect(_inCard(find.text('Mit A-Trust ausprobieren')), findsOneWidget);
      expect(_inCard(find.text(_onlineHelp)), findsOneWidget);
      expect(
        find.descendant(
          of: _key('rksv-online-probe-on'),
          matching: find.text('Ausprobieren'),
        ),
        findsOneWidget,
      );
      expect(t.getSize(_key('rksv-online-probe-on')).height, 56);
      expect(
        t.getTopLeft(_key('rksv-online-probe-on')).dy,
        greaterThan(t.getTopLeft(_key('rksv-probe-on')).dy),
      );
      expect(_key('rksv-connection-check'), findsNothing);
      expect(_key('rksv-relogin'), findsNothing);
      // Das Öffnen der Einstellungen fragt nichts bei A-Trust.
      expect(fake.requests, isEmpty);
    });

    testWidgets('Mitarbeiter ohne Chef-Rolle sieht die neuen Zeilen nicht', (
      t,
    ) async {
      final fake = FakeAtrust();
      final secrets = MemoryRksvSecrets();
      await secrets.writeAtrustRejected(true);
      await pumpApp(
        t,
        SingleChildScrollView(
          child: SignaturePanel(
            onOpenCardCheck: () {},
            onOpenConnectionCheck: (_) {},
          ),
        ),
        overrides: [
          ...await memoryOverrides(),
          ...onlineOverrides(fake, secrets: secrets),
        ],
      );
      final c = ProviderScope.containerOf(
        t.element(find.byType(SignaturePanel)),
      );
      await c.read(sessionProvider.notifier).login('1234');
      await t.pumpAndSettle();
      expect(find.text('Nicht eingerichtet'), findsOneWidget);
      expect(_key('rksv-online-probe-on'), findsNothing);
      expect(find.text('Mit A-Trust ausprobieren'), findsNothing);

      await seedProbe(t, container: c, unit: RksvUnit.atrustTest);
      expect(find.text('Online-Probe'), findsOneWidget);
      expect(_key('rksv-connection-check'), findsNothing);
      expect(_key('rksv-relogin'), findsNothing);
      expect(find.text(_rejected), findsNothing);
    });

    testWidgets('Online-Probe: Wort, Unterzeile, "Verbindung prüfen", "Probe '
        'beenden" bleibt', (t) async {
      final fake = FakeAtrust();
      await _settings(t, fake);
      await seedProbe(t, unit: RksvUnit.atrustTest);
      expect(_inCard(find.text('Online-Probe')), findsOneWidget);
      expect(_inCard(find.text('Probe')), findsNothing);
      expect(
        _inCard(find.text('$_onlineSubline Kassen-ID $fixedCashBoxId.')),
        findsOneWidget,
      );
      expect(_inCard(find.text('Verbindung prüfen')), findsOneWidget);
      expect(
        _inCard(find.text('Internet und A-Trust ausprobieren.')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _key('rksv-connection-check'),
          matching: find.text('Prüfen'),
        ),
        findsOneWidget,
      );
      expect(t.getSize(_key('rksv-connection-check')).height, 56);
      expect(_key('rksv-probe-off'), findsOneWidget);
      expect(_key('rksv-zero'), findsOneWidget);
      expect(_key('rksv-online-probe-on'), findsNothing);
      expect(_key('rksv-relogin'), findsNothing);
      expect(fake.requests, isEmpty);
    });

    testWidgets('Probe auf dem Tablet: kein "Verbindung prüfen"', (t) async {
      await _settings(t, FakeAtrust());
      await seedProbe(t);
      expect(_inCard(find.text('Probe')), findsOneWidget);
      expect(_key('rksv-connection-check'), findsNothing);
      expect(_key('rksv-online-probe-on'), findsNothing);
    });

    testWidgets('Ausfall der Online-Probe: Wort und Grund in einem Satz', (
      t,
    ) async {
      await _settings(t, FakeAtrust());
      await seedProbe(
        t,
        unit: RksvUnit.atrustTest,
        outageSince: DateTime(2026, 11, 17, 13, 5),
        outageReason: 'Kein Internet.',
      );
      expect(
        _inCard(find.text('Online-Probe, Signatur ausgefallen')),
        findsOneWidget,
      );
      expect(_inCard(find.text('Kein Internet.')), findsOneWidget);
      expect(_key('rksv-connection-check'), findsOneWidget);
    });

    testWidgets('Ausfall der Probe: auch dort steht der Grund', (t) async {
      await _settings(t, FakeAtrust());
      await seedProbe(t, outageSince: DateTime(2026, 11, 17, 10, 30));
      expect(
        _inCard(find.text('Die Signatur hat nicht geantwortet.')),
        findsOneWidget,
      );
    });

    testWidgets('abgelehnt: Hinweis mit "Erneut anmelden"; das Antippen '
        'schickt genau eine Anmeldung', (t) async {
      final fake = FakeAtrust();
      final secrets = MemoryRksvSecrets();
      await secrets.writeAtrustRejected(true);
      await _settings(t, fake, secrets: secrets);
      await seedProbe(t, unit: RksvUnit.atrustTest);
      expect(_inCard(find.text(_rejected)), findsOneWidget);
      expect(
        find.descendant(
          of: _key('rksv-relogin'),
          matching: find.text('Erneut anmelden'),
        ),
        findsOneWidget,
      );
      expect(t.getSize(_key('rksv-relogin')).height, 56);
      expect(fake.requests, isEmpty);

      await _tap(t, 'rksv-relogin');
      expect(_key('connection-check'), findsOneWidget);
      expect(_requests(fake), [_zda, _certificate, _login, _sign]);
      expect(fake.requests.where((r) => r == _login), hasLength(1));
      // Aus der Online-Probe heraus gibt es nichts einzuschalten.
      expect(_key('connection-start'), findsNothing);

      await _tap(t, 'connection-check-back');
      expect(_key('signature-card'), findsOneWidget);
      expect(_inCard(find.text(_rejected)), findsNothing);
      expect(await secrets.atrustRejected(), isFalse);
    });

    testWidgets('StateError aus dem Dienst zeigt einen Satz statt nichts', (
      t,
    ) async {
      await _settings(t, FakeAtrust());
      await _tap(t, 'rksv-probe-on');
      // Während das Blatt offen ist, läuft die Signatur schon (etwa von einer
      // zweiten Kassa).
      final db = containerOf(t).read(databaseProvider);
      await (db.update(db.rksvStateRows)..where((r) => r.id.equals(1))).write(
        RksvStateRowsCompanion(mode: Value(RksvMode.probe.name)),
      );
      await _tap(t, 'rksv-question-confirm');
      expect(_inCard(find.text(_stale)), findsOneWidget);
    });
  });

  group('Ablauf "Mit A-Trust ausprobieren"', () {
    testWidgets('Blatt mit Frage, Text, "Abbrechen" und "Weiter"', (t) async {
      final fake = FakeAtrust();
      await _settings(t, fake);
      await _tap(t, 'rksv-online-probe-on');
      expect(find.text(_question), findsOneWidget);
      expect(find.text(_questionText), findsOneWidget);
      expect(
        find.descendant(
          of: _key('rksv-question-confirm'),
          matching: find.text('Weiter'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _key('rksv-question-cancel'),
          matching: find.text('Abbrechen'),
        ),
        findsOneWidget,
      );
      expect(t.getSize(_key('rksv-question-confirm')).height, 64);
      expect(t.getSize(_key('rksv-question-cancel')).height, 64);

      await _tap(t, 'rksv-question-cancel');
      expect(find.text(_question), findsNothing);
      expect(_key('connection-check'), findsNothing);
      expect(fake.requests, isEmpty);
      expect((await _state(t)).mode, RksvMode.off);
    });

    testWidgets('bis zum Startbeleg: vier Haken, "Online-Probe starten", '
        'Startbeleg gedruckt, zurück zur Karte', (t) async {
      final fake = FakeAtrust();
      await _settings(t, fake, printer: true);
      await _openFromQuestion(t);

      expect(find.text(_question), findsNothing);
      expect(_key('connection-check'), findsOneWidget);
      expect(_inScreen(find.text('Verbindung prüfen')), findsOneWidget);
      for (final row in ConnectionRow.values) {
        expect(_key('connection-row-${row.name}'), findsOneWidget);
      }
      expect(_inScreen(find.text('A-Trust')), findsOneWidget);
      expect(_inScreen(find.text('Zertifikat')), findsOneWidget);
      expect(_inScreen(find.text('Anmeldung')), findsOneWidget);
      expect(_inScreen(find.text('Probe-Unterschrift')), findsOneWidget);
      expect(_inScreen(find.text('Angemeldet.')), findsOneWidget);
      expect(_check(t).state.value.facts, isNotNull);
      expect(_requests(fake), [_zda, _certificate, _login, _sign]);

      expect(t.getSize(_key('connection-start')).height, 76);
      expect(
        find.descendant(
          of: _key('connection-start'),
          matching: find.text('Online-Probe starten'),
        ),
        findsOneWidget,
      );
      expect(_enabled(t, 'connection-start'), isTrue);
      expect(
        find.descendant(
          of: _key('connection-retry'),
          matching: find.text('Nochmal prüfen'),
        ),
        findsOneWidget,
      );
      expect(_key('connection-share'), findsOneWidget);

      await _tap(t, 'connection-start');
      expect(_key('connection-check'), findsNothing);
      expect(_key('signature-card'), findsOneWidget);
      expect(_requests(fake), [_zda, _certificate, _login, _sign, _sign]);
      final state = await _state(t);
      expect(state.mode, RksvMode.probe);
      expect(state.unit, RksvUnit.atrustTest);
      expect(await _kinds(t), ['start']);
      final start = (await queryRows(
        t,
        "SELECT id FROM receipts WHERE kind = 'start'",
      )).single['id']!;
      expect(printerOf(t).printed, [start]);
      expect(_inCard(find.text('Online-Probe')), findsOneWidget);
      expect(_key('rksv-connection-check'), findsOneWidget);
    });

    testWidgets('Doppeltipp auf "Online-Probe starten" ergibt eine Kette', (
      t,
    ) async {
      final fake = FakeAtrust();
      await _settings(t, fake, printer: true);
      await _openFromQuestion(t);
      await t.ensureVisible(_key('connection-start'));
      await t.pumpAndSettle();
      await t.tap(_key('connection-start'));
      await t.tap(_key('connection-start'), warnIfMissed: false);
      await t.pumpAndSettle();
      expect(await _chains(t), 1);
      expect(await _kinds(t), ['start']);
      expect(fake.requests.where((r) => r.startsWith('POST')), hasLength(2));
      expect(printerOf(t).printed, hasLength(1));
    });

    testWidgets('offline: kein Start möglich, Zeile 1 sagt "WLAN prüfen."', (
      t,
    ) async {
      final fake = FakeAtrust()..offline = true;
      await _settings(t, fake);
      await _openFromQuestion(t);
      final reach = _key('connection-row-reach');
      expect(
        find.descendant(of: reach, matching: find.text('Kein Internet.')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: reach, matching: find.text('WLAN prüfen.')),
        findsOneWidget,
      );
      expect(t.getSemantics(_key('connection-sign-reach')).label, 'Fehler');
      expect(_key('connection-start'), findsNothing);
      expect(t.getSize(_key('connection-retry')).height, 76);
      expect(_key('connection-share'), findsOneWidget);
      expect(await _chains(t), 0);
      expect((await _state(t)).mode, RksvMode.off);
    });

    testWidgets('scheitert der Startbeleg, steht der Satz am Bildschirm und '
        'die Taste bleibt', (t) async {
      final fake = FakeAtrust();
      await _settings(t, fake);
      await _openFromQuestion(t);
      fake.offline = true;
      await _tap(t, 'connection-start');
      expect(_key('connection-check'), findsOneWidget);
      expect(
        find.descendant(
          of: _key('connection-start-problem'),
          matching: find.text('Kein Internet.'),
        ),
        findsOneWidget,
      );
      expect(_key('connection-start'), findsOneWidget);
      expect(_enabled(t, 'connection-start'), isTrue);
      expect(await _chains(t), 0);
      expect((await _state(t)).mode, RksvMode.off);

      // Das Netz ist wieder da: derselbe Bildschirm schaltet ein.
      fake.offline = false;
      await _tap(t, 'connection-start');
      expect(_key('connection-check'), findsNothing);
      expect((await _state(t)).unit, RksvUnit.atrustTest);
    });

    testWidgets('läuft die Signatur schon: der Satz statt nichts', (t) async {
      await _settings(t, FakeAtrust());
      await _openFromQuestion(t);
      final db = containerOf(t).read(databaseProvider);
      await (db.update(db.rksvStateRows)..where((r) => r.id.equals(1))).write(
        RksvStateRowsCompanion(mode: Value(RksvMode.probe.name)),
      );
      await _tap(t, 'connection-start');
      expect(
        find.descendant(
          of: _key('connection-start-problem'),
          matching: find.text(_stale),
        ),
        findsOneWidget,
      );
      expect(await _chains(t), 0);
    });
  });

  group('Bildschirm "Verbindung prüfen"', () {
    testWidgets('aus der Zeile der Karte: läuft einmal, ohne Starttaste', (
      t,
    ) async {
      final fake = FakeAtrust();
      await _settings(t, fake);
      await seedProbe(t, unit: RksvUnit.atrustTest);
      await _tap(t, 'rksv-connection-check');
      expect(_key('connection-check'), findsOneWidget);
      expect(_requests(fake), [_zda, _certificate, _login, _sign]);
      expect(_key('connection-start'), findsNothing);
      expect(t.getSize(_key('connection-retry')).height, 76);
      // Ein neuer Aufbau (andere Ansicht) startet keinen zweiten Lauf.
      final repo = containerOf(t).read(settingsRepositoryProvider);
      await repo.save(
        (await repo.current()).copyWith(themeMode: AppThemeMode.dark),
      );
      await t.pumpAndSettle();
      expect(_key('connection-check'), findsOneWidget);
      expect(fake.requests, hasLength(4));
    });

    testWidgets('abgelehnt: ohne Antippen keine Anfrage, "Nochmal prüfen" ist '
        'genau eine Anmeldung', (t) async {
      final fake = FakeAtrust();
      final secrets = MemoryRksvSecrets();
      await secrets.writeAtrustRejected(true);
      await _settings(t, fake, secrets: secrets);
      await seedProbe(t, unit: RksvUnit.atrustTest);
      await _tap(t, 'rksv-connection-check');
      expect(fake.requests, isEmpty);
      final login = _key('connection-row-login');
      expect(
        find.descendant(of: login, matching: find.text(_rejected)),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _key('connection-retry'),
          matching: find.text('Nochmal prüfen'),
        ),
        findsOneWidget,
      );

      fake.loginStatus = 403;
      await _tap(t, 'connection-retry');
      expect(fake.requests.where((r) => r == _login), hasLength(1));
      expect(
        find.descendant(of: login, matching: find.text(_rejected)),
        findsOneWidget,
      );
      // Wieder abgelehnt: der nächste Lauf ohne Antippen bleibt still.
      final before = fake.requests.length;
      await _check(t).run(chefTapped: false);
      await t.pumpAndSettle();
      expect(fake.requests, hasLength(before));
    });

    testWidgets('"Bericht teilen" mit Betreff und dem Bericht des Laufs', (
      t,
    ) async {
      final fake = FakeAtrust();
      final share = FakeShareSheet();
      await _settings(t, fake, share: share);
      await seedProbe(t, unit: RksvUnit.atrustTest);
      await _tap(t, 'rksv-connection-check');
      expect(
        find.descendant(
          of: _key('connection-share'),
          matching: find.text('Bericht teilen'),
        ),
        findsOneWidget,
      );
      await _tap(t, 'connection-share');
      expect(share.calls, hasLength(1));
      expect(share.calls.single.subject, 'Kassa: Verbindung zu A-Trust');
      expect(share.calls.single.text, _check(t).report());
      expect(share.calls.single.text, contains('A-Trust: gut.'));
      // Der Sitzungsschlüssel des Fakes (erste Anmeldung) steht nie darin.
      final sessionKey = base64.encode(
        List.generate(32, (i) => (i * 7 + 1) % 256),
      );
      expect(share.calls.single.text, isNot(contains(sessionKey)));
    });

    testWidgets('Teilen geht nicht: ein Satz', (t) async {
      await _settings(t, FakeAtrust(), share: FakeShareSheet(result: false));
      await seedProbe(t, unit: RksvUnit.atrustTest);
      await _tap(t, 'rksv-connection-check');
      await _tap(t, 'connection-share');
      expect(find.text('Teilen geht auf diesem Tablet nicht.'), findsOneWidget);
    });

    testWidgets('während des Laufs: Taste gesperrt; Verlassen wirft später '
        'nichts', (t) async {
      final fake = FakeAtrust()..delay = const Duration(seconds: 1);
      await _settings(t, fake);
      await _tap(t, 'rksv-online-probe-on');
      await t.tap(_key('rksv-question-confirm'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 500));
      expect(_check(t).state.value.running, isTrue);
      expect(_key('connection-start'), findsOneWidget);
      expect(_enabled(t, 'connection-start'), isFalse);
      expect(_key('connection-share'), findsNothing);

      await t.tap(_key('connection-check-back'));
      await t.pump();
      expect(_key('connection-check'), findsNothing);
      await t.pump(const Duration(seconds: 10));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(_check(t).state.value.running, isFalse);
      expect(fake.requests, hasLength(4));
      expect((await _state(t)).mode, RksvMode.off);
    });

    testWidgets('"Zurück" des Tablets schließt den Bildschirm', (t) async {
      await _settings(t, FakeAtrust());
      await seedProbe(t, unit: RksvUnit.atrustTest);
      await _tap(t, 'rksv-connection-check');
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(_key('connection-check'), findsNothing);
      expect(_key('signature-card'), findsOneWidget);
    });
  });
}
