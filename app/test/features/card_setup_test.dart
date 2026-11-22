// "Karte und PIN" und die Zeile "Mit Karte ausprobieren" der Karte
// "Signatur": gegen den nachgebauten Leser mit Karte über die Provider. Der
// Startbeleg der Karten-Probe wird mit dem echten Halter von der Karte
// signiert. Die PINs stehen nur in den Körpern der Tests.

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/data/database.dart';
import 'package:kassa/data/providers.dart';
import 'package:kassa/domain/receipt.dart';
import 'package:kassa/domain/staff.dart';
import 'package:kassa/features/login/session.dart';
import 'package:kassa/features/settings/card_setup_screen.dart';
import 'package:kassa/features/settings/signature_panel.dart';
import 'package:kassa/rksv/card/card_check.dart';
import 'package:kassa/rksv/card/card_facts.dart';
import 'package:kassa/rksv/card/card_providers.dart';
import 'package:kassa/rksv/card/certificate.dart';
import 'package:kassa/rksv/card/pin_guard.dart';
import 'package:kassa/rksv/rksv_providers.dart';
import 'package:kassa/rksv/rksv_secrets.dart';
import 'package:kassa/rksv/rksv_service.dart';
import 'package:kassa/rksv/rksv_state.dart';
import 'package:kassa/ui/pressable.dart';
import 'package:material_ui/material_ui.dart';

import '../support/cash_pump.dart' show queryRows, setUpPrinter;
import '../support/fake_card_reader.dart';
import '../support/kassa_pump.dart' show containerOf;
import '../support/pump.dart';
import '../support/settings_pump.dart';
import '../support/signature_pump.dart';

const _cardNumber = '0102030405060708';
const _title = 'Karte und PIN';
const _intro =
    'Steck die Signaturkarte in den Kartenleser. Die Kassa liest sie und '
    'fragt dann einmal nach der PIN.';
const _hintStored =
    'Die PIN bleibt verschlüsselt auf diesem Tablet. So muss sie niemand bei '
    'jedem Bon eingeben.';
const _hintLock =
    'Nach drei falschen Eingaben sperrt sich die Karte. Gib nur eine PIN ein, '
    'die du sicher weißt.';
const _stored = 'Karte und PIN sind gespeichert.';
const _running = 'Die Probe mit der Karte läuft.';
const _storeProblem = 'Das Tablet konnte die PIN nicht sicher speichern.';
const _cardHelp =
    'Die Signaturkarte im Kartenleser signiert die Bons. Ohne Internet. Sie '
    'bleiben Testbons.';
const _setupHelp =
    'Für den echten Betrieb, mit Signaturkarte oder A-Trust online.';

Finder _key(String key) => find.byKey(Key(key));

Finder _inCard(Finder f) =>
    find.descendant(of: _key('signature-card'), matching: f);

Finder _inScreen(Finder f) =>
    find.descendant(of: _key('card-setup'), matching: f);

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

CardCheck _check(WidgetTester t) => containerOf(t).read(cardCheckProvider);

RowResult _row(WidgetTester t, CheckRow row) => _check(t).state.rows[row]!;

Future<RksvState> _state(WidgetTester t) =>
    containerOf(t).read(rksvRepositoryProvider).current();

Future<List<String>> _kinds(WidgetTester t) async => [
  for (final r in await queryRows(
    t,
    "SELECT kind FROM receipts WHERE kind != 'sale' ORDER BY number",
  ))
    r['kind']! as String,
];

/// Die PIN für die nachgebaute Karte speichern, wie "Karte und PIN" es tut;
/// mit [numberHex] für eine andere Kartennummer.
Future<void> _storePin(
  MemoryRksvSecrets secrets, {
  String pin = '123456',
  String numberHex = _cardNumber,
}) => secrets.writeCardPin(
  CardPin(
    kind: testSignatureCard().profile.kind.name,
    numberHex: numberHex,
    pin: pin,
  ),
);

