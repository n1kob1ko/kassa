// Ein Tag mit Pfand zurück und Gutscheinen für die Tests der Auswertungen.
// Ohne Erwartungen.

import 'package:kassa/data/receipt_repository.dart';
import 'package:kassa/domain/cart.dart';
import 'package:kassa/domain/staff.dart';

import 'sales.dart';

/// Vier Bons zur Zeit der Uhr, Ids `a` bis `d` (oder die vier aus [ids]):
/// A: [cart] bar (18,20 €). B: ein Gutschein über 25,00 € bar verkauft.
/// C: [cartCard] (9,65 €) mit diesem Gutschein bezahlt. D: 3 × Pfand zurück
/// zu 0,25 € ausbezahlt (−0,75 €).
Future<void> sellVoucherDepositDay(
  TestShop shop, {
  List<String> ids = const ['a', 'b', 'c', 'd'],
}) async {
  await shop.sell(ids[0]);
  final voucher = await sellVoucher(shop, 2500, saleId: ids[1]);
  await shop.receipts.finalizeVoucherSale(
    saleId: ids[2],
    cart: cartCard.applyVoucher(applied(voucher)),
    staff: shop.anna,
  );
  await shop.receipts.finalizePayout(
    saleId: ids[3],
    cart: const Cart.empty().setDepositReturn(depositCents: 25, quantity: 3),
    staff: shop.anna,
  );
}

/// Die Bons B bis D von [sellVoucherDepositDay] über [receipts] als [staff],
/// für Tests am Bildschirm (Bon A ist dort der übliche Verkauf zu 18,20 €).
Future<void> sellVoucherAndPayout(
  ReceiptRepository receipts,
  Staff staff, {
  List<String> ids = const ['b', 'c', 'd'],
}) async {
  final sold = (await receipts.finalizeCashSale(
    saleId: ids[0],
    cart: const Cart.empty().addVoucherSale(valueCents: 2500),
    givenCents: 2500,
    staff: staff,
  )).soldVouchers.single;
  await receipts.finalizeVoucherSale(
    saleId: ids[1],
    cart: cartCard.applyVoucher(
      AppliedVoucher(
        voucherId: sold.voucherId,
        code: sold.code,
        balanceCents: 2500,
      ),
    ),
    staff: staff,
  );
  await receipts.finalizePayout(
    saleId: ids[2],
    cart: const Cart.empty().setDepositReturn(depositCents: 25, quantity: 3),
    staff: staff,
  );
}
