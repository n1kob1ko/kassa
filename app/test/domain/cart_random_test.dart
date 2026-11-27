import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/domain/cart.dart';
import 'package:kassa/domain/catalog.dart';

import '../support/random_cart.dart';

void main() {
  test('2000 zufällige Bons mit Pfand zurück, Gutschein-Zeilen und gewählten '
      'Gutscheinen: Zeilen ergeben den Bon, kein Rabatt auf Gutschein und '
      'Pfand zurück, noch zu zahlen nie unter 0', () {
    const seed = 20261127;
    final random = Random(seed);
    var withReturn = 0, withSale = 0, withVouchers = 0, belowZero = 0;
    for (var i = 0; i < 2000; i++) {
      final c = randomCart(random, withStufe1b: true);
      final p = c.pricing;
      final why = 'Seed $seed, Bon $i: ${jsonEncode(c.toJson())}';
      if (c.lines.any((l) => l.isDepositReturn)) withReturn++;
      if (c.hasVoucherSale) withSale++;
      if (c.vouchers.isNotEmpty) withVouchers++;
      if (p.totalCents < 0) belowZero++;
      // Die Anteile ergeben genau den Bon-Rabatt, auch ohne Gutschein-Zeilen.
      expect(
        p.lines.fold<int>(0, (s, l) => s + l.shareCents),
        p.receiptDiscountCents,
        reason: why,
      );
      expect(
        p.goodsCents,
        p.subtotalCents - p.receiptDiscountCents,
        reason: why,
      );
      expect(
        p.receiptDiscountCents,
        inInclusiveRange(0, max(0, p.discountBaseCents)),
        reason: why,
      );
      expect(
        p.discountBaseCents,
        p.subtotalCents - p.voucherSaleCents,
        reason: why,
      );
      // Das Pfand des Bons (verlangt minus zurück) ist das der Preise.
      expect(p.depositCents, c.depositCents, reason: why);
      expect(p.totalCents, p.goodsCents + p.depositCents, reason: why);
      expect(
        p.grossByRate.values.fold<int>(0, (a, b) => a + b),
        p.goodsCents,
        reason: why,
      );
      var sales = 0;
      for (final (n, l) in p.lines.indexed) {
        final line = c.lines[n];
        final whyLine = '$why, Zeile $n';
        expect(
          l.grossByRate.values.fold<int>(0, (a, b) => a + b),
          l.goodsCents,
          reason: whyLine,
        );
        expect(l.depositCents, line.depositCents, reason: whyLine);
        if (line.isVoucherSale || line.isDepositReturn) {
          expect(l.discountCents, 0, reason: whyLine);
          expect(l.goodsCents, l.listCents, reason: whyLine);
        }
        if (line.isDepositReturn) {
          expect(
            (l.listCents, line.depositCents < 0),
            (0, true),
            reason: whyLine,
          );
        }
        if (line.isVoucherSale) {
          sales += l.goodsCents;
          expect(l.grossByRate, {
            TaxRate.zero: line.item.priceCents,
          }, reason: whyLine);
        }
      }
      expect(p.voucherSaleCents, sales, reason: why);
      expect(
        p.voucherCents,
        p.voucherUses.fold<int>(0, (s, u) => s + u.amountCents),
        reason: why,
      );
      expect(p.dueCents, p.totalCents - p.voucherCents, reason: why);
      if (p.totalCents >= 0) {
        expect(p.dueCents, greaterThanOrEqualTo(0), reason: why);
      } else {
        expect(p.voucherUses, isEmpty, reason: why);
      }
      for (final u in p.voucherUses) {
        final v = c.vouchers.singleWhere((v) => v.voucherId == u.voucherId);
        final whyUse = '$why, Gutschein ${u.voucherId}';
        expect(
          u.amountCents,
          inInclusiveRange(1, v.balanceCents),
          reason: whyUse,
        );
        expect(
          u.balanceAfterCents,
          v.balanceCents - u.amountCents,
          reason: whyUse,
        );
      }
      expect(c.hasVoucherSale && c.vouchers.isNotEmpty, isFalse, reason: why);
      final back = Cart.fromJson(c.toJson(), catalogOf(c));
      expect(
        (back.pricing.totalCents, back.pricing.dueCents, back.lines.length),
        (p.totalCents, p.dueCents, c.lines.length),
        reason: why,
      );
    }
    // Jeder Fall kommt oft genug vor.
    for (final (name, count) in [
      ('Pfand zurück', withReturn),
      ('Gutschein-Zeile', withSale),
      ('gewählte Gutscheine', withVouchers),
      ('Summe unter 0', belowZero),
    ]) {
      expect(count, greaterThan(50), reason: name);
    }
  });

  test('ohne den Schalter: kein Pfand zurück, keine Gutscheine', () {
    final random = Random(7);
    for (var i = 0; i < 200; i++) {
      final x = randomCart(random);
      expect(
        x.lines.any((l) => l.isDepositReturn || l.isVoucherSale),
        isFalse,
        reason: 'Seed 7, Bon $i',
      );
      expect(x.vouchers, isEmpty, reason: 'Seed 7, Bon $i');
    }
  });
}
