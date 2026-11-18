import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/domain/cart.dart';
import 'package:kassa/domain/catalog.dart';
import 'package:kassa/domain/receipt.dart';
import 'package:kassa/domain/stats.dart';

import '../support/demo_fixtures.dart';
import '../support/sales.dart';

void main() {
  late TestShop shop;

  setUp(() async => shop = await TestShop.open());
  tearDown(() => shop.close());

  Future<void> sellCart(String id, Cart c) => shop.receipts.finalizeCashSale(
    saleId: id,
    cart: c,
    givenCents: 100000,
    staff: shop.anna,
  );

  test(
    'heute: Balken pro Stunde von der ersten Verkaufsstunde bis jetzt',
    () async {
      shop.clock.value = DateTime(2026, 11, 17, 11, 10);
      await shop.sell('s1'); // 1820
      shop.clock.value = DateTime(2026, 11, 17, 13, 40);
      await shop.sell('s2');
      final o = await shop.stats.overview(StatsRange.today);
      expect(o.buckets.map((b) => (b.label, b.cents)), [
        ('11', 1820),
        ('12', 0),
        ('13', 1820),
      ]);
      expect(o.buckets.first.start, DateTime(2026, 11, 17, 11));
      expect(
        (o.revenueCents, o.receiptCount, o.cashCents, o.cardCents),
        (3640, 2, 3640, 0),
      );
      expect(o.topItems.first.name, 'Cola 0,33 l');
      expect(o.topItems.first.quantity, 4);
      expect(
        o.byCategory.last,
        isA<CategoryStat>().having((c) => (c.name, c.cents), 'Pfand', (
          'Pfand',
          100,
        )),
      );
      expect(o.byCategory.fold<int>(0, (s, c) => s + c.cents), o.revenueCents);
    },
  );

  test('Storno zählt Umsatz, Anzahl und Mengen wieder ab', () async {
    final r = await shop.sell('s1');
    await shop.receipts.voidReceipt(r.id, staff: shop.chef);
    final o = await shop.stats.overview(StatsRange.today);
    expect((o.revenueCents, o.receiptCount), (0, 0));
    expect(o.topItems, isEmpty);
    expect(o.byCategory, isEmpty);
  });

  test('voidCount zählt die Storno-Bons im Zeitraum', () async {
    expect((await shop.stats.overview(StatsRange.today)).voidCount, 0);
    final r = await shop.sell('s1');
    await shop.sell('s2');
    expect((await shop.stats.overview(StatsRange.today)).voidCount, 0);
    await shop.receipts.voidReceipt(r.id, staff: shop.chef);
    final o = await shop.stats.overview(StatsRange.today);
    expect((o.voidCount, o.receiptCount), (1, 1));
    expect((await shop.stats.overview(StatsRange.days7)).voidCount, 1);
  });

  test('7 Tage: sieben Balken nach Kalendertag, Vergleich mit den sieben Tagen davor', () async {
    shop.clock.value = DateTime(2026, 11, 9, 12);
    await shop.sell('alt');
    shop.clock.value = DateTime(2026, 11, 17, 0, 30);
    await shop.sell('nachts');
    final o = await shop.stats.overview(StatsRange.days7);
    expect(o.buckets, hasLength(7));
    expect(
      (o.buckets.first.label, o.buckets.first.start),
      ('11.11.', DateTime(2026, 11, 11)),
    );
    expect((o.buckets.last.label, o.buckets.last.cents), ('17.11.', 1820));
    expect((o.revenueCents, o.previousRevenueCents), (1820, 1820));
  });

  test('ohne Bons: leere Übersicht', () async {
    final o = await shop.stats.overview(StatsRange.today);
    expect((o.revenueCents, o.receiptCount), (0, 0));
    expect(o.buckets, isEmpty);
    expect(o.topItems, isEmpty);
    expect(o.byCategory, isEmpty);
  });

  test('30 Tage: dreißig Balken, der erste ist der 19.10.', () async {
    final o = await shop.stats.overview(StatsRange.days30);
    expect(o.buckets, hasLength(30));
    expect(o.buckets.first.label, '19.10.');
    expect(o.buckets.last.label, '17.11.');
    expect(o.buckets.every((b) => b.cents == 0), isTrue);
  });

  test(
    'heute: Vergleich mit demselben Wochentag bis zur selben Uhrzeit',
    () async {
      shop.clock.value = DateTime(2026, 11, 10, 10);
      await shop.sell('vor-10');
      shop.clock.value = DateTime(2026, 11, 10, 15);
      await shop.sell('vor-15');
      shop.clock.value = DateTime(2026, 11, 17, 12);
      final o = await shop.stats.overview(StatsRange.today);
      expect(o.previousRevenueCents, 1820);
      expect(o.revenueCents, 0);
    },
  );

  test(
    'Storno von gestern zählt heute negativ, der gestrige Balken bleibt',
    () async {
      shop.clock.value = DateTime(2026, 11, 16, 12);
      final r = await shop.sell('gestern');
      shop.clock.value = DateTime(2026, 11, 17, 9);
      await shop.receipts.voidReceipt(r.id, staff: shop.chef);
      final today = await shop.stats.overview(StatsRange.today);
      expect((today.revenueCents, today.receiptCount), (-1820, -1));
      final week = await shop.stats.overview(StatsRange.days7);
      expect(week.buckets[5].label, '16.11.');
      expect(week.buckets[5].cents, 1820);
      expect(week.buckets[6].cents, -1820);
      expect((week.revenueCents, week.receiptCount), (0, 0));
    },
  );

  test(
    'Bestseller: höchstens fünf, nach Menge, bei Gleichstand nach Umsatz',
    () async {
      var cart = const Cart.empty();
      void add(String id, int n) {
        for (var i = 0; i < n; i++) {
          cart = cart.add(catalog.item(id));
        }
      }

      add('pommes', 6);
      add('edamame', 5);
      add('mochi', 4);
      add('bananenkuchen', 3);
      add('teigtaschen', 3);
      add('fruehlingsrollen', 1);
      await sellCart('viel', cart);
      final o = await shop.stats.overview(StatsRange.today);
      expect(o.topItems.map((i) => (i.name, i.quantity)), [
        ('Pommes', 6),
        ('Edamame', 5),
        ('Mochi', 4),
        ('Teigtaschen', 3),
        ('Bananenkuchen', 3),
      ]);
      expect(o.topItems.first.cents, 6 * 390);
    },
  );

  test(
    'entfernter Artikel bleibt unter seiner Kategorie, sonst Sonstiges',
    () async {
      await shop.sell('s1');
      final reduced = Catalog(
        business: catalog.business,
        categories: [
          for (final k in catalog.categories)
            if (k.id != 'getraenke') k,
        ],
        items: [
          for (final i in catalog.items)
            if (i.categoryId != 'getraenke') i,
        ],
        templates: catalog.templates,
      );
      await shop.catalogRepo.importCatalog(reduced);
      var o = await shop.stats.overview(StatsRange.today);
      expect(o.byCategory.map((c) => (c.name, c.cents)), [
        ('Bowls', 1190),
        ('Getränke', 580),
        ('Pfand', 50),
      ]);

      await (shop.db.delete(
        shop.db.itemRows,
      )..where((t) => t.id.equals('cola'))).go();
      o = await shop.stats.overview(StatsRange.today);
      expect(o.byCategory.map((c) => (c.name, c.cents)), [
        ('Bowls', 1190),
        ('Sonstiges', 580),
        ('Pfand', 50),
      ]);
      expect(o.byCategory.fold<int>(0, (s, c) => s + c.cents), o.revenueCents);
    },
  );

  test('Übersicht zählt den Kartenanteil', () async {
    await shop.sell('s1'); // 1820 bar
    final card = await shop.sellCard('c1');
    final o = await shop.stats.overview(StatsRange.today);
    expect(o.cashCents, 1820);
    expect(o.cardCents, card.totalCents);
    expect(o.revenueCents, 1820 + card.totalCents);
    expect(o.receiptCount, 2);
  });

  test('Sonderbelege zählen nicht: weder Anzahl noch Balken', () async {
    shop.clock.value = DateTime(2026, 11, 17, 11, 10);
    await shop.sell('s1'); // 1820
    final before = await shop.stats.overview(StatsRange.today);
    // Ein Startbeleg vor dem ersten Verkauf, ein Nullbeleg danach.
    await shop.insertSpecialReceipt(
      'st',
      2,
      ReceiptKind.start,
      at: DateTime(2026, 11, 17, 9),
    );
    await shop.insertSpecialReceipt('z', 3, ReceiptKind.zero);
    final o = await shop.stats.overview(StatsRange.today);
    expect(
      (o.revenueCents, o.receiptCount, o.voidCount, o.cashCents, o.cardCents),
      (1820, 1, 0, 1820, 0),
    );
    expect(
      o.buckets.map((b) => (b.label, b.cents)),
      before.buckets.map((b) => (b.label, b.cents)),
    );
    expect(o.buckets.map((b) => b.label), ['11']);
  });
}
