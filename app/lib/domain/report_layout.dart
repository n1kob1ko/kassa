// Setzt einen Tagesabschluss oder einen Zeitraum-Bericht zu Druckzeilen.
// Berichte sind keine Belege: kein QR-Code, keine Signatur, keine Nummer.
// Reines Dart, ohne Flutter und ohne Datenbank.

import '../core/german_dates.dart';
import '../core/money.dart';
import 'business_info.dart';
import 'catalog.dart' show TaxRate;
import 'day.dart';
import 'period_report.dart';
import 'pricing.dart';
import 'print_builder.dart';
import 'print_document.dart';

/// "1 Bon", "1.067 Bons", "-1 Bons".
String bonsText(int n) => n == 1 ? '1 Bon' : '${groupThousands(n)} Bons';

void _head(
  PrintBuilder b,
  BusinessInfo business,
  String title,
  String subtitle, {
  bool testMode = false,
}) {
  b.businessHead(business);
  b.blank();
  b.text(title, align: PrintAlign.center, bold: true);
  b.centered(subtitle);
  if (testMode) b.centered('Testbetrieb');
  b.blank();
}

void _income(
  PrintBuilder b, {
  required int cashCount,
  required int cashCents,
  required int cardCount,
  required int cardCents,
  required int count,
  required int revenueCents,
  required int voidCount,
  required int voidedCents,
  required int discountCount,
  required int discountCents,
  required int voucherPaidCents,
  required int voucherSoldCount,
  required int voucherSoldCents,
  required int depositReturnCount,
  required int depositReturnCents,
}) {
  b.text('EINNAHMEN', bold: true);
  b.row3('Bar', bonsText(cashCount), amount(cashCents));
  b.row3('Karte', bonsText(cardCount), amount(cardCents));
  // Nur, wenn es sie gibt: so ergibt die Spalte von oben nach unten
  // "Gesamt" (bar + Karte + mit Gutschein bezahlt − verkaufte Gutscheine).
  if (voucherPaidCents != 0) {
    b.row3('Mit Gutschein bezahlt', '', amount(voucherPaidCents));
  }
  if (voucherSoldCount != 0 || voucherSoldCents != 0) {
    b.row3(
      'Gutscheine verkauft',
      groupThousands(voucherSoldCount),
      amount(-voucherSoldCents),
    );
  }
  b.row3('Gesamt', bonsText(count), amount(revenueCents));
  if (voidCount != 0) {
    b.row3('Storniert', bonsText(voidCount), amount(voidedCents));
  }
  if (discountCount != 0 || discountCents != 0) {
    b.row3('Rabatte', bonsText(discountCount), amount(-discountCents));
  }
  if (depositReturnCount != 0 || depositReturnCents != 0) {
    b.row3(
      'Pfand zurück',
      groupThousands(depositReturnCount),
      amount(-depositReturnCents),
    );
  }
}

/// Karten-Trinkgeld je Person, ihre Summe und was am Kartenkonto ankommt;
/// nur, wenn es Trinkgeld gibt. Endet mit einer Linie.
void _cardTips(
  PrintBuilder b, {
  required List<StaffTip> tips,
  required int cardTipCents,
  required int cardAccountCents,
}) {
  if (tips.isEmpty) return;
  b.text('TRINKGELD KARTE', bold: true);
  for (final t in tips) {
    b.row(t.staffName, amount(t.cents));
  }
  b.row('Gesamt', amount(cardTipCents));
  b.row('Am Kartenkonto', amount(cardAccountCents));
  b.rule();
}

/// Die Zeilen je Satz, wie sie signiert werden. Unter dem Satz 0 (fehlt er,
/// nach allen Sätzen) "davon Gutscheine", wenn Gutscheine verkauft wurden.
void _tax(
  PrintBuilder b,
  List<TaxLine> lines,
  int depositCents,
  int voucherSoldCents,
) {
  b.text('STEUER', bold: true);
  void vouchers() => b.row('  davon Gutscheine', amount(voucherSoldCents));
  var vouchersShown = voucherSoldCents == 0;
  for (final t in lines) {
    b.text('MwSt ${t.rate.percent} %');
    b.row('  Brutto', amount(t.grossCents));
    b.row('  Netto', amount(t.netCents));
    b.row('  Steuer', amount(t.taxCents));
    if (t.rate == TaxRate.zero && !vouchersShown) {
      vouchers();
      vouchersShown = true;
    }
  }
  if (!vouchersShown) vouchers();
  if (depositCents != 0) b.row('Pfand, ohne MwSt', amount(depositCents));
}

void _end(PrintBuilder b, DateTime printedAt) {
  b.centered('Gedruckt ${dateTimeText(printedAt)}');
  b.centered('Kein Beleg');
  b.ops
    ..add(const PrintFeed(3))
    ..add(const PrintCut());
}

