// Echter Betrieb (Plan S2b, Task 2, Q6): Im Zustand `live` wird jeder Fehler
// der Signatureinheit ein Ausfall, nie ein gescheiterter Verkauf. Nur ein
// Fehler der Datenbank lässt den Verkauf scheitern. K9 bleibt bei der Probe.

import 'dart:async';
import 'dart:typed_data';

import 'package:drift/native.dart' show SqliteException;
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/data/receipt_repository.dart';
import 'package:kassa/domain/receipt.dart';
import 'package:kassa/rksv/rksv_journal.dart';
import 'package:kassa/rksv/rksv_service.dart' show RksvProblem;
import 'package:kassa/rksv/rksv_state.dart';
import 'package:kassa/rksv/signature_unit.dart';

import '../support/fake_atrust.dart';
import '../support/fake_signature_unit.dart';
import '../support/rksv_rig.dart';
import '../support/sales.dart' show cart;

const _down = 'Die Signatur ist ausgefallen.';
const _noCredentials = 'Die Zugangsdaten von A-Trust fehlen.';
const _atrustFailed = 'Die Signatur von A-Trust ist gescheitert.';
const _ground3 =
    'Grund: 3, Ausfall der Verbindung zur Signaturerstellungseinheit';

/// Signiert, bis [broken] gesetzt ist; dann wirft [sign] einen [StateError]
/// (kein [SignatureFailure]).
class _BreakingUnit implements SignatureUnit {
  final FakeSignatureUnit _fake = FakeSignatureUnit();
  bool broken = false;

  @override
  Future<SignerInfo> info() => _fake.info();

  @override
  Future<Uint8List> sign(String signingInput) async {
    if (broken) throw StateError('Fehler in der Einheit');
    return _fake.sign(signingInput);
  }
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
  group('am nachgebauten A-Trust', () {
    late RksvRig rig;
    late FakeAtrust atrust;
    late int chain;

    setUp(() async {
      atrust = FakeAtrust();
      rig = await RksvRig.open(atrust: atrust);
      chain = await rig.seedLive();
      expect(atrust.requests, [
        'PUT /Session/u-beispiel',
        endsWith('/Sign/Hash'),
      ]);
      expect((await rig.entries(chain)).single.damaged, isFalse);
      atrust.requests.clear();
    });
    tearDown(() => rig.close());

    /// Ein Verkauf, der höchstens [limit] dauern darf.
    Future<Receipt> sellWithin(String id, Duration limit) async {
      final watch = Stopwatch()..start();
      final r = await rig.sell(id, cart);
      expect(watch.elapsed, lessThan(limit), reason: 'Dauer von $id');
      return r;
    }

    Future<void> expectOutage(String reason) async {
      final s1 = await sellWithin('s1', RksvJournal.signLimit);
      expect(s1.rksv!.damaged, isTrue);
      expect((await rig.entryOf('s1'))!.damaged, isTrue);
      final state = await rig.stateRow();
      expect(state.outageReason, reason);
      expect(state.outageSince, isNotNull);
      expect(state.mode, 'live');
      expect(state.chain, chain);

      // Während des Ausfalls: Sammelbeleg scheitert, Verkauf läuft weiter.
      final s2 = await sellWithin('s2', RksvJournal.signLimitDuringOutage);
      expect(s2.rksv!.damaged, isTrue);
      expect(await rig.entryKinds(chain), ['start', 'sale', 'sale']);
      expect(atrust.requests, isEmpty);
      expect(await rig.journal.chainIsSound(chain), isTrue);
      await rig.verifyChain(chain);
    }

    test(
      'Review Focus 4: keine Zugangsdaten: Verkauf gespeichert, Eintrag '
      'mit Ausfall, Grund der Einheit, keine Anfrage, unter der Frist',
      () async {
        await rig.secrets.writeAtrustCredentials(null);
        rig.liveKeeper!.forget();
        await expectOutage(_noCredentials);
      },
    );

    test('Review Focus 4: der geschützte Speicher liest die Zugangsdaten '
        'nicht: Verkauf gespeichert, Ausfall, keine Anfrage', () async {
      rig.secrets.failCredentialReads = true;
      rig.liveKeeper!.forget();
      await expectOutage(_atrustFailed);
    });

    test('Fehler der Datenbank beim Schreiben des Eintrags: der Verkauf '
        'scheitert, nichts bleibt zurück', () async {
      final receipts = await rig.count('receipts');
      final entries = await rig.count('rksv_entries');
      await rig.db.customStatement(
        'CREATE TEMP TRIGGER fail_entry BEFORE INSERT ON rksv_entries BEGIN '
        "SELECT RAISE(ABORT, 'Datenbank kaputt'); END",
      );
      await expectLater(rig.sell('s1', cart), throwsA(isA<SqliteException>()));
      expect(await rig.receipts.find('s1'), isNull);
      expect(await rig.count('receipts'), receipts);
      expect(await rig.count('rksv_entries'), entries);
      expect(await rig.count('payments'), 0);
      final state = await rig.stateRow();
      expect(
        (state.mode, state.chain, state.outageSince),
        ('live', chain, null),
      );
    });

    test('Ausfall über 48 Stunden an einer atrust-Kette: die Aufgabe nennt '
        'Grund 3', () async {
      await rig.secrets.writeAtrustCredentials(null);
      rig.liveKeeper!.forget();
      await rig.sell('s1', cart);
      rig.clock.value = rig.clock.value.add(const Duration(hours: 49));
      await rig.sell('s2', cart);
      final task = (await rig.rksv.current()).tasks.singleWhere(
        (t) => t.kind == RksvTaskKind.reportOutage,
      );
      expect(task.detail, '18.11.2026 13:05. $_ground3');
      expect(
        rksvTaskText(task),
        'Ausfall der Signatur bei FinanzOnline melden. Beginn: '
        '18.11.2026 13:05. $_ground3.',
      );
    });

    test('Storno: Bon der laufenden live-Kette geht und wird signiert, '
        'ein Bon aus der Probe-Zeit nicht', () async {
      final live = await rig.sell('l1', cart);
      final voided = await rig.receipts.voidReceipt(live.id, staff: rig.chef);
      expect(voided.kind, ReceiptKind.voided);
      expect(voided.rksv!.damaged, isFalse);
      expect((await rig.entryOf(voided.id))!.chain, chain);
      expect((await rig.codeFieldsOf(voided.id))[10], 'U1RP');
      await rig.verifyChain(chain);
    });

    test('chainIsSound: live-Kette mit Verkauf, Storno, Ausfall und '
        'Sammelbeleg', () async {
      await rig.sell('s1', cart);
      await rig.receipts.voidReceipt('s1', staff: rig.chef);
      atrust.signStatus = 500;
      final s2 = await rig.sell('s2', cart);
      expect(s2.rksv!.damaged, isTrue);
      atrust.signStatus = null;
      final s3 = await rig.sell('s3', cart);
      expect(s3.rksv!.damaged, isFalse);
      expect(await rig.entryKinds(chain), [
        'start',
        'sale',
        'voided',
        'sale',
        'collective',
        'sale',
      ]);
      expect((await rig.stateRow()).outageSince, isNull);
      expect(await rig.journal.chainIsSound(chain), isTrue);
      await rig.verifyChain(chain);
    });
  });

