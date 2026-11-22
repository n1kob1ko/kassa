// Das Journal mit einer Kette der Signaturkarte: echter Halter, echte
// CardSignatureUnit, nachgebauter Leser mit Karte (Review Focus 1).

import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/data/database.dart';
import 'package:kassa/domain/receipt.dart';
import 'package:kassa/rksv/card/card_signature_unit.dart';
import 'package:kassa/rksv/card/reader_transport.dart';
import 'package:kassa/rksv/rksv_journal.dart';
import 'package:kassa/rksv/rksv_secrets.dart';
import 'package:kassa/rksv/rksv_state.dart';
import 'package:kassa/rksv/signature_unit.dart';

import '../support/fake_card_reader.dart';
import '../support/rksv_rig.dart';
import '../support/sales.dart' show cart;

const _noCard = 'Keine Karte im Kartenleser.';
const _pinRejected = 'Die Karte hat die PIN abgelehnt.';
const _ground2 =
    'Grund: 2, Signatur- bzw. Siegelerstellung unmöglich oder fehlerhaft';
const _probeEnded =
    'Die Probe-Signatur wurde beendet, weil sie nicht mehr arbeiten konnte. '
    'Der Verkauf läuft normal weiter.';
const _ms = Duration(milliseconds: 1);

Future<Never> _noOnline(RksvChainRow chain, RksvCertificateRow cert) =>
    fail('online darf hier nicht gerufen werden');

/// Wartet bei `open` und bei jedem Austausch, der die Unterschrift trägt
/// (`2A 9E 9A`), je [delay]; alles andere geht gleich weiter.
class _SlowCardReader implements ReaderTransport {
  _SlowCardReader(this.inner);

  final FakeCardReader inner;
  Duration delay = Duration.zero;

  static bool _isSign(Uint8List? out) {
    if (out == null) return false;
    for (var i = 0; i + 2 < out.length; i++) {
      if (out[i] == 0x2A && out[i + 1] == 0x9E && out[i + 2] == 0x9A) {
        return true;
      }
    }
    return false;
  }

  @override
  Future<List<UsbDeviceInfo>> list() => inner.list();

  @override
  Future<Uint8List> open(String address) async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    return inner.open(address);
  }

  @override
  Future<Uint8List> exchange(Uint8List? out, {required Duration limit}) async {
    if (delay > Duration.zero && _isSign(out)) {
      await Future<void>.delayed(delay);
    }
    return inner.exchange(out, limit: limit);
  }

  @override
  Future<void> close() => inner.close();

  @override
  Future<TabletInfo> info() => inner.info();
}

/// Wartet in gedachter Zeit auf [f], ohne die Zeit weiterzudrehen.
T _await<T>(FakeAsync async, Future<T> f) {
  late T value;
  Object? error;
  var done = false;
  f.then(
    (v) {
      value = v;
      done = true;
    },
    onError: (Object e) {
      error = e;
      done = true;
    },
  );
  async.flushMicrotasks();
  if (!done) fail('Nicht fertig, ohne dass die Zeit weiterläuft.');
  if (error != null) throw error!;
  return value;
}

