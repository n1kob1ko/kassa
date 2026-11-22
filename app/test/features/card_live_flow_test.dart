// "Signatur einrichten" mit der Wahl "Womit signiert die Kassa?", der Weg
// mit der Signaturkarte bis "In Betrieb" und "Kassen-ID ändern": gegen den
// nachgebauten Leser mit Karte über die Provider. Der Startbeleg wird mit dem
// echten Halter von der Karte signiert. Kassen-Kennung, AES-Schlüssel und PIN
// sind erfunden.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/data/providers.dart';
import 'package:kassa/domain/business_info.dart';
import 'package:kassa/domain/print_document.dart';
import 'package:kassa/domain/receipt.dart';
import 'package:kassa/domain/receipt_layout.dart';
import 'package:kassa/domain/staff.dart';
import 'package:kassa/features/shell/shell_screen.dart';
import 'package:kassa/rksv/card/card_facts.dart';
import 'package:kassa/rksv/card/card_providers.dart';
import 'package:kassa/rksv/card/card_signer.dart';
import 'package:kassa/rksv/card/certificate.dart';
import 'package:kassa/rksv/rksv_providers.dart';
import 'package:kassa/rksv/rksv_secrets.dart';
import 'package:kassa/rksv/rksv_service.dart';
import 'package:kassa/rksv/rksv_state.dart';
import 'package:kassa/rksv/setup_facts.dart';
import 'package:kassa/ui/pressable.dart';
import 'package:kassa/ui/primary_button.dart';
import 'package:material_ui/material_ui.dart';

import '../support/cash_pump.dart' show queryRows, setUpPrinter;
import '../support/fake_card_reader.dart';
import '../support/kassa_pump.dart' show containerOf;
import '../support/pump.dart' show printerOf, typePin;
import '../support/settings_pump.dart';
import '../support/signature_pump.dart';

const _cardNumber = '0102030405060708';
const _cashBoxId = 'R4TW9KD2PX';

/// 32 erfundene Bytes für den AES-Schlüssel.
final _aesKey = Uint8List.fromList(List.generate(32, (i) => 7 * i + 3));

const _choiceTitle = 'Womit signiert die Kassa?';
const _cardTitle = 'Signaturkarte am Kartenleser';
const _cardHelp = 'Ohne Internet. Die Karte muss immer im Leser stecken.';
const _onlineTitle = 'A-Trust online';
const _onlineHelp = 'Braucht Internet und die Zugangsdaten von A-Trust.';
const _introCard =
    'Diese Angaben trägst du bei FinanzOnline ein, wenn du die '
    'Signaturkarte und die Kassa anmeldest.';
const _introOnline =
    'Diese Angaben trägst du bei FinanzOnline ein, wenn du die '
    'Signatureinheit und die Kassa anmeldest.';
const _done = 'Die Kassa ist in Betrieb.';
const _stepCard =
    'Signaturkarte und Kassa bei FinanzOnline anmelden, spätestens eine '
    'Woche nach dem Start.';
const _stepOnline =
    'Signatureinheit und Kassa bei FinanzOnline anmelden, spätestens eine '
    'Woche nach dem Start.';
const _sheetTitle = 'Kassen-ID ändern';
const _sheetHelp = 'Buchstaben, Ziffern und Bindestrich, höchstens 20 Zeichen.';
const _hintRegistered =
    'Nimm keine Kennung, die bei FinanzOnline schon angemeldet ist.';
const _hintSlip = 'Ein schon gedruckter Zettel gilt danach nicht mehr.';
const _used = 'Diese Kassen-ID hat diese Kassa schon verwendet.';

Finder _key(String key) => find.byKey(Key(key));

Future<void> _tap(WidgetTester t, String key) async {
  await t.ensureVisible(_key(key));
  await t.pumpAndSettle();
  await t.tap(_key(key));
  await t.pumpAndSettle();
}

