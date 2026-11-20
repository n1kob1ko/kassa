// Die Karte "Signatur" im echten Betrieb (Plan Task 7): "Signatur
// einrichten", "In Betrieb", "Außer Betrieb", die Nachfrage vor der
// Außerbetriebnahme und "abgelehnt" am echten System, gegen den
// nachgebauten Dienst von A-Trust. Zugangsdaten und Kassen-Kennung sind
// erfunden.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/data/providers.dart';
import 'package:kassa/devices/printer.dart';
import 'package:kassa/domain/receipt.dart';
import 'package:kassa/domain/staff.dart';
import 'package:kassa/features/login/session.dart';
import 'package:kassa/features/settings/connection_check_screen.dart';
import 'package:kassa/features/settings/signature_panel.dart';
import 'package:kassa/features/shell/shell_screen.dart';
import 'package:kassa/rksv/online/atrust_client.dart';
import 'package:kassa/rksv/rksv_providers.dart';
import 'package:kassa/rksv/rksv_secrets.dart';
import 'package:kassa/rksv/rksv_service.dart';
import 'package:kassa/rksv/rksv_state.dart';
import 'package:kassa/ui/primary_button.dart';
import 'package:kassa/ui/tokens.dart';
import 'package:material_ui/material_ui.dart';

import '../support/bons_pump.dart' show sellCash;
import '../support/cash_pump.dart' show queryRows, setUpPrinter;
import '../support/fake_atrust.dart';
import '../support/kassa_pump.dart' show containerOf, pumpKassa;
import '../support/pump.dart';
import '../support/settings_pump.dart';
import '../support/signature_pump.dart';

Finder _key(String key) => find.byKey(Key(key));

Finder _inCard(Finder f) =>
    find.descendant(of: _key('signature-card'), matching: f);

Future<void> _tap(WidgetTester t, String key) async {
  await t.ensureVisible(_key(key));
  await t.pumpAndSettle();
  await t.tap(_key(key));
  await t.pumpAndSettle();
}

const _setupHelp =
    'Für den echten Betrieb. Du brauchst die Zugangsdaten von A-Trust.';
const _liveHelp = 'Signatur von A-Trust. Kassen-ID $fixedLiveCashBoxId.';
const _offHelp = 'Die Kassa ist außer Betrieb. Neue Bons sind Testbons.';
const _credentialsHelp = 'Benutzername und Passwort von A-Trust ändern.';
const _decommissionHelp =
    'Die Kassa erstellt einen Schlussbeleg. Danach sind neue Bons wieder '
    'Testbons.';
const _question =
    'Das lässt sich nicht zurücknehmen. Die Kassa erstellt den Schlussbeleg '
    'und signiert danach keine Bons mehr. Du musst das bei FinanzOnline '
    'melden.';
const _rejected = 'A-Trust hat die Zugangsdaten abgelehnt.';
const _practice = 'Aufgaben aus der Probe sind zum Üben.';

/// Ein A-Trust, dessen Zertifikat heute gilt.
FakeAtrust _fake() => FakeAtrust(validFrom: DateTime.utc(2024, 1, 1));

