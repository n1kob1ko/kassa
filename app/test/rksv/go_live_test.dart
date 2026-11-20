// Einrichtung, Inbetriebnahme und Außerbetriebnahme im Service (Plan S2b,
// Task 3, Q2, Q7, Q8, Q15). Angesprochen wird nur der nachgebaute A-Trust.

import 'dart:convert';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/data/database.dart';
import 'package:kassa/data/outbox_repository.dart';
import 'package:kassa/domain/receipt.dart';
import 'package:kassa/rksv/dep_export.dart';
import 'package:kassa/rksv/online/atrust_client.dart';
import 'package:kassa/rksv/online/connection_check.dart';
import 'package:kassa/rksv/rksv_secrets.dart';
import 'package:kassa/rksv/rksv_service.dart';
import 'package:kassa/rksv/rksv_state.dart';
import 'package:kassa/sync/push_wire.dart';

import '../support/fake_atrust.dart';
import '../support/rksv_rig.dart';
import '../support/sales.dart' show cart;

const _due = '25.11.2026';

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
  late RksvRig rig;
  late FakeAtrust atrust;

  setUp(() async {
    atrust = FakeAtrust();
    rig = await RksvRig.open(atrust: atrust);
    await rig.secrets.writeAtrustCredentials(RksvRig.liveCredentials);
  });
  tearDown(() => rig.close());

  /// "Verbindung prüfen" am Testsystem mit dem Halter der Bons.
  Future<ConnectionFacts> testFacts() async {
    final result = await ConnectionCheck(
      client: AtrustClient(atrust.client, AtrustSystem.test),
      keeper: rig.keeper!,
      user: () async => atrustTestUser,
      clock: rig.clock,
    ).run(chefTapped: false);
    return result.facts!;
  }

  Future<String> receiptKind(String id) async =>
      (await rig.receipts.byId(id)).kind.name;

  group('prepareSetup', () {
    test('zweimal: dieselbe Kennung, derselbe Schlüssel; schreibt nichts in '
        'die Datenbank', () async {
      final facts = await rig.liveFacts();
      final first = await rig.service.prepareSetup(facts: facts);
      final second = await rig.service.prepareSetup(facts: facts);
      expect(first.cashBoxId, matches(RegExp(r'^[A-HJ-NP-Z2-9]{10}$')));
      expect(base64.decode(first.aesKeyBase64), hasLength(32));
      expect(second.cashBoxId, first.cashBoxId);
      expect(second.aesKeyBase64, first.aesKeyBase64);
      final pending = (await rig.secrets.pendingSetup())!;
      expect(pending.cashBoxId, first.cashBoxId);
      expect(base64.encode(pending.aesKey), first.aesKeyBase64);
      expect(
        first.kind,
        'Hardware-Sicherheitsmodul (HSM) eines Dienstleisters',
      );
      expect(first.provider, 'AT1 = A-TRUST');
      expect(first.certSerialHex, '2159b9f6');
      expect(first.certSerialDecimal, '559528438');
      expect(first.aesChecksum, hasLength(4));
      expect(await rig.count('rksv_chains'), 0);
      expect(await rig.count('receipts'), 0);
      final state = await rig.stateRow();
      expect((state.mode, state.chain, state.tasks), ('off', null, '[]'));
    });

    test('nach einem neuen Service (neuer Start, gleicher Speicher) wieder '
        'dieselben', () async {
      final facts = await rig.liveFacts();
      final first = await rig.service.prepareSetup(facts: facts);
      final again = RksvService(rig.db, rig.secrets, rig.receipts, rig.clock);
      final second = await again.prepareSetup(facts: facts);
      expect(second.cashBoxId, first.cashBoxId);
      expect(second.aesKeyBase64, first.aesKeyBase64);
      expect(second.aesChecksum, first.aesChecksum);
    });

    test('Angaben vom Testsystem: StateError, nichts angelegt', () async {
      final facts = await testFacts();
      await expectLater(
        rig.service.prepareSetup(facts: facts),
        throwsStateError,
      );
      expect(await rig.secrets.pendingSetup(), isNull);
    });

    test('im Zustand live: StateError', () async {
      await rig.seedLive();
      await expectLater(
        rig.service.prepareSetup(facts: await rig.liveFacts()),
        throwsStateError,
      );
    });

    test('geschützter Speicher schreibt nicht: RksvProblem, kein '
        'PendingSetup', () async {
      final facts = await rig.liveFacts();
      rig.secrets.failWrites = true;
      await expectLater(
        rig.service.prepareSetup(facts: facts),
        throwsA(
          isA<RksvProblem>().having(
            (p) => p.message,
            'message',
            'Das Tablet konnte den Schlüssel nicht sicher speichern.',
          ),
        ),
      );
      rig.secrets.failWrites = false;
      expect(await rig.secrets.pendingSetup(), isNull);
    });

    test('geschützter Speicher liest nicht: RksvProblem, ein vorhandenes '
        'PendingSetup bleibt', () async {
      final facts = await rig.liveFacts();
      final first = await rig.service.prepareSetup(facts: facts);
      rig.secrets.failReads = true;
      await expectLater(
        rig.service.prepareSetup(facts: facts),
        throwsA(isA<RksvProblem>()),
      );
      rig.secrets.failReads = false;
      expect((await rig.secrets.pendingSetup())!.cashBoxId, first.cashBoxId);
    });
  });

  group('goLive', () {
    test('Review Focus 3: Angaben abgeschrieben, drei Tage später in '
        'Betrieb: Kennung und AES-Schlüssel der Kette sind die gezeigten; '
        'PendingSetup ist weg', () async {
      final facts = await rig.liveFacts();
      final shown = await rig.service.prepareSetup(facts: facts);
      rig.clock.value = rig.clock.value.add(const Duration(days: 3));
      // Ein neuer Start der App dazwischen.
      final later = RksvService(rig.db, rig.secrets, rig.receipts, rig.clock);
      await later.goLive(staff: rig.chef, facts: facts);
      final chain = (await rig.stateRow()).chain!;
      expect((await rig.chainRow(chain)).cashBoxId, shown.cashBoxId);
      expect(
        base64.encode((await rig.secrets.aesKey(chain))!),
        shown.aesKeyBase64,
      );
      expect(await rig.secrets.pendingSetup(), isNull);
      await rig.verifyChain(chain);
    });

    test('aus off: Startbeleg von A-Trust signiert, Stand live, Einheit '
        'atrust, zwei Aufgaben mit Datum, Zähler 0', () async {
      final facts = await rig.liveFacts();
      final shown = await rig.service.prepareSetup(facts: facts);
      atrust.requests.clear();
      final start = await rig.service.goLive(staff: rig.chef, facts: facts);

      expect(start.kind, ReceiptKind.start);
      expect(start.rksv!.damaged, isFalse);
      expect(start.rksv!.probe, isFalse);
      expect(atrust.requests, [
        'PUT /Session/u-beispiel',
        endsWith('/Sign/Hash'),
      ]);

      final chain = await rig.chainRow(1);
      expect(
        (chain.mode, chain.unit, chain.zdaId, chain.certSerial, chain.endedAt),
        ('live', 'atrust', 'AT1', '2159b9f6', null),
      );
      expect(chain.cashBoxId, shown.cashBoxId);
      expect(chain.startedAt, rig.clock.now());
      final cert = await (rig.db.select(
        rig.db.rksvCertificateRows,
      )..where((t) => t.serialHex.equals('2159b9f6'))).getSingle();
      expect(issuersBase64(cert), [
        for (final i in facts.certificate.issuersDer) base64.encode(i),
      ]);

      final state = await rig.rksv.current();
      expect(
        (state.mode, state.unit, state.chain, state.counterCents),
        (RksvMode.live, RksvUnit.atrust, 1, 0),
      );
      expect(state.decommissioned, isFalse);
      expect(state.outage, isFalse);
      expect(await rig.tasks(), [
        ('register-finanzonline-1', RksvTaskKind.registerFinanzOnline, _due),
        ('check-start-1', RksvTaskKind.checkStart, ''),
      ]);
      expect(
        rksvTaskText(state.tasks.first),
        'Signatureinheit und Kassa bei FinanzOnline anmelden, bis $_due.',
      );
      expect(await rig.entryKinds(1), ['start']);
      await rig.verifyChain(1);
      expect(await rig.journal.chainIsSound(1), isTrue);
    });

    test('der AES-Schlüssel ist gleich im Journal (Q17): danach ist der '
        'Speicher egal', () async {
      await rig.seedLive();
      rig.secrets.failReads = true;
      final s1 = await rig.sell('s1', cart);
      expect(s1.rksv!.damaged, isFalse);
      expect(await rig.journal.chainIsSound(1), isTrue);
    });

    test('aus laufender Probe: Schlussbeleg der Probe, Kette beendet, '
        'Aufgaben der Probe weg, neue Kette live', () async {
      await rig.service.enableProbe(staff: rig.chef);
      await rig.sell('p1', cart);
      expect(await rig.tasks(), [
        ('check-start-1', RksvTaskKind.checkStart, ''),
      ]);
      rig.clock.value = DateTime(2026, 11, 18, 14);
      final chain = await rig.seedLive();

      expect(chain, 2);
      expect(await rig.entryKinds(1), ['start', 'sale', 'closing']);
      expect((await rig.chainRow(1)).endedAt, DateTime(2026, 11, 18, 14));
      await rig.verifyChain(1);
      expect((await rig.chainRow(2)).mode, 'live');
      expect(await rig.entryKinds(2), ['start']);
      expect(await rig.tasks(), [
        ('register-finanzonline-2', RksvTaskKind.registerFinanzOnline, _due),
        ('check-start-2', RksvTaskKind.checkStart, ''),
      ]);
      await rig.verifyChain(2);
    });

    test('aus laufender Online-Probe: Schlussbeleg am Testsystem, Kette '
        'beendet, neue Kette live', () async {
      await rig.service.enableOnlineProbe(
        staff: rig.chef,
        facts: await testFacts(),
      );
      final chain = await rig.seedLive();
      expect(chain, 2);
      expect(await rig.entryKinds(1), ['start', 'closing']);
      expect([for (final e in await rig.entries(1)) e.damaged], [false, false]);
      expect((await rig.chainRow(1)).endedAt, isNotNull);
      final live = await rig.chainRow(2);
      expect((live.mode, live.unit), ('live', 'atrust'));
      expect(
        [for (final t in await rig.tasks()) t.$1],
        ['register-finanzonline-2', 'check-start-2'],
      );
      await rig.verifyChain(1);
      await rig.verifyChain(2);
    });

    group('Review Focus 1: der Startbeleg scheitert', () {
      late ConnectionFacts facts;
      late RksvStateRow before;
      late int receiptsBefore;

      setUp(() async {
        facts = await rig.liveFacts();
        await rig.service.prepareSetup(facts: facts);
        await rig.service.enableProbe(staff: rig.chef);
        await rig.sell('p1', cart);
        before = await rig.stateRow();
        receiptsBefore = await rig.count('receipts');
      });

      Future<void> expectAsBefore() async {
        final after = await rig.stateRow();
        expect(after.toJson(), before.toJson());
        expect(after.mode, 'probe');
        expect(await rig.count('rksv_chains'), 1);
        expect((await rig.chainRow(1)).endedAt, isNull);
        expect(await rig.entryKinds(1), ['start', 'sale']);
        expect(await rig.count('receipts'), receiptsBefore);
        expect(await rig.secrets.pendingSetup(), isNotNull);
        // Die Probe läuft weiter.
        final p2 = await rig.sell('p2', cart);
        expect(p2.rksv!.probe, isTrue);
        expect(await rig.entryKinds(1), ['start', 'sale', 'sale']);
        await rig.verifyChain(1);
      }

      test('500 beim Signieren: RksvProblem mit dem Satz der Einheit, alles '
          'wie vorher', () async {
        atrust.signStatus = 500;
        await expectLater(
          rig.service.goLive(staff: rig.chef, facts: facts),
          throwsA(
            isA<RksvProblem>().having(
              (p) => p.message,
              'message',
              'A-Trust meldet einen Fehler.',
            ),
          ),
        );
        await expectAsBefore();
      });

      test('falsche Signatur: RksvProblem, alles wie vorher', () async {
        atrust.wrongSignature = true;
        await expectLater(
          rig.service.goLive(staff: rig.chef, facts: facts),
          throwsA(
            isA<RksvProblem>().having(
              (p) => p.message,
              'message',
              'Die Signatur von A-Trust passt nicht zum Zertifikat.',
            ),
          ),
        );
        await expectAsBefore();
      });

      test(
        'kein Netz: RksvProblem("Kein Internet."), alles wie vorher',
        () async {
          atrust.offline = true;
          await expectLater(
            rig.service.goLive(staff: rig.chef, facts: facts),
            throwsA(
              isA<RksvProblem>().having(
                (p) => p.message,
                'message',
                'Kein Internet.',
              ),
            ),
          );
          atrust.offline = false;
          await expectAsBefore();
        },
      );

      test('danach mit neuen Angaben in Betrieb: der Startbeleg trägt den '
          'neuen Schlüssel, nicht den des gescheiterten Versuchs', () async {
        atrust.signStatus = 500;
        await expectLater(
          rig.service.goLive(staff: rig.chef, facts: facts),
          throwsA(isA<RksvProblem>()),
        );
        atrust.signStatus = null;
        await rig.secrets.writePendingSetup(null);
        await rig.service.disableProbe(staff: rig.chef);
        await rig.service.prepareSetup(facts: facts);
        await rig.service.goLive(staff: rig.chef, facts: facts);
        expect((await rig.chainRow(2)).mode, 'live');
        await rig.verifyChain(2);
        expect(await rig.journal.chainIsSound(2), isTrue);
      });
    });

    test('Review Focus 1: A-Trust antwortet nicht: nach der Frist '
        'RksvProblem, alles wie vorher, die Probe läuft weiter', () {
      fakeAsync((async) {
        final a = FakeAtrust();
        final r = _await(async, RksvRig.open(atrust: a));
        try {
          _await(
            async,
            r.secrets.writeAtrustCredentials(RksvRig.liveCredentials),
          );
          final facts = _await(async, r.liveFacts());
          _await(async, r.service.prepareSetup(facts: facts));
          _await(async, r.service.enableProbe(staff: r.chef));
          final before = _await(async, r.stateRow());
          a.holdLogins = true;
          Object? error;
          r.service
              .goLive(staff: r.chef, facts: facts)
              .then<void>((_) {}, onError: (Object e) => error = e);
          async.elapse(const Duration(seconds: 6));
          expect(
            error,
            isA<RksvProblem>().having(
              (p) => p.message,
              'message',
              'Die Signatur hat nicht geantwortet.',
            ),
          );
          final after = _await(async, r.stateRow());
          expect(after.toJson(), before.toJson());
          expect(_await(async, r.count('rksv_chains')), 1);
          expect(_await(async, r.entryKinds(1)), ['start']);
          expect(_await(async, r.count('receipts')), 1);
          expect(_await(async, r.secrets.pendingSetup()), isNotNull);
          for (final held in a.heldLogins) {
            held.complete(500);
          }
          async.flushMicrotasks();
        } finally {
          _await(async, r.close());
        }
      });
    });

    test('ohne PendingSetup: StateError, keine Anfrage', () async {
      final facts = await rig.liveFacts();
      atrust.requests.clear();
      await expectLater(
        rig.service.goLive(staff: rig.chef, facts: facts),
        throwsStateError,
      );
      expect(atrust.requests, isEmpty);
      expect(await rig.count('rksv_chains'), 0);
      expect(await rig.count('receipts'), 0);
    });

    test('mit Angaben vom Testsystem: StateError, keine Anfrage', () async {
      final live = await rig.liveFacts();
      await rig.service.prepareSetup(facts: live);
      final facts = await testFacts();
      atrust.requests.clear();
      await expectLater(
        rig.service.goLive(staff: rig.chef, facts: facts),
        throwsStateError,
      );
      expect(atrust.requests, isEmpty);
      expect(await rig.count('rksv_chains'), 0);
      expect(await rig.secrets.pendingSetup(), isNotNull);
    });

    test('im Zustand live: StateError, keine Anfrage', () async {
      await rig.seedLive();
      final facts = await rig.liveFacts();
      await rig.secrets.writePendingSetup(
        PendingSetup(
          cashBoxId: 'BSPIMNEU22',
          aesKey: Uint8List.fromList(List.filled(32, 7)),
        ),
      );
      atrust.requests.clear();
      await expectLater(
        rig.service.goLive(staff: rig.chef, facts: facts),
        throwsStateError,
      );
      expect(atrust.requests, isEmpty);
      expect(await rig.count('rksv_chains'), 1);
      expect(await rig.secrets.pendingSetup(), isNotNull);
    });

    test('PendingSetup löschen scheitert nach der Inbetriebnahme: ohne '
        'Folgen', () async {
      final facts = await rig.liveFacts();
      await rig.service.prepareSetup(facts: facts);
      rig.secrets.failPendingSetupWrites = true;
      final start = await rig.service.goLive(staff: rig.chef, facts: facts);
      expect(start.rksv!.damaged, isFalse);
      final state = await rig.rksv.current();
      expect((state.mode, state.chain), (RksvMode.live, 1));
      expect(await rig.secrets.pendingSetup(), isNotNull);
      expect((await rig.sell('s1', cart)).rksv!.damaged, isFalse);

      // Nach "außer Betrieb" gilt das liegengebliebene als keins: goLive
      // ohne neue Angaben scheitert, prepareSetup legt eine neue Kennung an.
      await rig.service.decommission(staff: rig.chef);
      await expectLater(
        rig.service.goLive(staff: rig.chef, facts: facts),
        throwsStateError,
      );
      rig.secrets.failPendingSetupWrites = false;
      final next = await rig.service.prepareSetup(facts: facts);
      expect(next.cashBoxId, isNot((await rig.chainRow(1)).cashBoxId));
    });
  });

  group('eine Probe nach "außer Betrieb" lässt die Aufgaben der live-Kette '
      'stehen', () {
    /// Kette 1 live mit offenen Aufgaben (anmelden, Startbeleg, Ausfall
    /// über 48 Stunden mit Beginn und Ende), dann außer Betrieb. Liefert
    /// die Ids der offenen Aufgaben danach.
    Future<List<String>> decommissioned() async {
      await rig.seedLive();
      atrust.signStatus = 500;
      await rig.sell('s1', cart);
      rig.clock.value = rig.clock.value.add(const Duration(hours: 49));
      await rig.sell('s2', cart);
      atrust.signStatus = null;
      expect(await rig.service.retrySignature(staff: rig.chef), isTrue);
      await rig.service.decommission(staff: rig.chef);
      final ids = [for (final t in await rig.tasks()) t.$1];
      expect(ids, [
        'register-finanzonline-1',
        'check-start-1',
        'report-outage-1-2',
        'report-outage-end-1-4',
        'report-decommission-1',
        'backup-decommission-1',
      ]);
      return ids;
    }

    Future<List<String>> openIds() async => [
      for (final t in await rig.tasks()) t.$1,
    ];

    test('disableProbe', () async {
      final live = await decommissioned();
      await rig.service.enableProbe(staff: rig.chef);
      expect(await openIds(), [...live, 'check-start-2']);
      await rig.service.disableProbe(staff: rig.chef);
      expect(await openIds(), live);
    });

    test('goLive aus der Probe', () async {
      final live = await decommissioned();
      await rig.service.enableProbe(staff: rig.chef);
      final facts = await rig.liveFacts();
      await rig.service.prepareSetup(facts: facts);
      await rig.service.goLive(staff: rig.chef, facts: facts);
      expect(await openIds(), [
        ...live,
        'register-finanzonline-3',
        'check-start-3',
      ]);
    });

    test('K9: die Probe beendet sich nach einem Fehler', () async {
      final live = await decommissioned();
      await rig.service.enableProbe(staff: rig.chef);
      rig.secrets.failReads = true;
      expect((await rig.sell('p1', cart)).rksv, isNull);
      rig.secrets.failReads = false;
      final state = await rig.stateRow();
      expect(state.mode, 'off');
      expect(state.notice, contains('Probe-Signatur wurde beendet'));
      expect(await openIds(), live);
      expect((await rig.rksv.current()).decommissioned, isFalse);
    });

    test('Online-Probe: enableOnlineProbe, dann disableProbe', () async {
      final live = await decommissioned();
      await rig.service.enableOnlineProbe(
        staff: rig.chef,
        facts: await testFacts(),
      );
      expect(await openIds(), [...live, 'check-start-2']);
      await rig.service.disableProbe(staff: rig.chef);
      expect(await openIds(), live);
    });

    test('Aufgaben ohne Kettennummer (Jahresbeleg, Protokoll sichern) der '
        'live-Kette bleiben, die der Probe gehen', () async {
      await rig.seedLive();
      rig.clock.value = DateTime(2027, 1, 5, 10);
      await rig.sell('s1', cart);
      await rig.service.decommission(staff: rig.chef);
      final live = await openIds();
      expect(live, [
        'register-finanzonline-1',
        'check-start-1',
        'check-year-2026',
        'backup-2027-Q1',
        'report-decommission-1',
      ]);
      rig.clock.value = DateTime(2027, 1, 5, 11);
      await rig.service.enableProbe(staff: rig.chef);
      rig.clock.value = DateTime(2027, 4, 2, 9);
      await rig.sell('p1', cart);
      expect(await openIds(), [...live, 'check-start-2', 'backup-2027-Q2']);
      await rig.service.disableProbe(staff: rig.chef);
      expect(await openIds(), live);
    });
  });

  group('decommission', () {
    test('Schlussbeleg, Kette beendet, mode off, decommissioned, Aufgaben '
        'mit Datum; die offenen bleiben', () async {
      final chain = await rig.seedLive();
      await rig.sell('s1', cart);
      final closing = await rig.service.decommission(staff: rig.chef);

      expect(closing.kind, ReceiptKind.closing);
      expect(closing.rksv!.damaged, isFalse);
      expect(await rig.entryKinds(chain), ['start', 'sale', 'closing']);
      expect((await rig.chainRow(chain)).endedAt, rig.clock.now());
      await rig.verifyChain(chain);
      final state = await rig.rksv.current();
      expect(
        (state.mode, state.chain, state.outage),
        (RksvMode.off, null, false),
      );
      expect(state.decommissioned, isTrue);
      expect(await rig.tasks(), [
        ('register-finanzonline-1', RksvTaskKind.registerFinanzOnline, _due),
        ('check-start-1', RksvTaskKind.checkStart, ''),
        ('report-decommission-1', RksvTaskKind.reportDecommission, _due),
        ('backup-decommission-1', RksvTaskKind.backupProtocol, ''),
      ]);
      expect(
        rksvTaskText(state.tasks[2]),
        'Außerbetriebnahme bei FinanzOnline melden, bis $_due. '
        'Grund: 6, planmäßige Außerbetriebnahme.',
      );
    });

    test('während eines Ausfalls trägt der Schlussbeleg den Vermerk; der '
        'Ausfall ist danach gelöscht', () async {
      final chain = await rig.seedLive();
      atrust.signStatus = 500;
      expect((await rig.sell('s1', cart)).rksv!.damaged, isTrue);
      final closing = await rig.service.decommission(staff: rig.chef);
      expect(closing.rksv!.damaged, isTrue);
      expect(await rig.entryKinds(chain), ['start', 'sale', 'closing']);
      final state = await rig.stateRow();
      expect(
        (state.mode, state.outageSince, state.outageReason),
        ('off', null, null),
      );
      await rig.verifyChain(chain);
    });

    test('danach ein Verkauf: Bon ohne Eintrag, test true', () async {
      await rig.seedLive();
      await rig.service.decommission(staff: rig.chef);
      final sold = await rig.sell('nach', cart);
      expect(sold.rksv, isNull);
      expect(await rig.entryOf('nach'), isNull);
      final built = await PushPayloads(rig.db)
          .build(OutboxEntry(id: 1, kind: 'receipt', ref: 'nach', rev: 0));
      expect((built!['receipt'] as Map)['test'], isTrue);
      expect(await receiptKind('nach'), 'sale');
    });

    test('nicht in Betrieb: StateError', () async {
      await expectLater(
        rig.service.decommission(staff: rig.chef),
        throwsStateError,
      );
      await rig.service.enableProbe(staff: rig.chef);
      await expectLater(
        rig.service.decommission(staff: rig.chef),
        throwsStateError,
      );
      expect((await rig.stateRow()).mode, 'probe');
    });

    test('backupProtocol genau einmal, auch wenn es schon offen ist', () async {
      final chain = await rig.seedLive();
      // Neues Vierteljahr: Das Journal legt "Protokoll sichern" an.
      rig.clock.value = DateTime(2027, 1, 5, 10);
      await rig.sell('s1', cart);
      expect(
        (await rig.tasks()).where((t) => t.$2 == RksvTaskKind.backupProtocol),
        hasLength(1),
      );
      await rig.service.decommission(staff: rig.chef);
      expect(
        (await rig.tasks()).where((t) => t.$2 == RksvTaskKind.backupProtocol),
        hasLength(1),
      );
      expect(
        (await rig.tasks()).where(
          (t) => t.$2 == RksvTaskKind.reportDecommission,
        ),
        [
          (
            'report-decommission-$chain',
            RksvTaskKind.reportDecommission,
            '12.01.2027',
          ),
        ],
      );
    });

    test('danach wieder prepareSetup und goLive: neue Kette mit neuer '
        'Kennung, decommissioned falsch', () async {
      final facts = await rig.liveFacts();
      final first = await rig.service.prepareSetup(facts: facts);
      await rig.service.goLive(staff: rig.chef, facts: facts);
      await rig.service.decommission(staff: rig.chef);
      expect((await rig.rksv.current()).decommissioned, isTrue);

      final second = await rig.service.prepareSetup(facts: facts);
      expect(second.cashBoxId, isNot(first.cashBoxId));
      expect(second.aesKeyBase64, isNot(first.aesKeyBase64));
      await rig.service.goLive(staff: rig.chef, facts: facts);
      final chain = await rig.chainRow(2);
      expect((chain.mode, chain.cashBoxId), ('live', second.cashBoxId));
      final state = await rig.rksv.current();
      expect((state.mode, state.chain), (RksvMode.live, 2));
      expect(state.decommissioned, isFalse);
      await rig.verifyChain(1);
      await rig.verifyChain(2);
    });

    test('decommissioned nur bei einer beendeten live-Kette als jüngster: '
        'nach einer Probe danach falsch', () async {
      expect((await rig.rksv.current()).decommissioned, isFalse);
      await rig.service.enableProbe(staff: rig.chef);
      await rig.service.disableProbe(staff: rig.chef);
      expect((await rig.rksv.current()).decommissioned, isFalse);
      await rig.seedLive();
      await rig.service.decommission(staff: rig.chef);
      expect((await rig.rksv.current()).decommissioned, isTrue);
      await rig.service.enableProbe(staff: rig.chef);
      expect((await rig.rksv.current()).decommissioned, isFalse);
      await rig.service.disableProbe(staff: rig.chef);
      expect((await rig.rksv.current()).decommissioned, isFalse);
    });

    test('watch liefert decommissioned', () async {
      await rig.seedLive();
      final seen = <bool>[];
      final sub = rig.rksv.watch().listen((s) => seen.add(s.decommissioned));
      addTearDown(sub.cancel);
      await pumpEventQueue();
      await rig.service.decommission(staff: rig.chef);
      await pumpEventQueue();
      expect(seen.first, isFalse);
      expect(seen.last, isTrue);
    });
  });

  group('Nullbeleg, Nochmal prüfen, Protokoll im Zustand live', () {
    test('zeroReceipt und retrySignature', () async {
      final chain = await rig.seedLive();
      final zero = await rig.service.zeroReceipt(staff: rig.chef);
      expect((zero.kind, zero.rksv!.damaged), (ReceiptKind.zero, false));
      atrust.signStatus = 500;
      await rig.sell('s1', cart);
      expect(await rig.service.retrySignature(staff: rig.chef), isFalse);
      atrust.signStatus = null;
      expect(await rig.service.retrySignature(staff: rig.chef), isTrue);
      expect(await rig.entryKinds(chain), [
        'start',
        'zero',
        'sale',
        'collective',
      ]);
      await rig.verifyChain(chain);
    });

    test(
      'exportProtocol einer laufenden live-Kette: ohne PROBE im Namen',
      () async {
        final chain = await rig.seedLive();
        await rig.sell('s1', cart);
        expect(
          await rig.service.exportProtocol(
            ExportRange.all,
            now: rig.clock.now(),
          ),
          ExportOutcome.saved,
        );
        expect(
          rig.saver.saved.last.$1,
          'kassa-protokoll-${RksvRig.liveCashBoxId}-20261118.json',
        );
        expect(rig.saver.lastText, await buildDepExport(rig.db, chain: chain));
      },
    );

    test('Q15: nach decommission die beendete live-Kette (mit Schlussbeleg); '
        'auch nach einer neuen Probe mit Verkauf', () async {
      await rig.service.enableProbe(staff: rig.chef);
      await rig.sell('p1', cart);
      final chain = await rig.seedLive();
      await rig.sell('s1', cart);
      await rig.service.decommission(staff: rig.chef);

      Future<List<String>> exportedKinds() async {
        expect(
          await rig.service.exportProtocol(
            ExportRange.all,
            now: rig.clock.now(),
          ),
          ExportOutcome.saved,
        );
        expect(
          rig.saver.saved.last.$1,
          'kassa-protokoll-${RksvRig.liveCashBoxId}-20261118.json',
        );
        expect(rig.saver.lastText, await buildDepExport(rig.db, chain: chain));
        return rig.entryKinds(chain);
      }

      expect(await exportedKinds(), ['start', 'sale', 'closing']);
      await rig.service.enableProbe(staff: rig.chef);
      await rig.sell('p2', cart);
      expect(await exportedKinds(), ['start', 'sale', 'closing']);
    });

    test(
      'Q15: ohne live-Kette bleibt es beim Bestand (laufende Probe)',
      () async {
        await rig.service.enableProbe(staff: rig.chef);
        await rig.service.disableProbe(staff: rig.chef);
        await rig.service.enableProbe(staff: rig.chef);
        await rig.service.exportProtocol(ExportRange.all, now: rig.clock.now());
        expect(rig.saver.lastText, await buildDepExport(rig.db, chain: 2));
        expect(rig.saver.saved.last.$1, startsWith('kassa-protokoll-PROBE-'));
      },
    );
  });
}
