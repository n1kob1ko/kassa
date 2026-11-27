import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/data/database.dart';
import 'package:kassa/domain/voucher.dart';
import 'package:kassa/sync/wire.dart';

import '../support/sales.dart';

void main() {
  late TestShop shop;

  setUp(() async => shop = await TestShop.open());
  tearDown(() => shop.close());

  Future<void> insertVoucher(
    String id,
    String code, {
    int valueCents = 1000,
    String? soldReceiptId,
    int? soldLinePosition,
  }) => shop.db
      .into(shop.db.voucherRows)
      .insert(
        VoucherRowsCompanion.insert(
          id: id,
          code: code,
          valueCents: valueCents,
          createdAt: shop.clock.now(),
          soldReceiptId: Value(soldReceiptId),
          soldLinePosition: Value(soldLinePosition),
          isTest: false,
        ),
      );

  Future<void> insertMovement(
    String voucherId,
    String receiptId,
    VoucherMovementKind kind,
    int amountCents,
  ) => shop.db
      .into(shop.db.voucherMovementRows)
      .insert(
        VoucherMovementRowsCompanion.insert(
          voucherId: voucherId,
          receiptId: receiptId,
          kind: kind.dbName,
          amountCents: amountCents,
          createdAt: shop.clock.now(),
        ),
      );

  test(
    'findByCode: keiner, einer oder mehrere (zwei Kassen, ein Code)',
    () async {
      await insertVoucher('a', '11112222');
      await insertVoucher('b', '33334444');
      await insertVoucher('c', '33334444');
      expect(await shop.vouchers.findByCode('99999999'), isEmpty);
      expect(
        [for (final v in await shop.vouchers.findByCode('11112222')) v.id],
        ['a'],
      );
      expect(
        {for (final v in await shop.vouchers.findByCode('33334444')) v.id},
        {'b', 'c'},
      );
    },
  );

  test('byId: der Gutschein mit allen Feldern und seinen Bewegungen in der '
      'Reihenfolge, in der sie entstanden; unbekannt gibt null', () async {
    await insertVoucher(
      'a',
      '11112222',
      valueCents: 2500,
      soldReceiptId: 'r1',
      soldLinePosition: 3,
    );
    await insertMovement('a', 'r1', VoucherMovementKind.sale, 2500);
    await insertMovement('a', 'r2', VoucherMovementKind.redeem, -900);
    await insertMovement('a', 'r3', VoucherMovementKind.voidRedeem, 900);
    final v = (await shop.vouchers.byId('a'))!;
    expect(
      (v.code, v.valueCents, v.isTest, v.soldReceiptId, v.createdAt),
      ('11112222', 2500, false, 'r1', shop.clock.now()),
    );
    expect(
      [for (final m in v.movements) (m.receiptId, m.kind, m.amountCents)],
      [
        ('r1', VoucherMovementKind.sale, 2500),
        ('r2', VoucherMovementKind.redeem, -900),
        ('r3', VoucherMovementKind.voidRedeem, 900),
      ],
    );
    expect(await shop.vouchers.byId('x'), isNull);
  });

  test('balanceOf: Summe der Bewegungen, 0 ohne Bewegung', () async {
    await insertVoucher('a', '11112222');
    expect(await shop.vouchers.balanceOf('a'), 0);
    expect(await shop.vouchers.balanceOf('unbekannt'), 0);
    await insertMovement('a', 'r1', VoucherMovementKind.sale, 1000);
    await insertMovement('a', 'r2', VoucherMovementKind.redeem, -1250);
    expect(await shop.vouchers.balanceOf('a'), -250);
  });

  test('soldOn: die Gutscheine eines Bons nach ihrer Zeile', () async {
    await insertVoucher(
      'b',
      '33334444',
      soldReceiptId: 'r1',
      soldLinePosition: 4,
    );
    await insertVoucher(
      'a',
      '11112222',
      soldReceiptId: 'r1',
      soldLinePosition: 1,
    );
    await insertVoucher(
      'c',
      '55556666',
      soldReceiptId: 'r2',
      soldLinePosition: 0,
    );
    expect(
      [for (final v in await shop.vouchers.soldOn('r1')) v.id],
      ['a', 'b'],
    );
    expect(await shop.vouchers.soldOn('r3'), isEmpty);
  });

  group('mergeFromServer', () {
    final sold = DateTime.utc(2026, 11, 17, 9);
    WireVoucher wire(String id, String code, {int valueCents = 1000}) =>
        WireVoucher(
          id: id,
          code: code,
          valueCents: valueCents,
          createdAt: sold,
          isTest: false,
          soldReceiptId: 'bon-$id',
        );
    WireVoucherMovement move(
      String voucherId,
      String receiptId,
      String kind,
      int cents,
    ) => WireVoucherMovement(
      voucherId: voucherId,
      receiptId: receiptId,
      kind: kind,
      amountCents: cents,
      createdAt: sold,
    );
    Future<List<Object>> rows() async => [
      await shop.db.select(shop.db.voucherRows).get(),
      await shop.db.select(shop.db.voucherMovementRows).get(),
      await shop.db
          .customSelect('SELECT * FROM outbox')
          .get()
          .then((r) => [for (final x in r) x.data]),
    ];

    test('fügt Neues an, ohne Eintrag in "noch zu senden"; noch einmal '
        'dasselbe ändert nichts und gibt false', () async {
      final vouchers = [wire('a', '11112222')];
      final movements = [
        move('a', 'bon-a', 'sale', 1000),
        move('a', 'bon-x', 'redeem', -400),
      ];
      expect(await shop.vouchers.mergeFromServer(vouchers, movements), isTrue);
      final a = (await shop.vouchers.byId('a'))!;
      expect(
        (a.code, a.valueCents, a.soldReceiptId, a.isTest, a.balanceCents),
        ('11112222', 1000, 'bon-a', false, 600),
      );
      expect([
        for (final r in await shop.db.select(shop.db.outboxRows).get()) r.id,
      ], isEmpty);
      final before = await rows();
      expect(await shop.vouchers.mergeFromServer(vouchers, movements), isFalse);
      expect(await rows(), before);
      expect(await shop.vouchers.mergeFromServer(const [], const []), isFalse);
    });

    test('ändert nichts Vorhandenes: ein eigener Gutschein und seine '
        'Bewegung bleiben, wie sie sind', () async {
      await insertVoucher(
        'a',
        '11112222',
        soldReceiptId: 'bon-a',
        soldLinePosition: 2,
      );
      await insertMovement('a', 'bon-a', VoucherMovementKind.sale, 1000);
      final before = await rows();
      expect(
        await shop.vouchers.mergeFromServer(
          [wire('a', '11112222')],
          [move('a', 'bon-a', 'sale', 1000)],
        ),
        isFalse,
      );
      expect(await rows(), before);
      expect((await shop.vouchers.byId('a'))!.movements, hasLength(1));
    });

    test('eine Bewegung, deren Gutschein noch nicht bekannt ist, geht nicht '
        'verloren: das Guthaben stimmt, sobald der Gutschein kommt', () async {
      expect(
        await shop.vouchers.mergeFromServer(const [], [
          move('b', 'bon-y', 'redeem', -300),
        ]),
        isTrue,
      );
      expect(await shop.vouchers.byId('b'), isNull);
      expect(await shop.vouchers.balanceOf('b'), -300);
      expect(
        await shop.vouchers.mergeFromServer(
          [wire('b', '33334444')],
          [move('b', 'bon-b', 'sale', 1000)],
        ),
        isTrue,
      );
      final b = (await shop.vouchers.byId('b'))!;
      expect((b.balanceCents, b.state), (700, VoucherState.active));
      expect([for (final m in b.movements) m.receiptId], ['bon-y', 'bon-b']);
    });

    test('eine Art, die diese Version nicht kennt, wird gespeichert, wie sie '
        'kommt; das Guthaben bleibt die Summe der Beträge', () async {
      expect(
        await shop.vouchers.mergeFromServer(
          [wire('n', '77778888')],
          [
            move('n', 'bon-n', 'sale', 1000),
            move('n', 'bon-z', 'top_up', 500),
          ],
        ),
        isTrue,
      );
      final stored = await shop.db.select(shop.db.voucherMovementRows).get();
      expect([for (final r in stored) r.kind], ['sale', 'top_up']);
      final n = (await shop.vouchers.byId('n'))!;
      expect((n.balanceCents, n.state), (1500, VoucherState.active));
      expect(
        [for (final m in n.movements) m.kind],
        [VoucherMovementKind.sale, VoucherMovementKind.unknown],
      );
      expect(await shop.vouchers.balanceOf('n'), 1500);
    });

    test('mehr Gutscheine auf einmal, als SQLite in einer Abfrage nennen '
        'kann (neue Kassa koppeln): alle kommen an, noch einmal ändert '
        'nichts', () async {
      const n = 33000;
      final vouchers = [
        for (var i = 0; i < n; i++)
          wire('v$i', (10000000 + i).toString(), valueCents: 100),
      ];
      final movements = [
        for (var i = 0; i < n; i++) move('v$i', 'bon-v$i', 'sale', 100),
      ];
      Future<bool> merge() => shop.db.transaction(
        () => shop.vouchers.mergeFromServer(vouchers, movements),
      );
      expect(await merge(), isTrue);
      Future<int> count(String table) => shop.db
          .customSelect('SELECT COUNT(*) AS c FROM $table')
          .getSingle()
          .then((r) => r.read<int>('c'));
      expect(
        (await count('vouchers'), await count('voucher_movements')),
        (n, n),
      );
      expect(await merge(), isFalse);
      expect(await shop.vouchers.balanceOf('v${n - 1}'), 100);
    });

    test(
      'derselbe Code wie ein eigener Gutschein: findByCode gibt beide',
      () async {
        await insertVoucher('eigen', '55556666');
        await shop.vouchers.mergeFromServer(
          [wire('fremd', '55556666', valueCents: 4000)],
          [move('fremd', 'bon-fremd', 'sale', 4000)],
        );
        expect(
          {for (final v in await shop.vouchers.findByCode('55556666')) v.id},
          {'eigen', 'fremd'},
        );
      },
    );
  });
}