/// Einstellungen als Chef mit [fake] als A-Trust und [secrets].
Future<void> _settings(
  WidgetTester t, {
  FakeAtrust? fake,
  MemoryRksvSecrets? secrets,
  bool printer = false,
  List<Override> extra = const [],
}) async {
  await pumpSettings(
    t,
    extra: [
      ...onlineOverrides(fake ?? _fake(), secrets: secrets),
      ...extra,
    ],
  );
  if (printer) await setUpPrinter(t);
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

Future<List<({String kind, bool damaged})>> _entries(WidgetTester t) async => [
  for (final r in await queryRows(
    t,
    'SELECT r.kind AS kind, e.damaged AS damaged FROM rksv_entries e '
    'JOIN receipts r ON r.id = e.receipt_id ORDER BY e.chain, e.position',
  ))
    (kind: r['kind']! as String, damaged: r['damaged'] == 1),
];

/// Die Schlüssel der Zeilen der Karte mit Taste, von oben nach unten.
List<String> _rowsInOrder(WidgetTester t) {
  const keys = [
    'rksv-task-done-register-finanzonline-1',
    'rksv-task-done-check-start-1',
    'rksv-task-done-report-decommission-1',
    'rksv-task-done-backup-decommission-1',
    'rksv-connection-check',
    'rksv-zero',
    'rksv-export',
    'rksv-credentials',
    'rksv-decommission',
    'rksv-probe-on',
    'rksv-online-probe-on',
    'rksv-probe-off',
    'rksv-setup',
    'open-card-check',
  ];
  final present = [
    for (final k in keys)
      if (_key(k).evaluate().isNotEmpty) k,
  ];
  present.sort(
    (a, b) => t.getTopLeft(_key(a)).dy.compareTo(t.getTopLeft(_key(b)).dy),
  );
  return present;
}

int _logins(FakeAtrust fake) =>
    fake.requests.where((r) => r.startsWith('PUT /Session/')).length;

/// Ein Dienst, dessen Außerbetriebnahme erst weiterläuft, wenn [gate]
/// erfüllt ist, und dann mit [failure] scheitert, wenn es eines gibt.
class _GatedService extends RksvService {
  _GatedService(Ref ref)
    : super(
        ref.watch(databaseProvider),
        ref.watch(rksvSecretsProvider),
        ref.watch(receiptRepositoryProvider),
        ref.watch(clockProvider),
        saver: ref.watch(protocolSaverProvider),
      );

  Completer<void> gate = Completer<void>();
  Object? failure;
  int calls = 0;

  @override
  Future<Receipt> decommission({required Staff staff}) async {
    calls++;
    await gate.future;
    if (failure case final f?) throw f;
    return super.decommission(staff: staff);
  }
}

_GatedService _gatedOf(WidgetTester t) =>
    containerOf(t).read(rksvServiceProvider) as _GatedService;

void main() {
  group('Signatur einrichten', () {
    testWidgets('steht in "Nicht eingerichtet", "Probe" und "Online-Probe" '
        'vor "Karte prüfen" und öffnet die Zugangsdaten', (t) async {
      for (final unit in [null, RksvUnit.probe, RksvUnit.atrustTest]) {
        await _settings(t);
        if (unit != null) await seedProbe(t, unit: unit);
        expect(_inCard(find.text('Signatur einrichten')), findsOneWidget);
        expect(_inCard(find.text(_setupHelp)), findsOneWidget);
        expect(
          find.descendant(
            of: _key('rksv-setup'),
            matching: find.text('Einrichten'),
          ),
          findsOneWidget,
        );
        expect(t.getSize(_key('rksv-setup')).height, 56);
        final rows = _rowsInOrder(t);
        expect(rows.sublist(rows.length - 2), [
          'rksv-setup',
          'open-card-check',
        ]);

        await _tap(t, 'rksv-setup');
        expect(_key('credentials'), findsOneWidget, reason: '$unit');
        expect(_key('credentials-user'), findsOneWidget);
        expect(_key('signature-card'), findsNothing);
      }
    });

    testWidgets('openCredentials tut für Mitarbeiter ohne Chef-Rolle nichts, '
        'auch nichts, was der nächste Chef sähe', (t) async {
      await pumpKassa(
        t,
        overrides: [...await memoryOverrides(), ...onlineOverrides(_fake())],
      );
      openCredentials(t.element(_key('area-kassa')));
      await t.pumpAndSettle();
      expect(_key('area-kassa'), findsOneWidget);
      // Der Chef meldet sich an, ohne dass die Hülle dazwischen abgebaut
      // wird.
      await containerOf(t).read(sessionProvider.notifier).login('4711');
      await t.pumpAndSettle();
      expect(containerOf(t).read(sessionProvider)!.isChef, isTrue);
      expect(_key('credentials'), findsNothing);
      expect(_key('area-settings'), findsNothing);
      expect(_key('area-kassa'), findsOneWidget);
    });

    testWidgets('steht in Betrieb nicht da', (t) async {
      await _settings(t);
      await seedLive(t);
      expect(_key('rksv-setup'), findsNothing);
      expect(_inCard(find.text('Signatur einrichten')), findsNothing);
    });
  });

  group('In Betrieb', () {
    testWidgets('Pille, Hilfe, Aufgaben ohne den Satz zum Üben und die Zeilen '
        'in der Reihenfolge des Bilds; die Zeilen der Probe fehlen', (t) async {
      await _settings(t);
      await seedLive(t, tasks: liveTasks);
      expect(_inCard(find.text('In Betrieb')), findsOneWidget);
      expect(_inCard(find.text(_liveHelp)), findsOneWidget);
      expect(_inCard(find.text('Zu erledigen')), findsOneWidget);
      expect(_inCard(find.text(_practice)), findsNothing);
      expect(
        _inCard(
          find.text(
            'Signatureinheit und Kassa bei FinanzOnline anmelden, bis '
            '24.11.2026.',
          ),
        ),
        findsOneWidget,
      );
      expect(_rowsInOrder(t), [
        'rksv-task-done-register-finanzonline-1',
        'rksv-task-done-check-start-1',
        'rksv-connection-check',
        'rksv-zero',
        'rksv-export',
        'rksv-credentials',
        'rksv-decommission',
        'open-card-check',
      ]);
      for (final (title, help) in [
        ('Verbindung prüfen', 'Internet und A-Trust ausprobieren.'),
        (
          'Nullbeleg drucken',
          'Ein Beleg über 0 Euro, zum Beispiel für eine Kontrolle.',
        ),
        (
          'Protokoll ausgeben',
          'Speichert die signierten Bons als Datei, zum Beispiel auf einen '
              'USB-Stick.',
        ),
        ('Zugangsdaten', _credentialsHelp),
        ('Kassa außer Betrieb nehmen', _decommissionHelp),
      ]) {
        expect(_inCard(find.text(title)), findsOneWidget, reason: title);
        expect(_inCard(find.text(help)), findsOneWidget, reason: help);
      }
      for (final (key, label) in [
        ('rksv-credentials', 'Ändern'),
        ('rksv-decommission', 'Außer Betrieb'),
      ]) {
        expect(
          find.descendant(of: _key(key), matching: find.text(label)),
          findsOneWidget,
        );
        expect(t.getSize(_key(key)).height, 56);
      }
      for (final text in [
        'Zum Ausprobieren einschalten',
        'Mit A-Trust ausprobieren',
        'Probe beenden',
        'Signatur einrichten',
      ]) {
        expect(_inCard(find.text(text)), findsNothing, reason: text);
      }
    });

    testWidgets('im Ausfall: Pille "In Betrieb, Signatur ausgefallen" und der '
        'Grund darunter', (t) async {
      await _settings(t);
      await seedLive(t, outageSince: DateTime(2026, 11, 17, 13, 5));
      final pill = _inCard(find.text('In Betrieb, Signatur ausgefallen'));
      expect(pill, findsOneWidget);
      expect(t.widget<Text>(pill).style!.color, KassaColors.light.warnInk);
      expect(_inCard(find.text('In Betrieb')), findsNothing);
      expect(_inCard(find.text(_liveHelp)), findsOneWidget);
      expect(_inCard(find.textContaining('Kein Internet.')), findsOneWidget);
      expect(_key('rksv-decommission'), findsOneWidget);
    });

    testWidgets('"Zugangsdaten" "Ändern" öffnet die Zugangsdaten', (t) async {
      final secrets = MemoryRksvSecrets();
      await secrets.writeAtrustCredentials(exampleLiveCredentials);
      await _settings(t, secrets: secrets);
      await seedLive(t);
      await _tap(t, 'rksv-credentials');
      expect(_key('credentials'), findsOneWidget);
      expect(_key('credentials-saved'), findsOneWidget);
    });

    testWidgets('"Verbindung prüfen" prüft am echten System, ohne "Weiter"; '
        'in der Online-Probe am Testsystem', (t) async {
      final secrets = MemoryRksvSecrets();
      await secrets.writeAtrustCredentials(exampleLiveCredentials);
      await _settings(t, secrets: secrets);
      await seedLive(t);
      await _tap(t, 'rksv-connection-check');
      var screen = t.widget<ConnectionCheckScreen>(
        find.byType(ConnectionCheckScreen),
      );
      expect(screen.system, AtrustSystem.live);
      expect(screen.onContinue, isNull);
      expect(_key('connection-continue'), findsNothing);
      expect(_key('connection-start'), findsNothing);

      await _settings(t);
      await seedProbe(t, unit: RksvUnit.atrustTest);
      await _tap(t, 'rksv-connection-check');
      screen = t.widget<ConnectionCheckScreen>(
        find.byType(ConnectionCheckScreen),
      );
      expect(screen.system, AtrustSystem.test);
    });

    testWidgets('Mitarbeiter ohne Chef-Rolle sieht keine der Tasten', (
      t,
    ) async {
      await pumpApp(
        t,
        SingleChildScrollView(
          child: SignaturePanel(
            onOpenCardCheck: () {},
            onOpenConnectionCheck: (_) {},
          ),
        ),
        overrides: [...await memoryOverrides(), ...onlineOverrides(_fake())],
      );
      final c = ProviderScope.containerOf(
        t.element(find.byType(SignaturePanel)),
      );
      await c.read(sessionProvider.notifier).login('1234');
      await seedLive(t, container: c, tasks: liveTasks);
      expect(find.text('In Betrieb'), findsOneWidget);
      expect(find.text(rksvTaskText(liveTasks.first)), findsOneWidget);
      for (final k in [
        'rksv-connection-check',
        'rksv-zero',
        'rksv-export',
        'rksv-credentials',
        'rksv-decommission',
        'rksv-setup',
        'rksv-task-done-register-finanzonline-1',
      ]) {
        expect(_key(k), findsNothing, reason: k);
      }
      expect(find.text('Erledigt'), findsNothing);
    });

    testWidgets('neue Aufgaben gehen mit "Erledigt" weg', (t) async {
      await _settings(t);
      await seedLive(t, tasks: liveTasks);
      await _tap(t, 'rksv-task-done-register-finanzonline-1');
      expect(_key('rksv-task-register-finanzonline-1'), findsNothing);
      expect(
        [for (final x in (await _state(t)).tasks) x.id],
        ['check-start-1'],
      );
    });
  });

  group('abgelehnt', () {
    testWidgets('in Betrieb: der Satz und "Zugangsdaten neu eingeben" öffnet '
        'die Felder', (t) async {
      final secrets = MemoryRksvSecrets();
      await secrets.writeAtrustCredentials(exampleLiveCredentials);
      await secrets.writeAtrustRejected(true, live: true);
      await _settings(t, secrets: secrets);
      await seedLive(t);
      expect(
        find.descendant(
          of: _key('rksv-rejected'),
          matching: find.text(_rejected),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _key('rksv-credentials-again'),
          matching: find.text('Zugangsdaten neu eingeben'),
        ),
        findsOneWidget,
      );
      expect(_key('rksv-relogin'), findsNothing);
      expect(t.getSize(_key('rksv-credentials-again')).height, 56);
      await _tap(t, 'rksv-credentials-again');
      expect(_key('credentials'), findsOneWidget);
      expect(_key('credentials-user'), findsOneWidget);
      expect(_key('credentials-password'), findsOneWidget);
      expect(_key('credentials-saved'), findsNothing);
    });

    testWidgets('das Kennzeichen des Testsystems zählt in Betrieb nicht, das '
        'des echten nicht in der Online-Probe (Q4)', (t) async {
      final testRejected = MemoryRksvSecrets();
      await testRejected.writeAtrustRejected(true);
      await _settings(t, secrets: testRejected);
      await seedLive(t);
      expect(_key('rksv-rejected'), findsNothing);

      final liveRejected = MemoryRksvSecrets();
      await liveRejected.writeAtrustRejected(true, live: true);
      await _settings(t, secrets: liveRejected);
      await seedProbe(t, unit: RksvUnit.atrustTest);
      expect(_key('rksv-rejected'), findsNothing);

      final both = MemoryRksvSecrets();
      await both.writeAtrustRejected(true);
      await _settings(t, secrets: both);
      await seedProbe(t, unit: RksvUnit.atrustTest);
      expect(_key('rksv-relogin'), findsOneWidget);
      expect(_key('rksv-credentials-again'), findsNothing);
    });

    testWidgets('Review Focus 5: abgelehnt verkauft mit Vermerk ohne Anfrage, '
        'nach neuen Zugangsdaten genau eine Anmeldung und beim nächsten Bon '
        'der Sammelbeleg', (t) async {
      final fake = _fake();
      final secrets = MemoryRksvSecrets();
      await _settings(t, fake: fake, secrets: secrets);
      await goLiveInApp(t);
      expect((await _state(t)).mode, RksvMode.live);

      // Die Sitzung läuft ab, und A-Trust lehnt die Anmeldung ab.
      fake.expireSessions = true;
      fake.loginStatus = 403;
      await sellCash(t);
      await t.pumpAndSettle();
      expect(await secrets.atrustRejected(live: true), isTrue);
      expect(await secrets.atrustRejected(), isFalse);
      expect((await _state(t)).outage, isTrue);

      // Weiterer Verkauf: mit Vermerk, keine Anfrage.
      final before = fake.requests.length;
      await sellCash(t);
      await t.pumpAndSettle();
      expect(fake.requests, hasLength(before));
      expect((await _entries(t)).map((e) => (e.kind, e.damaged)), [
        ('start', false),
        ('sale', true),
        ('sale', true),
      ]);

      // Der Chef gibt neue Zugangsdaten ein.
      expect(_key('rksv-rejected'), findsOneWidget);
      await _tap(t, 'rksv-credentials-again');
      fake.loginStatus = 200;
      fake.password = 'geheim-neu';
      final logins = _logins(fake);
      await t.enterText(
        find.descendant(
          of: _key('credentials-user'),
          matching: find.byType(TextField),
        ),
        'u-beispiel',
      );
      await t.enterText(
        find.descendant(
          of: _key('credentials-password'),
          matching: find.byType(TextField),
        ),
        'geheim-neu',
      );
      await t.pump();
      await _tap(t, 'credentials-save');
      expect(await secrets.atrustRejected(live: true), isFalse);

      await sellCash(t);
      await t.pumpAndSettle();
      expect(_logins(fake), logins + 1);
      expect((await _state(t)).outage, isFalse);
      expect((await _entries(t)).map((e) => (e.kind, e.damaged)), [
        ('start', false),
        ('sale', true),
        ('sale', true),
        ('collective', false),
        ('sale', false),
      ]);
    });
  });

  group('Außer Betrieb nehmen', () {
    testWidgets('fragt nach, "Abbrechen" ändert nichts', (t) async {
      final fake = _fake();
      await _settings(t, fake: fake, printer: true);
      await goLiveInApp(t);
      final requests = fake.requests.length;
      await _tap(t, 'rksv-decommission');
      expect(_key('rksv-question'), findsOneWidget);
      expect(find.text('Kassa außer Betrieb nehmen?'), findsOneWidget);
      expect(find.text(_question), findsOneWidget);
      expect(
        find.descendant(
          of: _key('rksv-question-confirm'),
          matching: find.text('Außer Betrieb nehmen'),
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
      await _tap(t, 'rksv-question-cancel');
      expect(_key('rksv-question'), findsNothing);
      expect(await _kinds(t), ['start']);
      expect((await _state(t)).mode, RksvMode.live);
      expect(printerOf(t).printed, isEmpty);
      expect(fake.requests, hasLength(requests));
    });

    testWidgets('Bestätigen: genau ein Schlussbeleg (Doppeltipp), gedruckt, '
        'danach "Außer Betrieb" mit den Aufgaben, "Protokoll ausgeben" und '
        'den Zeilen von "Nicht eingerichtet"', (t) async {
      await _settings(t, printer: true);
      await goLiveInApp(t);
      await _tap(t, 'rksv-decommission');
      await t.tap(_key('rksv-question-confirm'));
      await t.tap(_key('rksv-question-confirm'), warnIfMissed: false);
      await t.pumpAndSettle();

      expect(await _kinds(t), ['start', 'closing']);
      final closing =
          (await queryRows(
                t,
                "SELECT id FROM receipts WHERE kind = 'closing'",
              )).single['id']!
              as String;
      expect(printerOf(t).printed, [closing]);
      final state = await _state(t);
      expect(state.mode, RksvMode.off);
      expect(state.decommissioned, isTrue);

      expect(_inCard(find.text('Außer Betrieb')), findsOneWidget);
      expect(_inCard(find.text(_offHelp)), findsOneWidget);
      expect(_inCard(find.text(_practice)), findsNothing);
      expect(
        _inCard(
          find.text(
            'Außerbetriebnahme bei FinanzOnline melden, bis 24.11.2026. '
            'Grund: 6, planmäßige Außerbetriebnahme.',
          ),
        ),
        findsOneWidget,
      );
      expect(_rowsInOrder(t), [
        'rksv-task-done-register-finanzonline-1',
        'rksv-task-done-check-start-1',
        'rksv-task-done-report-decommission-1',
        'rksv-task-done-backup-decommission-1',
        'rksv-export',
        'rksv-probe-on',
        'rksv-online-probe-on',
        'rksv-setup',
        'open-card-check',
      ]);
      expect(_key('rksv-decommission'), findsNothing);
      expect(_key('rksv-credentials'), findsNothing);
      expect(_key('rksv-zero'), findsNothing);
      expect(_key('rksv-message'), findsNothing);
    });

    testWidgets('scheitert der Druck, bleibt die Kassa außer Betrieb', (
      t,
    ) async {
      await _settings(t, printer: true);
      await goLiveInApp(t);
      printerOf(t).next = const PrintOutcome.failed(PrintProblem.paperOut);
      await _tap(t, 'rksv-decommission');
      await _tap(t, 'rksv-question-confirm');
      expect(printerOf(t).printed, hasLength(1));
      expect((await _state(t)).decommissioned, isTrue);
      expect(_inCard(find.text('Außer Betrieb')), findsOneWidget);
    });

    testWidgets('scheitert die Außerbetriebnahme: der Satz unter der Zeile, '
        'die Kassa bleibt in Betrieb', (t) async {
      await _settings(
        t,
        extra: [rksvServiceProvider.overrideWith(_GatedService.new)],
      );
      await seedLive(t);
      final service = _gatedOf(t)
        ..failure = const RksvProblem('Die Signatur hat nicht geantwortet.')
        ..gate.complete();
      await _tap(t, 'rksv-decommission');
      await _tap(t, 'rksv-question-confirm');
      expect(service.calls, 1);
      expect(
        find.descendant(
          of: _key('rksv-message'),
          matching: find.text('Die Signatur hat nicht geantwortet.'),
        ),
        findsOneWidget,
      );
      // Unter der Zeile "Kassa außer Betrieb nehmen".
      expect(
        t.getTopLeft(_key('rksv-message')).dy,
        greaterThan(t.getTopLeft(_key('rksv-decommission')).dy),
      );
      expect((await _state(t)).mode, RksvMode.live);
      expect(_inCard(find.text('In Betrieb')), findsOneWidget);
    });

    for (final fails in [false, true]) {
      testWidgets('während der Außerbetriebnahme tun "Zurück", ein anderer '
          'Bereich, die Einstellungen-Taste und Abmelden nichts; danach geht '
          'alles wieder (${fails ? 'gescheitert' : 'geschafft'})', (t) async {
        await _settings(
          t,
          extra: [rksvServiceProvider.overrideWith(_GatedService.new)],
        );
        await seedLive(t);
        final service = _gatedOf(t);
        if (fails) service.failure = const RksvProblem('Kein Internet.');
        await _tap(t, 'rksv-decommission');
        await t.tap(_key('rksv-question-confirm'));
        await t.pumpAndSettle();
        expect(service.calls, 1);
        expect(
          t.widget<PrimaryButton>(_key('rksv-decommission')).onPressed,
          isNull,
        );

        await t.binding.handlePopRoute();
        await t.pump();
        expect(_key('signature-card'), findsOneWidget);
        for (final key in ['tab-Kassa', 'tab-Bons', 'settings', 'staff']) {
          await t.tap(_key(key));
          await t.pump();
          expect(_key('signature-card'), findsOneWidget, reason: key);
        }
        expect(_key('area-kassa'), findsNothing);

        service.gate.complete();
        await t.pumpAndSettle();
        final state = await _state(t);
        expect(state.decommissioned, !fails);
        if (fails) {
          expect(find.text('Kein Internet.'), findsOneWidget);
        } else {
          expect(_inCard(find.text('Außer Betrieb')), findsOneWidget);
        }
        await t.binding.handlePopRoute();
        await t.pumpAndSettle();
        expect(_key('signature-card'), findsNothing);
        await _tap(t, 'tab-Bons');
        expect(_key('area-bons'), findsOneWidget);
      });
    }
  });
  group('Schlüssel nicht lesbar (Schlussprüfung C1)', () {
    const keyUnreadable =
        'Das Tablet konnte den Schlüssel nicht lesen. Bitte nichts löschen '
        'und die App nicht neu installieren.';

    for (final zero in [false, true]) {
      testWidgets('${zero ? 'Nullbeleg' : 'Außer Betrieb nehmen'}: der Satz '
          'unter der Zeile, die Kassa bleibt in Betrieb', (t) async {
        final secrets = MemoryRksvSecrets();
        await _settings(t, secrets: secrets, printer: true);
        await seedLive(t);
        secrets.failReads = true;
        if (zero) {
          await _tap(t, 'rksv-zero');
        } else {
          await _tap(t, 'rksv-decommission');
          await _tap(t, 'rksv-question-confirm');
        }
        expect(
          find.descendant(
            of: _key('rksv-message'),
            matching: find.text(keyUnreadable),
          ),
          findsOneWidget,
        );
        expect(find.text(staleSettingsSentence), findsNothing);
        final row = zero ? 'rksv-zero' : 'rksv-decommission';
        expect(
          t.getTopLeft(_key('rksv-message')).dy,
          greaterThan(t.getTopLeft(_key(row)).dy),
        );
        secrets.failReads = false;
        final state = await _state(t);
        expect((state.mode, state.chain), (RksvMode.live, 1));
        expect(await _kinds(t), isEmpty);
        expect(printerOf(t).printed, isEmpty);
        expect(_inCard(find.text('In Betrieb')), findsOneWidget);
      });
    }
  });

  testWidgets('Schlussprüfung: läuft eine Probe nach der Außerbetriebnahme, '
      'steht "zum Üben" nicht über den Aufgaben der echten Kette; erst wenn '
      'nur noch Aufgaben der Probe da sind', (t) async {
    await _settings(t, printer: true);
    await goLiveInApp(t);
    final c = containerOf(t);
    final chef = c.read(sessionProvider)!;
    await c.read(rksvServiceProvider).decommission(staff: chef);
    await c.read(rksvServiceProvider).enableProbe(staff: chef);
    await t.pumpAndSettle();
    final state = await _state(t);
    expect(state.mode, RksvMode.probe);
    final ids = [for (final task in state.tasks) task.id];
    expect(ids, contains('report-decommission-1'));
    expect(ids, contains('backup-decommission-1'));
    expect(_inCard(find.text('Zu erledigen')), findsOneWidget);
    expect(_inCard(find.text(_practice)), findsNothing);

    // Die Aufgaben der echten Kette erledigt: nur noch die der Probe.
    for (final id in ids) {
      if (id.endsWith('-1')) await _tap(t, 'rksv-task-done-$id');
    }
    final rest = (await _state(t)).tasks;
    expect(rest, isNotEmpty);
    expect(rest.every((task) => !task.id.endsWith('-1')), isTrue);
    expect(_inCard(find.text(_practice)), findsOneWidget);
  });
}
