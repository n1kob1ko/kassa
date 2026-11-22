// Die Kassa mit einer laufenden Kette der Signaturkarte: Aufwärmen beim Start
// und beim Fortsetzen, der Hinweis im Ausfall mit dem Grund der Karte,
// "Nochmal prüfen" und "PIN neu eingeben". Gegen den nachgebauten Leser mit
// Karte; der Startbeleg und die Bons werden vom echten Halter von der Karte
// signiert. Kassen-Kennung, AES-Schlüssel und PIN sind erfunden.

import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/data/database.dart';
import 'package:kassa/data/providers.dart';
import 'package:kassa/domain/staff.dart';
import 'package:kassa/features/login/session.dart';
import 'package:kassa/features/settings/card_setup_screen.dart';
import 'package:kassa/rksv/card/card_facts.dart';
import 'package:kassa/rksv/card/card_providers.dart';
import 'package:kassa/rksv/card/card_signer.dart';
import 'package:kassa/rksv/card/certificate.dart';
import 'package:kassa/rksv/card/pin_guard.dart';
import 'package:kassa/rksv/rksv_providers.dart';
import 'package:kassa/rksv/rksv_secrets.dart';
import 'package:kassa/rksv/rksv_service.dart';
import 'package:kassa/rksv/rksv_state.dart';
import 'package:kassa/ui/primary_button.dart';
import 'package:material_ui/material_ui.dart';

import '../support/bons_pump.dart' show sellCash;
import '../support/cash_pump.dart' show queryRows;
import '../support/fake_card_reader.dart';
import '../support/kassa_pump.dart';
import '../support/pump.dart';
import '../support/settings_pump.dart';
import '../support/signature_pump.dart';

Finder _key(String key) => find.byKey(Key(key));

Finder _inBanner(Finder f) =>
    find.descendant(of: _key('rksv-outage'), matching: f);

String _sentence(CardSignProblem p) => CardSignException(p).sentence;

const _cashBoxId = 'BSPIMBKARTE';

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

/// Der echte Dienst, der jedes [retrySignature] in [events] schreibt.
class _RecordingService extends RksvService {
  _RecordingService(
    super.db,
    super.secrets,
    super.receipts,
    super.clock,
    this.events,
  );

  final List<String> events;

  @override
  Future<bool> retrySignature({required Staff staff}) {
    events.add('retrySignature');
    return super.retrySignature(staff: staff);
  }
}

typedef _Rig = ({
  FakeCardReader reader,
  MemoryRksvSecrets secrets,
  List<String> events,
});

