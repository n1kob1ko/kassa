// "Angaben für FinanzOnline" und "Jetzt in Betrieb nehmen" (Plan Task 6),
// gegen den nachgebauten Dienst von A-Trust am echten System. Zugangsdaten,
// Kassen-Kennung und AES-Schlüssel sind erfunden.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/data/providers.dart';
import 'package:kassa/devices/printer.dart';
import 'package:kassa/domain/business_info.dart';
import 'package:kassa/domain/print_document.dart';
import 'package:kassa/domain/receipt_layout.dart';
import 'package:kassa/features/login/session.dart';
import 'package:kassa/features/shell/shell_screen.dart';
import 'package:kassa/rksv/online/atrust_client.dart';
import 'package:kassa/rksv/online/online_providers.dart';
import 'package:kassa/rksv/rksv_providers.dart';
import 'package:kassa/rksv/rksv_secrets.dart';
import 'package:kassa/rksv/rksv_state.dart';
import 'package:kassa/rksv/setup_facts.dart';
import 'package:kassa/ui/primary_button.dart';
import 'package:kassa/ui/tokens.dart';
import 'package:material_ui/material_ui.dart';

import '../support/cash_pump.dart' show queryRows, setUpPrinter;
import '../support/fake_atrust.dart';
import '../support/kassa_pump.dart' show containerOf;
import '../support/pump.dart' show printerOf;
import '../support/settings_pump.dart';
import '../support/signature_pump.dart';

const _user = 'u-beispiel';
const _password = 'geheim-beispiel';
const _cashBoxId = 'R4TW9KD2PX';

/// 32 erfundene Bytes für den AES-Schlüssel.
final _aesKey = Uint8List.fromList(List.generate(32, (i) => 7 * i + 3));

const _intro =
    'Diese Angaben trägst du bei FinanzOnline ein, wenn du die '
    'Signatureinheit und die Kassa anmeldest.';
const _question =
    'Das lässt sich nicht zurücknehmen. Ab jetzt ist jeder Bon ein echter Bon '
    'für das Finanzamt.';
const _probeEnds = 'Die laufende Probe endet mit einem Schlussbeleg.';
const _done = 'Die Kassa ist in Betrieb.';

Finder _key(String key) => find.byKey(Key(key));

Future<void> _tap(WidgetTester t, String key) async {
  await t.ensureVisible(_key(key));
  await t.pumpAndSettle();
  await t.tap(_key(key));
  await t.pumpAndSettle();
}

/// Ein A-Trust, dessen Zertifikat heute gilt.
FakeAtrust _fake() => FakeAtrust(validFrom: DateTime.utc(2024, 1, 1));

/// Ein geschützter Speicher, dessen PendingSetup sich nicht lesen lässt,
/// solange [failSetupReads] gilt (Zugangsdaten bleiben lesbar).
class _Secrets extends MemoryRksvSecrets {
  bool failSetupReads = false;

  @override
  Future<PendingSetup?> pendingSetup() async {
    if (failSetupReads) {
      throw StateError('Der sichere Speicher ist nicht lesbar.');
    }
    return super.pendingSetup();
  }
}

/// Speicher mit gespeicherten Zugangsdaten und, mit [pending], einem
/// PendingSetup mit [_cashBoxId] und [_aesKey].
Future<_Secrets> _secrets({bool pending = true}) async {
  final s = _Secrets();
  await s.writeAtrustCredentials(const AtrustCredentials(_user, _password));
  if (pending) {
    await s.writePendingSetup(
      PendingSetup(cashBoxId: _cashBoxId, aesKey: _aesKey),
    );
  }
  return s;
}

/// Einstellungen als Chef mit [fake] und [secrets], mit [printer] ein
/// eingerichteter Drucker, mit [probe] eine laufende Probe-Signatur.
Future<void> _settings(
  WidgetTester t, {
  required FakeAtrust fake,
  required MemoryRksvSecrets secrets,
  bool printer = true,
  bool probe = false,
  double textScale = 1.0,
}) async {
  await pumpSettings(
    t,
    textScale: textScale,
    extra: onlineOverrides(fake, secrets: secrets),
  );
  if (printer) await setUpPrinter(t);
  if (probe) {
    final c = containerOf(t);
    await c
        .read(rksvServiceProvider)
        .enableProbe(staff: c.read(sessionProvider)!);
    await t.pumpAndSettle();
  }
}