String _clock(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// Tagesabschluss. [drawer] sagt, ob die Kassa eine Geldlade hat: ohne heißt
/// der Teil "BARGELD".
List<PrintOp> layoutDayReport(
  DaySummary s,
  BusinessInfo business, {
  required String? registerName,
  required bool drawer,
  required DateTime printedAt,
  int columns = 48,
}) {
  final b = PrintBuilder(columns);
  final day = s.day;
  final opened = day.openedAt;
  _head(
    b,
    business,
    'TAGESABSCHLUSS',
    '${germanWeekdays[opened.weekday - 1]}, ${dateText(opened)}',
  );
  if (registerName != null) b.row('Kassa', registerName);
  b.row('Von', dateTimeText(opened));
  final closedAt = day.closedAt;
  if (closedAt != null) b.row('Bis', dateTimeText(closedAt));
  final closedBy = day.closedByName;
  if (closedAt != null && closedBy != null) {
    b.row('Abgeschlossen von', closedBy);
  }
  final first = s.firstNumber;
  final last = s.lastNumber;
  if (first != null && last != null) b.row('Bons Nr.', '$first bis $last');
  b.rule();
  _income(
    b,
    cashCount: s.cashReceiptCount,
    cashCents: s.cashRevenueCents,
    cardCount: s.cardReceiptCount,
    cardCents: s.cardRevenueCents,
    count: s.receiptCount,
    revenueCents: s.revenueCents,
    voidCount: s.voidCount,
    voidedCents: s.voidedCents,
    discountCount: s.discountCount,
    discountCents: s.discountCents,
    voucherPaidCents: s.voucherPaidCents,
    voucherSoldCount: s.voucherSoldCount,
    voucherSoldCents: s.voucherSoldCents,
    depositReturnCount: s.depositReturnCount,
    depositReturnCents: s.depositReturnCents,
  );
  b.rule();
  _cardTips(
    b,
    tips: s.tipsByStaff,
    cardTipCents: s.cardTipCents,
    cardAccountCents: s.cardAccountCents,
  );
  _tax(b, s.taxLines, s.depositCents, s.voucherSoldCents);
  b.rule();
  b.text(drawer ? 'GELDLADE' : 'BARGELD', bold: true);
  b.row('Wechselgeld am Morgen', amount(s.openingFloatCents));
  b.row('Bar-Einnahmen', amount(s.cashRevenueCents));
  for (final m in s.movements) {
    final deposit = m.kind == CashMovementKind.deposit;
    b.row(
      '${_clock(m.createdAt)} ${deposit ? 'Eingelegt' : 'Entnommen'}: '
      '${reasonLabel(m.reason)}',
      amount(deposit ? m.amountCents : -m.amountCents),
    );
  }
  b.row('Soll', amount(day.expectedCents ?? s.expectedCashCents));
  final counted = day.countedCents;
  final left = day.leftInDrawerCents;
  final difference = day.differenceCents;
  if (counted != null) b.row('Gezählt', amount(counted));
  if (difference != null) b.row('Unterschied', amount(difference));
  if (left != null) {
    b.row(
      drawer ? 'In der Lade gelassen' : 'Wechselgeld für morgen',
      amount(left),
    );
  }
  if (counted != null && left != null) {
    b.row('Entnommen', amount(counted - left));
  }
  b.rule();
  _end(b, printedAt);
  return b.ops;
}

/// Monatsabrechnung (ein Monat) oder Abrechnung (mehrere Monate).
List<PrintOp> layoutPeriodReport(
  PeriodReport r,
  BusinessInfo business, {
  required String? registerName,
  required DateTime printedAt,
  int columns = 48,
}) {
  final b = PrintBuilder(columns);
  _head(
    b,
    business,
    r.range.single ? 'MONATSABRECHNUNG' : 'ABRECHNUNG',
    periodTitle(r.range),
    testMode: r.testMode,
  );
  final span =
      '${dateText(r.range.from.start)} bis ${dateText(r.range.to.lastDay)}';
  // Passt die Zeile nicht, steht die Bezeichnung allein darüber (wie bei row3).
  final stacked = 'Zeitraum'.length + 1 + span.length > columns;
  if (stacked) b.row('Zeitraum', '');
  b.row(stacked ? '' : 'Zeitraum', span);
  if (registerName != null) b.row('Kassa', registerName);
  final first = r.firstNumber;
  final last = r.lastNumber;
  if (first != null && last != null) b.row('Bons Nr.', '$first bis $last');
  b.rule();
  _income(
    b,
    cashCount: r.cashReceiptCount,
    cashCents: r.cashRevenueCents,
    cardCount: r.cardReceiptCount,
    cardCents: r.cardRevenueCents,
    count: r.receiptCount,
    revenueCents: r.revenueCents,
    voidCount: r.voidCount,
    voidedCents: r.voidedCents,
    discountCount: r.discountCount,
    discountCents: r.discountCents,
    voucherPaidCents: r.voucherPaidCents,
    voucherSoldCount: r.voucherSoldCount,
    voucherSoldCents: r.voucherSoldCents,
    depositReturnCount: r.depositReturnCount,
    depositReturnCents: r.depositReturnCents,
  );
  b.rule();
  _cardTips(
    b,
    tips: r.tipsByStaff,
    cardTipCents: r.cardTipCents,
    cardAccountCents: r.cardAccountCents,
  );
  _tax(b, r.taxLines, r.depositCents, r.voucherSoldCents);
  b.rule();
  if (!r.range.single) {
    b.text('MONATE', bold: true);
    for (final row in r.rows) {
      b.row3(
        '${germanMonths[row.start.month - 1]} ${row.start.year}',
        bonsText(row.receiptCount),
        amount(row.revenueCents),
      );
    }
    b.rule();
  }
  _end(b, printedAt);
  return b.ops;
}
