import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/data/database.dart';
import 'package:kassa/data/rksv_repository.dart';
import 'package:kassa/rksv/rksv_state.dart';

final _created = DateTime(2026, 11, 18, 13, 5);

final _tasks = [
  RksvTask(id: 't1', kind: RksvTaskKind.checkStart, createdAt: _created),
  RksvTask(
    id: 't2',
    kind: RksvTaskKind.reportOutage,
    createdAt: _created,
    detail: '18.11.2026 13:05',
  ),
  RksvTask(id: 't3', kind: RksvTaskKind.backupProtocol, createdAt: _created),
];

void main() {
  late KassaDatabase db;
  late RksvRepository repo;

  setUp(() async {
    db = KassaDatabase(NativeDatabase.memory());
    repo = RksvRepository(db);
    await db
        .into(db.rksvCertificateRows)
        .insert(
          RksvCertificateRowsCompanion.insert(
            serialHex: '0a1b',
            certificate: Uint8List.fromList([0x30, 0x82]),
          ),
        );
  });
  tearDown(() => db.close());

  Future<void> writeState(RksvStateRowsCompanion c) =>
      (db.update(db.rksvStateRows)..where((t) => t.id.equals(1))).write(c);

  Future<void> writeTasks(List<RksvTask> tasks) => writeState(
    RksvStateRowsCompanion(
      tasks: Value(jsonEncode([for (final t in tasks) t.toJson()])),
    ),
  );

  test('frischer Stand ist off ohne Aufgaben', () async {
    final s = await repo.current();
    expect(s.mode, RksvMode.off);
    expect(s.chain, isNull);
    expect(s.cashBoxId, isNull);
    expect(s.counterCents, 0);
    expect(s.outageSince, isNull);
    expect(s.outageReason, isNull);
    expect(s.outage, isFalse);
    expect(s.tasks, isEmpty);
    expect(s.notice, isNull);
  });

  test(
    'alle Felder werden gelesen, die Kassen-Kennung aus der Kette',
    () async {
      await db
          .into(db.rksvChainRows)
          .insert(
            RksvChainRowsCompanion.insert(
              chain: const Value(1),
              mode: 'probe',
              cashBoxId: 'ABCDEFGHJK',
              zdaId: 'AT100',
              certSerial: '0a1b',
              startedAt: _created,
            ),
          );
      await db
          .into(db.rksvChainRows)
          .insert(
            RksvChainRowsCompanion.insert(
              chain: const Value(2),
              mode: 'probe',
              cashBoxId: 'MNPQRSTUVW',
              zdaId: 'AT100',
              certSerial: '0a1b',
              startedAt: _created,
            ),
          );
      await writeState(
        RksvStateRowsCompanion(
          mode: const Value('probe'),
          chain: const Value(2),
          counterCents: const Value(123456),
          outageSince: Value(_created),
          outageReason: const Value('Die Signatur hat nicht geantwortet.'),
          notice: const Value('Hinweis'),
        ),
      );
      await writeTasks(_tasks.take(1).toList());
      final s = await repo.current();
      expect(
        (s.mode, s.chain, s.cashBoxId, s.counterCents),
        (RksvMode.probe, 2, 'MNPQRSTUVW', 123456),
      );
      expect(s.outage, isTrue);
      expect(s.outageSince, _created);
      expect(s.outageReason, 'Die Signatur hat nicht geantwortet.');
      expect(s.notice, 'Hinweis');
      expect(s.tasks.map((t) => (t.id, t.kind, t.createdAt, t.detail)), [
        ('t1', RksvTaskKind.checkStart, _created, ''),
      ]);
    },
  );

  test('Einheit der laufenden Kette: null ohne Kette, sonst ihr Wert; ein '
      'unbekannter Wert ergibt null, watch() läuft weiter', () async {
    expect((await repo.current()).unit, isNull);
    await db
        .into(db.rksvChainRows)
        .insert(
          RksvChainRowsCompanion.insert(
            chain: const Value(1),
            mode: 'probe',
            cashBoxId: 'ABCDEFGHJK',
            zdaId: 'AT1',
            certSerial: '0a1b',
            startedAt: _created,
            unit: const Value('atrustTest'),
          ),
        );
    await writeState(
      const RksvStateRowsCompanion(mode: Value('probe'), chain: Value(1)),
    );
    expect((await repo.current()).unit, RksvUnit.atrustTest);

    final seen = <RksvUnit?>[];
    final sub = repo.watch().listen((s) => seen.add(s.unit));
    addTearDown(sub.cancel);
    await pumpEventQueue();
    Future<void> setUnit(String unit) => db
        .update(db.rksvChainRows)
        .write(RksvChainRowsCompanion(unit: Value(unit)));
    await setUnit('neu');
    await pumpEventQueue();
    await setUnit('probe');
    await pumpEventQueue();
    expect(seen, [RksvUnit.atrustTest, null, RksvUnit.probe]);
  });

  test('unbekannter Zustand gilt als off', () async {
    await writeState(const RksvStateRowsCompanion(mode: Value('neu')));
    expect((await repo.current()).mode, RksvMode.off);
  });

  test('completeTask entfernt genau eine', () async {
    await writeTasks(_tasks);
    await repo.completeTask('t2');
    final s = await repo.current();
    expect(s.tasks.map((t) => t.id), ['t1', 't3']);
    expect(s.tasks.first.kind, RksvTaskKind.checkStart);
    expect(s.tasks.last.kind, RksvTaskKind.backupProtocol);
  });

  test('completeTask mit unbekannter Id ändert nichts', () async {
    await writeTasks(_tasks);
    final before = await db.select(db.rksvStateRows).getSingle();
    await repo.completeTask('gibt-es-nicht');
    final after = await db.select(db.rksvStateRows).getSingle();
    expect(after.tasks, before.tasks);
    expect((await repo.current()).tasks, hasLength(3));
  });

  test('clearNotice löscht den Hinweis und lässt den Rest', () async {
    await writeState(
      const RksvStateRowsCompanion(
        notice: Value('Hinweis'),
        counterCents: Value(500),
      ),
    );
    await writeTasks(_tasks);
    await repo.clearNotice();
    final s = await repo.current();
    expect(s.notice, isNull);
    expect(s.counterCents, 500);
    expect(s.tasks, hasLength(3));
  });

  test('watch meldet die Änderung', () async {
    await writeTasks(_tasks);
    final emitted = expectLater(
      repo.watch().map((s) => [for (final t in s.tasks) t.id]),
      emitsInOrder([
        ['t1', 't2', 't3'],
        ['t1', 't3'],
      ]),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await repo.completeTask('t2');
    await emitted;
  });

  test('watch meldet eine neue Kette mit ihrer Kassen-Kennung', () async {
    final emitted = expectLater(
      repo.watch().map((s) => (s.mode, s.cashBoxId)),
      emitsThrough((RksvMode.probe, 'ABCDEFGHJK')),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await db.transaction(() async {
      await db
          .into(db.rksvChainRows)
          .insert(
            RksvChainRowsCompanion.insert(
              chain: const Value(1),
              mode: 'probe',
              cashBoxId: 'ABCDEFGHJK',
              zdaId: 'AT100',
              certSerial: '0a1b',
              startedAt: _created,
            ),
          );
      await writeState(
        const RksvStateRowsCompanion(mode: Value('probe'), chain: Value(1)),
      );
    });
    await emitted;
  });

  group('watchHasEndedChain', () {
    Future<void> insertChain({DateTime? endedAt}) => db
        .into(db.rksvChainRows)
        .insert(
          RksvChainRowsCompanion.insert(
            chain: const Value(1),
            mode: 'probe',
            cashBoxId: 'ABCDEFGHJK',
            zdaId: 'AT100',
            certSerial: '0a1b',
            startedAt: _created,
            endedAt: Value(endedAt),
          ),
        );

    test('false ohne Kette', () async {
      expect(await repo.watchHasEndedChain().first, isFalse);
    });

    test('false mit laufender Kette', () async {
      await insertChain();
      expect(await repo.watchHasEndedChain().first, isFalse);
    });

    test('true mit beendeter Kette', () async {
      await insertChain(endedAt: _created.add(const Duration(hours: 1)));
      expect(await repo.watchHasEndedChain().first, isTrue);
    });

    test('meldet das Beenden der laufenden Kette', () async {
      await insertChain();
      final emitted = expectLater(
        repo.watchHasEndedChain(),
        emitsInOrder([false, true]),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await (db.update(db.rksvChainRows)..where((t) => t.chain.equals(1)))
          .write(RksvChainRowsCompanion(endedAt: Value(_created)));
      await emitted;
    });
  });

  test('kaputtes JSON in tasks ergibt eine leere Liste statt einer Ausnahme', () async {
    for (final broken in const [
      '{nicht json',
      '{"id":"t1"}',
      '[{"id":"t1","kind":"gibtsnicht","createdAt":"2026-11-18T13:05:00.000"}]',
      '[{"id":"t1"}]',
      '[17]',
    ]) {
      await writeState(RksvStateRowsCompanion(tasks: Value(broken)));
      expect((await repo.current()).tasks, isEmpty, reason: broken);
    }
  });

  test('RksvTask: toJson und fromJson ergeben dieselbe Aufgabe', () {
    for (final t in _tasks) {
      final back = RksvTask.fromJson(
        jsonDecode(jsonEncode(t.toJson())) as Map<String, Object?>,
      );
      expect(
        (back.id, back.kind, back.createdAt, back.detail),
        (t.id, t.kind, t.createdAt, t.detail),
      );
    }
  });

  group('rksvTaskText', () {
    RksvTask task(RksvTaskKind kind, [String detail = '']) =>
        RksvTask(id: 'x', kind: kind, createdAt: _created, detail: detail);

    test('checkStart', () {
      expect(
        rksvTaskText(task(RksvTaskKind.checkStart)),
        'Startbeleg mit der App "BMF Belegcheck" prüfen.',
      );
    });

    test('checkYear', () {
      expect(
        rksvTaskText(task(RksvTaskKind.checkYear, '2026')),
        'Jahresbeleg 2026 mit der App "BMF Belegcheck" prüfen, bis 15. Februar.',
      );
    });

    test('reportOutage', () {
      expect(
        rksvTaskText(task(RksvTaskKind.reportOutage, '18.11.2026 13:05')),
        'Ausfall der Signatur bei FinanzOnline melden. Beginn: 18.11.2026 13:05.',
      );
    });

    test('reportOutageEnd', () {
      expect(
        rksvTaskText(task(RksvTaskKind.reportOutageEnd, '20.11.2026 09:30')),
        'Ende des Ausfalls bei FinanzOnline melden. Ende: 20.11.2026 09:30.',
      );
    });

    test('backupProtocol', () {
      expect(
        rksvTaskText(task(RksvTaskKind.backupProtocol)),
        'Protokoll sichern: "Protokoll ausgeben" und die Datei aufheben.',
      );
    });
  });
}