/// Von den gespeicherten Zugangsdaten über "Weiter" und "Verbindung prüfen"
/// bis "Angaben für FinanzOnline".
Future<void> _toFacts(WidgetTester t) async {
  openCredentials(t.element(_key('area-settings')));
  await t.pumpAndSettle();
  await _tap(t, 'credentials-continue');
  expect(_key('connection-check'), findsOneWidget);
  await _tap(t, 'connection-continue');
  expect(_key('setup-facts'), findsOneWidget);
}

Future<({FakeAtrust fake, _Secrets secrets})> _open(
  WidgetTester t, {
  bool pending = true,
  bool printer = true,
  bool probe = false,
  double textScale = 1.0,
}) async {
  final fake = _fake();
  final secrets = await _secrets(pending: pending);
  await _settings(
    t,
    fake: fake,
    secrets: secrets,
    printer: printer,
    probe: probe,
    textScale: textScale,
  );
  await _toFacts(t);
  return (fake: fake, secrets: secrets);
}

/// Die Angaben, die zu [_cashBoxId], [_aesKey] und den Angaben der Prüfung
/// am echten System gehören.
SetupFacts _expected(WidgetTester t) {
  final facts = containerOf(t)
      .read(connectionCheckProvider(AtrustSystem.live))
      .state
      .value
      .facts!;
  return setupFactsOf(
    zdaId: facts.zdaId,
    certSerialHex: facts.certificate.serialHex,
    cashBoxId: _cashBoxId,
    aesKey: _aesKey,
  );
}

String _value(WidgetTester t, String key) => t
    .widget<Text>(
      find.descendant(of: _key(key), matching: find.byType(Text)).first,
    )
    .data!;

List<String> _aesLines(WidgetTester t) => [
  for (final e
      in find
          .descendant(of: _key('setup-value-aes'), matching: find.byType(Text))
          .evaluate())
    (e.widget as Text).data!,
];

PrimaryButton _button(WidgetTester t, String key) => t.widget<PrimaryButton>(
  find.descendant(of: _key(key), matching: find.byType(PrimaryButton)),
);

Future<List<String>> _kinds(WidgetTester t) async => [
  for (final r in await queryRows(
    t,
    "SELECT kind FROM receipts WHERE kind != 'sale' ORDER BY number",
  ))
    r['kind']! as String,
];

Future<List<String>> _liveChains(WidgetTester t) async => [
  for (final r in await queryRows(
    t,
    "SELECT cash_box_id FROM rksv_chains WHERE mode = 'live'",
  ))
    r['cash_box_id']! as String,
];

Future<RksvState> _state(WidgetTester t) =>
    containerOf(t).read(rksvRepositoryProvider).current();

/// Startet nach der Nachfrage die Inbetriebnahme, während A-Trust jede
/// Antwort eine Sekunde verzögert; die Inbetriebnahme läuft danach noch.
Future<void> _startDelayed(WidgetTester t, FakeAtrust fake) async {
  await _tap(t, 'setup-go-live');
  fake.delay = const Duration(seconds: 1);
  await t.tap(_key('go-live-confirm'));
  await t.pump();
  await t.pump(const Duration(milliseconds: 300));
  expect(_button(t, 'setup-go-live').leading, isNotNull);
}

/// Lässt die verzögerte Inbetriebnahme zu Ende laufen.
Future<void> _finish(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(seconds: 1));
  }
  await t.pumpAndSettle();
}

