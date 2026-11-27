// Firmenkunden und Rechnungsempfänger am Tablet (Spec 5.3): Speichern trägt
// selbst in die Liste "noch zu senden" ein; ein Empfänger ist eine neue
// Fassung und ändert den Bon und seine Signatur nicht.

import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/core/clock.dart';
import 'package:kassa/data/customer_repository.dart';
import 'package:kassa/data/database.dart';

import '../support/rksv_rig.dart';
import '../support/sales.dart';

Future<List<Map<String, Object?>>> _rows(KassaDatabase db, String sql) async =>
    [for (final r in await db.customSelect(sql).get()) r.data];

/// Rückt die Uhr eine Minute weiter.
void _later(FixedClock clock) =>
    clock.value = clock.value.add(const Duration(minutes: 1));

void main() {
  test('save trägt den Kunden in die Liste "noch zu senden" ein; '
      'setRecipient zählt Fassungen und ändert den Bon nicht', () async {
    final rig = await RksvRig.open();
    addTearDown(rig.close);
    await rig.startLive();
    final receipt = await rig.sell('s1', cart);
    final repo = CustomerRepository(rig.db, rig.clock);

    final receiptBefore = await _rows(
      rig.db,
      "SELECT * FROM receipts WHERE id = '${receipt.id}'",
    );
    final protocolBefore = await _rows(rig.db, 'SELECT * FROM rksv_entries');
    expect(protocolBefore, isNotEmpty);
    await rig.db.customStatement('DELETE FROM outbox');

    final customer = await repo.save(
      name: '  Muster GmbH ',
      addressLine1: 'Musterweg 1',
      addressLine2: '1010 Wien',
      vatId: 'ATU00000000',
    );
    expect(customer.name, 'Muster GmbH');
    expect(customer.updatedAt, rig.clock.now());
    expect(customer.lastUsedAt, isNull);
    expect(await _rows(rig.db, 'SELECT kind, ref FROM outbox'), [
      {'kind': 'customer', 'ref': customer.id},
    ]);

    // Noch einmal gespeichert, solange der Eintrag wartet: eine Zeile, die
    // Fassung zählt hoch.
    _later(rig.clock);
    final changed = await repo.save(
      id: customer.id,
      name: 'Muster GmbH',
      addressLine1: 'Musterweg 2',
      addressLine2: '1010 Wien',
      vatId: '',
    );
    expect(changed.id, customer.id);
    expect(changed.addressLine1, 'Musterweg 2');
    expect(changed.vatId, isNull);
    expect(changed.updatedAt, rig.clock.now());
    expect(await _rows(rig.db, 'SELECT kind, ref, rev FROM outbox'), [
      {'kind': 'customer', 'ref': customer.id, 'rev': 1},
    ]);
    await rig.db.customStatement('DELETE FROM outbox');

    _later(rig.clock);
    final first = await repo.setRecipient(
      receiptId: receipt.id,
      customerId: customer.id,
      name: 'Muster GmbH',
      addressLine1: 'Musterweg 2',
      addressLine2: '1010 Wien',
      staff: rig.anna,
    );
    expect(first.version, 0);
    expect(first.customerId, customer.id);
    expect(first.staffId, rig.anna.id);
    expect(first.staffName, 'Anna');
    expect(first.createdAt, rig.clock.now());
    // Verwendet ist keine Änderung: kein Eintrag `customer`.
    expect(await _rows(rig.db, 'SELECT kind, ref FROM outbox'), [
      {'kind': 'recipient', 'ref': '${receipt.id}/0'},
    ]);
    final used = (await repo.list()).single;
    expect(used.lastUsedAt, rig.clock.now());
    expect(used.updatedAt, changed.updatedAt);

    final second = await repo.setRecipient(
      receiptId: receipt.id,
      name: ' Muster  GmbH ',
      addressLine1: 'Musterweg 3',
      addressLine2: '1010 Wien',
      vatId: 'ATU00000000',
      staff: rig.chef,
    );
    expect(second.version, 1);
    expect(second.customerId, isNull);
    expect(second.name, 'Muster  GmbH');
    expect((await repo.recipientOf(receipt.id))!.addressLine1, 'Musterweg 3');
    expect((await repo.recipientOf(receipt.id))!.vatId, 'ATU00000000');
    expect(await repo.recipientOf('kein-bon'), isNull);
    expect(
      await _rows(
        rig.db,
        'SELECT version, address_line1 FROM receipt_recipients '
        'ORDER BY version',
      ),
      [
        {'version': 0, 'address_line1': 'Musterweg 2'},
        {'version': 1, 'address_line1': 'Musterweg 3'},
      ],
    );
    expect(await _rows(rig.db, 'SELECT kind, ref FROM outbox ORDER BY id'), [
      {'kind': 'recipient', 'ref': '${receipt.id}/0'},
      {'kind': 'recipient', 'ref': '${receipt.id}/1'},
    ]);

    // Ändert jemand später den Firmenkunden, bleibt der Empfänger.
    await repo.save(
      id: customer.id,
      name: 'Muster AG',
      addressLine1: 'Musterweg 9',
      addressLine2: '1010 Wien',
    );
    expect(
      await _rows(
        rig.db,
        'SELECT name FROM receipt_recipients WHERE version = 0',
      ),
      [
        {'name': 'Muster GmbH'},
      ],
    );

    expect(
      await _rows(rig.db, "SELECT * FROM receipts WHERE id = '${receipt.id}'"),
      receiptBefore,
    );
    expect(await _rows(rig.db, 'SELECT * FROM rksv_entries'), protocolBefore);
  });

  test('setRecipient nimmt keinen Empfänger mit fehlendem Namen oder zu '
      'einem unbekannten Bon', () async {
    final shop = await TestShop.open();
    addTearDown(shop.close);
    final receipt = await shop.sell('s1');
    final repo = CustomerRepository(shop.db, shop.clock);
    await expectLater(
      repo.setRecipient(
        receiptId: receipt.id,
        name: ' ',
        addressLine1: 'Musterweg 1',
        addressLine2: '1010 Wien',
        staff: shop.anna,
      ),
      throwsArgumentError,
    );
    await expectLater(
      repo.setRecipient(
        receiptId: 'kein-bon',
        name: 'Muster GmbH',
        addressLine1: 'Musterweg 1',
        addressLine2: '1010 Wien',
        staff: shop.anna,
      ),
      throwsStateError,
    );
    expect(await shop.count('receipt_recipients'), 0);
    expect(
      await _rows(shop.db, "SELECT kind FROM outbox WHERE kind = 'recipient'"),
      isEmpty,
    );
  });

  test('list: zuletzt verwendete oben, dann nach Name; initial filtert; '
      'archivierte fehlen', () async {
    final shop = await TestShop.open();
    addTearDown(shop.close);
    final clock = shop.clock;
    final repo = CustomerRepository(shop.db, clock);
    Future<String> add(String name) async => (await repo.save(
      name: name,
      addressLine1: 'Musterweg 1',
      addressLine2: '1010 Wien',
    )).id;

    final zeta = await add('Zeta Bau');
    final alpha = await add('alpha Handel');
    final muster = await add('Muster GmbH');
    final mBeta = await add('Mbeta KG');
    final digit = await add('1. Wiener Bau');
    final archived = await add('Archiv GmbH');
    await shop.db.customStatement(
      "UPDATE customers SET archived = 1 WHERE id = '$archived'",
    );

    // Ohne Verwendung: nach Name, ohne Rücksicht auf groß und klein.
    expect(
      [for (final c in await repo.list()) c.id],
      [digit, alpha, mBeta, muster, zeta],
    );
    expect(await repo.initials(), ['A', 'M', 'Z', '#']);

    final r1 = await shop.sell('s1');
    final r2 = await shop.sell('s2');
    _later(clock);
    await repo.setRecipient(
      receiptId: r1.id,
      customerId: zeta,
      name: 'Zeta Bau',
      addressLine1: 'Musterweg 1',
      addressLine2: '1010 Wien',
      staff: shop.anna,
    );
    _later(clock);
    await repo.setRecipient(
      receiptId: r2.id,
      customerId: muster,
      name: 'Muster GmbH',
      addressLine1: 'Musterweg 1',
      addressLine2: '1010 Wien',
      staff: shop.anna,
    );
    expect(
      [for (final c in await repo.list()) c.id],
      [muster, zeta, digit, alpha, mBeta],
    );
    expect(
      [for (final c in await repo.list(initial: 'M')) c.id],
      [muster, mBeta],
    );
    expect([for (final c in await repo.list(initial: '#')) c.id], [digit]);
    expect(await repo.list(initial: 'Q'), isEmpty);
  });
}
