import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/money.dart';
import '../../domain/period_report.dart';
import '../../domain/receipt.dart';
import '../../l10n/generated/l10n.dart';
import '../../ui/dates_text.dart';
import '../../ui/ltr.dart';
import '../../ui/primary_button.dart';
import '../../ui/tokens.dart';
import '../overview/overview_cards.dart' show OverviewCard;
import 'close_format.dart' show bonsLabel;

/// Karte "Monatsbeleg der Signatur" (bei einem Jahresbeleg und im Dezember
/// "Jahresbeleg der Signatur"): wann und mit welcher Nummer der Beleg
/// entstand, und "Drucken" ([onPrint], ohne Wert gesperrt). Ohne [receipt]
/// der Hinweis, dass er mit dem nächsten Bon kommt, ohne Taste.
class SignatureReceiptCard extends StatelessWidget {
  const SignatureReceiptCard({
    super.key,
    required this.month,
    required this.receipt,
    required this.onPrint,
  });

  final YearMonth month;
  final Receipt? receipt;
  final VoidCallback? onPrint;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final l = L10n.of(context);
    final r = receipt;
    final year = r != null ? r.kind == ReceiptKind.year : month.month == 12;
    final String line;
    if (r == null) {
      line = l.closeSignatureComes;
    } else {
      final t = r.createdAt;
      final mm = t.minute.toString().padLeft(2, '0');
      final hh = t.hour.toString().padLeft(2, '0');
      line = l.closeSignatureCreated(
        ltrIsolate(context, '${t.day}.${t.month}.'),
        ltrIsolate(context, '$hh:$mm'),
        r.number,
      );
    }
    return OverviewCard(
      key: const Key('signature-receipt-card'),
      padding: const EdgeInsetsDirectional.fromSTEB(
        KassaTokens.spaceHuge,
        KassaTokens.spaceXl,
        KassaTokens.spaceXl,
        KassaTokens.spaceXl,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: KassaTokens.keypadKeyHeight,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    year ? l.closeSignatureYear : l.closeSignatureMonth,
                    style: text.titleMedium!.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: KassaTokens.spaceXxs),
                  Text(
                    line,
                    style: text.bodyMedium!.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: c.ink2,
                    ),
                  ),
                ],
              ),
            ),
            if (r != null) ...[
              const SizedBox(width: KassaTokens.spaceXxl),
              PrimaryButton(
                key: const Key('print-signature-receipt'),
                label: l.closePrint,
                filled: false,
                icon: LucideIcons.printer,
                height: KassaTokens.keypadKeyHeight,
                onPressed: onPrint,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Karte "Tage" (ein Monat: je Kalendertag mit Bon) oder "Monate" (mehrere:
/// je Monat, auch leere): Datum, Anzahl Bons, Umsatz.
class PeriodRowsCard extends StatelessWidget {
  const PeriodRowsCard(this.report, {super.key});

  final PeriodReport report;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final l = L10n.of(context);
    final days = report.range.single;
    return OverviewCard(
      key: const Key('period-rows'),
      padding: const EdgeInsets.fromLTRB(
        KassaTokens.spaceHuge,
        KassaTokens.spaceXxl,
        KassaTokens.spaceHuge,
        KassaTokens.spaceSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            constraints: const BoxConstraints(minHeight: 40),
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    days ? l.closeDays : l.closeMonths,
                    style: text.titleLarge,
                  ),
                ),
                Text(
                  days ? l.closeScreenOnly : l.closeAlsoOnPaper,
                  textAlign: TextAlign.end,
                  style: text.bodySmall!.copyWith(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: c.ink2,
                  ),
                ),
              ],
            ),
          ),
          for (final row in report.rows)
            _Row(
              label: days
                  ? _dayLabel(context, row.start)
                  : _monthLabel(l, row.start),
              labelWidth: days ? 150 : 190,
              count: bonsLabel(l, row.receiptCount),
              amount: formatEuro(row.revenueCents),
            ),
        ],
      ),
    );
  }

  /// "Do., 1.10." (das Datum auch in Arabisch von links nach rechts)
  static String _dayLabel(BuildContext context, DateTime d) =>
      '${weekdayShortName(L10n.of(context), d.weekday)}, '
      '${ltrIsolate(context, '${d.day}.${d.month}.')}';

  /// "Jänner 2026"
  static String _monthLabel(L10n l, DateTime d) =>
      l.closeMonthYear(monthName(l, d.month), d.year);
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.labelWidth,
    required this.count,
    required this.amount,
  });

  final String label;
  final double labelWidth;
  final String count;
  final String amount;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: c.line, width: KassaTokens.borderThin),
        ),
      ),
      child: Row(
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(minWidth: labelWidth),
            child: Text(
              label,
              style: text.bodyLarge!.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: KassaTokens.spaceMd),
          Expanded(
            child: Text(
              count,
              style: text.bodyMedium!.copyWith(
                fontWeight: FontWeight.w600,
                color: c.ink2,
              ),
            ),
          ),
          Ltr(
            child: Text(
              amount,
              textAlign: TextAlign.end,
              style: text.bodyLarge!.copyWith(
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ein Satz statt der Karten, etwa "In diesem Zeitraum gibt es keine Bons."
class PeriodNote extends StatelessWidget {
  const PeriodNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return OverviewCard(
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyLarge!.copyWith(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: KassaColors.of(context).ink2,
        ),
      ),
    );
  }
}
