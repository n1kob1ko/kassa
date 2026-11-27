import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/domain/cart.dart';
import 'package:kassa/domain/catalog.dart';
import 'package:kassa/domain/receipt.dart';
import 'package:kassa/domain/stats.dart';

import '../support/demo_fixtures.dart';
import '../support/sales.dart';
import '../support/voucher_deposit_day.dart';

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

  test('freier Betrag: "Diverses 20 %" bei meistverkauft, "Sonstiges" bei '
      'den Kategorien', () async {
    await sellCart(
      's1',
      const Cart.empty()
          .add(teigtaschen)
          .addOpenAmount(amountCents: 1250, rate: TaxRate.normal)
          .addOpenAmount(amountCents: 300, rate: TaxRate.normal)
          .addOpenAmount(amountCents: 400, rate: TaxRate.reduced1),
    );
    final o = await shop.stats.overview(StatsRange.today);
    expect(o.topItems.map((i) => (i.name, i.quantity, i.cents)), [
      ('Diverses 20 %', 2, 1550),
      ('Teigtaschen', 1, 650),
      ('Diverses 10 %', 1, 400),
    ]);
    final teigtaschenCategory = catalog.categories
        .firstWhere((k) => k.id == teigtaschen.categoryId)
        .name;
    expect(o.byCategory.map((c) => (c.name, c.cents)), [
      ('Sonstiges', 1950),
      (teigtaschenCategory, 650),
    ]);
    expect(o.byCategory.fold<int>(0, (s, c) => s + c.cents), o.revenueCents);
  });

  test('Übersicht zählt den Kartenanteil', () async {
    await shop.sell('s1'); // 1820 bar
    final card = await shop.sellCard('c1');
    final o = await shop.stats.overview(StatsRange.today);
    expect(o.cashCents, 1820);
    expect(o.cardCents, card.totalCents);
    expect(o.revenueCents, 1820 + card.totalCents);
    expect(o.receiptCount, 2);
  });

  test('Übersicht: Zahlungsarten aus den Zahlungen', () async {
    await shop.sell('a'); // bar 18,20
    await shop.sellCard('b'); // Karte 9,65
    await shop.sellCard('m1', cart: cart, cashPartCents: 1000, tipCents: 80);
    final o = await shop.stats.overview(StatsRange.today);
    expect(
      (o.revenueCents, o.cashCents, o.cardCents, o.receiptCount),
      (4605, 2820, 1785, 3),
    );
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

  test('meistverkauft und Kategorien nach Rabatt', () async {
    await sellCart('r1', discounted);
    final o = await shop.stats.overview(StatsRange.today);
    expect(o.topItems.map((i) => (i.name, i.quantity, i.cents)), [
      ('Cola 0,33 l', 2, 522),
      ('Huhn Bowl', 1, 964),
    ]);
    final names = {for (final k in catalog.categories) k.id: k.name};
    expect(o.byCategory.map((c) => (c.name, c.cents)), [
      (names[huhnBowl.categoryId], 964),
      (names[cola.categoryId], 522),
      ('Pfand', 50),
    ]);
    expect(o.byCategory.fold<int>(0, (s, c) => s + c.cents), o.revenueCents);
  });

  test('Gutschein und Pfand zurück stehen nicht bei meistverkauft; der Umsatz '
      'ist ohne den verkauften Gutschein', () async {
    await sellVoucherDepositDay(shop);
    final o = await shop.stats.overview(StatsRange.today);
    expect(
      (
        o.revenueCents,
        o.cashCents,
        o.cardCents,
        o.voucherCents,
        o.receiptCount,
      ),
      (2710, 4245, 0, 965, 4),
    );
    expect(o.topItems.map((i) => i.name), [
      cola.name,
      huhnBowl.name,
      teigtaschen.name,
    ]);
    expect(o.topItems.first.quantity, 3);
    expect(o.byCategory.fold<int>(0, (s, c) => s + c.cents), o.revenueCents);
    expect(o.buckets.fold<int>(0, (s, b) => s + b.cents), o.revenueCents);

    // Der Gutschein-Verkauf allein ist kein Umsatz.
    await shop.receipts.voidReceipt('c', staff: shop.chef);
    await shop.receipts.voidReceipt('d', staff: shop.chef);
    await shop.receipts.voidReceipt('a', staff: shop.chef);
    final v = await shop.stats.overview(StatsRange.today);
    expect(
      (v.revenueCents, v.cashCents, v.cardCents, v.voucherCents),
      (0, 2500, 0, 0),
    );
    expect(v.topItems, isEmpty);
    expect(v.byCategory, isEmpty);
    expect(v.buckets.map((b) => b.cents), [0]);
  });
  test('die gemeinsame Datei stufe_1b.json: die Zahlen des Tablets für die '
      'vier Bons, so wie der Server sie nachrechnet', () {
    // Die Datei schreibt test/sync/shared_fixtures_test.dart aus einer echten
    // Datenbank; hier stehen dieselben Zahlen von Hand.
    final file = File('../shared/fixtures/stats/stufe_1b.json');
    final fx = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
    final expected = fx['expected']! as Map<String, Object?>;
    final receipts = fx['receipts']! as List<Object?>;
    expect([for (final r in receipts) (r! as Map)['v']], [3, 3, 3, 3]);
    expect(
      [for (final r in receipts) (r! as Map)['totalCents']],
      [1820, 2500, 965, -75],
    );

    (int, int, int, int, int) newFigures(Map<String, Object?> m) => (
      m['voucherPaidCents']! as int,
      m['voucherSoldCount']! as int,
      m['voucherSoldCents']! as int,
      m['depositReturnCount']! as int,
      m['depositReturnCents']! as int,
    );
    final day = expected['day']! as Map<String, Object?>;
    final summary = expected['summary']! as Map<String, Object?>;
    expect(
      (day['revenueCents'], day['cashCents'], day['cardCents']),
      (2710, 4245, 0),
    );
    expect(newFigures(day), (965, 1, 2500, 3, 75));
    expect(
      (day['receiptCount'], day['cashReceiptCount'], day['cardReceiptCount']),
      (4, 3, 0),
    );
    expect(
      (
        summary['revenueCents'],
        summary['cashRevenueCents'],
        summary['cardRevenueCents'],
      ),
      (2710, 4245, 0),
    );
    expect(newFigures(summary), (965, 1, 2500, 3, 75));
    expect(summary['rows'], [
      {'key': '2026-10-14', 'receiptCount': 4, 'revenueCents': 2710},
    ]);
    expect(expected['months'], [
      {'month': '2026-10', 'receiptCount': 4, 'revenueCents': 2710},
    ]);
    // Bar + Karte + mit Gutschein bezahlt − Gutscheine verkauft = Umsatz.
    int identity(Map<String, Object?> m, String cash, String card) =>
        (m[cash]! as int) +
        (m[card]! as int) +
        (m['voucherPaidCents']! as int) -
        (m['voucherSoldCents']! as int);
    expect(identity(day, 'cashCents', 'cardCents'), day['revenueCents']);
    expect(
      identity(summary, 'cashRevenueCents', 'cardRevenueCents'),
      summary['revenueCents'],
    );

    final days30 =
        (expected['overview']! as Map<String, Object?>)['days30']!
            as Map<String, Object?>;
    expect(
      (
        days30['revenueCents'],
        days30['cashCents'],
        days30['cardCents'],
        days30['voucherCents'],
        days30['receiptCount'],
      ),
      (2710, 4245, 0, 965, 4),
    );
    expect(
      [for (final i in days30['topItems']! as List) (i as Map)['name']],
      [cola.name, huhnBowl.name, teigtaschen.name],
    );
  });
}