/// Ist die Taste mit [key] eingeschaltet?
bool _enabled(WidgetTester t, String key) =>
    t
        .widget<Pressable>(
          find
              .descendant(of: _key(key), matching: find.byType(Pressable))
              .first,
        )
        .onTap !=
    null;

PrimaryButton _button(WidgetTester t, String key) => t.widget<PrimaryButton>(
  find.descendant(of: _key(key), matching: find.byType(PrimaryButton)),
);

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

Future<RksvState> _state(WidgetTester t) =>
    containerOf(t).read(rksvRepositoryProvider).current();

Future<List<String>> _kinds(WidgetTester t) async => [
  for (final r in await queryRows(
    t,
    "SELECT kind FROM receipts WHERE kind != 'sale' ORDER BY number",
  ))
    r['kind']! as String,
];

String _serialOfTestCard() =>
    CardCertificate.parse(testSignatureCard().certificate).serial
        .toRadixString(16);

/// Die Angaben, die zur nachgebauten Karte, [_cashBoxId] und [_aesKey]
/// gehören.
SetupFacts _expected({String cashBoxId = _cashBoxId}) => setupFactsOf(
  kind: setupKindCard,
  zdaId: 'AT1',
  certSerialHex: _serialOfTestCard(),
  cashBoxId: cashBoxId,
  aesKey: _aesKey,
);

Future<void> _storePin(MemoryRksvSecrets secrets) => secrets.writeCardPin(
  CardPin(
    kind: testSignatureCard().profile.kind.name,
    numberHex: _cardNumber,
    pin: '123456',
  ),
);

/// Ruft [RksvService.goLiveWithCard] mit, zählt die Aufrufe und schreibt sie
/// in [events].
class _CountingService extends RksvService {
  _CountingService(
    super.db,
    super.secrets,
    super.receipts,
    super.clock,
    this.events,
  );

  final List<String> events;
  int goLiveCalls = 0;

  @override
  Future<Receipt> goLiveWithCard({
    required Staff staff,
    required CardFacts facts,
  }) {
    goLiveCalls++;
    events.add('goLiveWithCard');
    return super.goLiveWithCard(staff: staff, facts: facts);
  }
}

/// Der echte Halter, der jedes [warmUp] in [events] schreibt; mit [hold]
/// endet ein Aufwärmen mit `ask` erst, wenn der Test es freigibt.
class _RecordingSigner extends CardSigner {
  _RecordingSigner({
    required super.transport,
    required super.secrets,
    required super.guard,
    required this.events,
    this.hold,
  });

  final List<String> events;
  final Completer<void>? hold;

  @override
  Future<void> warmUp({bool ask = false}) async {
    events.add('warmUp(ask: $ask)');
    if (ask && hold != null) await hold!.future;
    return super.warmUp(ask: ask);
  }
}

typedef _Rig = ({
  FakeCardReader reader,
  MemoryRksvSecrets secrets,
  List<String> events,
  _CountingService Function() service,
});

/// Einstellungen als Chef mit der nachgebauten Karte im Leser, einem
/// PendingSetup ([pending]) und, mit [storedPin], der gespeicherten PIN.
Future<_Rig> _settings(
  WidgetTester t, {
  bool pending = true,
  bool storedPin = true,
  bool printer = true,
  Completer<void>? holdWarmUp,
  List<Override> extra = const [],
}) async {
  final reader = FakeCardReader(card: testSignatureCard());
  final secrets = MemoryRksvSecrets();
  if (pending) {
    await secrets.writePendingSetup(
      PendingSetup(cashBoxId: _cashBoxId, aesKey: _aesKey),
    );
  }
  if (storedPin) await _storePin(secrets);
  final events = <String>[];
  late _CountingService service;
  await pumpSettings(
    t,
    reader: reader,
    extra: [
      ...signatureOverrides(secrets: secrets),
      rksvServiceProvider.overrideWith(
        (ref) => service = _CountingService(
          ref.watch(databaseProvider),
          ref.watch(rksvSecretsProvider),
          ref.watch(receiptRepositoryProvider),
          ref.watch(clockProvider),
          events,
        ),
      ),
      cardSignerProvider.overrideWith((ref) {
        final signer = _RecordingSigner(
          transport: ref.watch(readerTransportProvider),
          secrets: ref.watch(rksvSecretsProvider),
          guard: ref.watch(pinGuardProvider),
          events: events,
          hold: holdWarmUp,
        );
        ref.onDispose(() => unawaited(signer.release()));
        return signer;
      }),
      ...extra,
    ],
  );
  if (printer) await setUpPrinter(t);
  return (
    reader: reader,
    secrets: secrets,
    events: events,
    service: () => service,
  );
}