  test('Storno eines Bons aus der Probe-Zeit im Zustand live: '
      'NotInCurrentChainException, nichts wird storniert', () async {
    final atrust = FakeAtrust();
    final rig = await RksvRig.open(atrust: atrust);
    addTearDown(rig.close);
    await rig.service.enableProbe(staff: rig.chef);
    await rig.sell('p1', cart);
    final chain = await rig.seedLive();
    final before = await rig.count('receipts');
    await expectLater(
      rig.receipts.voidReceipt('p1', staff: rig.chef),
      throwsA(isA<NotInCurrentChainException>()),
    );
    expect(await rig.count('receipts'), before);
    expect(await rig.entryKinds(chain), ['start']);
  });

  test(
    'Online-Probe (atrustTest): Ausfall über 48 Stunden nennt Grund 3',
    () async {
      final atrust = FakeAtrust();
      final rig = await RksvRig.open(atrust: atrust);
      addTearDown(rig.close);
      await rig.startAtrustTest(atrust);
      atrust.offline = true;
      await rig.sell('s1', cart);
      rig.clock.value = rig.clock.value.add(const Duration(hours: 49));
      await rig.sell('s2', cart);
      expect(
        (await rig.tasks()).where((t) => t.$2 == RksvTaskKind.reportOutage),
        [
          (
            'report-outage-1-1',
            RksvTaskKind.reportOutage,
            '18.11.2026 13:05. $_ground3',
          ),
        ],
      );
    },
  );

