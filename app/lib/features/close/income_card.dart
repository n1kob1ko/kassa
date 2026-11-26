import 'package:material_ui/material_ui.dart';

import '../../core/money.dart';
import '../../domain/day.dart';
import '../../domain/period_report.dart';
import '../../domain/pricing.dart' show TaxLine;
import '../../l10n/generated/l10n.dart';
import '../../ui/ltr.dart';
import '../../ui/tokens.dart';
import '../overview/overview_cards.dart' show OverviewCard;
import 'close_format.dart';
import 'summary_rows.dart';

/// Die Zahlen der Karte "Einnahmen | Steuer": ein Tag oder ein Zeitraum.
class IncomeFigures {
  const IncomeFigures({
    required this.cashCount,
    required this.cashCents,
    required this.cardCount,
    required this.cardCents,
    required this.count,
    required this.revenueCents,
    required this.voidCount,
    required this.voidedCents,
    required this.taxLines,
    required this.depositCents,
  });

  factory IncomeFigures.ofDay(DaySummary s) => IncomeFigures(
    cashCount: s.cashReceiptCount,
    cashCents: s.cashRevenueCents,
    cardCount: s.cardReceiptCount,
    cardCents: s.cardRevenueCents,
    count: s.receiptCount,
    revenueCents: s.revenueCents,
    voidCount: s.voidCount,
    voidedCents: s.voidedCents,
    taxLines: s.taxLines,
    depositCents: s.depositCents,
  );

  factory IncomeFigures.ofPeriod(PeriodReport r) => IncomeFigures(
    cashCount: r.cashReceiptCount,
    cashCents: r.cashRevenueCents,
    cardCount: r.cardReceiptCount,
    cardCents: r.cardRevenueCents,
    count: r.receiptCount,
    revenueCents: r.revenueCents,
    voidCount: r.voidCount,
    voidedCents: r.voidedCents,
    taxLines: r.taxLines,
    depositCents: r.depositCents,
  );

  final int cashCount;
  final int cashCents;
  final int cardCount;
  final int cardCents;
  final int count;
  final int revenueCents;
  final int voidCount;
  final int voidedCents;
  final List<TaxLine> taxLines;
  final int depositCents;
}

class IncomeCard extends StatelessWidget {
  const IncomeCard(this.f, {super.key});

  final IncomeFigures f;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final l = L10n.of(context);
    final income = _Section(
      title: l.closeIncome,
      rows: [
        SummaryLine(
          label: l.kassaCash,
          middle: bonsLabel(l, f.cashCount),
          amount: formatEuro(f.cashCents),
          amountKey: const Key('income-cash'),
        ),
        SummaryLine(
          label: l.kassaCard,
          middle: bonsLabel(l, f.cardCount),
          amount: formatEuro(f.cardCents),
          amountKey: const Key('income-card'),
        ),
        SummaryLine(
          label: l.closeTotal,
          middle: bonsLabel(l, f.count),
          amount: formatEuro(f.revenueCents),
          bold: true,
          amountKey: const Key('income-total'),
        ),
        if (f.voidCount > 0)
          SummaryLine(
            label: l.bonsVoided,
            middle: bonsLabel(l, f.voidCount),
            amount: formatEuro(f.voidedCents),
            amountMuted: true,
            amountKey: const Key('left-voided'),
          ),
      ],
    );
    final tax = _Section(
      title: l.closeTax,
      headers: [l.closeRevenue, l.closeOfWhichVat],
      rows: [
        for (final t in f.taxLines)
          _TaxLine(
            l.closeVatRate(t.rate.percent),
            formatEuro(t.grossCents),
            formatEuro(t.taxCents),
          ),
        if (f.depositCents != 0)
          _TaxLine(l.closeDepositNoVat, formatEuro(f.depositCents), null),
      ],
    );
    return OverviewCard(
      child: LayoutBuilder(
        builder: (context, box) {
          if (box.maxWidth < 640) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                income,
                const SizedBox(height: KassaTokens.spaceHuge),
                tax,
              ],
            );
          }
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: income),
                Container(
                  width: KassaTokens.borderThin,
                  margin: const EdgeInsets.symmetric(
                    horizontal: KassaTokens.spaceHuge,
                  ),
                  color: c.line,
                ),
                Expanded(child: tax),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TaxLine extends StatelessWidget {
  const _TaxLine(this.label, this.gross, this.tax);

  final String label;
  final String gross;
  final String? tax;

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
          Expanded(
            child: Text(
              label,
              style: text.bodyLarge!.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 100),
            child: Ltr(
              child: Text(
                gross,
                textAlign: ltrAlign(context, TextAlign.end),
                style: text.bodyMedium!.copyWith(
                  fontWeight: FontWeight.w600,
                  color: c.ink2,
                ),
              ),
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 96),
            child: Ltr(
              child: Text(
                tax ?? '',
                textAlign: ltrAlign(context, TextAlign.end),
                style: text.bodyLarge!.copyWith(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Titelzeile (mit Spaltenköpfen) und darunter die Zeilen.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.rows, this.headers});

  final String title;
  final List<String>? headers;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final head = text.bodySmall!.copyWith(
      fontSize: 12.5,
      fontWeight: FontWeight.w700,
      color: c.ink2,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          constraints: const BoxConstraints(minHeight: 40),
          alignment: AlignmentDirectional.centerStart,
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: Text(title, style: text.titleLarge)),
              if (headers != null) ...[
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 100),
                  child: Text(
                    headers![0],
                    textAlign: TextAlign.end,
                    style: head,
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 96),
                  child: Text(
                    headers![1],
                    textAlign: TextAlign.end,
                    style: head,
                  ),
                ),
              ],
            ],
          ),
        ),
        ...rows,
      ],
    );
  }
}