/// Die Kassa (Anna angemeldet) mit der nachgebauten Karte im Leser.
Future<_Rig> _kassa(WidgetTester t, {Completer<void>? holdWarmUp}) async {
  final reader = FakeCardReader(card: testSignatureCard());
  final secrets = MemoryRksvSecrets();
  final events = <String>[];
  final List<Override> overrides = [
    ...await memoryOverrides(),
    ...signatureOverrides(secrets: secrets),
    readerTransportProvider.overrideWithValue(reader),
    pinGuardProvider.overrideWithValue(MemoryPinGuard()),
    shareSheetProvider.overrideWithValue(FakeShareSheet()),
    rksvServiceProvider.overrideWith(
      (ref) => _RecordingService(
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
  ];
  await pumpKassa(t, overrides: overrides);
  return (reader: reader, secrets: secrets, events: events);
}

CardFacts _facts(FakeCard card) {
  final certificate = CardCertificate.parse(card.certificate);
  return CardFacts(
    kind: card.profile.kind.name,
    numberHex: compactHex(card.number),
    certificateDer: certificate.der,
    serialHex: certificate.serial.toRadixString(16),
  );
}

Future<void> _storePin(_Rig rig, {String? pin}) {
  final card = rig.reader.card!;
  return rig.secrets.writeCardPin(
    CardPin(
      kind: card.profile.kind.name,
      numberHex: compactHex(card.number),
      pin: pin ?? card.pin,
    ),
  );
}

/// Startet eine Kette mit Karte über den Dienst, als Chef; danach ist
/// wieder Anna angemeldet, wenn nicht [asChef].
Future<void> _startCardChain(
  WidgetTester t,
  _Rig rig, {
  RksvUnit unit = RksvUnit.card,
  bool asChef = false,
}) async {
  final c = containerOf(t);
  await c.read(sessionProvider.notifier).login('4711');
  await _storePin(rig);
  final service = c.read(rksvServiceProvider);
  final chef = c.read(sessionProvider)!;
  final facts = _facts(rig.reader.card!);
  if (unit == RksvUnit.cardTest) {
    await service.enableCardProbe(staff: chef, facts: facts);
  } else {
    await service.prepareCardSetup(facts: facts);
    await service.changeCashBoxId(_cashBoxId);
    await service.goLiveWithCard(staff: chef, facts: facts);
  }
  if (!asChef) await c.read(sessionProvider.notifier).login('1234');
  await t.pumpAndSettle();
}

Future<RksvState> _state(WidgetTester t) =>
    containerOf(t).read(rksvRepositoryProvider).current();

Future<List<String>> _kinds(WidgetTester t) async => [
  for (final r in await queryRows(
    t,
    'SELECT kind FROM receipts ORDER BY number',
  ))
    r['kind']! as String,
];

/// Der Eintrag des letzten Bons: beschädigt (Ausfall) oder signiert.
Future<bool> _lastDamaged(WidgetTester t) async =>
    (await queryRows(
      t,
      'SELECT damaged FROM rksv_entries ORDER BY position DESC LIMIT 1',
    )).single['damaged'] ==
    1;

int _warmUps(_Rig rig) =>
    rig.events.where((e) => e == 'warmUp(ask: true)').length;

void main() {
  for (final unit in [RksvUnit.card, RksvUnit.cardTest]) {
    testWidgets('Start mit laufender Kette ${unit.name}: warmUp(ask: true) '
        'einmal, Fortsetzen noch einmal', (t) async {
      final rig = await _kassa(t);
      await _startCardChain(t, rig, unit: unit);
      rig.events.clear();
      await pumpKassa(t, sameDatabase: true);
      await t.pumpAndSettle();
      expect(_warmUps(rig), 1);

      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pumpAndSettle();
      expect(_warmUps(rig), 2);
      expect(rig.events.where((e) => e == 'warmUp(ask: false)'), isEmpty);
    });
  }

  testWidgets('ohne Kette mit Karte: kein Aufwärmen', (t) async {
    final rig = await _kassa(t);
    await seedProbe(t);
    await pumpKassa(t, sameDatabase: true);
    await t.pumpAndSettle();
    expect(rig.events, isEmpty);
  });

  testWidgets('ein hängendes Aufwärmen hält weder Bild noch Verkauf auf', (
    t,
  ) async {
    final hold = Completer<void>();
    final rig = await _kassa(t, holdWarmUp: hold);
    await _startCardChain(t, rig);
    await pumpKassa(t, sameDatabase: true);
    await t.pumpAndSettle();
    expect(_warmUps(rig), greaterThanOrEqualTo(1));
    expect(_key('cart-count'), findsOneWidget);
    await tapItem(t, 'cola');
    expect(t.widget<PrimaryButton>(_key('pay-cash')).onPressed, isNotNull);
    await sellCash(t);
    await t.pumpAndSettle();
    expect(await _lastDamaged(t), isFalse);
    hold.complete();
    await t.pumpAndSettle();
  });

  testWidgets('Verkauf mit gezogener Karte: Hinweis mit dem Grund, '
      '"Nochmal prüfen" nach "wieder da": Sammelbeleg, Hinweis weg', (t) async {
    final rig = await _kassa(t);
    await _startCardChain(t, rig);
    rig.reader.card!.removed = true;

    await sellCash(t);
    await t.pumpAndSettle();
    expect((await _state(t)).outage, isTrue);
    expect(await _lastDamaged(t), isTrue);
    expect(_key('rksv-outage'), findsOneWidget);
    expect(
      _inBanner(find.text(_sentence(CardSignProblem.noCard))),
      findsOneWidget,
    );
    expect(_key('rksv-retry'), findsOneWidget);
    expect(_key('rksv-repin'), findsNothing);

    rig.reader.card!.removed = false;
    rig.events.clear();
    await t.tap(_key('rksv-retry'));
    await t.pumpAndSettle();
    expect(rig.events, ['warmUp(ask: true)', 'retrySignature']);
    expect(find.text('Die Signatur geht wieder.'), findsOneWidget);
    expect((await _state(t)).outage, isFalse);
    expect(await _kinds(t), ['start', 'sale', 'collective']);

    await t.pump(const Duration(seconds: 4));
    await t.pumpAndSettle();
    expect(_key('rksv-outage'), findsNothing);
  });

  testWidgets('abgelehnte PIN: "PIN neu eingeben" öffnet "Karte und PIN", '
      'danach signiert der nächste Bon', (t) async {
    final rig = await _kassa(t);
    await _startCardChain(t, rig, asChef: true);
    // Eine falsche PIN im Speicher; der Halter prüft sie beim nächsten Bon.
    await _storePin(rig, pin: '999999');
    containerOf(t).read(cardSignerProvider).pinChanged();

    await sellCash(t);
    await t.pumpAndSettle();
    expect(
      (await _state(t)).outageReason,
      _sentence(CardSignProblem.pinRejected),
    );
    expect(
      _inBanner(find.text(_sentence(CardSignProblem.pinRejected))),
      findsOneWidget,
    );
    expect(_key('rksv-retry'), findsNothing);
    expect(_key('rksv-repin'), findsOneWidget);
    expect(_inBanner(find.text('PIN neu eingeben')), findsOneWidget);
    expect(t.getSize(_key('rksv-repin')).height, 56);

    await t.tap(_key('rksv-repin'));
    await t.pumpAndSettle();
    expect(
      t.widget<CardSetupScreen>(find.byType(CardSetupScreen)).purpose,
      CardSetupPurpose.repin,
    );
    await t.ensureVisible(_key('card-check-pin'));
    await t.pumpAndSettle();
    await t.tap(_key('card-check-pin'));
    await t.pumpAndSettle();
    await typePin(t, '123456');
    await t.tap(_key('card-pin-submit'));
    await t.pumpAndSettle();
    expect((await rig.secrets.cardPin())!.pin, '123456');
    await t.tap(_key('card-setup-main'));
    await t.pumpAndSettle();
    expect(find.byType(CardSetupScreen), findsNothing);

    await sellCash(t);
    await t.pumpAndSettle();
    expect(await _lastDamaged(t), isFalse);
    expect((await _state(t)).outage, isFalse);
    expect(await _kinds(t), ['start', 'sale', 'collective', 'sale']);
  });

  for (final problem in [
    CardSignProblem.pinRejected,
    CardSignProblem.pinMissing,
  ]) {
    testWidgets('${problem.name}: der Chef sieht "PIN neu eingeben", ein '
        'Mitarbeiter den Grund und "Nochmal prüfen"', (t) async {
      final rig = await _kassa(t);
      await _startCardChain(t, rig);
      final db = containerOf(t).read(databaseProvider);
      await (db.update(db.rksvStateRows)..where((r) => r.id.equals(1))).write(
        RksvStateRowsCompanion(
          outageSince: Value(DateTime(2026, 11, 17, 13, 5)),
          outageReason: Value(_sentence(problem)),
        ),
      );
      await t.pumpAndSettle();
      expect(_inBanner(find.text(_sentence(problem))), findsOneWidget);
      expect(_key('rksv-retry'), findsOneWidget);
      expect(_key('rksv-repin'), findsNothing);

      await containerOf(t).read(sessionProvider.notifier).login('4711');
      await t.pumpAndSettle();
      expect(_inBanner(find.text(_sentence(problem))), findsOneWidget);
      expect(_key('rksv-retry'), findsNothing);
      expect(_key('rksv-repin'), findsOneWidget);
    });
  }
}
