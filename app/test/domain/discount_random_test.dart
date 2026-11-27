import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/domain/cart.dart';

import '../support/random_cart.dart';

void main() {
  test('2000 zufällige Bons: Zeilen ergeben den Bon, nichts wird negativ, zweimal gerechnet ist gleich', () {
    final random = Random(20261126);
    for (var i = 0; i < 2000; i++) {
      final c = randomCart(random);
      final p = c.pricing;
      expect(
        p.lines.fold<int>(0, (s, l) => s + l.discountCents),
        p.discountCents,
        reason: '$i',
      );
      expect(
        p.lines.fold<int>(0, (s, l) => s + l.goodsCents),
        p.goodsCents,
        reason: '$i',
      );
      expect(p.totalCents, p.goodsCents + p.depositCents, reason: '$i');
      expect(
        p.grossByRate.values.fold<int>(0, (a, b) => a + b),
        p.goodsCents,
        reason: '$i',
      );
      for (final (n, l) in p.lines.indexed) {
        expect(
          l.discountCents,
          inInclusiveRange(0, l.listCents),
          reason: '$i/$n',
        );
        expect(
          l.grossByRate.values.fold<int>(0, (a, b) => a + b),
          l.goodsCents,
          reason: '$i/$n',
        );
        final before = c.lines[n].listGrossByRate;
        for (final rate in before.keys) {
          expect(
            l.grossByRate[rate] ?? 0,
            greaterThanOrEqualTo(min(0, before[rate]!)),
            reason: '$i/$n/$rate',
          );
        }
      }
      expect(p.totalCents, greaterThanOrEqualTo(p.depositCents), reason: '$i');
      expect(
        Cart.fromJson(c.toJson(), catalogOf(c)).pricing.totalCents,
        p.totalCents,
        reason: '$i',
      );
    }
  });
}