/// Ruft [RksvService.enableCardProbe] mit und zählt die Aufrufe.
class _CountingService extends RksvService {
  _CountingService(super.db, super.secrets, super.receipts, super.clock);

  int cardProbeCalls = 0;

  @override
  Future<Receipt> enableCardProbe({
    required Staff staff,
    required CardFacts facts,
  }) {
    cardProbeCalls++;
    return super.enableCardProbe(staff: staff, facts: facts);
  }
}

/// Einstellungen als Chef mit der nachgebauten Karte im Leser; öffnet mit
/// [open] gleich "Karte und PIN" über "Mit Karte ausprobieren".
Future<FakeCardReader> _settings(
  WidgetTester t, {
  MemoryRksvSecrets? secrets,
  PinGuard? guard,
  bool printer = false,
  bool open = true,
  List<Override> extra = const [],
}) async {
  final reader = FakeCardReader(card: testSignatureCard());
  await pumpSettings(
    t,
    reader: reader,
    guard: guard,
    extra: [
      ...signatureOverrides(secrets: secrets),
      ...extra,
    ],
  );
  if (printer) await setUpPrinter(t);
  if (open) await _tap(t, 'rksv-card-probe-on');
  return reader;
}

Future<void> _enterPin(WidgetTester t, String key, String pin) async {
  await _tap(t, key);
  expect(_key('card-pin-sheet'), findsOneWidget);
  await typePin(t, pin);
  await t.tap(_key('card-pin-submit'));
  await t.pumpAndSettle();
}