void main() {
  group('Kette card', () {
    late RksvRig rig;

    setUp(() async {
      rig = await RksvRig.open(card: rigCard());
      await rig.startCardChain();
    });
    tearDown(() => rig.close());

    FakeCard card() => rig.cardReader!.card!;

    test(
      'Karte da: der Bon ist von der Karte signiert, Kette besteht',
      () async {
        final sold = await rig.sell('s1', cart);
        expect(sold.rksv!.damaged, isFalse);
        // Startbeleg und Bon.
        expect(card().signCount, 2);
        expect((await rig.codeFieldsOf('s1'))[1], 'R1-AT1');
        expect((await rig.stateRow()).outageSince, isNull);
        await rig.verifyChain(1);
      },
    );

    test('Review Focus 1: Karte weg, Bon mit Vermerk und Grund im Stand; '
        'Karte wieder da, schon der nächste Bon signiert, davor der '
        'Sammelbeleg; Ausfall beendet', () async {
      await rig.sell('s1', cart);
      card().removed = true;
      rig.clock.value = DateTime(2026, 11, 18, 13, 10);
      final s2 = await rig.sell('s2', cart);
      expect(s2.rksv!.damaged, isTrue);
      var state = await rig.stateRow();
      expect(state.mode, 'live');
      expect(state.outageSince, rig.clock.now());
      expect(state.outageReason, _noCard);
      await pumpEventQueue();

      card().removed = false;
      rig.clock.value = DateTime(2026, 11, 18, 13, 20);
      final s3 = await rig.sell('s3', cart);
      expect(s3.rksv!.damaged, isFalse);
      expect(await rig.entryKinds(), [
        'start',
        'sale',
        'sale',
        'collective',
        'sale',
      ]);
      final entries = await rig.entries(1);
      expect(
        [for (final e in entries) e.damaged],
        [false, false, true, false, false],
      );
      state = await rig.stateRow();
      expect((state.outageSince, state.outageReason), (null, null));
      expect(state.mode, 'live');
      await rig.verifyChain(1);
      expect(await rig.journal.chainIsSound(1), isTrue);
    });

    test('Karte wieder da: "Nochmal prüfen" bringt den Sammelbeleg, ohne '
        'Verkauf', () async {
      card().removed = true;
      await rig.sell('s1', cart);
      expect((await rig.stateRow()).outageReason, _noCard);
      expect(await rig.service.retrySignature(staff: rig.chef), isFalse);
      card().removed = false;
      expect(await rig.service.retrySignature(staff: rig.chef), isTrue);
      expect(await rig.entryKinds(), ['start', 'sale', 'collective']);
      expect((await rig.entries(1)).last.damaged, isFalse);
      final state = await rig.stateRow();
      expect((state.outageSince, state.outageReason), (null, null));
      await rig.verifyChain(1);
    });

    test(
      'B1: Der Grund folgt dem letzten Versuch, der Beginn bleibt: erst '
      'keine Karte, dann die abgelehnte PIN (Nochmal prüfen und Bon)',
      () async {
        card().removed = true;
        await rig.sell('s1', cart);
        final since = (await rig.stateRow()).outageSince;
        expect((await rig.stateRow()).outageReason, _noCard);

        // Die Karte ist wieder da, aber die gespeicherte PIN gilt als
        // abgelehnt (C4): Der Halter schickt keine PIN mehr.
        card().removed = false;
        await rig.secrets.writeCardPinStatus(
          const CardPinStatus(rejected: true),
        );
        expect(await rig.service.retrySignature(staff: rig.chef), isFalse);
        var state = await rig.stateRow();
        expect(state.outageReason, _pinRejected);
        expect(state.outageSince, since);

        // Ein Bon: Der Sammelbeleg davor scheitert, der Grund bleibt wahr.
        await rig.secrets.writeCardPinStatus(const CardPinStatus());
        rig.cardSigner!.pinChanged();
        card().removed = true;
        rig.clock.value = rig.clock.value.add(const Duration(minutes: 5));
        await rig.sell('s2', cart);
        state = await rig.stateRow();
        expect(state.outageReason, _noCard);
        expect(state.outageSince, since);
        expect(await rig.entryKinds(), ['start', 'sale', 'sale']);
      },
    );

    test('B1: Leser abgezogen und ohne Erlaubnis wieder angesteckt: der Grund '
        'nennt die Erlaubnis', () async {
      final reader = rig.cardReader!;
      final device = reader.devices.single;
      reader.devices.clear();
      await rig.cardSigner!.release();
      await rig.sell('s1', cart);
      expect((await rig.stateRow()).outageReason, 'Kein Kartenleser gefunden.');

      reader.devices.add(FakeCardReader.readerDevice(granted: false));
      expect(await rig.service.retrySignature(staff: rig.chef), isFalse);
      expect(
        (await rig.stateRow()).outageReason,
        'Der Zugriff auf den Kartenleser ist nicht erlaubt.',
      );

      reader.devices
        ..clear()
        ..add(device);
      expect(await rig.service.retrySignature(staff: rig.chef), isTrue);
      final state = await rig.stateRow();
      expect((state.outageSince, state.outageReason), (null, null));
    });

    test('ein unerwarteter Fehler beim Bauen der Einheit ist im Betrieb ein '
        'Ausfall (Q6)', () async {
      rig.cardUnitError = StateError('kaputt');
      final sold = await rig.sell('s1', cart);
      expect(sold.rksv!.damaged, isTrue);
      final state = await rig.stateRow();
      expect(state.mode, 'live');
      expect(state.outageReason, 'Die Signatur ist ausgefallen.');
    });

    test('Ausfall über 48 Stunden: die Aufgabe nennt Grund 2', () async {
      card().removed = true;
      await rig.sell('s1', cart);
      rig.clock.value = rig.clock.value.add(const Duration(hours: 49));
      await rig.sell('s2', cart);
      final task = (await rig.rksv.current()).tasks.singleWhere(
        (t) => t.kind == RksvTaskKind.reportOutage,
      );
      expect(task.id, 'report-outage-1-2');
      expect(task.detail, '18.11.2026 13:05. $_ground2');
      expect(
        rksvTaskText(task),
        'Ausfall der Signatur bei FinanzOnline melden. Beginn: '
        '18.11.2026 13:05. Grund: 2, Signatur- bzw. Siegelerstellung '
        'unmöglich oder fehlerhaft.',
      );
    });
  });

  for (final unit in [RksvUnit.card, RksvUnit.cardTest]) {
    test('Frist (C5), ${unit.name}: eine Karte, die für Öffnen und '
        'Unterschrift 2 Sekunden braucht, signiert im Ausfall trotzdem; der '
        'Bon wartet nicht länger als 5 Sekunden', () {
      fakeAsync((async) {
        late _SlowCardReader slow;
        final rig = _await(
          async,
          RksvRig.open(
            card: rigCard(),
            wrapCardReader: (r) => slow = _SlowCardReader(r),
          ),
        );
        try {
          _await(async, rig.startCardChain(unit: unit));
          final card = rig.cardReader!.card!;
          card.removed = true;
          Receipt? first;
          rig.sell('s1', cart).then((r) => first = r);
          async.elapse(const Duration(seconds: 5));
          expect(first!.rksv!.damaged, isTrue);
          expect(_await(async, rig.stateRow()).outageReason, _noCard);
          // Das Aufwärmen nach dem Fehler ist vorbei.
          async.elapse(const Duration(seconds: 5));
          expect(rig.cardSigner!.ready, isFalse);

          card.removed = false;
          slow.delay = const Duration(seconds: 1);
          rig.clock.value = DateTime(2026, 11, 18, 13, 20);
          Receipt? second;
          rig.sell('s2', cart).then((r) => second = r);
          // Mit der Frist von 1 Sekunde wäre der Sammelbeleg hier schon
          // gescheitert.
          async.elapse(const Duration(seconds: 1) + _ms);
          expect(second, isNull);
          async.elapse(const Duration(seconds: 1));
          expect(second, isNull);
          async.elapse(const Duration(seconds: 3));
          expect(second, isNotNull);
          expect(second!.rksv!.damaged, isFalse);
          expect(_await(async, rig.entryKinds()), [
            'start',
            'sale',
            'collective',
            'sale',
          ]);
          final entries = _await(async, rig.entries(1));
          expect(
            [for (final e in entries) e.damaged],
            [false, true, false, false],
          );
          final state = _await(async, rig.stateRow());
          expect((state.outageSince, state.outageReason), (null, null));
          _await(async, rig.verifyChain(1));
        } finally {
          _await(async, rig.close());
        }
      });
    });
  }

  group('Kette cardTest', () {
    late RksvRig rig;

    setUp(() async {
      rig = await RksvRig.open(card: rigCard());
      await rig.startCardChain(unit: RksvUnit.cardTest);
    });
    tearDown(() => rig.close());

    test('Testbon von der Karte; Satz der Einheit ist ein Ausfall, die Probe '
        'läuft weiter', () async {
      final s1 = await rig.sell('s1', cart);
      expect(s1.rksv!.damaged, isFalse);
      expect((await rig.chainRow(1)).mode, 'probe');
      rig.cardReader!.card!.removed = true;
      final s2 = await rig.sell('s2', cart);
      expect(s2.rksv!.damaged, isTrue);
      final state = await rig.stateRow();
      expect((state.mode, state.chain, state.notice), ('probe', 1, null));
      expect(state.outageReason, _noCard);
      await rig.verifyChain(1);
    });

    test('StateError beim Bauen der Einheit beendet die Probe mit dem '
        'bekannten Hinweis; der Verkauf geht', () async {
      rig.cardUnitError = StateError('kaputt');
      final sold = await rig.sell('s1', cart);
      expect(sold.rksv, isNull);
      final state = await rig.stateRow();
      expect((state.mode, state.chain), ('off', null));
      expect(state.notice, _probeEnded);
      expect((await rig.chainRow(1)).endedAt, isNotNull);
    });

    test('Ausfall über 48 Stunden: die Aufgabe nennt Grund 2', () async {
      rig.cardReader!.card!.removed = true;
      await rig.sell('s1', cart);
      rig.clock.value = rig.clock.value.add(const Duration(hours: 49));
      await rig.sell('s2', cart);
      final task = (await rig.rksv.current()).tasks.singleWhere(
        (t) => t.kind == RksvTaskKind.reportOutage,
      );
      expect(task.detail, '18.11.2026 13:05. $_ground2');
    });
  });

  group('signatureUnitOf mit Karte', () {
    late RksvRig rig;

    setUp(() async => rig = await RksvRig.open(card: rigCard()));
    tearDown(() => rig.close());

    for (final unit in [RksvUnit.cardTest, RksvUnit.card]) {
      test('Kette ${unit.name} ruft card mit Kette und Zertifikat', () async {
        await rig.startCardChain(unit: unit);
        final calls = <(RksvChainRow, RksvCertificateRow)>[];
        final result = await signatureUnitOf(
          rig.db,
          rig.secrets,
          online: _noOnline,
          card: (chain, cert) async {
            calls.add((chain, cert));
            return rig.fake;
          },
        )(1);
        expect(result, same(rig.fake));
        final (chain, cert) = calls.single;
        expect((chain.chain, chain.unit, chain.zdaId), (1, unit.name, 'AT1'));
        expect(
          chain.cashBoxId,
          unit == RksvUnit.card
              ? RksvRig.cardCashBoxId
              : matches(RegExp(r'^[A-HJ-NP-Z2-9]{10}$')),
        );
        expect(cert.serialHex, 'cf36cd7808');
      });

      test('probeSignatureUnitOf lehnt ${unit.name} ab', () async {
        await rig.startCardChain(unit: unit);
        await expectLater(
          probeSignatureUnitOf(rig.db, rig.secrets)(1),
          throwsStateError,
        );
      });
    }

    test(
      'cardTest im Modus live: StateError, card wird nicht gerufen',
      () async {
        await rig.startCardChain(unit: RksvUnit.cardTest);
        await rig.db.customStatement("UPDATE rksv_chains SET mode = 'live'");
        await expectLater(
          signatureUnitOf(
            rig.db,
            rig.secrets,
            online: _noOnline,
            card: (chain, cert) => fail('card darf hier nicht gerufen werden'),
          )(1),
          throwsStateError,
        );
      },
    );

    test('die Einheit der Rig-Kette ist eine CardSignatureUnit', () async {
      await rig.startCardChain();
      final unit = await signatureUnitOf(
        rig.db,
        rig.secrets,
        online: _noOnline,
        card: (chain, cert) async => CardSignatureUnit(
          signer: rig.cardSigner!,
          zdaId: chain.zdaId,
          certificateDer: cert.certificate,
        ),
      )(1);
      final SignerInfo info = await unit.info();
      expect((info.zdaId, info.serialHex), ('AT1', 'cf36cd7808'));
    });
  });
}
