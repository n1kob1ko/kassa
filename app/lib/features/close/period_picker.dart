import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/money.dart';
import '../../domain/period_report.dart';
import '../../domain/period_selection.dart';
import '../../l10n/generated/l10n.dart';
import '../../ui/dates_text.dart';
import '../../ui/ltr.dart';
import '../../ui/pressable.dart';
import '../../ui/primary_button.dart';
import '../../ui/segmented.dart';
import '../../ui/tokens.dart';
import 'amount_entry.dart';
import 'day_closed_view.dart' show PrintResult;

/// "1.10. bis 31.10.2026", über den Jahreswechsel "1.11.2025 bis 28.2.2026".
/// Die Daten stehen auch in einem arabischen Satz von links nach rechts.
String periodDates(BuildContext context, MonthRange r) {
  final from = r.from.start;
  final to = r.to.lastDay;
  final start = from.year == to.year
      ? '${from.day}.${from.month}.'
      : '${from.day}.${from.month}.${from.year}';
  return L10n.of(context).closePeriodDates(
    ltrIsolate(context, start),
    ltrIsolate(context, '${to.day}.${to.month}.${to.year}'),
  );
}

/// Überschrift eines Zeitraums am Bildschirm: "Oktober 2026", "Jänner bis
/// Oktober 2026", "November 2025 bis Februar 2026" ([periodTitle] bleibt die
/// Fassung des Zettels).
String periodTitleText(L10n l, MonthRange r) {
  final from = monthName(l, r.from.month);
  final to = monthName(l, r.to.month);
  if (r.single) return l.closeMonthYear(from, r.from.year);
  if (r.from.year == r.to.year) {
    return l.closePeriodSameYear(from, to, r.to.year);
  }
  return l.closePeriodTwoYears(
    l.closeMonthYear(from, r.from.year),
    l.closeMonthYear(to, r.to.year),
  );
}

/// Die feste Spalte "Zeitraum" der Monatsabrechnung: Ein Monat oder Von bis,
/// das Jahr, zwölf Monate, der gewählte Zeitraum mit Summe und unten
/// "Drucken". Monate außerhalb von [choice] sind gesperrt. Ohne
/// abrechenbaren Monat gibt es keine Taste.
class PeriodPicker extends StatelessWidget {
  const PeriodPicker({
    super.key,
    required this.choice,
    required this.selection,
    required this.year,
    required this.onMode,
    required this.onYear,
    required this.onMonth,
    required this.totalCents,
    required this.hint,
    required this.printerSetUp,
    required this.onPrint,
    this.printMessage,
    this.printFailed = false,
  });

  final MonthChoice choice;
  final PeriodSelection selection;

  /// Das angezeigte Jahr der zwölf Monate.
  final int year;
  final ValueChanged<bool> onMode;
  final ValueChanged<int> onYear;
  final ValueChanged<YearMonth> onMonth;

  /// Gesamt des angezeigten Zeitraums; ohne Wert noch nicht geladen.
  final int? totalCents;
  final String? hint;

  final bool printerSetUp;

