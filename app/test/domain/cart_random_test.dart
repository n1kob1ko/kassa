import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/domain/cart.dart';
import 'package:kassa/domain/catalog.dart';

import '../support/random_cart.dart';

void main() {
  test('2000 zufällige Bons mit Pfand zurück, Gutschein-Zeilen und gewählten '
      'Gutscheinen: Zeilen ergeben den Bon, kein Rabatt auf Gutschein und '
      'Pfand zurück, noch zu zahlen nie unter 0', () {
    final random = Random(20261127);
    var withReturn = 0, withSale = 0, withVouchers = 0, belowZero = 0;
    for (var i = 0; i < 2000; i++) {
      final c = randomCart(random, withStufe1b: true);
      final p = c.pricing;
      if (c.lines.any((l) => l.isDepositReturn)) withReturn++;
      if (c.hasVoucherSale) withSale++;
      if (c.vouchers.isNotEmpty) withVouchers++;
      if (p.totalCents < 0) belowZero++;
      expect(
        p.lines.fold<int>(0, (s, l) => s + l.goodsCents),
        p.goodsCents,
        reason: '$i',
      );
      expect(
        p.lines.fold<int>(0, (s, l) => s + l.depositCents),
        p.depositCents,
        reason: '$i',
      );
      expect(p.totalCents, p.goodsCents + p.depositCents, reason: '$i');
      expect(
        p.grossByRate.values.fold<int>(0, (a, b) => a + b),
        p.goodsCents,
        reason: '$i',
      );
      var sales = 0;
      for (final (n, l) in p.lines.indexed) {
        final line = c.lines[n];
        if (line.isVoucherSale || line.isDepositReturn) {
          expect(l.discountCents, 0, reason: '$i/$n');
          expect(l.goodsCents, l.listCents, reason: '$i/$n');
        }
        if (line.isVoucherSale) {
          sales += l.goodsCents;
          expect(l.grossByRate, {TaxRate.zero: line.item.priceCents});
        }
      }
      expect(p.voucherSaleCents, sales, reason: '$i');
      expect(
        p.voucherCents,
        p.voucherUses.fold<int>(0, (s, u) => s + u.amountCents),
        reason: '$i',
      );
      expect(p.dueCents, p.totalCents - p.voucherCents, reason: '$i');
      if (p.totalCents >= 0) {
        expect(p.dueCents, greaterThanOrEqualTo(0), reason: '$i');
      }
      for (final u in p.voucherUses) {
        final v = c.vouchers.singleWhere((v) => v.voucherId == u.voucherId);
        expect(u.amountCents, inInclusiveRange(1, v.balanceCents));
        expect(u.balanceAfterCents, v.balanceCents - u.amountCents);
      }
      expect(c.hasVoucherSale && c.vouchers.isNotEmpty, isFalse, reason: '$i');
      final back = Cart.fromJson(c.toJson(), catalogOf(c));
      expect(
        (back.pricing.totalCents, back.pricing.dueCents, back.lines.length),
        (p.totalCents, p.dueCents, c.lines.length),
        reason: '$i',
      );
    }
    // Jeder Fall kommt oft genug vor.
    for (final count in [withReturn, withSale, withVouchers, belowZero]) {
      expect(count, greaterThan(50));
    }
  });

  test('ohne den Schalter: kein Pfand zurück, keine Gutscheine', () {
    final random = Random(7);
    for (var i = 0; i < 200; i++) {
      final x = randomCart(random);
      expect(x.lines.any((l) => l.isDepositReturn || l.isVoucherSale), isFalse);
      expect(x.vouchers, isEmpty);
    }
  });
}
