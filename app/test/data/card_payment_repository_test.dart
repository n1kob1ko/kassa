import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/data/card_payment_repository.dart';

import '../support/sales.dart';

void main() {
  late TestShop shop;
  late CardPaymentRepository repo;

  setUp(() async {
    shop = await TestShop.open();
    repo = CardPaymentRepository(shop.db, shop.clock);
  });
  tearDown(() => shop.close());

  test(
    'begin schreibt die offene Zahlung, markUnknown ändert den Zustand',
    () async {
      await repo.begin(paymentId: 'p1', cart: cart, staff: shop.anna);
      final p = (await repo.pending()).single;
      expect(
        (p.id, p.amountCents, p.staffId, p.staffName, p.unknown),
        ('p1', 1820, shop.anna.id, 'Anna', false),
      );
      expect(p.startedAt, shop.clock.now());
      expect(p.cartJson, contains('"lines"'));
      await repo.markUnknown('p1');
      expect((await repo.pending()).single.unknown, isTrue);
    },
  );

  test('discard entfernt, unbekannte Id ist kein Fehler', () async {
    await repo.begin(paymentId: 'p1', cart: cart, staff: shop.anna);
    await repo.discard('gibt-es-nicht');
    expect(await repo.pending(), hasLength(1));
    await repo.discard('p1');
    expect(await repo.pending(), isEmpty);
  });

  test('watchPending meldet Änderungen', () async {
    final seen = <List<String>>[];
    final sub = repo.watchPending().listen(
      (l) => seen.add([for (final p in l) p.id]),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await repo.begin(paymentId: 'p1', cart: cart, staff: shop.anna);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await repo.discard('p1');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await sub.cancel();
    expect(seen, [
      <String>[],
      ['p1'],
      <String>[],
    ]);
  });

  test('begin mit derselben Id zweimal: eine Zeile', () async {
    await repo.begin(paymentId: 'p1', cart: cart, staff: shop.anna);
    await repo.begin(paymentId: 'p1', cart: cart, staff: shop.anna);
    expect(await repo.pending(), hasLength(1));
  });
}