void main() {
  group('Zeile "Mit Karte ausprobieren"', () {
    testWidgets('steht für den Chef direkt nach "Mit A-Trust ausprobieren", '
        '"Signatur einrichten" mit neuer Hilfe', (t) async {
      await _settings(t, open: false);
      expect(_inCard(find.text('Mit Karte ausprobieren')), findsOneWidget);
      expect(_inCard(find.text(_cardHelp)), findsOneWidget);
      expect(
        find.descendant(
          of: _key('rksv-card-probe-on'),
          matching: find.text('Ausprobieren'),
        ),
        findsOneWidget,
      );
      expect(t.getSize(_key('rksv-card-probe-on')).height, 56);
      final online = t.getRect(find.text('Mit A-Trust ausprobieren'));
      final card = t.getRect(find.text('Mit Karte ausprobieren'));
      final setup = t.getRect(find.text('Signatur einrichten'));
      expect(card.top, greaterThan(online.top));
      expect(setup.top, greaterThan(card.top));
      expect(_inCard(find.text(_setupHelp)), findsOneWidget);
      expect(
        _inCard(
          find.text(
            'Für den echten Betrieb. Du brauchst die Zugangsdaten von '
            'A-Trust.',
          ),
        ),
        findsNothing,
      );
    });

    testWidgets('außer Betrieb steht sie auch, in der Probe nicht', (t) async {
      await _settings(t, open: false);
      await seedLive(t, decommissioned: true);
      expect(_key('rksv-card-probe-on'), findsOneWidget);
      expect(_inCard(find.text(_setupHelp)), findsOneWidget);
    });

    testWidgets('in der Probe fehlt sie', (t) async {
      await _settings(t, open: false);
      await seedProbe(t);
      expect(_key('rksv-card-probe-on'), findsNothing);
      expect(_inCard(find.text('Mit Karte ausprobieren')), findsNothing);
    });

    testWidgets('ein Mitarbeiter ohne Chef-Recht sieht sie nicht', (t) async {
      await pumpApp(
        t,
        SingleChildScrollView(
          child: SignaturePanel(
            onOpenCardCheck: () {},
            onOpenConnectionCheck: (_) {},
          ),
        ),
        overrides: [...await memoryOverrides(), ...signatureOverrides()],
      );
      final c = ProviderScope.containerOf(
        t.element(find.byType(SignaturePanel)),
      );
      await c.read(sessionProvider.notifier).login('1234');
      await t.pumpAndSettle();
      expect(find.text('Nicht eingerichtet'), findsOneWidget);
      expect(_key('rksv-card-probe-on'), findsNothing);
      expect(find.text('Mit Karte ausprobieren'), findsNothing);
      expect(find.text(_cardHelp), findsNothing);
    });
  });

  group('Karte und PIN', () {
    testWidgets('der ganze Weg: vier Haken, PIN, fünfter Haken, gespeichert, '
        '"Probe starten", Startbeleg von der Karte, Probe mit cardTest', (
      t,
    ) async {
      final secrets = MemoryRksvSecrets();
      final reader = await _settings(t, secrets: secrets, printer: true);
      final card = reader.card!;

      expect(_key('card-setup'), findsOneWidget);
      expect(_inScreen(find.text(_title)), findsOneWidget);
      expect(_inScreen(find.text(_intro)), findsOneWidget);
      expect(_inScreen(find.text(_hintStored)), findsOneWidget);
      expect(_inScreen(find.text(_hintLock)), findsOneWidget);
      for (final row in CheckRow.values.take(4)) {
        expect(_row(t, row).state, RowState.ok, reason: row.name);
        expect(
          t.getSemantics(_key('card-check-sign-${row.name}')).label,
          'in Ordnung',
        );
      }
      expect(_row(t, CheckRow.signature).state, RowState.waiting);
      expect(card.verifyCount, 0);
      expect(_key('card-pin-sheet'), findsNothing);
      expect(
        find.descendant(
          of: _key('card-check-pin'),
          matching: find.text('PIN eingeben'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _key('card-setup-main'),
          matching: find.text('Probe starten'),
        ),
        findsOneWidget,
      );
      expect(_enabled(t, 'card-setup-main'), isFalse);
      expect(_inScreen(find.text(_stored)), findsNothing);

      await _enterPin(t, 'card-check-pin', '123456');
      expect(_row(t, CheckRow.signature).state, RowState.ok);
      expect(_key('card-check-pin'), findsNothing);
      expect(_key('card-setup-stored'), findsOneWidget);
      expect(_inScreen(find.text(_stored)), findsOneWidget);
      final pin = await secrets.cardPin();
      expect(pin!.kind, card.profile.kind.name);
      expect(pin.numberHex, _cardNumber);
      expect(pin.pin, '123456');
      expect(await secrets.cardPinStatus(), isA<CardPinStatus>());
      expect(_enabled(t, 'card-setup-main'), isTrue);
      final trial = card.signCount;

      await _tap(t, 'card-setup-main');
      expect(_key('card-setup'), findsNothing);
      expect(_key('signature-card'), findsOneWidget);
      expect(_inCard(find.text(_running)), findsOneWidget);
      final state = await _state(t);
      expect(state.mode, RksvMode.probe);
      expect(state.unit, RksvUnit.cardTest);
      expect(state.outage, isFalse);
      expect(await _kinds(t), ['start']);
      // Die Karte hat den Startbeleg signiert.
      expect(card.signCount, trial + 1);
      final start = (await queryRows(
        t,
        "SELECT id FROM receipts WHERE kind = 'start'",
      )).single['id']!;
      expect(printerOf(t).printed, [start]);
      final serial = CardCertificate.parse(card.certificate).serial
          .toRadixString(16);
      final chain = (await queryRows(
        t,
        'SELECT unit, zda_id, cert_serial FROM rksv_chains',
      )).single;
      expect(chain['unit'], 'cardTest');
      expect(chain['zda_id'], 'AT1');
      expect(chain['cert_serial'], serial);
    });

    testWidgets('falsche PIN: Zeile 5 wie in "Karte prüfen", nichts '
        'gespeichert, Haupttaste aus', (t) async {
      final secrets = MemoryRksvSecrets();
      final reader = await _settings(t, secrets: secrets);
      await _enterPin(t, 'card-check-pin', '654321');
      expect(find.text('Die PIN war falsch. Noch 2 Versuche.'), findsOneWidget);
      expect(
        find.text(
          'Frag im Betrieb nach der richtigen PIN, bevor du es nochmal '
          'versuchst.',
        ),
        findsOneWidget,
      );
      expect(t.getSemantics(_key('card-check-sign-signature')).label, 'Fehler');
      expect(reader.card!.verifyCount, 1);
      expect(_key('card-pin-sheet'), findsNothing);
      expect(await secrets.cardPin(), isNull);
      expect(_enabled(t, 'card-setup-main'), isFalse);
      expect(_inScreen(find.text(_stored)), findsNothing);
      // Ein neuer Versuch nur über die Taste.
      expect(_key('card-check-pin'), findsOneWidget);
    });

    testWidgets('Speicher schreibt nicht: der Satz, Haupttaste aus', (t) async {
      final secrets = MemoryRksvSecrets();
      await _settings(t, secrets: secrets);
      secrets.failWrites = true;
      await _enterPin(t, 'card-check-pin', '123456');
      expect(_row(t, CheckRow.signature).state, RowState.ok);
      expect(_inScreen(find.text(_storeProblem)), findsOneWidget);
      expect(_inScreen(find.text(_stored)), findsNothing);
      expect(_enabled(t, 'card-setup-main'), isFalse);
    });

    testWidgets(
      'schon gespeichert: kein Zahlenfeld nötig, "PIN neu eingeben"',
      (t) async {
        final secrets = MemoryRksvSecrets();
        await _storePin(secrets);
        final reader = await _settings(t, secrets: secrets);
        expect(_key('card-pin-sheet'), findsNothing);
        expect(_key('card-check-pin'), findsNothing);
        expect(_inScreen(find.text(_stored)), findsOneWidget);
        expect(
          find.descendant(
            of: _key('card-setup-repin'),
            matching: find.text('PIN neu eingeben'),
          ),
          findsOneWidget,
        );
        // Die Probe-Unterschrift lief mit der gespeicherten PIN.
        expect(_row(t, CheckRow.signature).state, RowState.ok);
        expect(_check(t).facts, isNotNull);
        expect(reader.card!.verifyCount, greaterThan(0));
        expect(_enabled(t, 'card-setup-main'), isTrue);

        await _tap(t, 'card-setup-main');
        expect(_inCard(find.text(_running)), findsOneWidget);
        expect((await _state(t)).unit, RksvUnit.cardTest);
      },
    );

    testWidgets('"PIN neu eingeben" öffnet das Zahlenfeld und speichert die '
        'neue PIN', (t) async {
      final secrets = MemoryRksvSecrets();
      await _storePin(secrets);
      await _settings(t, secrets: secrets);
      await _enterPin(t, 'card-setup-repin', '123456');
      expect(_inScreen(find.text(_stored)), findsOneWidget);
      expect(_enabled(t, 'card-setup-main'), isTrue);
    });

    testWidgets('andere Karte als die gespeicherte: PIN wird neu verlangt', (
      t,
    ) async {
      final secrets = MemoryRksvSecrets();
      await _storePin(secrets, numberHex: '0909090909090909');
      final reader = await _settings(t, secrets: secrets);
      expect(_key('card-check-pin'), findsOneWidget);
      expect(_key('card-setup-repin'), findsNothing);
      expect(_inScreen(find.text(_stored)), findsNothing);
      expect(reader.card!.verifyCount, 0);
      expect(_enabled(t, 'card-setup-main'), isFalse);
    });

    testWidgets('abgelehnte PIN gilt nicht als gespeichert', (t) async {
      final secrets = MemoryRksvSecrets();
      await _storePin(secrets);
      await secrets.writeCardPinStatus(const CardPinStatus(rejected: true));
      final reader = await _settings(t, secrets: secrets);
      expect(_key('card-check-pin'), findsOneWidget);
      expect(reader.card!.verifyCount, 0);
      expect(_enabled(t, 'card-setup-main'), isFalse);
    });

    testWidgets('PIN-Wächter hält zurück: Zeile und "Zähler ist wieder voll" '
        'wie in "Karte prüfen"', (t) async {
      final reader = await _settings(
        t,
        guard: MemoryPinGuard({_cardNumber: 1}),
      );
      expect(
        find.text('Die Karte hat vermutlich nur noch einen Versuch.'),
        findsOneWidget,
      );
      expect(_key('card-check-pin'), findsNothing);
      expect(_key('card-check-reset-guard'), findsOneWidget);
      await _tap(t, 'card-check-reset-guard');
      expect(_key('card-check-reset-question'), findsOneWidget);
      await _tap(t, 'card-check-reset-confirm');
      expect(_key('card-check-pin'), findsOneWidget);
      expect(reader.card!.verifyCount, 0);
    });

    testWidgets('Doppeltipp auf "Probe starten" ruft einmal', (t) async {
      late _CountingService service;
      final secrets = MemoryRksvSecrets();
      await _storePin(secrets);
      await _settings(
        t,
        secrets: secrets,
        extra: [
          rksvServiceProvider.overrideWith(
            (ref) => service = _CountingService(
              ref.watch(databaseProvider),
              ref.watch(rksvSecretsProvider),
              ref.watch(receiptRepositoryProvider),
              ref.watch(clockProvider),
            ),
          ),
        ],
      );
      await t.ensureVisible(_key('card-setup-main'));
      await t.pumpAndSettle();
      await t.tap(_key('card-setup-main'));
      await t.tap(_key('card-setup-main'), warnIfMissed: false);
      await t.pumpAndSettle();
      expect(service.cardProbeCalls, 1);
      expect(await _kinds(t), ['start']);
      expect(_inCard(find.text(_running)), findsOneWidget);
    });

    testWidgets('scheitert die Probe: der Satz, der Bildschirm bleibt offen', (
      t,
    ) async {
      final secrets = MemoryRksvSecrets();
      await _storePin(secrets);
      final reader = await _settings(t, secrets: secrets);
      expect(_enabled(t, 'card-setup-main'), isTrue);
      reader.card!.removed = true;
      await _tap(t, 'card-setup-main');
      expect(_key('card-setup'), findsOneWidget);
      expect(
        _inScreen(find.text('Keine Karte im Kartenleser.')),
        findsOneWidget,
      );
      expect((await _state(t)).mode, RksvMode.off);
      expect(await _kinds(t), isEmpty);
    });

    testWidgets('Zurück (Taste und Geste) führt zu den Einstellungen ohne '
        'Probe', (t) async {
      await _settings(t);
      await _tap(t, 'card-setup-back');
      expect(_key('card-setup'), findsNothing);
      expect(_key('signature-card'), findsOneWidget);

      await _tap(t, 'rksv-card-probe-on');
      expect(_key('card-setup'), findsOneWidget);
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(_key('card-setup'), findsNothing);
      expect(_key('area-settings'), findsOneWidget);
      expect((await _state(t)).mode, RksvMode.off);
      expect(await _kinds(t), isEmpty);
    });

    testWidgets('Tippflächen: alle Tasten mindestens 48 dp', (t) async {
      final secrets = MemoryRksvSecrets();
      await _storePin(secrets);
      await _settings(t, secrets: secrets);
      for (final key in [
        'card-setup-back',
        'card-setup-main',
        'card-setup-repin',
        'card-setup-retry',
      ]) {
        final size = t.getSize(_key(key));
        expect(size.height, greaterThanOrEqualTo(48), reason: key);
        expect(size.width, greaterThanOrEqualTo(48), reason: key);
      }
    });
  });

  group('repin', () {
    /// "Karte und PIN" mit [purpose] direkt, erst nachdem die Kette steht.
    Future<FakeCardReader> pumpScreen(
      WidgetTester t, {
      required CardSetupPurpose purpose,
      required String chainSerial,
      MemoryRksvSecrets? secrets,
    }) async {
      final reader = FakeCardReader(card: testSignatureCard());
      final show = ValueNotifier(false);
      var backs = 0;
      await pumpApp(
        t,
        ValueListenableBuilder<bool>(
          valueListenable: show,
          builder: (context, shown, _) => shown
              ? CardSetupScreen(purpose: purpose, onBack: () => backs++)
              : const SizedBox(key: Key('host')),
        ),
        overrides: [
          ...await memoryOverrides(),
          ...signatureOverrides(secrets: secrets),
          readerTransportProvider.overrideWithValue(reader),
          pinGuardProvider.overrideWithValue(MemoryPinGuard()),
          shareSheetProvider.overrideWithValue(FakeShareSheet()),
        ],
      );
      final c = ProviderScope.containerOf(
        t.element(find.byKey(const Key('host'))),
      );
      final db = c.read(databaseProvider);
      await db
          .into(db.rksvCertificateRows)
          .insert(
            RksvCertificateRowsCompanion.insert(
              serialHex: chainSerial,
              certificate: testSignatureCard().certificate,
            ),
          );
      await db
          .into(db.rksvChainRows)
          .insert(
            RksvChainRowsCompanion.insert(
              chain: const Value(1),
              mode: RksvMode.probe.name,
              unit: Value(RksvUnit.cardTest.name),
              cashBoxId: fixedCashBoxId,
              zdaId: 'AT1',
              certSerial: chainSerial,
              startedAt: DateTime(2026, 11, 17, 9),
            ),
          );
      await (db.update(db.rksvStateRows)..where((r) => r.id.equals(1))).write(
        RksvStateRowsCompanion(
          mode: Value(RksvMode.probe.name),
          chain: const Value(1),
        ),
      );
      show.value = true;
      await t.pumpAndSettle();
      return reader;
    }

    String serialOfTestCard() =>
        CardCertificate.parse(testSignatureCard().certificate).serial
            .toRadixString(16);

    testWidgets('falsche Seriennummer: Kreuz in Zeile 4, keine PIN', (t) async {
      final reader = await pumpScreen(
        t,
        purpose: CardSetupPurpose.repin,
        chainSerial: '01',
      );
      final check = ProviderScope.containerOf(
        t.element(find.byType(CardSetupScreen)),
      ).read(cardCheckProvider);
      expect(check.state.rows[CheckRow.certificate]!.state, RowState.problem);
      expect(
        find.text('Das ist nicht die Karte dieser Kassa.'),
        findsOneWidget,
      );
      expect(
        t.getSemantics(_key('card-check-sign-certificate')).label,
        'Fehler',
      );
      expect(_key('card-check-pin'), findsNothing);
      expect(reader.card!.verifyCount, 0);
      expect(
        find.descendant(
          of: _key('card-setup-main'),
          matching: find.text('Fertig'),
        ),
        findsOneWidget,
      );
      expect(_enabled(t, 'card-setup-main'), isFalse);
    });

    testWidgets('richtige Seriennummer und neue PIN: "Fertig"', (t) async {
      final secrets = MemoryRksvSecrets();
      await pumpScreen(
        t,
        purpose: CardSetupPurpose.repin,
        chainSerial: serialOfTestCard(),
        secrets: secrets,
      );
      expect(_enabled(t, 'card-setup-main'), isFalse);
      await _enterPin(t, 'card-check-pin', '123456');
      expect(find.text(_stored), findsOneWidget);
      expect((await secrets.cardPin())!.numberHex, _cardNumber);
      expect(_enabled(t, 'card-setup-main'), isTrue);
    });
  });
}
