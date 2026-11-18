import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/data/database.dart';
import 'package:kassa/data/sync_state_repository.dart';

void main() {
  late KassaDatabase db;
  late SyncStateRepository repo;

  setUp(() {
    db = KassaDatabase(NativeDatabase.memory());
    repo = SyncStateRepository(db);
  });
  tearDown(() => db.close());

  test('frische Datenbank: nicht gekoppelt, Cursor 0', () async {
    final s = await repo.current();
    expect(s.registerId, isNull);
    expect(s.registerName, isNull);
    expect(s.businessId, isNull);
    expect(s.pullCursor, 0);
    expect(s.initialPullDone, isFalse);
    expect(s.lastPullAt, isNull);
    expect(s.lastError, isNull);
    expect(s.blocked, isFalse);
    expect(s.hasRegister, isFalse);
    expect(s.paired, isFalse);
  });

  test('saveRegister setzt Cursor und initialPullDone zurück', () async {
    await repo.saveRegister(
      registerId: 'r1',
      registerName: 'Kassa 1',
      businessId: 'b1',
    );
    await db.customStatement(
      "UPDATE sync_state SET pull_cursor = 42, initial_pull_done = 1, blocked = 1, last_error = 'unauthorized' WHERE id = 1",
    );
    var s = await repo.current();
    expect(s.pullCursor, 42);
    expect(s.paired, isTrue);

    await repo.saveRegister(
      registerId: 'r2',
      registerName: 'Kassa 2',
      businessId: 'b1',
    );
    s = await repo.current();
    expect(s.registerId, 'r2');
    expect(s.registerName, 'Kassa 2');
    expect(s.businessId, 'b1');
    expect(s.pullCursor, 0);
    expect(s.initialPullDone, isFalse);
    expect(s.blocked, isFalse);
    // Eine neu gekoppelte Kassa hat noch keinen Fehler, auch nicht den alten
    // "unbekannt", der sonst wieder "Neu koppeln" zeigte.
    expect(s.lastError, isNull);
    expect(s.hasRegister, isTrue);
    expect(s.paired, isFalse);
  });

  test('setResult: Fehler lässt lastPullAt stehen, Erfolg setzt es und löscht den Fehler', () async {
    await repo.saveRegister(
      registerId: 'r',
      registerName: 'K',
      businessId: 'b',
    );
    final t1 = DateTime(2026, 11, 18, 10);
    final t2 = DateTime(2026, 11, 18, 11);
    final t3 = DateTime(2026, 11, 18, 12);

    await repo.setResult(at: t1);
    var s = await repo.current();
    expect(s.lastPullAt, t1);
    expect(s.lastError, isNull);
    expect(s.blocked, isFalse);

    await repo.setResult(at: t2, error: 'offline');
    s = await repo.current();
    expect(s.lastPullAt, t1, reason: 'bei einem Fehler bleibt der Zeitpunkt');
    expect(s.lastError, 'offline');
    expect(s.blocked, isFalse, reason: 'blocked ohne Angabe bleibt');

    await repo.setResult(at: t2, error: 'gesperrt', blocked: true);
    s = await repo.current();
    expect(s.blocked, isTrue);
    expect(s.lastPullAt, t1);

    await repo.setResult(at: t3, blocked: false);
    s = await repo.current();
    expect(s.lastPullAt, t3);
    expect(s.lastError, isNull);
    expect(s.blocked, isFalse);
  });

  test('watch meldet jede Änderung', () async {
    final seen = <SyncState>[];
    final sub = repo.watch().listen(seen.add);
    await pumpEventQueue();
    expect(seen, isNotEmpty);
    expect(seen.last.hasRegister, isFalse);

    await repo.saveRegister(
      registerId: 'r',
      registerName: 'K',
      businessId: 'b',
    );
    await pumpEventQueue();
    expect(seen.last.registerId, 'r');

    await repo.setResult(at: DateTime(2026, 11, 18), error: 'x');
    await pumpEventQueue();
    expect(seen.last.lastError, 'x');
    await sub.cancel();
  });
}