  /// "Drucken"; ohne Wert gesperrt.
  final VoidCallback? onPrint;
  final String? printMessage;
  final bool printFailed;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final l = L10n.of(context);
    final first = choice.first;
    final last = choice.last;
    final range = selection.range;
    return CloseColumn(
      title: l.closePeriod,
      content: [
        Segmented<bool>(
          expand: true,
          segments: [(false, l.closeOneMonth), (true, l.closeFromTo)],
          selected: selection.rangeMode,
          onSelected: onMode,
        ),
        const SizedBox(height: KassaTokens.spaceXl),
        Row(
          children: [
            _YearArrow(
              keyName: 'year-prev',
              icon: directionalIcon(
                context,
                ltr: LucideIcons.chevronLeft,
                rtl: LucideIcons.chevronRight,
              ),
              label: l.closeYearBefore,
              onTap: first != null && year > first.year
                  ? () => onYear(year - 1)
                  : null,
            ),
            Expanded(
              child: Text(
                '$year',
                key: const Key('year-label'),
                textAlign: TextAlign.center,
                style: text.headlineMedium,
              ),
            ),
            _YearArrow(
              keyName: 'year-next',
              icon: directionalIcon(
                context,
                ltr: LucideIcons.chevronRight,
                rtl: LucideIcons.chevronLeft,
              ),
              label: l.closeYearAfter,
              onTap: last != null && year < last.year
                  ? () => onYear(year + 1)
                  : null,
            ),
          ],
        ),
        const SizedBox(height: KassaTokens.spaceXl),
        for (var row = 0; row < 4; row++) ...[
          if (row > 0) const SizedBox(height: KassaTokens.spaceMd),
          Row(
            children: [
              for (var col = 0; col < 3; col++) ...[
                if (col > 0) const SizedBox(width: KassaTokens.spaceMd),
                Expanded(
                  child: _monthButton(l, YearMonth(year, row * 3 + col + 1)),
                ),
              ],
            ],
          ),
        ],
        if (range != null) ...[
          const SizedBox(height: KassaTokens.spaceXl),
          Text(
            periodDates(context, range),
            key: const Key('period-text'),
            style: text.bodyMedium!.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: KassaTokens.spaceXxs),
          Ltr(
            child: Text(
              totalCents == null ? '' : formatEuro(totalCents!),
              key: const Key('period-total'),
              maxLines: 1,
              textAlign: ltrAlign(context, TextAlign.start),
              style: text.headlineLarge!.copyWith(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                height: 1.15,
              ),
            ),
          ),
        ],
        if (hint != null) ...[
          const SizedBox(height: KassaTokens.spaceXxs),
          Text(
            hint!,
            style: text.bodySmall!.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: c.ink2,
            ),
          ),
        ],
      ],
      bottom: last == null
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!printerSetUp) ...[
                  Text(
                    l.closeNoPrinter,
                    key: const Key('period-no-printer'),
                    style: text.bodyMedium!.copyWith(
                      fontWeight: FontWeight.w600,
                      color: c.ink2,
                    ),
                  ),
                  const SizedBox(height: KassaTokens.spaceXl),
                ] else if (printMessage != null) ...[
                  PrintResult(
                    key: const Key('period-print-result'),
                    message: printMessage!,
                    failed: printFailed,
                  ),
                  const SizedBox(height: KassaTokens.spaceXl),
                ],
                PrimaryButton(
                  key: const Key('print-period'),
                  label: l.closePrint,
                  icon: LucideIcons.printer,
                  height: KassaTokens.mainActionHeight,
                  onPressed: onPrint,
                ),
              ],
            ),
    );
  }

  Widget _monthButton(L10n l, YearMonth m) {
    final range = selection.range;
    final end = range != null && (m == range.from || m == range.to);
    return _MonthButton(
      number: m.month,
      label: monthShortName(l, m.month),
      state: end
          ? _MonthState.end
          : selection.marks(m)
          ? _MonthState.between
          : _MonthState.plain,
      onTap: choice.allows(m) ? () => onMonth(m) : null,
    );
  }
}

enum _MonthState { plain, between, end }

/// Monatstaste, 56 dp hoch. Gewählt (Beginn und Ende): `accent`; dazwischen:
/// `accentSoft` mit Rand `accentSnack`; gesperrt: `fill`, Deckkraft 0,4.
class _MonthButton extends StatelessWidget {
  const _MonthButton({
    required this.number,
    required this.label,
    required this.state,
    required this.onTap,
  });

  /// 1 bis 12, Schlüssel `month-<number>`.
  final int number;
  final String label;
  final _MonthState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final (
      Color bg,
      Color border,
      Color fg,
      FontWeight weight,
    ) = switch (state) {
      _MonthState.end => (c.accent, c.accent, c.onAccent, FontWeight.w800),
      _MonthState.between => (
        c.accentSoft,
        c.accentSnack,
        c.accentInk,
        FontWeight.w700,
      ),
      _MonthState.plain => (
        onTap == null ? c.fill : c.card,
        c.line,
        c.ink,
        FontWeight.w600,
      ),
    };
    return Pressable(
      key: Key('month-$number'),
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        height: KassaTokens.keypadKeyHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(KassaTokens.radiusXl),
          border: Border.all(color: border, width: KassaTokens.borderButton),
        ),
        child: Text(
          label,
          maxLines: 1,
          style: Theme.of(context).textTheme.bodyLarge!
              .copyWith(fontWeight: weight, color: fg),
        ),
      ),
    );
  }
}

/// Pfeiltaste für das Jahr, 56 × 56 dp.
class _YearArrow extends StatelessWidget {
  const _YearArrow({
    required this.keyName,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final String keyName;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    return Pressable(
      key: Key(keyName),
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        width: KassaTokens.keypadKeyHeight,
        height: KassaTokens.keypadKeyHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: onTap == null ? c.fill : c.card,
          borderRadius: BorderRadius.circular(KassaTokens.radiusXl),
          border: Border.all(color: c.line, width: KassaTokens.borderButton),
        ),
        child: Icon(icon, size: 24, color: c.ink),
      ),
    );
  }
}
