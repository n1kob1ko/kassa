// Erfundene Berichte für die Drucktests.

import 'package:kassa/domain/day.dart';
import 'package:kassa/domain/period_report.dart';

DaySummary sampleDay({
  String id = 'd1',
  int discountCount = 0,
  int discountCents = 0,
  int cardTipCents = 0,
  List<StaffTip> tipsByStaff = const [],
}) => DaySummary(
  day: BusinessDay(
    id: id,
    openedAt: DateTime(2026, 11, 17, 9),
    closedAt: DateTime(2026, 11, 17, 21),
    openingFloatCents: 15000,
    countedCents: 20000,
    leftInDrawerCents: 15000,
    expectedCents: 20000,
    differenceCents: 0,
    closedByName: 'Mira',
  ),
  receiptCount: 3,
  cashReceiptCount: 2,
  cardReceiptCount: 1,
  voidCount: 0,
  voidedCents: 0,
  revenueCents: 3000,
  cashRevenueCents: 2000,
  cardRevenueCents: 1000,
  depositCents: 0,
  taxLines: const [],
  openingFloatCents: 15000,
  cashInCents: 0,
  cashOutCents: 0,
  expectedCashCents: 20000,
  movements: const [],
  firstNumber: 1,
  lastNumber: 3,
  discountCount: discountCount,
  discountCents: discountCents,
  cardTipCents: cardTipCents,
  tipsByStaff: tipsByStaff,
);

PeriodReport samplePeriod() => PeriodReport(
  range: MonthRange(YearMonth(2026, 9), YearMonth(2026, 10)),
  testMode: false,
  receiptCount: 3,
  cashReceiptCount: 2,
  cardReceiptCount: 1,
  voidCount: 0,
  voidedCents: 0,
  revenueCents: 3000,
  cashRevenueCents: 2000,
  cardRevenueCents: 1000,
  depositCents: 0,
  taxLines: const [],
  firstNumber: 1,
  lastNumber: 3,
  rows: [
    PeriodRow(start: DateTime(2026, 9), receiptCount: 3, revenueCents: 3000),
  ],
);
