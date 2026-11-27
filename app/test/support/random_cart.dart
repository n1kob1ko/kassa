// Zufällige offene Bons für Tests, die viele Bons durchrechnen. Ohne
// Erwartungen: nur der Bon und ein Katalog, aus dem er sich wieder lesen lässt.

import 'dart:math';

import 'package:kassa/domain/cart.dart';
import 'package:kassa/domain/catalog.dart';
import 'package:kassa/domain/discount.dart';

/// 1 bis 8 Zeilen; Preis 0 bis 50,00; Menge 1 bis 9; Pfand 0 oder 0,25;
/// 0 bis 2 Optionen mit Aufpreis -1,00 bis 3,00 (Einzelpreis nie unter 0),
/// teils mit eigenem Satz; jede dritte Zeile mit Rabatt (Prozent aus
/// [discountPercents] oder Betrag bis zum Doppelten des Werts); jeder zweite
/// Bon mit Bon-Rabatt.
///
/// Mit [withStufe1b] kommen nach den Zeilen dazu: bei jedem zweiten Bon 0 bis 2
/// Zeilen "Pfand zurück" (0,25 oder 1,00 €, Menge 1 bis 60), dann entweder
/// 1 bis 2 Gutschein-Zeilen (1,00 bis 500,00 €) oder 0 bis 3 gewählte
/// Gutscheine (Guthaben 0 bis 50,00 €). Ohne den Schalter ist der Bon genau
/// wie bisher (dieselben Zufallszahlen in derselben Reihenfolge).
Cart randomCart(Random random, {bool withStufe1b = false}) {
  T pick<T>(List<T> list) => list[random.nextInt(list.length)];
  Discount randomDiscount(int valueCents) {
    final reason = pick(DiscountReason.values);
    if (random.nextBool()) {
      return Discount.percent(pick(discountPercents), reason);
    }
    return Discount.amount(1 + random.nextInt(max(1, 2 * valueCents)), reason);
  }

  var cart = const Cart.empty();
  final lineCount = 1 + random.nextInt(8);
  for (var n = 0; n < lineCount; n++) {
    final price = random.nextInt(5001);
    final options = <ModifierOption>[];
    var unit = price;
    for (var k = random.nextInt(3); k > 0; k--) {
      // Nie unter 0 im Einzelpreis: der Minus-Aufpreis höchstens so groß wie
      // der Preis bisher.
      final surcharge = max(-100, -unit) + random.nextInt(301 + min(100, unit));
      unit += surcharge;
      options.add(
        ModifierOption(
          id: 'o$n/${options.length}',
          name: 'Option ${options.length}',
          surchargeCents: surcharge,
          taxRate: random.nextBool() ? pick(TaxRate.values) : null,
        ),
      );
    }
    final item = Item(
      id: 'i$n',
      name: 'Artikel $n',
      priceCents: price,
      categoryId: 'c',
      taxRate: pick(TaxRate.values),
      depositCents: random.nextBool() ? 25 : 0,
      templateId: options.isEmpty ? null : 't$n',
      position: n,
    );
    final lineId = 'l$n';
    cart = cart
        .add(item, options: options, lineId: lineId)
        .setQuantity(lineId, 1 + random.nextInt(9));
    if (n % 3 == 0) {
      final line = cart.lines.last;
      cart = cart.setLineDiscount(lineId, randomDiscount(line.goodsCents));
    }
  }
  if (withStufe1b) {
    if (random.nextBool()) {
      for (final cents in [25, 100]) {
        if (random.nextBool()) {
          cart = cart.setDepositReturn(
            depositCents: cents,
            quantity: 1 + random.nextInt(60),
          );
        }
      }
    }
    if (random.nextBool()) {
      for (var k = 1 + random.nextInt(2); k > 0; k--) {
        cart = cart.addVoucherSale(
          valueCents:
              voucherMinCents +
              random.nextInt(voucherMaxCents - voucherMinCents + 1),
        );
      }
    } else {
      for (var k = random.nextInt(4); k > 0; k--) {
        cart = cart.applyVoucher(
          AppliedVoucher(
            voucherId: 'v$k',
            code: '${10000000 + k}',
            balanceCents: random.nextInt(5001),
          ),
        );
      }
    }
  }
  if (random.nextBool()) {
    cart = cart.setReceiptDiscount(randomDiscount(cart.pricing.subtotalCents));
  }
  return cart;
}

/// Ein Katalog mit genau den Artikeln und Optionen von [cart], damit
/// [Cart.fromJson] den Bon wieder lesen kann.
Catalog catalogOf(Cart cart) => Catalog(
  business: const BusinessInfo(name: 'Beispiel-Imbiss'),
  categories: const [Category(id: 'c', name: 'Alles', position: 0)],
  items: [for (final l in cart.lines) l.item],
  templates: [
    for (final l in cart.lines)
      if (l.item.templateId != null)
        ModifierTemplate(
          id: l.item.templateId!,
          name: 'Vorlage',
          groups: [
            ModifierGroup(
              id: 'g${l.item.id}',
              name: 'Gruppe',
              min: 0,
              max: null,
              options: l.options,
            ),
          ],
        ),
  ],
);
