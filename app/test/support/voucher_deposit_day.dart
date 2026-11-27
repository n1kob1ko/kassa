// Ein Tag mit Pfand zurück und Gutscheinen für die Tests der Auswertungen.
// Ohne Erwartungen.

import 'package:kassa/domain/cart.dart';

import 'sales.dart';

/// Vier Bons zur Zeit der Uhr, Ids `a` bis `d`:
/// A: [cart] bar (18,20 €). B: ein Gutschein über 25,00 € bar verkauft.
/// C: [cartCard] (9,65 €) mit diesem Gutschein bezahlt. D: 3 × Pfand zurück
/// zu 0,25 € ausbezahlt (−0,75 €).
Future<void> sellVoucherDepositDay(TestShop shop) async {
  await shop.sell('a');
  final voucher = await sellVoucher(shop, 2500, saleId: 'b');
  await shop.receipts.finalizeVoucherSale(
    saleId: 'c',
    cart: cartCard.applyVoucher(applied(voucher)),
    staff: shop.anna,
  );
  await shop.receipts.finalizePayout(
    saleId: 'd',
    cart: const Cart.empty().setDepositReturn(depositCents: 25, quantity: 3),
    staff: shop.anna,
  );
}
