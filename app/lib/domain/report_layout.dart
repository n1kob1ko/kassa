// Setzt einen Tagesabschluss oder einen Zeitraum-Bericht zu Druckzeilen.
// Berichte sind keine Belege: kein QR-Code, keine Signatur, keine Nummer.
// Reines Dart, ohne Flutter und ohne Datenbank.

import '../core/german_dates.dart';
import '../core/money.dart';
import 'business_info.dart';
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
}) {
  b.text('EINNAHMEN', bold: true);
  b.row3('Bar', bonsText(cashCount), amount(cashCents));
  b.row3('Karte', bonsText(cardCount), amount(cardCents));
  b.row3('Gesamt', bonsText(count), amount(revenueCents));
  if (voidCount != 0) {
    b.row3('Storniert', bonsText(voidCount), amount(voidedCents));
  }
}

void _tax(PrintBuilder b, List<TaxLine> lines, int depositCents) {
  b.text('STEUER', bold: true);
  for (final t in lines) {
    b.text('MwSt ${t.rate.percent} %');
    b.row('  Brutto', amount(t.grossCents));
    b.row('  Netto', amount(t.netCents));
    b.row('  Steuer', amount(t.taxCents));
  }
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
  );
  b.rule();
  _tax(b, s.taxLines, s.depositCents);
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
  if (left != null) b.row('In der Lade gelassen', amount(left));
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
  b.row(
    'Zeitraum',
    '${dateText(r.range.from.start)} bis ${dateText(r.range.to.lastDay)}',
  );
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
  );
  b.rule();
  _tax(b, r.taxLines, r.depositCents);
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