void main() {
  testWidgets('zeigt Titel, Satz, die sechs Angaben aus SetupFacts und '
      '"Bevor du startest"', (t) async {
    await _open(t);
    final facts = _expected(t);
    expect(find.text('Angaben für FinanzOnline'), findsOneWidget);
    expect(find.text(_intro), findsOneWidget);
    for (final name in [
      'Art der Sicherheitseinrichtung',
      'Anbieter',
      'Seriennummer des Zertifikats',
      'Kassenidentifikationsnummer',
      'AES-Schlüssel',
      'Prüfwert',
    ]) {
      expect(find.text(name), findsOneWidget, reason: name);
    }
    expect(_value(t, 'setup-value-kind'), setupKind);
    expect(_value(t, 'setup-value-provider'), facts.provider);
    expect(_value(t, 'setup-value-serial'), facts.certSerialHex);
    expect(find.text('dezimal ${facts.certSerialDecimal}'), findsOneWidget);
    expect(_value(t, 'setup-value-cashbox'), _cashBoxId);
    expect(_aesLines(t), [
      facts.aesKeyBase64.substring(0, 22),
      facts.aesKeyBase64.substring(22),
    ]);
    expect(_value(t, 'setup-value-checksum'), facts.aesChecksum);
    // Die Werte in Ziffern-Schrift mit gleich breiten Zeichen.
    final style = t
        .widget<Text>(
          find
              .descendant(
                of: _key('setup-value-cashbox'),
                matching: find.byType(Text),
              )
              .first,
        )
        .style!;
    expect(style.fontFamily, KassaTokens.monoFontFamily);
    final aesStyle = t
        .widget<Text>(
          find
              .descendant(
                of: _key('setup-value-aes'),
                matching: find.byType(Text),
              )
              .first,
        )
        .style!;
    expect(aesStyle.fontFamily, KassaTokens.monoFontFamily);
    // Die Art der Sicherheitseinrichtung ist Text, keine Kennung.
    expect(
      t
          .widget<Text>(
            find
                .descendant(
                  of: _key('setup-value-kind'),
                  matching: find.byType(Text),
                )
                .first,
          )
          .style!
          .fontFamily,
      isNot(KassaTokens.monoFontFamily),
    );

    expect(find.text('Bevor du startest'), findsOneWidget);
    for (final step in [
      'An der alten Kassa den Schlussbeleg erstellen und sie bei FinanzOnline '
          'abmelden.',
      'Signatureinheit und Kassa bei FinanzOnline anmelden, spätestens eine '
          'Woche nach dem Start.',
      'Den Startbeleg mit der App "BMF Belegcheck" prüfen und den Ausdruck '
          'aufheben.',
    ]) {
      expect(find.text(step), findsOneWidget, reason: step);
    }
    expect(
      find.descendant(
        of: _key('setup-print'),
        matching: find.text('Angaben drucken'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: _key('setup-go-live'),
        matching: find.text('Jetzt in Betrieb nehmen'),
      ),
      findsOneWidget,
    );
    expect(_button(t, 'setup-go-live').onPressed, isNotNull);
    expect(t.takeException(), isNull);
  });

  testWidgets('große Schrift: nichts läuft über, jede Zeile des Schlüssels '
      'bleibt eine Zeile', (t) async {
    await _open(t, textScale: 1.3);
    expect(t.takeException(), isNull);
    final lines = find.descendant(
      of: _key('setup-value-aes'),
      matching: find.byType(Text),
    );
    final single = t.getSize(
      find
          .descendant(
            of: _key('setup-value-cashbox'),
            matching: find.byType(Text),
          )
          .first,
    );
    for (final e in lines.evaluate()) {
      expect(
        t.getSize(find.byWidget(e.widget)).height,
        single.height,
        reason: (e.widget as Text).data,
      );
    }
  });

  testWidgets('ohne PendingSetup: neue Werte, im geschützten Speicher, und '
      'zweimal öffnen zeigt dieselben', (t) async {
    final (fake: _, :secrets) = await _open(t, pending: false);
    final stored = (await secrets.pendingSetup())!;
    final cashBox = _value(t, 'setup-value-cashbox');
    final aes = _aesLines(t);
    expect(cashBox, stored.cashBoxId);
    expect(aes.join(), base64.encode(stored.aesKey));
    expect(aes.map((l) => l.length), [22, 22]);
    expect((await _state(t)).mode, RksvMode.off);

    // "Zurück" des Tablets: zu den Zugangsdaten (nicht zur Prüfung, die sonst
    // noch einmal liefe), dann zu den Einstellungen.
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(_key('setup-facts'), findsNothing);
    expect(_key('connection-check'), findsNothing);
    expect(_key('credentials-saved'), findsOneWidget);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(_key('credentials'), findsNothing);
    expect(_key('signature-card'), findsOneWidget);

    await _toFacts(t);
    expect(_value(t, 'setup-value-cashbox'), cashBox);
    expect(_aesLines(t), aes);
    expect((await secrets.pendingSetup())!.cashBoxId, stored.cashBoxId);

    // "Zurück" am Bildschirm führt ebenso zu den Zugangsdaten.
    await _tap(t, 'setup-facts-back');
    expect(_key('credentials-saved'), findsOneWidget);
  });

  testWidgets('"Angaben drucken" schickt den Zettel mit allen Werten an den '
      'Drucker, der Schlüssel in zwei Zeilen', (t) async {
    await _open(t);
    final facts = _expected(t);
    await _tap(t, 'setup-print');
    final printer = printerOf(t);
    expect(printer.log, ['setup']);
    final slip = printer.setupSlips.single;
    expect(slip.kind, facts.kind);
    expect(slip.provider, facts.provider);
    expect(slip.certSerialHex, facts.certSerialHex);
    expect(slip.certSerialDecimal, facts.certSerialDecimal);
    expect(slip.cashBoxId, facts.cashBoxId);
    expect(slip.aesKeyBase64, facts.aesKeyBase64);
    expect(slip.aesChecksum, facts.aesChecksum);

    final lines = [
      for (final o in layoutSetupFacts(
        slip,
        const BusinessInfo(name: 'Beispiel-Imbiss'),
        DateTime(2026, 11, 17, 11),
      ))
        if (o is PrintText) o.text,
    ];
    final key = lines.indexOf('AES-Schlüssel');
    expect(lines.sublist(key + 1, key + 3), [
      facts.aesKeyBase64.substring(0, 22),
      facts.aesKeyBase64.substring(22),
    ]);
    expect(lines, contains(facts.certSerialHex));
    expect(lines, contains('dezimal ${facts.certSerialDecimal}'));
    expect(_key('setup-print-problem'), findsNothing);
  });

  testWidgets('"Angaben drucken" ohne Drucker oder mit Fehler: der Satz des '
      'Druckers', (t) async {
    await _open(t, printer: false);
    await _tap(t, 'setup-print');
    expect(printerOf(t).log, isEmpty);
    expect(
      find.descendant(
        of: _key('setup-print-problem'),
        matching: find.text('Kein Bondrucker eingerichtet.'),
      ),
      findsOneWidget,
    );

    await setUpPrinter(t);
    printerOf(t).next = const PrintOutcome.failed(PrintProblem.paperOut);
    await _tap(t, 'setup-print');
    expect(
      find.descendant(
        of: _key('setup-print-problem'),
        matching: find.text('Drucker nicht bereit. Das Papier ist leer.'),
      ),
      findsOneWidget,
    );
    expect(find.text('Kein Bondrucker eingerichtet.'), findsNothing);
  });

  testWidgets('"Jetzt in Betrieb nehmen" fragt nach, "Abbrechen" ändert '
      'nichts', (t) async {
    final (:fake, secrets: _) = await _open(t);
    final signs = fake.signBodies.length;
    await _tap(t, 'setup-go-live');
    expect(find.text('Jetzt in Betrieb nehmen?'), findsOneWidget);
    expect(find.text(_question), findsOneWidget);
    expect(find.textContaining(_probeEnds), findsNothing);
    expect(
      find.descendant(
        of: _key('go-live-confirm'),
        matching: find.text('In Betrieb nehmen'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: _key('go-live-cancel'),
        matching: find.text('Abbrechen'),
      ),
      findsOneWidget,
    );
    await _tap(t, 'go-live-cancel');
    expect(find.text('Jetzt in Betrieb nehmen?'), findsNothing);
    expect(_key('setup-facts'), findsOneWidget);
    expect((await _state(t)).mode, RksvMode.off);
    expect(await _liveChains(t), isEmpty);
    expect(await _kinds(t), isEmpty);
    expect(fake.signBodies, hasLength(signs));
    expect(printerOf(t).printed, isEmpty);
  });

  testWidgets('"In Betrieb nehmen": goLive genau einmal (Doppeltipp), '
      'Startbeleg gedruckt, zurück in die Einstellungen mit der Meldung', (
    t,
  ) async {
    final (:fake, :secrets) = await _open(t);
    final signs = fake.signBodies.length;

    // Doppeltipp auf die Haupttaste öffnet eine Nachfrage.
    await t.tap(_key('setup-go-live'));
    await t.pump();
    await t.tap(_key('setup-go-live'), warnIfMissed: false);
    await t.pumpAndSettle();
    expect(_key('go-live-question'), findsOneWidget);

    // Jede Antwort dauert eine Sekunde: Die Inbetriebnahme läuft sichtbar.
    fake.delay = const Duration(seconds: 1);
    await t.tap(_key('go-live-confirm'));
    await t.tap(_key('go-live-confirm'), warnIfMissed: false);
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    expect(_key('go-live-question'), findsNothing);
    expect(_key('setup-facts'), findsOneWidget);
    expect(_button(t, 'setup-go-live').onPressed, isNull);
    expect(_button(t, 'setup-print').onPressed, isNull);
    expect(_button(t, 'setup-go-live').leading, isNotNull);
    await t.tap(_key('setup-go-live'), warnIfMissed: false);
    await t.pump();
    expect(_key('go-live-question'), findsNothing);

    for (var i = 0; i < 6; i++) {
      await t.pump(const Duration(seconds: 1));
    }
    await t.pumpAndSettle();

    expect(fake.signBodies, hasLength(signs + 1));
    expect(await _liveChains(t), [_cashBoxId]);
    expect(await _kinds(t), ['start']);
    expect((await _state(t)).mode, RksvMode.live);
    expect(await secrets.pendingSetup(), isNull);
    final start =
        (await queryRows(
              t,
              "SELECT id FROM receipts WHERE kind = 'start'",
            )).single['id']!
            as String;
    expect(printerOf(t).printed, [start]);

    // Der ganze Weg ist zu, die Einstellungen zeigen die Meldung.
    expect(_key('setup-facts'), findsNothing);
    expect(_key('credentials'), findsNothing);
    expect(_key('connection-check'), findsNothing);
    expect(
      find.descendant(
        of: _key('signature-card'),
        matching: find.text('In Betrieb'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: _key('rksv-message'), matching: find.text(_done)),
      findsOneWidget,
    );

    // Die Meldung gilt nur bis zur nächsten Seite.
    await _tap(t, 'open-card-check');
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(_key('signature-card'), findsOneWidget);
    expect(find.text(_done), findsNothing);
  });

  testWidgets('scheitert der Druck des Startbelegs, bleibt die Kassa in '
      'Betrieb', (t) async {
    await _open(t);
    printerOf(t).next = const PrintOutcome.failed(PrintProblem.paperOut);
    await _tap(t, 'setup-go-live');
    await _tap(t, 'go-live-confirm');
    expect((await _state(t)).mode, RksvMode.live);
    expect(printerOf(t).printed, hasLength(1));
    expect(find.text(_done), findsOneWidget);
  });

  testWidgets('mit laufender Probe: der Zusatzsatz in der Nachfrage, und die '
      'Probe endet mit Schlussbeleg', (t) async {
    await _open(t, probe: true);
    await _tap(t, 'setup-go-live');
    expect(find.text('Jetzt in Betrieb nehmen?'), findsOneWidget);
    expect(find.textContaining(_question), findsOneWidget);
    expect(find.textContaining(_probeEnds), findsOneWidget);
    await _tap(t, 'go-live-confirm');
    expect(await _kinds(t), ['start', 'closing', 'start']);
    expect((await _state(t)).mode, RksvMode.live);
    expect(find.text(_done), findsOneWidget);
  });

  testWidgets('scheitert goLive: der Satz steht da, der Bildschirm bleibt '
      'offen, die Kassa ist nicht in Betrieb', (t) async {
    final (:fake, :secrets) = await _open(t);
    fake.wrongSignature = true;
    await _tap(t, 'setup-go-live');
    await _tap(t, 'go-live-confirm');
    expect(_key('setup-facts'), findsOneWidget);
    expect(
      find.descendant(
        of: _key('setup-go-live-problem'),
        matching: find.text(
          'Die Signatur von A-Trust passt nicht zum Zertifikat.',
        ),
      ),
      findsOneWidget,
    );
    expect((await _state(t)).mode, RksvMode.off);
    expect(await _liveChains(t), isEmpty);
    expect(await _kinds(t), isEmpty);
    expect(printerOf(t).printed, isEmpty);
    expect((await secrets.pendingSetup())!.cashBoxId, _cashBoxId);
    expect(_button(t, 'setup-go-live').onPressed, isNotNull);
    expect(find.text(_done), findsNothing);
  });

  testWidgets('lassen sich die Werte nicht lesen: der Satz, "Nochmal '
      'versuchen", und "Jetzt in Betrieb nehmen" bleibt gesperrt', (t) async {
    final fake = _fake();
    final secrets = await _secrets();
    await _settings(t, fake: fake, secrets: secrets);
    secrets.failSetupReads = true;
    await _toFacts(t);
    expect(
      find.descendant(
        of: _key('setup-facts-problem'),
        matching: find.text('Das Tablet konnte den Schlüssel nicht lesen.'),
      ),
      findsOneWidget,
    );
    expect(_key('setup-value-aes'), findsNothing);
    expect(_button(t, 'setup-go-live').onPressed, isNull);
    expect(_button(t, 'setup-print').onPressed, isNull);

    secrets.failSetupReads = false;
    await _tap(t, 'setup-facts-retry');
    expect(_key('setup-facts-problem'), findsNothing);
    expect(_value(t, 'setup-value-cashbox'), _cashBoxId);
    expect(_button(t, 'setup-go-live').onPressed, isNotNull);
  });

  testWidgets('der ganze Weg: Zugangsdaten, Verbindung prüfen, Angaben, In '
      'Betrieb', (t) async {
    final fake = _fake()..password = _password;
    final secrets = _Secrets();
    await _settings(t, fake: fake, secrets: secrets);
    openCredentials(t.element(_key('area-settings')));
    await t.pumpAndSettle();
    for (final (key, text) in [
      ('credentials-user', _user),
      ('credentials-password', _password),
    ]) {
      await t.enterText(
        find.descendant(of: _key(key), matching: find.byType(TextField)),
        text,
      );
    }
    await t.pump();
    await _tap(t, 'credentials-save');
    expect(_key('connection-check'), findsOneWidget);
    await _tap(t, 'connection-continue');
    expect(_key('setup-facts'), findsOneWidget);
    final cashBox = _value(t, 'setup-value-cashbox');
    final aes = _aesLines(t).join();
    await _tap(t, 'setup-go-live');
    await _tap(t, 'go-live-confirm');

    expect((await _state(t)).mode, RksvMode.live);
    expect(await _liveChains(t), [cashBox]);
    expect(await secrets.aesKey((await _state(t)).chain!), base64.decode(aes));
    expect(await _kinds(t), ['start']);
    expect(printerOf(t).printed, hasLength(1));
    expect(find.text(_done), findsOneWidget);
    // Genau eine Anmeldung: die beim Speichern; der Startbeleg nutzt ihre
    // Sitzung.
    expect(
      fake.requests.where((r) => r.startsWith('PUT /Session/')),
      hasLength(1),
    );
  });

  testWidgets('"Zurück" während der Inbetriebnahme tut nichts, danach steht '
      'die Meldung da', (t) async {
    final (:fake, secrets: _) = await _open(t);
    await _startDelayed(t, fake);
    await t.binding.handlePopRoute();
    await t.pump();
    expect(_key('setup-facts'), findsOneWidget);
    await t.tap(_key('setup-facts-back'), warnIfMissed: false);
    await t.pump();
    expect(_key('setup-facts'), findsOneWidget);
    expect(_key('credentials-saved'), findsNothing);

    await _finish(t);
    expect((await _state(t)).mode, RksvMode.live);
    expect(_key('setup-facts'), findsNothing);
    expect(
      find.descendant(of: _key('rksv-message'), matching: find.text(_done)),
      findsOneWidget,
    );
  });

  testWidgets('ein anderer Bereich, die Einstellungen-Taste oder Abmelden '
      'während der Inbetriebnahme tun nichts, das Ergebnis geht nicht '
      'verloren', (t) async {
    final (:fake, secrets: _) = await _open(t);
    await _startDelayed(t, fake);
    for (final key in ['tab-Kassa', 'tab-Bons', 'settings', 'staff']) {
      await t.tap(_key(key));
      await t.pump();
      expect(_key('setup-facts'), findsOneWidget, reason: key);
    }
    expect(_key('area-kassa'), findsNothing);

    await _finish(t);
    expect((await _state(t)).mode, RksvMode.live);
    expect(_key('area-settings'), findsOneWidget);
    expect(
      find.descendant(of: _key('rksv-message'), matching: find.text(_done)),
      findsOneWidget,
    );
    // Danach geht alles wieder.
    await _tap(t, 'tab-Kassa');
    expect(_key('area-kassa'), findsOneWidget);
  });

  testWidgets('scheitert die verzögerte Inbetriebnahme mit "Zurück" '
      'dazwischen, steht der Satz trotzdem da', (t) async {
    final (:fake, secrets: _) = await _open(t);
    fake.wrongSignature = true;
    await _startDelayed(t, fake);
    await t.binding.handlePopRoute();
    await t.pump();
    await _finish(t);
    expect(_key('setup-facts'), findsOneWidget);
    expect(
      find.descendant(
        of: _key('setup-go-live-problem'),
        matching: find.text(
          'Die Signatur von A-Trust passt nicht zum Zertifikat.',
        ),
      ),
      findsOneWidget,
    );
    expect((await _state(t)).mode, RksvMode.off);
    // Danach führt "Zurück" wieder zu den Zugangsdaten.
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(_key('credentials-saved'), findsOneWidget);
  });
}
