import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/data/day_repository.dart';
import 'package:kassa/data/outbox_repository.dart';
import 'package:kassa/domain/day.dart';

import '../support/rksv_rig.dart';
import '../support/sales.dart' show cart;

/// Die Trigger der Liste "noch zu senden", geprüft über die echten
/// Repositories: Bons, Tage, Bewegungen und Signatur schreiben wie in der App,
/// niemand schreibt von Hand in `outbox`.
void main() {
  late RksvRig rig;
  late DayRepository days;

  setUp(() async {
    rig = await RksvRig.open();
    days = DayRepository(rig.db, rig.clock);
    // Das Zertifikat der Attrappe legt der Aufbau selbst an.
    await rig.db.customStatement('DELETE FROM outbox');
  });
  tearDown(() => rig.close());

  /// (Art, Kennung, rev, Zustand) in der Reihenfolge der Liste.
  Future<List<(String, String, int, String)>> list() async => [
    for (final r
        in await rig.db
            .customSelect(
              'SELECT kind, ref, rev, state FROM outbox ORDER BY id',
            )
            .get())
      (
        r.read<String>('kind'),
        r.read<String>('ref'),
        r.read<int>('rev'),
        r.read<String>('state'),
      ),
  ];

  test('Verkauf bar: ein Eintrag receipt, davor der Tag', () async {
    await rig.sell('s1', cart);
    final dayId = await rig.db
        .customSelect('SELECT id FROM business_days')
        .getSingle()
        .then((r) => r.read<String>('id'));
    expect(await list(), [
      ('day', dayId, 0, 'pending'),
      ('receipt', 's1', 0, 'pending'),
    ]);
  });

  test('Verkauf mit Karte ergibt einen Eintrag receipt', () async {
    await rig.sellCard('c1', cart);
    expect((await list()).map((e) => (e.$1, e.$2)), [
      ('day', await _dayId(rig)),
      ('receipt', 'c1'),
    ]);
  });

  test('Storno ergibt einen zweiten Eintrag receipt', () async {
    await rig.sell('s1', cart);
    await rig.receipts.voidReceipt('s1', staff: rig.chef);
    final receipts = (await list()).where((e) => e.$1 == 'receipt').toList();
    expect(receipts, hasLength(2));
    expect(receipts.first, ('receipt', 's1', 0, 'pending'));
    final stornoId = await rig.db
        .customSelect("SELECT id FROM receipts WHERE kind = 'voided'")
        .getSingle()
        .then((r) => r.read<String>('id'));
    expect(receipts.last, ('receipt', stornoId, 0, 'pending'));
  });

  test('Sonderbeleg ergibt einen Eintrag receipt', () async {
    await rig.service.enableProbe(staff: rig.chef);
    await rig.db.customStatement('DELETE FROM outbox');
    final zero = await rig.service.zeroReceipt(staff: rig.chef);
    expect(await list(), [('receipt', zero.id, 1, 'pending')]);
  });

  test('Probe einschalten ergibt Zertifikat, Kette und Startbeleg', () async {
    final start = await rig.service.enableProbe(staff: rig.chef);
    final kinds = (await list()).map((e) => e.$1).toList();
    expect(kinds, ['rksv_certificate', 'rksv_chain', 'receipt']);
    final all = await list();
    final serial = await rig.db
        .customSelect(
          "SELECT serial_hex FROM rksv_certificates "
          "WHERE serial_hex <> '${(await rig.fake.info()).serialHex}'",
        )
        .getSingle()
        .then((r) => r.read<String>('serial_hex'));
    expect(all[0].$2, serial);
    expect(all[1].$2, '1');
    // Der Startbeleg steht einmal da, sein Eintrag im Protokoll hebt rev an.
    expect(all[2].$2, start.id);
    expect(all[2].$3, 1);
  });

  test('Wechselgeld und Abschluss erhöhen rev des Tages statt eine zweite '
      'Zeile anzulegen', () async {
    await rig.sell('s1', cart);
    final dayId = await _dayId(rig);
    await days.setOpeningFloat(15000);
    expect((await list()).where((e) => e.$1 == 'day').toList(), [
      ('day', dayId, 1, 'pending'),
    ]);
    await days.close(
      countedCents: 16820,
      leftInDrawerCents: 15000,
      staff: rig.chef,
    );
    expect((await list()).where((e) => e.$1 == 'day').toList(), [
      ('day', dayId, 2, 'pending'),
    ]);
  });

  test('Bargeld-Bewegung ergibt einen Eintrag cash_movement', () async {
    await days.addMovement(
      kind: CashMovementKind.deposit,
      amountCents: 5000,
      reason: CashReason.change,
      staff: rig.chef,
    );
    final movement = await rig.db
        .customSelect('SELECT id FROM cash_movements')
        .getSingle()
        .then((r) => r.read<String>('id'));
    expect(await list(), [
      ('day', await _dayId(rig), 0, 'pending'),
      ('cash_movement', movement, 0, 'pending'),
    ]);
  });

  test('Transaktion bricht ab: weder Bon noch Eintrag', () async {
    await expectLater(
      rig.db.transaction(() async {
        await rig.sell('s1', cart);
        expect(await list(), isNotEmpty);
        throw StateError('abgebrochen');
      }),
      throwsStateError,
    );
    expect(await rig.count('receipts'), 0);
    expect(await rig.count('business_days'), 0);
    expect(await list(), isEmpty);
  });

  test(
    'abgelehnter Eintrag bleibt abgelehnt, auch wenn sich der Tag ändert',
    () async {
      await rig.sell('s1', cart);
      final outbox = OutboxRepository(rig.db);
      final dayEntry = (await outbox.nextBatch()).firstWhere(
        (e) => e.kind == 'day',
      );
      await outbox.markRejected(dayEntry.id, 'invalid');

      await days.setOpeningFloat(15000);

      final dayRows = (await list()).where((e) => e.$1 == 'day').toList();
      expect(dayRows, [('day', dayEntry.ref, 1, 'rejected')]);
      expect(await rig.count('outbox'), 2);
    },
  );
}

Future<String> _dayId(RksvRig rig) => rig.db
    .customSelect('SELECT id FROM business_days')
    .getSingle()
    .then((r) => r.read<String>('id'));