/// Von den Einstellungen über die Wahl und "Karte und PIN" (gespeicherte
/// PIN) bis "Angaben für FinanzOnline".
Future<void> _toCardFacts(WidgetTester t) async {
  await _tap(t, 'rksv-setup');
  await _tap(t, 'signer-choice-card');
  expect(_key('card-setup'), findsOneWidget);
  expect(_enabled(t, 'card-setup-main'), isTrue);
  await _tap(t, 'card-setup-main');
  expect(_key('setup-facts'), findsOneWidget);
}

/// Das Feld des Blatts "Kassen-ID ändern".
Finder get _field => find.descendant(
  of: _key('cash-box-id-field'),
  matching: find.byType(TextField),
);

String _fieldText(WidgetTester t) =>
    t.widget<TextField>(_field).controller!.text;

void main() {
  group('Wahl "Womit signiert die Kassa?"', () {
    testWidgets('"Signatur einrichten" öffnet die Wahl mit zwei großen '
        'Flächen', (t) async {
      await _settings(t);
      await _tap(t, 'rksv-setup');
      expect(_key('signer-choice'), findsOneWidget);
      expect(_key('signature-card'), findsNothing);
      expect(find.text(_choiceTitle), findsOneWidget);
      for (final (key, title, help) in [
        ('signer-choice-card', _cardTitle, _cardHelp),
        ('signer-choice-online', _onlineTitle, _onlineHelp),
      ]) {
        expect(
          find.descendant(of: _key(key), matching: find.text(title)),
          findsOneWidget,
          reason: key,
        );
        expect(
          find.descendant(of: _key(key), matching: find.text(help)),
          findsOneWidget,
          reason: key,
        );
        final size = t.getSize(_key(key));
        expect(size.height, 160, reason: key);
        expect(size.width, greaterThanOrEqualTo(300), reason: key);
      }
      // Die Karte zuerst, links.
      expect(
        t.getTopLeft(_key('signer-choice-card')).dx,
        lessThan(t.getTopLeft(_key('signer-choice-online')).dx),
      );
      expect(
        t.getSize(_key('signer-choice-back')).height,
        greaterThanOrEqualTo(48),
      );
      expect(t.takeException(), isNull);
    });

    testWidgets('Zurück (Taste und Geste) führt zu den Einstellungen', (
      t,
    ) async {
      await _settings(t);
      await _tap(t, 'rksv-setup');
      await _tap(t, 'signer-choice-back');
      expect(_key('signer-choice'), findsNothing);
      expect(_key('signature-card'), findsOneWidget);

      await _tap(t, 'rksv-setup');
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(_key('signer-choice'), findsNothing);
      expect(_key('signature-card'), findsOneWidget);
    });

    testWidgets('"A-Trust online" führt in den Ablauf ab "Zugangsdaten von '
        'A-Trust"', (t) async {
      await _settings(t);
      await _tap(t, 'rksv-setup');
      await _tap(t, 'signer-choice-online');
      expect(_key('signer-choice'), findsNothing);
      expect(_key('credentials'), findsOneWidget);
      expect(find.text('Zugangsdaten von A-Trust'), findsWidgets);
    });

    testWidgets('Zurück (Taste und Geste) aus den Zugangsdaten führt zur '
        'Wahl, wenn sie von dort geöffnet wurden; sonst wie bisher', (t) async {
      await _settings(t);
      await _tap(t, 'rksv-setup');
      await _tap(t, 'signer-choice-online');
      await _tap(t, 'credentials-back');
      expect(_key('credentials'), findsNothing);
      expect(_key('signer-choice'), findsOneWidget);

      await _tap(t, 'signer-choice-online');
      expect(_key('credentials'), findsOneWidget);
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(_key('credentials'), findsNothing);
      expect(_key('signer-choice'), findsOneWidget);
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(_key('signer-choice'), findsNothing);
      expect(_key('signature-card'), findsOneWidget);

      // Von anderswo geöffnet: zurück in die Einstellungen.
      openCredentials(t.element(_key('area-settings')));
      await t.pumpAndSettle();
      await _tap(t, 'credentials-back');
      expect(_key('signer-choice'), findsNothing);
      expect(_key('signature-card'), findsOneWidget);
      openCredentials(t.element(_key('area-settings')));
      await t.pumpAndSettle();
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(_key('signer-choice'), findsNothing);
      expect(_key('signature-card'), findsOneWidget);
    });

    testWidgets('"Signaturkarte am Kartenleser" öffnet "Karte und PIN" mit '
        '"Weiter"; Zurück (Taste und Geste) führt zur Wahl', (t) async {
      await _settings(t);
      await _tap(t, 'rksv-setup');
      await _tap(t, 'signer-choice-card');
      expect(_key('card-setup'), findsOneWidget);
      expect(
        find.descendant(
          of: _key('card-setup-main'),
          matching: find.text('Weiter'),
        ),
        findsOneWidget,
      );
      await _tap(t, 'card-setup-back');
      expect(_key('card-setup'), findsNothing);
      expect(_key('signer-choice'), findsOneWidget);

      await _tap(t, 'signer-choice-card');
      expect(_key('card-setup'), findsOneWidget);
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(_key('card-setup'), findsNothing);
      expect(_key('signer-choice'), findsOneWidget);
      expect((await _state(t)).mode, RksvMode.off);
    });
  });

  group('der Weg mit der Karte', () {
    testWidgets('Wahl, Karte und PIN, Angaben mit Karte, Angaben drucken, '
        'Frage, In Betrieb mit Einheit card, Startbeleg von der Karte', (
      t,
    ) async {
      final rig = await _settings(t, storedPin: false);
      final card = rig.reader.card!;
      await _tap(t, 'rksv-setup');
      await _tap(t, 'signer-choice-card');
      expect(_enabled(t, 'card-setup-main'), isFalse);
      await _tap(t, 'card-check-pin');
      expect(_key('card-pin-sheet'), findsOneWidget);
      await typePin(t, '123456');
      await t.tap(_key('card-pin-submit'));
      await t.pumpAndSettle();
      expect(_enabled(t, 'card-setup-main'), isTrue);
      await _tap(t, 'card-setup-main');

      // Angaben für FinanzOnline mit der Karte: sechs Zeilen.
      expect(_key('setup-facts'), findsOneWidget);
      expect(find.text('Angaben für FinanzOnline'), findsOneWidget);
      expect(find.text(_introCard), findsOneWidget);
      expect(find.text(_introOnline), findsNothing);
      // Schritt 2 rechts nennt die Signaturkarte.
      expect(find.text(_stepCard), findsOneWidget);
      expect(find.text(_stepOnline), findsNothing);
      final facts = _expected();
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
      expect(_value(t, 'setup-value-kind'), 'Signaturkarte');
      expect(_value(t, 'setup-value-provider'), 'AT1 = A-TRUST');
      expect(_value(t, 'setup-value-serial'), facts.certSerialHex);
      expect(find.text('dezimal ${facts.certSerialDecimal}'), findsOneWidget);
      expect(_value(t, 'setup-value-cashbox'), _cashBoxId);
      expect(_aesLines(t), [
        facts.aesKeyBase64.substring(0, 22),
        facts.aesKeyBase64.substring(22),
      ]);
      expect(_value(t, 'setup-value-checksum'), facts.aesChecksum);
      expect(_key('setup-cashbox-change'), findsOneWidget);

      // Angaben drucken: der Zettel trägt die Art "Signaturkarte".
      await _tap(t, 'setup-print');
      final slip = printerOf(t).setupSlips.single;
      expect(slip.kind, 'Signaturkarte');
      expect(slip.cashBoxId, _cashBoxId);
      expect(slip.certSerialHex, facts.certSerialHex);
      final lines = [
        for (final o in layoutSetupFacts(
          slip,
          const BusinessInfo(name: 'Beispiel-Imbiss'),
          DateTime(2026, 11, 22, 11),
        ))
          if (o is PrintText) o.text,
      ];
      expect(
        lines.sublist(
          lines.indexOf('Art der Sicherheitseinrichtung'),
          lines.indexOf('Art der Sicherheitseinrichtung') + 2,
        ),
        ['Art der Sicherheitseinrichtung', 'Signaturkarte'],
      );

      // Frage, dann In Betrieb.
      final signs = card.signCount;
      await _tap(t, 'setup-go-live');
      expect(find.text('Jetzt in Betrieb nehmen?'), findsOneWidget);
      await _tap(t, 'go-live-confirm');

      final state = await _state(t);
      expect(state.mode, RksvMode.live);
      expect(state.unit, RksvUnit.card);
      expect(await _kinds(t), ['start']);
      expect(card.signCount, signs + 1);
      final chain = (await queryRows(
        t,
        'SELECT unit, mode, cash_box_id, zda_id, cert_serial FROM rksv_chains',
      )).single;
      expect(chain['unit'], 'card');
      expect(chain['mode'], 'live');
      expect(chain['cash_box_id'], _cashBoxId);
      expect(chain['zda_id'], 'AT1');
      expect(chain['cert_serial'], facts.certSerialHex);
      expect(await rig.secrets.aesKey(state.chain!), _aesKey);
      expect(await rig.secrets.pendingSetup(), isNull);
      final start =
          (await queryRows(
                t,
                "SELECT id FROM receipts WHERE kind = 'start'",
              )).single['id']!
              as String;
      expect(printerOf(t).printed, [start]);

      // Zurück in den Einstellungen mit der Meldung, der ganze Weg ist zu.
      expect(_key('setup-facts'), findsNothing);
      expect(_key('card-setup'), findsNothing);
      expect(_key('signer-choice'), findsNothing);
      expect(
        find.descendant(of: _key('rksv-message'), matching: find.text(_done)),
        findsOneWidget,
      );
      expect(rig.service().goLiveCalls, 1);
    });

    testWidgets('vor goLiveWithCard wird der Halter mit ask aufgewärmt', (
      t,
    ) async {
      final rig = await _settings(t);
      await _toCardFacts(t);
      rig.events.clear();
      await _tap(t, 'setup-go-live');
      await _tap(t, 'go-live-confirm');
      expect(rig.events.take(2), ['warmUp(ask: true)', 'goLiveWithCard']);
      expect((await _state(t)).mode, RksvMode.live);
    });

    testWidgets('das Aufwärmen wartet höchstens 20 Sekunden, dann kommt '
        'goLiveWithCard trotzdem', (t) async {
      final hold = Completer<void>();
      final rig = await _settings(t, holdWarmUp: hold);
      await _toCardFacts(t);
      rig.events.clear();
      await _tap(t, 'setup-go-live');
      await t.tap(_key('go-live-confirm'));
      await t.pump();
      await t.pump(const Duration(seconds: 19));
      expect(rig.events, ['warmUp(ask: true)']);
      expect(_button(t, 'setup-go-live').leading, isNotNull);
      await t.pump(const Duration(seconds: 2));
      await t.pumpAndSettle();
      expect(rig.events, contains('goLiveWithCard'));
      expect((await _state(t)).mode, RksvMode.live);
      hold.complete();
      await t.pumpAndSettle();
    });

    testWidgets('Karte beim Start gezogen: der Satz, nicht in Betrieb, der '
        'Bildschirm bleibt', (t) async {
      final rig = await _settings(t);
      await _toCardFacts(t);
      rig.reader.card!.removed = true;
      await _tap(t, 'setup-go-live');
      await _tap(t, 'go-live-confirm');
      expect(_key('setup-facts'), findsOneWidget);
      expect(
        find.descendant(
          of: _key('setup-go-live-problem'),
          matching: find.text('Keine Karte im Kartenleser.'),
        ),
        findsOneWidget,
      );
      expect((await _state(t)).mode, RksvMode.off);
      expect(await _kinds(t), isEmpty);
      expect(printerOf(t).printed, isEmpty);
      expect((await rig.secrets.pendingSetup())!.cashBoxId, _cashBoxId);
      expect(_button(t, 'setup-go-live').onPressed, isNotNull);
      expect(find.text(_done), findsNothing);
    });

    testWidgets('Doppeltipp ruft goLiveWithCard einmal', (t) async {
      // Das Aufwärmen hält an: Die Inbetriebnahme läuft sichtbar.
      final hold = Completer<void>();
      final rig = await _settings(t, holdWarmUp: hold);
      await _toCardFacts(t);
      await t.tap(_key('setup-go-live'));
      await t.pump();
      await t.tap(_key('setup-go-live'), warnIfMissed: false);
      await t.pumpAndSettle();
      expect(_key('go-live-question'), findsOneWidget);
      await t.tap(_key('go-live-confirm'));
      await t.tap(_key('go-live-confirm'), warnIfMissed: false);
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(_key('go-live-question'), findsNothing);
      expect(_button(t, 'setup-go-live').onPressed, isNull);
      expect(_button(t, 'setup-cashbox-change').onPressed, isNull);
      await t.tap(_key('setup-go-live'), warnIfMissed: false);
      await t.pump();
      expect(_key('go-live-question'), findsNothing);
      hold.complete();
      await t.pumpAndSettle();
      expect(rig.service().goLiveCalls, 1);
      expect(await _kinds(t), ['start']);
      expect((await _state(t)).mode, RksvMode.live);
    });

    testWidgets('Zurück von den Angaben führt zu "Karte und PIN"', (t) async {
      await _settings(t);
      await _toCardFacts(t);
      await _tap(t, 'setup-facts-back');
      expect(_key('setup-facts'), findsNothing);
      expect(_key('card-setup'), findsOneWidget);

      await _tap(t, 'card-setup-main');
      expect(_key('setup-facts'), findsOneWidget);
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(_key('card-setup'), findsOneWidget);
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(_key('signer-choice'), findsOneWidget);
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(_key('signature-card'), findsOneWidget);
    });
  });

  group('Kassen-ID ändern', () {
    testWidgets('"Ändern" öffnet das Blatt: Titel, Feld vorbelegt, Hilfe, '
        'Hinweise, Tasten', (t) async {
      await _settings(t);
      await _toCardFacts(t);
      expect(
        find.descendant(
          of: _key('setup-cashbox-change'),
          matching: find.text('Ändern'),
        ),
        findsOneWidget,
      );
      expect(
        t.getSize(_key('setup-cashbox-change')).height,
        greaterThanOrEqualTo(48),
      );
      await _tap(t, 'setup-cashbox-change');
      expect(_key('cash-box-id-sheet'), findsOneWidget);
      expect(find.text(_sheetTitle), findsOneWidget);
      expect(_fieldText(t), _cashBoxId);
      expect(find.text(_sheetHelp), findsOneWidget);
      expect(find.text(_hintRegistered), findsOneWidget);
      expect(find.text(_hintSlip), findsOneWidget);
      for (final (key, label) in [
        ('cash-box-id-save', 'Speichern'),
        ('cash-box-id-cancel', 'Abbrechen'),
      ]) {
        expect(
          find.descendant(of: _key(key), matching: find.text(label)),
          findsOneWidget,
        );
        expect(t.getSize(_key(key)).height, greaterThanOrEqualTo(48));
      }
      expect(_enabled(t, 'cash-box-id-save'), isTrue);
    });

    testWidgets('Eingabe "yichi-1" wird "YICHI-1", gespeichert; Schlüssel und '
        'Prüfwert bleiben', (t) async {
      final rig = await _settings(t);
      await _toCardFacts(t);
      final aes = _aesLines(t);
      final checksum = _value(t, 'setup-value-checksum');
      await _tap(t, 'setup-cashbox-change');
      await t.enterText(_field, 'yichi-1');
      await t.pump();
      expect(_fieldText(t), 'YICHI-1');
      await _tap(t, 'cash-box-id-save');
      expect(_key('cash-box-id-sheet'), findsNothing);
      expect(_value(t, 'setup-value-cashbox'), 'YICHI-1');
      expect(_aesLines(t), aes);
      expect(_value(t, 'setup-value-checksum'), checksum);
      final stored = (await rig.secrets.pendingSetup())!;
      expect(stored.cashBoxId, 'YICHI-1');
      expect(stored.aesKey, _aesKey);
      expect(base64.encode(stored.aesKey), aes.join());

      // Der Zettel und die Inbetriebnahme nehmen die neue Kennung.
      await _tap(t, 'setup-print');
      expect(printerOf(t).setupSlips.single.cashBoxId, 'YICHI-1');
      await _tap(t, 'setup-go-live');
      await _tap(t, 'go-live-confirm');
      expect(
        (await queryRows(
          t,
          'SELECT cash_box_id FROM rksv_chains',
        )).single['cash_box_id'],
        'YICHI-1',
      );
    });

    testWidgets('erst drucken, dann ändern: neue Kennung am Bildschirm mit '
        'demselben Schlüssel und Prüfwert, der zweite Zettel trägt sie', (
      t,
    ) async {
      final rig = await _settings(t);
      await _toCardFacts(t);
      await _tap(t, 'setup-print');
      final first = printerOf(t).setupSlips.single;
      expect(first.cashBoxId, _cashBoxId);
      final aes = _aesLines(t);
      final checksum = _value(t, 'setup-value-checksum');
      expect(aes.join(), first.aesKeyBase64);
      expect(checksum, first.aesChecksum);

      await _tap(t, 'setup-cashbox-change');
      await t.enterText(_field, 'imbiss-neu');
      await t.pump();
      await _tap(t, 'cash-box-id-save');
      expect(_value(t, 'setup-value-cashbox'), 'IMBISS-NEU');
      expect(_aesLines(t), aes);
      expect(_value(t, 'setup-value-checksum'), checksum);
      expect((await rig.secrets.pendingSetup())!.aesKey, _aesKey);

      await _tap(t, 'setup-print');
      final slips = printerOf(t).setupSlips;
      expect(slips, hasLength(2));
      expect(slips.last.cashBoxId, 'IMBISS-NEU');
      expect(slips.last.aesKeyBase64, first.aesKeyBase64);
      expect(slips.last.aesChecksum, first.aesChecksum);
      expect(slips.last.kind, 'Signaturkarte');
    });

    testWidgets('Unterstrich und andere Zeichen lassen sich nicht tippen, '
        'höchstens 20 Zeichen', (t) async {
      await _settings(t);
      await _toCardFacts(t);
      await _tap(t, 'setup-cashbox-change');
      await t.enterText(_field, 'ab_c d.e');
      await t.pump();
      expect(_fieldText(t), 'ABCDE');
      await t.enterText(_field, 'A' * 21);
      await t.pump();
      expect(_fieldText(t), 'A' * 20);
    });

    testWidgets('leeres Feld: "Speichern" aus', (t) async {
      final rig = await _settings(t);
      await _toCardFacts(t);
      await _tap(t, 'setup-cashbox-change');
      await t.enterText(_field, '');
      await t.pump();
      expect(_enabled(t, 'cash-box-id-save'), isFalse);
      await t.tap(_key('cash-box-id-save'), warnIfMissed: false);
      await t.pumpAndSettle();
      expect(_key('cash-box-id-sheet'), findsOneWidget);
      expect((await rig.secrets.pendingSetup())!.cashBoxId, _cashBoxId);
    });

    testWidgets('vorhandene Kennung: der Satz unter dem Feld, das Blatt '
        'bleibt offen, nichts geändert', (t) async {
      final rig = await _settings(t);
      await seedProbe(t, ended: true);
      await t.pumpAndSettle();
      await _toCardFacts(t);
      await _tap(t, 'setup-cashbox-change');
      await t.enterText(_field, fixedCashBoxId.toLowerCase());
      await t.pump();
      await _tap(t, 'cash-box-id-save');
      expect(_key('cash-box-id-sheet'), findsOneWidget);
      final error = find.descendant(
        of: _key('cash-box-id-problem'),
        matching: find.text(_used),
      );
      expect(error, findsOneWidget);
      // Unter dem Feld.
      expect(
        t.getTopLeft(error).dy,
        greaterThan(t.getBottomLeft(_key('cash-box-id-field')).dy),
      );
      expect((await rig.secrets.pendingSetup())!.cashBoxId, _cashBoxId);

      // Nach einer Änderung im Feld geht der Satz weg.
      await t.enterText(_field, 'NEU-1');
      await t.pump();
      expect(find.text(_used), findsNothing);

      await _tap(t, 'cash-box-id-cancel');
      expect(_key('cash-box-id-sheet'), findsNothing);
      expect(_value(t, 'setup-value-cashbox'), _cashBoxId);
      expect((await rig.secrets.pendingSetup())!.cashBoxId, _cashBoxId);
    });

    testWidgets('offene Tastatur im Querformat: Feld und Tasten bleiben über '
        'ihr', (t) async {
      await _settings(t);
      await _toCardFacts(t);
      await _tap(t, 'setup-cashbox-change');
      // Eine Tastatur im Querformat deckt 360 von 800 dp ab.
      final ratio = t.view.devicePixelRatio;
      t.view.viewInsets = FakeViewPadding(bottom: 360 * ratio);
      addTearDown(t.view.resetViewInsets);
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      const keyboardTop = 800.0 - 360;

      /// Feld und Tasten liegen ganz im sichtbaren Teil des Blatts, und der
      /// liegt ganz über der Tastatur.
      void aboveKeyboard() {
        final viewport = t.getRect(
          find
              .descendant(
                of: _key('cash-box-id-sheet'),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(viewport.top, greaterThanOrEqualTo(0));
        expect(viewport.bottom, lessThanOrEqualTo(keyboardTop));
        for (final key in [
          'cash-box-id-field',
          'cash-box-id-save',
          'cash-box-id-cancel',
        ]) {
          final rect = t.getRect(_key(key));
          expect(rect.top, greaterThanOrEqualTo(viewport.top), reason: key);
          expect(rect.bottom, lessThanOrEqualTo(viewport.bottom), reason: key);
          expect(rect.left, greaterThanOrEqualTo(viewport.left), reason: key);
          expect(rect.right, lessThanOrEqualTo(viewport.right), reason: key);
        }
      }

      aboveKeyboard();
      // Auch mit einem Satz unter dem Feld.
      await seedProbe(t, ended: true);
      await t.enterText(_field, fixedCashBoxId);
      await t.pump();
      await t.tap(_key('cash-box-id-save'));
      await t.pumpAndSettle();
      expect(find.text(_used), findsOneWidget);
      expect(t.takeException(), isNull);
      aboveKeyboard();
      // Feld und Tasten nehmen Tipps an (ein verdecktes Ziel ließe tap()
      // warnen und ginge daneben).
      await t.tap(_key('cash-box-id-field'));
      await t.pump();
      expect(_key('cash-box-id-sheet'), findsOneWidget);
      await t.tap(_key('cash-box-id-cancel'));
      await t.pumpAndSettle();
      expect(_key('cash-box-id-sheet'), findsNothing);
    });
  });
}
