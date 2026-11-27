import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/core/clock.dart';
import 'package:kassa/data/database.dart';
import 'package:kassa/data/day_repository.dart';
import 'package:kassa/data/receipt_repository.dart';
import 'package:kassa/domain/cart.dart' show isReservedItemId;
import 'package:kassa/domain/catalog.dart';
import 'package:kassa/domain/day.dart';
import 'package:kassa/domain/receipt.dart';
import 'package:kassa/domain/staff.dart';

import '../support/random_cart.dart';
import '../support/sales.dart';
import '../support/voucher_deposit_day.dart';

void main() {
  late TestShop shop;
  late DayRepository days;
  late ReceiptRepository receipts;
  late KassaDatabase db;
  late FixedClock clock;
  late Staff chef;
  late Future<Receipt> Function(String) sell;

  setUp(() async {
    shop = await TestShop.open();
    days = shop.days;
    receipts = shop.receipts;
    db = shop.db;
    clock = shop.clock;
    chef = shop.chef;
    sell = shop.sell;
  });
  tearDown(() => shop.close());

  test(
    'der erste Bon öffnet den Tag, Wechselgeld fehlt am ersten Tag',
    () async {
      expect(await days.openDay(), isNull);
      await sell('s1');
      expect((await days.openDay())!.openedAt, DateTime(2026, 11, 17, 11));
      expect(await days.needsOpeningFloat(), isTrue);
      await days.setOpeningFloat(15000);
      expect(await days.needsOpeningFloat(), isFalse);
    },
  );

  test('Soll = Wechselgeld + Bar-Einnahmen + Einlagen - Entnahmen, Storno zählt ab', () async {
    await days.setOpeningFloat(15000);
    final a = await sell('s1'); // 1820
    await sell('s2'); // 1820
    await receipts.voidReceipt(a.id, staff: chef);
    await days.addMovement(
      kind: CashMovementKind.deposit,
      amountCents: 5000,
      reason: CashReason.change,
      staff: chef,
    );
    await days.addMovement(
      kind: CashMovementKind.withdrawal,
      amountCents: 2000,
      reason: CashReason.purchase,
      staff: chef,
    );
    final s = (await days.summary())!;
    expect(
      (s.receiptCount, s.revenueCents, s.cashRevenueCents),
      (1, 1820, 1820),
    );
    expect(
      (s.cashInCents, s.cashOutCents, s.expectedCashCents),
      (5000, 2000, 19820),
    );
    expect(s.taxLines.map((t) => (t.rate.percent, t.grossCents)), [
      (20, 580),
      (10, 1190),
    ]);
  });

  test('Abschließen: Unterschied, in der Lade gelassen wird Wechselgeld des nächsten Tages', () async {
    await days.setOpeningFloat(15000);
    await sell('s1');
    final closed = await days.close(
      countedCents: 16800,
      leftInDrawerCents: 15000,
      staff: chef,
    );
    expect(
      (closed.expectedCents, closed.differenceCents, closed.isOpen),
      (16820, -20, false),
    );
    expect(closed.closedByName, 'Chef');
    expect(closed.closedAt, DateTime(2026, 11, 17, 11));
    expect(await days.openDay(), isNull);
    clock.value = DateTime(2026, 11, 18, 10);
    await sell('s2');
    expect((await days.openDay())!.openingFloatCents, 15000);
    expect(await days.needsOpeningFloat(), isFalse);
  });

  test('ein Tag endet mit dem Abschluss, nicht um Mitternacht', () async {
    await sell('s1');
    clock.value = DateTime(2026, 11, 18, 1, 30);
    await sell('s2');
    expect((await days.summary())!.receiptCount, 2);
  });

  test('vergessener Abschluss', () async {
    await sell('s1');
    expect(await days.hasForgottenClose(), isFalse);
    clock.value = DateTime(2026, 11, 18, 3, 59);
    expect(await days.hasForgottenClose(), isFalse);
    clock.value = DateTime(2026, 11, 18, 4);
    expect(await days.hasForgottenClose(), isTrue);
  });

  test('ungültige Eingaben', () async {
    expect(
      () => days.close(countedCents: 0, leftInDrawerCents: 0, staff: chef),
      throwsA(isA<NoOpenDayException>()),
    );
    await sell('s1');
    expect(
      () =>
          days.close(countedCents: 1000, leftInDrawerCents: 2000, staff: chef),
      throwsA(isA<LeftInDrawerTooHighException>()),
    );
    expect(
      () => days.close(countedCents: -1, leftInDrawerCents: 0, staff: chef),
      throwsA(isA<InvalidAmountException>()),
    );
    expect(
      () => days.addMovement(
        kind: CashMovementKind.deposit,
        amountCents: 0,
        reason: CashReason.other,
        staff: chef,
      ),
      throwsA(isA<InvalidAmountException>()),
    );
    expect(
      () => days.setOpeningFloat(-1),
      throwsA(isA<InvalidAmountException>()),
    );
    await days.setOpeningFloat(0);
    expect(await days.needsOpeningFloat(), isFalse);
  });

  test('eine Bargeld-Bewegung öffnet auch einen Tag; abgeschlossene Tage sind gesperrt', () async {
    await days.addMovement(
      kind: CashMovementKind.deposit,
      amountCents: 5000,
      reason: CashReason.change,
      staff: chef,
    );
    final d = await days.close(
      countedCents: 5000,
      leftInDrawerCents: 5000,
      staff: chef,
    );
    expect(
      () => db.customStatement(
        "UPDATE business_days SET counted_cents = 1 WHERE id = '${d.id}'",
      ),
      throwsA(anything),
    );
  });

  test('ein zweiter offener Tag lässt sich nicht einfügen', () async {
    await sell('s1');
    expect(
      () => db.customStatement(
        "INSERT INTO business_days (id, opened_at) VALUES ('zweiter', 1763377200)",
      ),
      throwsA(anything),
    );
    expect(await shop.count('business_days'), 1);
  });

  test(
    'Bargeld-Bewegungen und Tage lassen sich nicht ändern oder löschen',
    () async {
      await days.addMovement(
        kind: CashMovementKind.deposit,
        amountCents: 5000,
        reason: CashReason.change,
        staff: chef,
      );
      expect(
        () => db.customStatement('UPDATE cash_movements SET amount_cents = 1'),
        throwsA(anything),
      );
      expect(
        () => db.customStatement('DELETE FROM cash_movements'),
        throwsA(anything),
      );
      expect(
        () => db.customStatement('DELETE FROM business_days'),
        throwsA(anything),
      );
      expect(await shop.count('cash_movements'), 1);
      expect(await shop.count('business_days'), 1);
    },
  );

  test(
    'das Wechselgeld lässt sich nach einem Abschluss nicht mehr setzen',
    () async {
      await sell('s1');
      await days.close(countedCents: 1820, leftInDrawerCents: 0, staff: chef);
      await sell('s2');
      expect(() => days.setOpeningFloat(15000), throwsA(isA<StateError>()));
    },
  );

  test('ohne offenen Tag gibt es keine Zusammenfassung, am ersten Start fehlt das Wechselgeld', () async {
    expect(await days.summary(), isNull);
    expect(await days.needsOpeningFloat(), isTrue);
  });

  test(
    'die Zusammenfassung zeigt die Bewegungen in zeitlicher Reihenfolge',
    () async {
      await days.addMovement(
        kind: CashMovementKind.deposit,
        amountCents: 5000,
        reason: CashReason.change,
        staff: chef,
      );
      clock.value = DateTime(2026, 11, 17, 12);
      await days.addMovement(
        kind: CashMovementKind.withdrawal,
        amountCents: 2000,
        reason: CashReason.purchase,
        staff: shop.anna,
      );
      final m = (await days.summary())!.movements;
      expect(
        [
          for (final x in m)
            (x.kind, x.amountCents, x.reason, x.staffName, x.createdAt),
        ],
        [
          (
            CashMovementKind.deposit,
            5000,
            CashReason.change,
            'Chef',
            DateTime(2026, 11, 17, 11),
          ),
          (
            CashMovementKind.withdrawal,
            2000,
            CashReason.purchase,
            'Anna',
            DateTime(2026, 11, 17, 12),
          ),
        ],
      );
    },
  );

  test(
    'ein Storno an einem späteren Tag mindert dessen Umsatz und Zahl',
    () async {
      final a = await sell('s1');
      await days.close(countedCents: 1820, leftInDrawerCents: 0, staff: chef);
      clock.value = DateTime(2026, 11, 18, 10);
      await receipts.voidReceipt(a.id, staff: chef);
      final s = (await days.summary())!;
      expect((s.revenueCents, s.receiptCount), (-1820, -1));
    },
  );

  test(
    'die Zusammenfassung zählt Bons je Zahlungsart und die Stornos',
    () async {
      await days.setOpeningFloat(15000);
      final a = await sell('s1'); // 1820 bar
      await sell('s2'); // 1820 bar
      await shop.insertCardReceipt('c1', 900, 1000);
      await receipts.voidReceipt(a.id, staff: chef);
      final s = (await days.summary())!;
      expect(s.cashReceiptCount, 1);
      expect(s.cardReceiptCount, 1);
      expect(s.receiptCount, 2);
      expect(s.voidCount, 1);
      expect(s.voidedCents, 1820);
      expect(s.cardRevenueCents, 1000);
    },
  );

  test('ohne Storno sind Stornozahl und Stornosumme 0', () async {
    await sell('s1');
    final s = (await days.summary())!;
    expect(s.voidCount, 0);
    expect(s.voidedCents, 0);
    expect(s.cardReceiptCount, 0);
  });

  test('kleinste und größte Nummer der Verkaufs- und Storno-Bons', () async {
    await days.openOrCreateDay();
    expect((await days.summary())!.firstNumber, isNull);
    expect((await days.summary())!.lastNumber, isNull);
    final a = await sell('s1');
    await sell('s2');
    final v = await receipts.voidReceipt(a.id, staff: chef);
    final s = (await days.summary())!;
    expect(s.firstNumber, a.number);
    expect(s.lastNumber, v.number);
  });

  test('die Zusammenfassung des letzten abgeschlossenen Tages', () async {
    expect(await days.lastClosedSummary(), isNull);
    await days.setOpeningFloat(15000);
    await sell('s1');
    await days.close(
      countedCents: 16820,
      leftInDrawerCents: 15000,
      staff: chef,
    );
    expect(await days.summary(), isNull);
    final s = (await days.lastClosedSummary())!;
    expect(s.day.isOpen, isFalse);
    expect(s.cashRevenueCents, 1820);
    expect(s.expectedCashCents, 16820);
    expect(s.cashReceiptCount, 1);
  });

  test(
    'Abschluss trennt Bar und Karte: erwartetes Bargeld zählt nur bar',
    () async {
      await days.setOpeningFloat(15000);
      await sell('s1'); // 1820 bar
      final card = await shop.sellCard('c1');
      final s = (await days.summary())!;
      expect(s.cashRevenueCents, 1820);
      expect(s.cardRevenueCents, card.totalCents);
      expect((s.cashReceiptCount, s.cardReceiptCount), (1, 1));
      expect(s.expectedCashCents, 15000 + 1820);
    },
  );

  test(
    'Sonderbelege ändern die Tagessumme nicht, auch nicht mit Tag',
    () async {
      await days.setOpeningFloat(15000);
      await sell('s1'); // 1820 bar
      await shop.sellCard('c1');
      List<Object> numbers(DaySummary s) => [
        s.receiptCount,
        s.cashReceiptCount,
        s.cardReceiptCount,
        s.voidCount,
        s.voidedCents,
        s.revenueCents,
        s.cashRevenueCents,
        s.cardRevenueCents,
        s.depositCents,
        s.expectedCashCents,
        [for (final t in s.taxLines) (t.rate, t.grossCents)],
      ];
      final before = numbers((await days.summary())!);
      await shop.insertSpecialReceipt('m', 3, ReceiptKind.month);
      await shop.insertSpecialReceipt(
        'z',
        4,
        ReceiptKind.zero,
        day: await shop.dayId(),
      );
      final after = numbers((await days.summary())!);
      expect(after, before);
      expect(after.first, 2);
    },
  );

  test('gemischter Bon: Bar und Karte kommen aus den Zahlungen, Trinkgeld zählt nicht zum Umsatz', () async {
    await shop.days.setOpeningFloat(10000);
    await shop.sell('a'); // bar 18,20
    await shop.sellCard('b'); // Karte 9,65
    await shop.sellCard('m1', cart: cart, cashPartCents: 1000, tipCents: 80);
    final s = (await shop.days.summary())!;
    expect(
      (s.revenueCents, s.cashRevenueCents, s.cardRevenueCents),
      (4605, 2820, 1785),
    );
    expect((s.receiptCount, s.cashReceiptCount, s.cardReceiptCount), (3, 2, 2));
    expect(s.expectedCashCents, 10000 + 2820);
  });

  test('Storno des gemischten Bons nimmt beide Teile zurück', () async {
    await shop.days.setOpeningFloat(10000);
    await shop.sell('a'); // bar 18,20
    await shop.sellCard('b'); // Karte 9,65
    await shop.sellCard('m1', cart: cart, cashPartCents: 1000, tipCents: 80);
    await shop.receipts.voidReceipt('m1', staff: shop.chef);
    final s = (await shop.days.summary())!;
    expect(
      (s.revenueCents, s.cashRevenueCents, s.cardRevenueCents),
      (2785, 1820, 965),
    );
    expect(
      (
        s.receiptCount,
        s.cashReceiptCount,
        s.cardReceiptCount,
        s.voidCount,
        s.voidedCents,
      ),
      (2, 1, 1, 1, 1820),
    );
    expect(s.expectedCashCents, 10000 + 1820);
  });

  test('Rabatte und Trinkgeld des Tages, Trinkgeld je Person; Storno durch den '
      'Chef zieht bei Anna ab', () async {
    await shop.receipts.finalizeCashSale(
      saleId: 'r1',
      cart: discounted,
      givenCents: 2000,
      staff: shop.anna,
    ); // Rabatt 2,84
    await shop.receipts.finalizeCardSale(
      saleId: 't1',
      cart: cartCard,
      staff: shop.anna,
      provider: 'sumup',
      tipCents: 35,
    );
    await shop.receipts.finalizeCardSale(
      saleId: 't2',
      cart: cartCard,
      staff: shop.chef,
      provider: 'sumup',
      tipCents: 100,
    );
    var s = (await shop.days.summary())!;
    expect(
      (
        s.discountCount,
        s.discountCents,
        s.cardTipCents,
        s.cardRevenueCents,
        s.cardAccountCents,
      ),
      (1, 284, 135, 1930, 2065),
    );
    expect(
      [for (final x in s.tipsByStaff) (x.staffName, x.cents)],
      [('Anna', 35), ('Chef', 100)],
    );
    expect(s.tipsByStaff.first.staffId, shop.anna.id);
    await shop.receipts.voidReceipt('t1', staff: shop.chef);
    await shop.receipts.voidReceipt('r1', staff: shop.chef);
    s = (await shop.days.summary())!;
    expect((s.discountCount, s.discountCents, s.cardTipCents), (0, 0, 100));
    expect(
      [for (final x in s.tipsByStaff) (x.staffName, x.cents)],
      [('Chef', 100)],
    );
  });

  test(
    'ohne Rabatt und Trinkgeld: alles 0, am Kartenkonto der Kartenumsatz',
    () async {
      await shop.sell('a');
      await shop.sellCard('b');
      final s = (await shop.days.summary())!;
      expect((s.discountCount, s.discountCents, s.cardTipCents), (0, 0, 0));
      expect(s.tipsByStaff, isEmpty);
      expect(s.cardAccountCents, s.cardRevenueCents);
    },
  );

  group('Pfand zurück und Gutscheine', () {
    Future<DaySummary> summaryOfToday() async => (await days.summary())!;

    (int, int, int, int, int) newFigures(DaySummary s) => (
      s.voucherPaidCents,
      s.voucherSoldCount,
      s.voucherSoldCents,
      s.depositReturnCount,
      s.depositReturnCents,
    );

    void identityHolds(DaySummary s, [String? reason]) => expect(
      s.cashRevenueCents +
          s.cardRevenueCents +
          s.voucherPaidCents -
          s.voucherSoldCents,
      s.revenueCents,
      reason: reason,
    );

    test('ein Tag mit Barbon, Gutschein-Verkauf, Gutschein-Zahlung und '
        'Pfand-Auszahlung', () async {
      await days.setOpeningFloat(15000);
      await sellVoucherDepositDay(shop);
      final s = await summaryOfToday();
      expect(
        (s.revenueCents, s.cashRevenueCents, s.cardRevenueCents),
        (2710, 4245, 0),
      );
      expect(newFigures(s), (965, 1, 2500, 3, 75));
      expect(s.expectedCashCents, s.openingFloatCents + 4245);
      expect(s.openingFloatCents, 15000);
      expect(
        (s.receiptCount, s.cashReceiptCount, s.cardReceiptCount),
        (4, 3, 0),
      );
      identityHolds(s);
    });

    test('Storno von C und D: voucherPaidCents 0, depositReturnCount 0, '
        'revenueCents 1820', () async {
      await days.setOpeningFloat(15000);
      await sellVoucherDepositDay(shop);
      await receipts.voidReceipt('c', staff: chef);
      await receipts.voidReceipt('d', staff: chef);
      final s = await summaryOfToday();
      // Die Zahlen von A und B allein.
      expect(
        (s.revenueCents, s.cashRevenueCents, s.cardRevenueCents),
        (1820, 4320, 0),
      );
      expect(newFigures(s), (0, 1, 2500, 0, 0));
      expect(s.expectedCashCents, 15000 + 4320);
      expect(
        (s.receiptCount, s.cashReceiptCount, s.cardReceiptCount),
        (2, 2, 0),
      );
      expect((s.voidCount, s.voidedCents), (2, 965 - 75));
      identityHolds(s);
    });

    test('ein Bon mit Gutschein und Karte zählt bei Karte, einer mit '
        'Gutschein und bar bei bar', () async {
      final voucher = await sellVoucher(shop, 500, saleId: 'g');
      await shop.sellCard('k', cart: cart.applyVoucher(applied(voucher)));
      final rest = await sellVoucher(shop, 300, saleId: 'h');
      await receipts.finalizeCashSale(
        saleId: 'b',
        cart: cartCard.applyVoucher(applied(rest)),
        givenCents: 1000,
        staff: shop.anna,
      );
      final s = await summaryOfToday();
      expect(
        (s.receiptCount, s.cashReceiptCount, s.cardReceiptCount),
        (4, 3, 1),
      );
      expect(
        (s.revenueCents, s.cashRevenueCents, s.cardRevenueCents),
        (1820 + 965, 500 + 300 + 965 - 300, 1820 - 500),
      );
      expect(newFigures(s), (800, 2, 800, 0, 0));
      identityHolds(s);
    });

    test(
      'ein Tag nur mit Bons wie in 1.11.0: die fünf neuen Zahlen sind 0',
      () async {
        await shop.sell('a');
        await shop.sellCard('b', cashPartCents: 300, tipCents: 50);
        await receipts.finalizeCashSale(
          saleId: 'c',
          cart: discounted,
          givenCents: 2000,
          staff: shop.anna,
        );
        final s = await summaryOfToday();
        expect(newFigures(s), (0, 0, 0, 0, 0));
        expect(s.revenueCents, 1820 + 965 + 1536);
        identityHolds(s);
      },
    );

    test('200 zufällige Bons mit Pfand zurück und Gutscheinen, danach alle '
        'storniert (Einlösungen vor den Verkäufen): Umsatz 0, alle fünf neuen '
        'Zahlen 0, erwartetes Bargeld = Wechselgeld', () async {
      await days.setOpeningFloat(15000);
      final random = Random(20261130);
      final pool = <String>[];
      final voucherSales = <Receipt>[];
      final others = <Receipt>[];
      var revenue = 0, cash = 0, card = 0;
      var paid = 0, soldCount = 0, soldCents = 0;
      var backCount = 0, backCents = 0;
      var payouts = 0, voucherOnly = 0, redeemed = 0, backs = 0;
      for (var n = 0; n < 200; n++) {
        final reason = 'Bon $n';
        var c = randomCart(random, withStufe1b: true);
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
        final id = 'z$n';
        final Receipt r;
        if (p.totalCents < 0) {
          payouts++;
          r = await receipts.finalizePayout(
            saleId: id,
            cart: c,
            staff: shop.anna,
          );
        } else if (p.voucherCents > 0 && p.dueCents == 0) {
          voucherOnly++;
          r = await receipts.finalizeVoucherSale(
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
          r = await receipts.finalizeCashSale(
            saleId: id,
            cart: c,
            givenCents: p.dueCents + random.nextInt(500),
            staff: shop.anna,
          );
        }
        if (r.voucherCents != 0) redeemed++;
        if (r.depositReturnQuantity != 0) backs++;
        revenue += r.revenueCents;
        for (final x in r.payments) {
          switch (x.kind) {
            case PaymentKind.cash:
              cash += x.amountCents;
            case PaymentKind.card:
              card += x.amountCents;
            case PaymentKind.voucher:
              paid += x.amountCents;
          }
        }
        soldCount += r.soldVouchers.length;
        soldCents += r.voucherSaleCents;
        backCount += r.depositReturnQuantity;
        backCents -= r.depositReturnCents;
        if (r.soldVouchers.isEmpty) {
          others.add(r);
        } else {
          voucherSales.add(r);
          pool.addAll([for (final s in r.soldVouchers) s.voucherId]);
        }

        final s = await summaryOfToday();
        expect(
          (s.revenueCents, s.cashRevenueCents, s.cardRevenueCents),
          (revenue, cash, card),
          reason: reason,
        );
        expect(newFigures(s), (
          paid,
          soldCount,
          soldCents,
          backCount,
          backCents,
        ), reason: reason);
        expect(s.expectedCashCents, 15000 + cash, reason: reason);
        identityHolds(s, reason);
      }
      // Damit der Test etwas prüft: jede Art kam vor.
      expect(payouts, greaterThan(0));
      expect(voucherOnly, greaterThan(0));
      expect(redeemed, greaterThan(10));
      expect(backs, greaterThan(10));
      expect(voucherSales, isNotEmpty);

      // Erst die Einlösungen und alles andere, dann die Verkäufe.
      for (final r in [...others.reversed, ...voucherSales.reversed]) {
        await receipts.voidReceipt(r.id, staff: chef);
        identityHolds(await summaryOfToday(), 'Storno ${r.id}');
      }
      final s = await summaryOfToday();
      expect(
        (s.revenueCents, s.cashRevenueCents, s.cardRevenueCents),
        (0, 0, 0),
      );
      expect(newFigures(s), (0, 0, 0, 0, 0));
      expect(s.expectedCashCents, s.openingFloatCents);
      expect(s.openingFloatCents, 15000);
      expect(
        (s.receiptCount, s.cashReceiptCount, s.cardReceiptCount),
        (0, 0, 0),
      );
    });
  });
}
