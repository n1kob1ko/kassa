import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/core/clock.dart';
import 'package:kassa/data/database.dart';
import 'package:kassa/data/day_repository.dart';
import 'package:kassa/data/receipt_repository.dart';
import 'package:kassa/domain/day.dart';
import 'package:kassa/domain/receipt.dart';
import 'package:kassa/domain/staff.dart';

import '../support/sales.dart';

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

  test('der erste Bon öffnet den Tag, Wechselgeld fehlt am ersten Tag', () async {
    expect(await days.openDay(), isNull);
    await sell('s1');
    expect((await days.openDay())!.openedAt, DateTime(2026, 11, 17, 11));
    expect(await days.needsOpeningFloat(), isTrue);
    await days.setOpeningFloat(15000);
    expect(await days.needsOpeningFloat(), isFalse);
  });

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
    expect((s.receiptCount, s.revenueCents, s.cashRevenueCents), (1, 1820, 1820));
    expect((s.cashInCents, s.cashOutCents, s.expectedCashCents), (5000, 2000, 19820));
    expect(s.taxLines.map((t) => (t.rate.percent, t.grossCents)), [(20, 580), (10, 1190)]);
  });

  test(
    'Abschließen: Unterschied, in der Lade gelassen wird Wechselgeld des nächsten Tages',
    () async {
      await days.setOpeningFloat(15000);
      await sell('s1');
      final closed = await days.close(countedCents: 16800, leftInDrawerCents: 15000, staff: chef);
      expect((closed.expectedCents, closed.differenceCents, closed.isOpen), (16820, -20, false));
      expect(closed.closedByName, 'Chef');
      expect(closed.closedAt, DateTime(2026, 11, 17, 11));
      expect(await days.openDay(), isNull);
      clock.value = DateTime(2026, 11, 18, 10);
      await sell('s2');
      expect((await days.openDay())!.openingFloatCents, 15000);
      expect(await days.needsOpeningFloat(), isFalse);
    },
  );

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
      () => days.close(countedCents: 1000, leftInDrawerCents: 2000, staff: chef),
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
    expect(() => days.setOpeningFloat(-1), throwsA(isA<InvalidAmountException>()));
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
    final d = await days.close(countedCents: 5000, leftInDrawerCents: 5000, staff: chef);
    expect(
      () => db.customStatement("UPDATE business_days SET counted_cents = 1 WHERE id = '${d.id}'"),
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

  test('Bargeld-Bewegungen und Tage lassen sich nicht ändern oder löschen', () async {
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
    expect(() => db.customStatement('DELETE FROM cash_movements'), throwsA(anything));
    expect(() => db.customStatement('DELETE FROM business_days'), throwsA(anything));
    expect(await shop.count('cash_movements'), 1);
    expect(await shop.count('business_days'), 1);
  });

  test('das Wechselgeld lässt sich nach einem Abschluss nicht mehr setzen', () async {
    await sell('s1');
    await days.close(countedCents: 1820, leftInDrawerCents: 0, staff: chef);
    await sell('s2');
    expect(() => days.setOpeningFloat(15000), throwsA(isA<StateError>()));
  });

  test(
    'ohne offenen Tag gibt es keine Zusammenfassung, am ersten Start fehlt das Wechselgeld',
    () async {
      expect(await days.summary(), isNull);
      expect(await days.needsOpeningFloat(), isTrue);
    },
  );

  test('die Zusammenfassung zeigt die Bewegungen in zeitlicher Reihenfolge', () async {
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
      [for (final x in m) (x.kind, x.amountCents, x.reason, x.staffName, x.createdAt)],
      [
        (CashMovementKind.deposit, 5000, CashReason.change, 'Chef', DateTime(2026, 11, 17, 11)),
        (
          CashMovementKind.withdrawal,
          2000,
          CashReason.purchase,
          'Anna',
          DateTime(2026, 11, 17, 12),
        ),
      ],
    );
  });

  test('ein Storno an einem späteren Tag mindert dessen Umsatz und Zahl', () async {
    final a = await sell('s1');
    await days.close(countedCents: 1820, leftInDrawerCents: 0, staff: chef);
    clock.value = DateTime(2026, 11, 18, 10);
    await receipts.voidReceipt(a.id, staff: chef);
    final s = (await days.summary())!;
    expect((s.revenueCents, s.receiptCount), (-1820, -1));
  });

  test('die Zusammenfassung zählt Bons je Zahlungsart und die Stornos', () async {
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
  });

  test('ohne Storno sind Stornozahl und Stornosumme 0', () async {
    await sell('s1');
    final s = (await days.summary())!;
    expect(s.voidCount, 0);
    expect(s.voidedCents, 0);
    expect(s.cardReceiptCount, 0);
  });

  test('die Zusammenfassung des letzten abgeschlossenen Tages', () async {
    expect(await days.lastClosedSummary(), isNull);
    await days.setOpeningFloat(15000);
    await sell('s1');
    await days.close(countedCents: 16820, leftInDrawerCents: 15000, staff: chef);
    expect(await days.summary(), isNull);
    final s = (await days.lastClosedSummary())!;
    expect(s.day.isOpen, isFalse);
    expect(s.cashRevenueCents, 1820);
    expect(s.expectedCashCents, 16820);
    expect(s.cashReceiptCount, 1);
  });
}
