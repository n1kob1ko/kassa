import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/domain/catalog.dart';
import 'package:kassa/domain/receipt.dart';

import '../support/random_cart.dart';
import '../support/sales.dart';

void main() {
  late TestShop shop;

  setUp(() async => shop = await TestShop.open());
  tearDown(() => shop.close());

  Map<TaxRate, int> negated(Map<TaxRate, int> m) => {
    for (final e in m.entries) e.key: -e.value,
  };

  test('200 zufällige Bons mit Rabatt: gespeichert wie gerechnet, Storno ist '
      'das Spiegelbild, die Regeln halten', () async {
    final random = Random(20261127);
    for (var n = 0; n < 200; n++) {
      final c = randomCart(random);
      // Die Artikel und Optionen des Bons im Katalog der Datenbank, damit
      // die Gruppennamen der Optionen gefunden werden.
      await shop.catalogRepo.importCatalog(catalogOf(c));
      final p = c.pricing;
      final id = 'b$n';
      final Receipt r;
      if (n % 3 == 2 && p.totalCents >= 2) {
        r = await shop.receipts.finalizeCardSale(
          saleId: id,
          cart: c,
          staff: shop.anna,
          provider: 'sumup',
          cashPartCents: p.totalCents ~/ 2,
          tipCents: random.nextInt(300),
        );
      } else {
        r = await shop.receipts.finalizeCashSale(
          saleId: id,
          cart: c,
          givenCents: p.totalCents + random.nextInt(500),
          staff: shop.anna,
        );
      }
      final reason = 'Bon $n';
      expect(r.totalCents, p.totalCents, reason: reason);
      expect(r.goodsCents, p.goodsCents, reason: reason);
      expect(r.discountCents, p.discountCents, reason: reason);
      expect(
        r.discount?.amountCents ?? 0,
        p.receiptDiscountCents,
        reason: reason,
      );
      expect(r.grossByRate, p.grossByRate, reason: reason);
      expect(
        [for (final l in r.lines) l.discountCents],
        [for (final l in p.lines) l.discountCents],
        reason: reason,
      );

      final v = await shop.receipts.voidReceipt(id, staff: shop.chef);
      expect(v.totalCents, -r.totalCents, reason: reason);
      expect(v.goodsCents, -r.goodsCents, reason: reason);
      expect(v.discountCents, -r.discountCents, reason: reason);
      expect(v.subtotalCents, -r.subtotalCents, reason: reason);
      expect(v.tipCents, -r.tipCents, reason: reason);
      expect(v.grossByRate, negated(r.grossByRate), reason: reason);
      expect(v.lines.length, r.lines.length, reason: reason);
      for (var i = 0; i < r.lines.length; i++) {
        final a = r.lines[i], b = v.lines[i];
        expect(b.discountCents, -a.discountCents, reason: reason);
        expect(b.grossByRate, negated(a.grossByRate), reason: reason);
        expect(
          b.discount?.amountCents,
          a.discount == null ? null : -a.discount!.amountCents,
          reason: reason,
        );
      }
      expect(v.payments.length, r.payments.length, reason: reason);
      for (var i = 0; i < r.payments.length; i++) {
        expect(
          v.payments[i].amountCents,
          -r.payments[i].amountCents,
          reason: reason,
        );
        expect(v.payments[i].tipCents, -r.payments[i].tipCents, reason: reason);
      }
    }
    final s = (await shop.days.summary())!;
    expect((s.revenueCents, s.cashRevenueCents, s.cardRevenueCents), (0, 0, 0));
  });
}