  test(
    'Probe-Kette: Ausfall über 48 Stunden behält den bisherigen Text',
    () async {
      final rig = await RksvRig.open();
      addTearDown(rig.close);
      await rig.service.enableProbe(staff: rig.chef);
      rig.fake.mode = FakeMode.error;
      await rig.sell('s1', cart);
      rig.clock.value = rig.clock.value.add(const Duration(hours: 49));
      await rig.sell('s2', cart);
      expect(
        (await rig.tasks()).where((t) => t.$2 == RksvTaskKind.reportOutage),
        [('report-outage-1-2', RksvTaskKind.reportOutage, '18.11.2026 13:05')],
      );
    },
  );

  group('Fehler außerhalb von SignatureFailure', () {
    late RksvRig rig;
    late _BreakingUnit unit;
    var brokenUnitOf = false;

    setUp(() async {
      unit = _BreakingUnit();
      brokenUnitOf = false;
      rig = await RksvRig.open(
        unitOf: (db, secrets) => (_) async {
          if (brokenUnitOf) throw StateError('Einheit nicht zu bauen');
          return unit;
        },
      );
    });
    tearDown(() => rig.close());

    Future<void> expectLiveOutage() async {
      final s1 = await rig.sell('s1', cart);
      expect(s1.rksv!.damaged, isTrue);
      var state = await rig.stateRow();
      expect(state.outageReason, _down);
      expect(state.mode, 'live');
      expect(state.chain, 1);
      expect(state.notice, isNull);
      expect((await rig.chainRow(1)).endedAt, isNull);
      // Der nächste Verkauf: Sammelbeleg scheitert ohne K9, Bon mit Vermerk.
      final s2 = await rig.sell('s2', cart);
      expect(s2.rksv!.damaged, isTrue);
      state = await rig.stateRow();
      expect((state.mode, state.chain), ('live', 1));
      expect(await rig.entryKinds(1), ['sale', 'sale']);
      await rig.verifyChain(1);
    }

    test(
      'unitOf wirft im Zustand live einen StateError: Ausfall, kein K9',
      () async {
        await rig.startLive();
        brokenUnitOf = true;
        await expectLiveOutage();
      },
    );

    test(
      'unit.sign wirft im Zustand live einen StateError: Ausfall, kein K9',
      () async {
        await rig.startLive();
        unit.broken = true;
        await expectLiveOutage();
      },
    );

    test('Sammelbeleg im Zustand live, unitOf wirft: kein Sammelbeleg, '
        'der Ausfall dauert an, die Kette läuft weiter', () async {
      await rig.startLive();
      unit.broken = true;
      await rig.sell('s1', cart);
      brokenUnitOf = true;
      expect(await rig.receipts.retryCollective(staff: rig.chef), isFalse);
      final state = await rig.stateRow();
      expect((state.mode, state.chain, state.outageReason), ('live', 1, _down));
      brokenUnitOf = false;
      unit.broken = false;
      expect(await rig.receipts.retryCollective(staff: rig.chef), isTrue);
      expect(await rig.entryKinds(1), ['sale', 'collective']);
      await rig.verifyChain(1);
    });

    test('derselbe Fehler im Zustand probe: K9 wie bisher', () async {
      await rig.service.enableProbe(staff: rig.chef);
      brokenUnitOf = true;
      final s1 = await rig.sell('s1', cart);
      expect(s1.rksv, isNull);
      final state = await rig.stateRow();
      expect(state.mode, 'off');
      expect(state.chain, isNull);
      expect(state.notice, contains('Probe-Signatur wurde beendet'));
      expect((await rig.chainRow(1)).endedAt, isNotNull);
    });
  });

  test('unitOf antwortet im Zustand live nicht: nach der Frist ein Ausfall '
      'mit dem Satz der Frist, der Verkauf ist gespeichert', () {
    fakeAsync((async) {
      var hang = false;
      final rig = _await(
        async,
        RksvRig.open(
          unitOf: (db, secrets) => (_) async {
            if (hang) await Completer<void>().future;
            return FakeSignatureUnit();
          },
        ),
      );
      try {
        _await(async, rig.startLive());
        hang = true;
        Receipt? sold;
        rig.sell('s1', cart).then((r) => sold = r);
        async.elapse(RksvJournal.signLimit - const Duration(milliseconds: 1));
        expect(sold, isNull);
        async.elapse(const Duration(milliseconds: 2));
        expect(sold!.rksv!.damaged, isTrue);
        final state = _await(async, rig.stateRow());
        expect(
          (state.mode, state.chain, state.outageReason),
          ('live', 1, 'Die Signatur hat nicht geantwortet.'),
        );
      } finally {
        _await(async, rig.close());
      }
    });
  });

