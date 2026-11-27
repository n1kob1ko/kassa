// Belegerteilung am Tablet (Spec 5.4): je Bon und Art ein Eintrag mit Zeit,
// nur anfügen; jeder neue Eintrag steht als `delivery` in "noch zu senden".

import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/data/database.dart';
import 'package:kassa/data/delivery_repository.dart';
import 'package:kassa/data/outbox_repository.dart';

import '../support/sales.dart';

Future<List<Map<String, Object?>>> _rows(KassaDatabase db, String sql) async =>
    [for (final r in await db.customSelect(sql).get()) r.data];

void main() {
  test('record schreibt je Bon und Art einen Eintrag, das zweite Mal nichts; '
      'der Eintrag steht in "noch zu senden"', () async {
    final shop = await TestShop.open();
    addTearDown(shop.close);
    final receipt = await shop.sell('s1');
    final other = await shop.sell('s2');
    await shop.db.customStatement('DELETE FROM outbox');
    final repo = DeliveryRepository(shop.db);
    final first = DateTime.utc(2026, 11, 27, 11, 3, 5);
    final later = DateTime.utc(2026, 11, 27, 11, 9);

    await repo.record(receipt.id, DeliveryKind.digital, at: first);
    await repo.record(receipt.id, DeliveryKind.printed, at: first);
    await repo.record(other.id, DeliveryKind.printed, at: later);
    // Das zweite Mal: die erste Zeit bleibt, kein neuer Eintrag.
    await repo.record(receipt.id, DeliveryKind.printed, at: later);
    await repo.record(receipt.id, DeliveryKind.digital, at: later);

    final mine = await repo.of(receipt.id);
    expect(
      [for (final d in mine) (d.receiptId, d.kind, d.at.toUtc())],
      [
        (receipt.id, DeliveryKind.printed, first),
        (receipt.id, DeliveryKind.digital, first),
      ],
    );
    expect([for (final d in await repo.of(other.id)) d.kind], [
      DeliveryKind.printed,
    ]);
    expect(await repo.of('gibt-es-nicht'), isEmpty);
    expect(await _rows(shop.db, 'SELECT COUNT(*) AS n FROM receipt_deliveries'), [
      {'n': 3},
    ]);
    expect(
      await _rows(
        shop.db,
        'SELECT kind, ref, state, rev FROM outbox ORDER BY id',
      ),
      [
        {
          'kind': 'delivery',
          'ref': '${receipt.id}/digital',
          'state': 'pending',
          'rev': 0,
        },
        {
          'kind': 'delivery',
          'ref': '${receipt.id}/printed',
          'state': 'pending',
          'rev': 0,
        },
        {
          'kind': 'delivery',
          'ref': '${other.id}/printed',
          'state': 'pending',
          'rev': 0,
        },
      ],
    );
    // Ist der Eintrag schon gesendet, kommt er durch ein zweites Mal nicht
    // wieder.
    final outbox = OutboxRepository(shop.db);
    for (final e in await outbox.nextBatch()) {
      await outbox.remove(e.id, rev: e.rev);
    }
    await repo.record(receipt.id, DeliveryKind.printed, at: later);
    expect(await _rows(shop.db, 'SELECT * FROM outbox'), isEmpty);
  });

  test('watchSent: wahr, sobald kein Eintrag mehr wartet; ein abgelehnter '
      'zählt als nicht gesendet', () async {
    final shop = await TestShop.open();
    addTearDown(shop.close);
    final outbox = OutboxRepository(shop.db);
    final seen = <bool>[];
    // Vor dem Bon gibt es keinen Eintrag.
    final sub = outbox
        .watchSent(kind: 'receipt', ref: 's1')
        .listen(seen.add);
    addTearDown(sub.cancel);
    await pumpEventQueue();
    expect(seen, [true]);

    // Der Trigger stellt den Bon in die Liste: nicht gesendet.
    await shop.sell('s1');
    await pumpEventQueue();
    expect(seen, [true, false]);

    final entry = (await outbox.nextBatch()).firstWhere(
      (e) => e.kind == 'receipt' && e.ref == 's1',
    );
    await outbox.markRejected(entry.id, 'invalid');
    await pumpEventQueue();
    expect(seen, [true, false]);
    expect(
      await outbox.watchSent(kind: 'receipt', ref: 's1').first,
      isFalse,
    );

    await outbox.remove(entry.id, rev: entry.rev);
    await pumpEventQueue();
    expect(seen, [true, false, true]);
    expect(await outbox.watchSent(kind: 'receipt', ref: 's1').first, isTrue);

    // Ein anderer Bon wartet: für s1 bleibt es wahr.
    await shop.sell('s2');
    expect(await outbox.watchSent(kind: 'receipt', ref: 's1').first, isTrue);
    expect(await outbox.watchSent(kind: 'receipt', ref: 's2').first, isFalse);
  });
}
