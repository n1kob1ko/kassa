import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/data/database.dart';
import 'package:kassa/data/outbox_repository.dart';
import 'package:kassa/data/sync_state_repository.dart';

void main() {
  late KassaDatabase db;
  late OutboxRepository outbox;

  setUp(() {
    db = KassaDatabase(NativeDatabase.memory());
    outbox = OutboxRepository(db);
  });
  tearDown(() => db.close());

  Future<void> insert(String kind, String ref) => db.customStatement(
    'INSERT INTO outbox (kind, ref) VALUES (?, ?)',
    [kind, ref],
  );

  test('nextBatch liefert in Reihenfolge und höchstens limit', () async {
    for (var i = 1; i <= 5; i++) {
      await insert('day', 'd$i');
    }
    expect((await outbox.nextBatch()).map((e) => e.ref), [
      'd1',
      'd2',
      'd3',
      'd4',
      'd5',
    ]);
    expect((await outbox.nextBatch(limit: 2)).map((e) => e.ref), ['d1', 'd2']);
    final first = (await outbox.nextBatch(limit: 1)).single;
    expect(
      (first.kind, first.rev, first.field, first.value),
      ('day', 0, null, null),
    );
  });

  test('remove löscht bei gleichem rev', () async {
    await insert('day', 'd1');
    final entry = (await outbox.nextBatch()).single;
    await outbox.remove(entry.id, rev: entry.rev);
    expect(await outbox.nextBatch(), isEmpty);
  });

  test('remove mit altem rev löscht nicht', () async {
    await insert('day', 'd1');
    final sent = (await outbox.nextBatch()).single;
    // Während das Paket unterwegs ist, ändert sich der Tag.
    await db.customStatement(
      "UPDATE outbox SET rev = rev + 1 WHERE kind = 'day' AND ref = 'd1'",
    );
    await outbox.remove(sent.id, rev: sent.rev);
    final left = (await outbox.nextBatch()).single;
    expect((left.ref, left.rev), ('d1', 1));
  });

  test('markRejected nimmt den Eintrag aus nextBatch und zählt ihn in '
      'watchCounts', () async {
    await insert('day', 'd1');
    await insert('receipt', 'r1');
    final first = (await outbox.nextBatch()).first;
    await outbox.markRejected(first.id, 'conflict');
    expect((await outbox.nextBatch()).map((e) => e.ref), ['r1']);
    final counts = await outbox.watchCounts().first;
    expect((counts.pending, counts.rejected), (1, 1));
    final row = await db
        .customSelect(
          'SELECT state, reason FROM outbox WHERE id = ?',
          variables: [Variable.withInt(first.id)],
        )
        .getSingle();
    expect(
      (row.read<String>('state'), row.read<String>('reason')),
      ('rejected', 'conflict'),
    );
  });

  test('watchCounts meldet Änderungen', () async {
    final seen = <(int, int)>[];
    final sub = outbox.watchCounts().listen(
      (c) => seen.add((c.pending, c.rejected)),
    );
    await pumpEventQueue();
    // Wie in der App: ein Tag wird geschrieben, der Trigger macht den Eintrag.
    await db
        .into(db.businessDayRows)
        .insert(
          BusinessDayRowsCompanion.insert(
            id: 'd1',
            openedAt: DateTime(2026, 11, 19, 8),
          ),
        );
    await pumpEventQueue();
    await sub.cancel();
    expect(seen.first, (0, 0));
    expect(seen.last, (1, 0));
  });

  test('pendingItemFields: Artikel und ihre Felder', () async {
    final at = DateTime(2026, 11, 19, 8);
    await outbox.addItemChange(
      itemId: 'cola',
      field: 'priceCents',
      value: 300,
      changedAt: at,
    );
    await outbox.addItemChange(
      itemId: 'cola',
      field: 'tags',
      value: ['spicy', 'vegan'],
      changedAt: at,
    );
    await outbox.addItemChange(
      itemId: 'huhn-bowl',
      field: 'inSale',
      value: false,
      changedAt: at,
    );
    expect(await outbox.pendingItemFields(), {
      'cola': {'priceCents', 'tags'},
      'huhn-bowl': {'inSale'},
    });
    final entries = await outbox.nextBatch();
    expect(entries.map((e) => (e.kind, e.ref, e.field, e.value)), [
      ('item_change', 'cola', 'priceCents', '300'),
      ('item_change', 'cola', 'tags', '["spicy","vegan"]'),
      ('item_change', 'huhn-bowl', 'inSale', 'false'),
    ]);
    expect(entries.first.changedAt, at);
  });

  test(
    'addItemChange ersetzt die wartende Änderung desselben Feldes',
    () async {
      await outbox.addItemChange(
        itemId: 'cola',
        field: 'priceCents',
        value: 300,
        changedAt: DateTime(2026, 11, 19, 8),
      );
      await outbox.addItemChange(
        itemId: 'cola',
        field: 'inSale',
        value: true,
        changedAt: DateTime(2026, 11, 19, 8, 1),
      );
      await outbox.addItemChange(
        itemId: 'cola',
        field: 'priceCents',
        value: 320,
        changedAt: DateTime(2026, 11, 19, 8, 2),
      );
      final entries = await outbox.nextBatch();
      expect(entries.map((e) => (e.field, e.value)), [
        ('inSale', 'true'),
        ('priceCents', '320'),
      ]);
      expect(entries.last.changedAt, DateTime(2026, 11, 19, 8, 2));
    },
  );

  test('clearItemChanges lässt andere Arten stehen', () async {
    await insert('day', 'd1');
    await insert('receipt', 'r1');
    await outbox.addItemChange(
      itemId: 'cola',
      field: 'priceCents',
      value: 300,
      changedAt: DateTime(2026, 11, 19, 8),
    );
    await outbox.clearItemChanges();
    expect((await outbox.nextBatch()).map((e) => e.kind), ['day', 'receipt']);
    expect(await outbox.pendingItemFields(), isEmpty);
  });

  test('deviceId() ist beim zweiten Aufruf dieselbe', () async {
    final sync = SyncStateRepository(db);
    final first = await sync.deviceId();
    expect(first, hasLength(36));
    expect(await sync.deviceId(), first);
    // Auch nach neuem Koppeln bleibt sie.
    await sync.saveRegister(
      registerId: 'r',
      registerName: 'Kassa',
      businessId: 'b',
    );
    expect(await sync.deviceId(), first);
  });

  test('setPushed hält den Zeitpunkt fest', () async {
    final sync = SyncStateRepository(db);
    expect((await sync.current()).lastPushAt, isNull);
    await sync.setPushed(DateTime(2026, 11, 19, 9));
    expect((await sync.current()).lastPushAt, DateTime(2026, 11, 19, 9));
  });
}