  group('AES-Schlüssel einer live-Kette im Arbeitsspeicher (Q17)', () {
    test('Schlüssel im Speicher, dann failReads: Verkauf, Storno und '
        'Nullbeleg signiert A-Trust, die Kette ist in Ordnung', () async {
      final atrust = FakeAtrust();
      final rig = await RksvRig.open(atrust: atrust);
      addTearDown(rig.close);
      final chain = await rig.seedLive();
      atrust.requests.clear();
      rig.secrets.failReads = true;
      final s1 = await rig.sell('s1', cart);
      expect(s1.rksv!.damaged, isFalse);
      final v = await rig.receipts.voidReceipt('s1', staff: rig.chef);
      expect(v.rksv!.damaged, isFalse);
      final z = await rig.service.zeroReceipt(staff: rig.chef);
      expect(z.rksv!.damaged, isFalse);
      expect(
        atrust.requests.where((r) => r.endsWith('/Sign/Hash')),
        hasLength(3),
      );
      expect((await rig.stateRow()).outageSince, isNull);
      expect(await rig.journal.chainIsSound(chain), isTrue);
      rig.secrets.failReads = false;
      await rig.verifyChain(chain);
    });

    test('Schlüssel im Speicher, dann hangReads: der Verkauf ist unter der '
        'Frist fertig und signiert', () async {
      final atrust = FakeAtrust();
      final rig = await RksvRig.open(atrust: atrust);
      addTearDown(rig.close);
      final chain = await rig.seedLive();
      rig.secrets.hangReads = true;
      final watch = Stopwatch()..start();
      final s1 = await rig.sell('s1', cart);
      expect(watch.elapsed, lessThan(RksvJournal.signLimit));
      expect(s1.rksv!.damaged, isFalse);
      expect((await rig.stateRow()).outageSince, isNull);
      expect(await rig.journal.chainIsSound(chain), isTrue);
    });

    test('Sammelbeleg nach einem Ausfall braucht den Speicher nicht', () async {
      final atrust = FakeAtrust();
      final rig = await RksvRig.open(atrust: atrust);
      addTearDown(rig.close);
      final chain = await rig.seedLive();
      rig.secrets.failReads = true;
      atrust.signStatus = 500;
      expect((await rig.sell('s1', cart)).rksv!.damaged, isTrue);
      atrust.signStatus = null;
      expect(await rig.service.retrySignature(staff: rig.chef), isTrue);
      expect(await rig.entryKinds(chain), ['start', 'sale', 'collective']);
      expect(await rig.journal.chainIsSound(chain), isTrue);
    });

    test('primeLiveKey liest den Schlüssel einmal; danach ist failReads '
        'egal', () async {
      final rig = await RksvRig.open();
      addTearDown(rig.close);
      await rig.startLive();
      final before = rig.secrets.aesKeyReads;
      await rig.journal.primeLiveKey();
      expect(rig.secrets.aesKeyReads, before + 1);
      await rig.journal.primeLiveKey();
      expect(rig.secrets.aesKeyReads, before + 1);
      rig.secrets.failReads = true;
      final s1 = await rig.sell('s1', cart);
      expect(s1.rksv!.damaged, isFalse);
      expect(rig.secrets.aesKeyReads, before + 1);
      expect(await rig.journal.chainIsSound(1), isTrue);
    });

    test('primeLiveKey wirft nicht, wenn der Speicher scheitert, und liest '
        'beim nächsten Mal wieder', () async {
      final rig = await RksvRig.open();
      addTearDown(rig.close);
      await rig.startLive();
      rig.secrets.failReads = true;
      await rig.journal.primeLiveKey();
      rig.secrets.failReads = false;
      await rig.journal.primeLiveKey();
      rig.secrets.failReads = true;
      expect((await rig.sell('s1', cart)).rksv!.damaged, isFalse);
    });

    test('primeLiveKey ohne live-Kette liest nichts', () async {
      final rig = await RksvRig.open();
      addTearDown(rig.close);
      await rig.journal.primeLiveKey();
      expect(rig.secrets.aesKeyReads, 0);
      await rig.service.enableProbe(staff: rig.chef);
      final reads = rig.secrets.aesKeyReads;
      await rig.journal.primeLiveKey();
      expect(rig.secrets.aesKeyReads, reads);
    });

    test('Probe-Kette mit failReads: K9 wie bisher, der Schlüssel wird '
        'jedes Mal gelesen', () async {
      final rig = await RksvRig.open();
      addTearDown(rig.close);
      await rig.service.enableProbe(staff: rig.chef);
      await rig.sell('s1', cart);
      final reads = rig.secrets.aesKeyReads;
      await rig.sell('s2', cart);
      expect(rig.secrets.aesKeyReads, greaterThan(reads));
      rig.secrets.failReads = true;
      final s3 = await rig.sell('s3', cart);
      expect(s3.rksv, isNull);
      final state = await rig.stateRow();
      expect((state.mode, state.chain), ('off', null));
      expect(state.notice, contains('Probe-Signatur wurde beendet'));
    });

    test('Rest (Q17): Schlüssel nie gelesen, Speicher scheitert: der Verkauf '
        'scheitert wie bisher, nichts bleibt zurück', () async {
      final rig = await RksvRig.open();
      addTearDown(rig.close);
      await rig.startLive();
      rig.secrets.failReads = true;
      await expectLater(
        rig.sell('s1', cart),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'Der sichere Speicher ist nicht lesbar.',
          ),
        ),
      );
      expect(await rig.receipts.find('s1'), isNull);
      expect(await rig.count('receipts'), 0);
      expect((await rig.stateRow()).mode, 'live');
    });

