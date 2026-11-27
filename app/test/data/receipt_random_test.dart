import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/data/receipt_repository.dart';
import 'package:kassa/domain/cart.dart'
    show isReservedItemId, isVoucherSaleItemId;
import 'package:kassa/domain/catalog.dart';
import 'package:kassa/domain/receipt.dart';
import 'package:kassa/domain/receipt_rules.dart';
import 'package:kassa/domain/voucher.dart';

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

  test('200 zufällige Bons mit Pfand zurück, Gutschein-Verkauf und '
      'Gutschein-Zahlung: Regeln halten, Storno ist das Spiegelbild, am Ende '
      'hat jeder Gutschein wieder sein Guthaben vom Verkauf oder ist '
      'storniert', () async {
    final random = Random(20261128);
    void rulesHold(Receipt r, String reason) {
      expect(
        () => checkReceiptRules(
          goodsCents: r.goodsCents,
          depositCents: r.depositCents,
          totalCents: r.totalCents,
          discountCents: r.discountCents,
          lines: r.lines,
          payments: r.payments,
          isVoid: r.kind == ReceiptKind.voided,
        ),
        returnsNormally,
        reason: reason,
      );
    }

    Future<Receipt> voidAndCompare(Receipt r, String reason) async {
      final v = await shop.receipts.voidReceipt(r.id, staff: shop.chef);
      rulesHold(v, reason);
      expect(v.publicToken, allOf(hasLength(22), isNot(r.publicToken)));
      expect(
        (v.totalCents, v.goodsCents, v.depositCents, v.tipCents),
        (-r.totalCents, -r.goodsCents, -r.depositCents, -r.tipCents),
        reason: reason,
      );
      expect(
        (v.depositReturnCents, v.depositReturnQuantity, v.voucherSaleCents),
        (-r.depositReturnCents, -r.depositReturnQuantity, -r.voucherSaleCents),
        reason: reason,
      );
      expect(v.grossByRate, negated(r.grossByRate), reason: reason);
      expect(
        [for (final l in v.lines) (l.itemId, l.quantity, l.info)],
        [for (final l in r.lines) (l.itemId, -l.quantity, l.info)],
        reason: reason,
      );
      expect(
        [
          for (final p in v.payments)
            (p.kind, p.amountCents, p.tipCents, p.voucherId, p.voucherCode),
        ],
        [
          for (final p in r.payments)
            (p.kind, -p.amountCents, -p.tipCents, p.voucherId, p.voucherCode),
        ],
        reason: reason,
      );
      expect(
        [for (final s in v.soldVouchers) (s.voucherId, s.valueCents)],
        [for (final s in r.soldVouchers) (s.voucherId, -s.valueCents)],
        reason: reason,
      );
      for (final p in v.payments) {
        if (p.kind != PaymentKind.voucher) continue;
        expect(
          p.voucherBalanceAfterCents,
          await shop.vouchers.balanceOf(p.voucherId!),
          reason: reason,
        );
      }
      for (final s in r.soldVouchers) {
        final voucher = (await shop.vouchers.byId(s.voucherId))!;
        expect(voucher.state, VoucherState.voided, reason: reason);
      }
      return v;
    }

    final valueOf = <String, int>{};
    final pool = <String>[];
    final keptSales = <Receipt>[];
    final keptOthers = <Receipt>[];
    var payouts = 0, voucherOnly = 0, redeemed = 0;
    for (var n = 0; n < 200; n++) {
      final reason = 'Bon $n';
      var c = randomCart(random, withStufe1b: true);
      // Die Zeilen aus dem Code (Pfand zurück, Gutschein) gehören in keinen
      // Katalog.
      final all = catalogOf(c);
      await shop.catalogRepo.importCatalog(
        Catalog(
          business: all.business,
          categories: all.categories,
          items: [
            for (final i in all.items)
              if (!isReservedItemId(i.id)) i,
          ],
          templates: all.templates,
        ),
      );
      // Statt der erfundenen Gutscheine echte aus den Verkäufen davor.
      if (c.vouchers.isNotEmpty) {
        final count = c.vouchers.length;
        for (final v in [...c.vouchers]) {
          c = c.removeVoucher(v.voucherId);
        }
        for (final id in ([...pool]..shuffle(random)).take(count)) {
          final v = (await shop.vouchers.byId(id))!;
          if (v.balanceCents > 0) c = c.applyVoucher(applied(v));
        }
      }
      final p = c.pricing;
      final id = 'b$n';
      final Receipt r;
      if (p.totalCents < 0) {
        payouts++;
        r = await shop.receipts.finalizePayout(
          saleId: id,
          cart: c,
          staff: shop.anna,
        );
      } else if (p.voucherCents > 0 && p.dueCents == 0) {
        voucherOnly++;
        r = await shop.receipts.finalizeVoucherSale(
          saleId: id,
          cart: c,
          staff: shop.anna,
        );
      } else if (n % 3 == 2 && p.dueCents >= 2) {
        r = await shop.receipts.finalizeCardSale(
          saleId: id,
          cart: c,
          staff: shop.anna,
          provider: 'sumup',
          cashPartCents: p.dueCents ~/ 2,
          tipCents: random.nextInt(300),
        );
      } else {
        r = await shop.receipts.finalizeCashSale(
          saleId: id,
          cart: c,
          givenCents: p.dueCents + random.nextInt(500),
          staff: shop.anna,
        );
      }
      rulesHold(r, reason);
      expect(r.publicToken, hasLength(22), reason: reason);
      expect(
        (r.totalCents, r.goodsCents, r.discountCents, r.voucherCents),
        (p.totalCents, p.goodsCents, p.discountCents, p.voucherCents),
        reason: reason,
      );
      expect(r.voucherSaleCents, p.voucherSaleCents, reason: reason);
      expect(r.revenueCents, p.totalCents - p.voucherSaleCents);
      expect(r.grossByRate, p.grossByRate, reason: reason);
      expect(
        [
          for (final x in r.payments)
            if (x.kind == PaymentKind.voucher)
              (x.voucherId, x.amountCents, x.voucherBalanceAfterCents),
        ],
        [
          for (final u in p.voucherUses)
            (u.voucherId, u.amountCents, u.balanceAfterCents),
        ],
        reason: reason,
      );
      for (final u in p.voucherUses) {
        redeemed++;
        expect(
          await shop.vouchers.balanceOf(u.voucherId),
          u.balanceAfterCents,
          reason: reason,
        );
      }
      final saleLines = [
        for (final l in r.lines)
          if (isVoucherSaleItemId(l.itemId)) l,
      ];
      expect(
        [for (final s in r.soldVouchers) (s.linePosition, s.valueCents)],
        [for (final l in saleLines) (l.position, l.unitPriceCents)],
        reason: reason,
      );
      for (var i = 0; i < saleLines.length; i++) {
        final s = r.soldVouchers[i];
        expect(
          saleLines[i].info,
          'Code ${formatVoucherCode(s.code)}',
          reason: reason,
        );
        expect(await shop.vouchers.balanceOf(s.voucherId), s.valueCents);
        valueOf[s.voucherId] = s.valueCents;
      }

      // Die Hälfte gleich stornieren, den Rest am Ende.
      if (random.nextBool()) {
        await voidAndCompare(r, reason);
      } else if (r.soldVouchers.isNotEmpty) {
        keptSales.add(r);
        pool.addAll([for (final s in r.soldVouchers) s.voucherId]);
      } else {
        keptOthers.add(r);
      }
    }
    // Damit der Test etwas prüft: jede Art kam vor.
    expect(payouts, greaterThan(0));
    expect(voucherOnly, greaterThan(0));
    expect(redeemed, greaterThan(10));

    // Ein Gutschein-Verkauf, dessen Gutschein eingelöst ist, bleibt stehen.
    var refused = 0;
    for (final r in keptSales) {
      final touched = [
        for (final s in r.soldVouchers)
          if (await shop.vouchers.balanceOf(s.voucherId) != s.valueCents) s,
      ];
      if (touched.isEmpty) continue;
      refused++;
      final rows = await shop.count('receipts');
      final moves = await shop.count('voucher_movements');
      await expectLater(
        shop.receipts.voidReceipt(r.id, staff: shop.chef),
        throwsA(isA<VoucherSaleRedeemedException>()),
      );
      expect(
        (await shop.count('receipts'), await shop.count('voucher_movements')),
        (rows, moves),
      );
    }
    expect(refused, greaterThan(0));

    // Alle übrigen Bons storniert, dann jeder zweite Gutschein-Verkauf.
    for (final r in keptOthers.reversed) {
      await voidAndCompare(r, 'Storno ${r.id}');
    }
    for (var i = 0; i < keptSales.length; i += 2) {
      await voidAndCompare(keptSales[i], 'Storno ${keptSales[i].id}');
    }
    final states = <VoucherState>{};
    for (final e in valueOf.entries) {
      final v = (await shop.vouchers.byId(e.key))!;
      states.add(v.state);
      expect(
        v.state == VoucherState.voided
            ? v.balanceCents
            : v.balanceCents - e.value,
        0,
        reason: 'Gutschein ${v.code}',
      );
    }
    expect(states, {VoucherState.voided, VoucherState.active});
  });
}
