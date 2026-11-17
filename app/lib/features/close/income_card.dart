import 'package:material_ui/material_ui.dart';

import '../../core/money.dart';
import '../../domain/day.dart';
import '../../ui/tokens.dart';
import '../overview/overview_cards.dart' show OverviewCard;
import 'close_format.dart';
import 'summary_rows.dart';

class IncomeCard extends StatelessWidget {
  const IncomeCard(this.s, {super.key});

  final DaySummary s;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final income = _Section(
      title: 'Einnahmen',
      rows: [
        SummaryLine(
          label: 'Bar',
          middle: bonsLabel(s.cashReceiptCount),
          amount: formatEuro(s.cashRevenueCents),
          amountKey: const Key('income-cash'),
        ),
        SummaryLine(
          label: 'Karte',
          middle: bonsLabel(s.cardReceiptCount),
          amount: formatEuro(s.cardRevenueCents),
          amountKey: const Key('income-card'),
        ),
        SummaryLine(
          label: 'Gesamt',
          middle: bonsLabel(s.receiptCount),
          amount: formatEuro(s.revenueCents),
          bold: true,
          amountKey: const Key('income-total'),
        ),
        if (s.voidCount > 0)
          SummaryLine(
            label: 'Storniert',
            middle: bonsLabel(s.voidCount),
            amount: formatEuro(s.voidedCents),
            amountMuted: true,
            amountKey: const Key('left-voided'),
          ),
      ],
    );
    final tax = _Section(
      title: 'Steuer',
      headers: const ['Umsatz', 'davon MwSt'],
      rows: [
        for (final t in s.taxLines)
          _TaxLine(
            'MwSt ${t.rate.percent} %',
            formatEuro(t.grossCents),
            formatEuro(t.taxCents),
          ),
        if (s.depositCents != 0)
          _TaxLine('Pfand, ohne MwSt', formatEuro(s.depositCents), null),
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
            child: Text(
              gross,
              textAlign: TextAlign.end,
              style: text.bodyMedium!.copyWith(
                fontWeight: FontWeight.w600,
                color: c.ink2,
              ),
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 96),
            child: Text(
              tax ?? '',
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
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: Text(title, style: text.titleLarge)),
              if (headers != null) ...[
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 100),
                  child: Text(headers![0], textAlign: TextAlign.end, style: head),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 96),
                  child: Text(headers![1], textAlign: TextAlign.end, style: head),
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