    test('Rest (Q17): Schlüssel nie gelesen, Speicher hängt: der Verkauf '
        'scheitert nach der Frist wie bisher', () {
      fakeAsync((async) {
        final rig = _await(async, RksvRig.open());
        try {
          _await(async, rig.startLive());
          rig.secrets.hangReads = true;
          Object? error;
          rig
              .sell('s1', cart)
              .then<void>((_) {}, onError: (Object e) => error = e);
          async.elapse(RksvJournal.signLimit + const Duration(milliseconds: 1));
          expect(
            error,
            isA<StateError>().having(
              (e) => e.message,
              'message',
              'Der geschützte Speicher hat nicht geantwortet.',
            ),
          );
          rig.secrets.hangReads = false;
          expect(_await(async, rig.count('receipts')), 0);
        } finally {
          _await(async, rig.close());
        }
      });
    });
  });

  group('Schlüssel nicht lesbar (Schlussprüfung C1)', () {
    const keyUnreadable =
        'Das Tablet konnte den Schlüssel nicht lesen. Bitte nichts löschen '
        'und die App nicht neu installieren.';
    final isKeyUnreadable = isA<RksvProblem>().having(
      (p) => p.message,
      'message',
      keyUnreadable,
    );

    for (final zero in [false, true]) {
      final what = zero ? 'Nullbeleg' : 'Außerbetriebnahme';
      test('$what, Speicher scheitert: der Satz, die Kassa bleibt in '
          'Betrieb, nichts geschrieben', () async {
        final rig = await RksvRig.open();
        addTearDown(rig.close);
        await rig.startLive();
        rig.secrets.failReads = true;
        await expectLater(
          zero
              ? rig.service.zeroReceipt(staff: rig.chef)
              : rig.service.decommission(staff: rig.chef),
          throwsA(isKeyUnreadable),
        );
        final state = await rig.stateRow();
        expect((state.mode, state.chain), ('live', 1));
        expect((await rig.chainRow(1)).endedAt, isNull);
        expect(await rig.count('receipts'), 0);
        expect(await rig.count('rksv_entries'), 0);
      });

      test('$what, Speicher hängt: nach der Frist der Satz, die Kassa '
          'bleibt in Betrieb', () {
        fakeAsync((async) {
          final rig = _await(async, RksvRig.open());
          try {
            _await(async, rig.startLive());
            rig.secrets.hangReads = true;
            Object? error;
            (zero
                    ? rig.service.zeroReceipt(staff: rig.chef)
                    : rig.service.decommission(staff: rig.chef))
                .then<void>((_) {}, onError: (Object e) => error = e);
            async.elapse(
              RksvJournal.signLimit + const Duration(milliseconds: 1),
            );
            expect(error, isKeyUnreadable);
            rig.secrets.hangReads = false;
            expect(_await(async, rig.stateRow()).mode, 'live');
            expect(_await(async, rig.count('receipts')), 0);
          } finally {
            _await(async, rig.close());
          }
        });
      });
    }

    test(
      'ein Verkauf scheitert weiter wie bisher (kein RksvProblem)',
      () async {
        final rig = await RksvRig.open();
        addTearDown(rig.close);
        await rig.startLive();
        rig.secrets.failReads = true;
        await expectLater(
          rig.sell('s1', cart),
          throwsA(isNot(isA<RksvProblem>())),
        );
      },
    );
  });
}
