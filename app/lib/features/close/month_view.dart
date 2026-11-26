import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/providers.dart';
import '../../devices/printer.dart';
import '../../domain/period_report.dart';
import '../../domain/period_selection.dart';
import '../../domain/receipt.dart';
import '../../l10n/generated/l10n.dart';
import '../../ui/dates_text.dart';
import '../../ui/print_problem_text.dart';
import '../../ui/tokens.dart';
import '../../ui/undo_toast.dart';
import '../kassa/sale_service.dart';
import 'amount_entry.dart';
import 'income_card.dart';
import 'month_providers.dart';
import 'period_cards.dart';
import 'period_picker.dart';
import 'report_print.dart';

/// "Monat" im Bereich Abschluss: links die Abrechnung des gewählten
/// Zeitraums (Einnahmen und Steuer, Monatsbeleg der Signatur, Tage oder
/// Monate), rechts die feste Spalte "Zeitraum". [switcher] ist der Umschalter
/// "Tag | Monat" rechts in der Kopfzeile. Beim Öffnen ist der letzte
/// abgeschlossene Monat gewählt. Beim Wechsel bleiben die alten Zahlen
/// stehen, bis die neuen da sind. Liest nur, schreibt nichts.
class MonthView extends ConsumerStatefulWidget {
  const MonthView({super.key, required this.switcher});

  final Widget switcher;

  @override
  ConsumerState<MonthView> createState() => _MonthViewState();
}

class _MonthViewState extends ConsumerState<MonthView> {
  PeriodSelection? _selection;
  int? _year;

  /// Zuletzt geladene Zahlen und Beleg, bleiben beim Wechsel stehen.
  PeriodReport? _shown;

  /// Geladene Monats- und Jahresbelege je Monat (null: keiner).
  final Map<YearMonth, Receipt?> _belege = {};

  bool _printing = false;

  /// Ergebnis des letzten Drucks der Abrechnung, `null` ohne.
  PrintOutcome? _printOutcome;
  bool _reprinting = false;

  /// Ein neuer Zeitraum löscht das Ergebnis des letzten Drucks.
  void _select(PeriodSelection s) => setState(() {
    _selection = s;
    _printOutcome = null;
  });

  /// Höchstens ein Druck zugleich. Das Ergebnis erscheint nur, wenn noch
  /// derselbe Zeitraum gewählt ist.
  Future<void> _print(PeriodReport report) async {
    if (_printing) return;
    setState(() {
      _printing = true;
      _printOutcome = null;
    });
    final outcome = await ref.read(reportPrintProvider).printPeriod(report);
    if (!mounted) return;
    setState(() {
      _printing = false;
      if (_selection?.range != report.range) return;
      _printOutcome = outcome;
    });
  }

  /// Druckt den gespeicherten Beleg noch einmal, wie "Drucken" im Bereich
  /// Bons, und meldet das Ergebnis unten.
  Future<void> _reprint(Receipt receipt) async {
    if (_reprinting) return;
    setState(() => _reprinting = true);
    PrintOutcome outcome;
    try {
      outcome = await ref.read(saleServiceProvider).reprint(receipt);
    } catch (_) {
      outcome = const PrintOutcome.failed(PrintProblem.unreachable);
    }
    if (!mounted) return;
    setState(() => _reprinting = false);
    if (outcome.problem == PrintProblem.notSetUp) return;
    final l = L10n.of(context);
    showUndoToast(
      context,
      message: outcome.ok
          ? l.kassaPrinted
          : printProblemText(l, outcome.problem!),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final l = L10n.of(context);
    final choiceAsync = ref.watch(monthChoiceProvider);
    final printerSetUp = ref.watch(printerSetUpProvider);
    final hasSignature = ref.watch(hasSignatureProvider).value ?? false;
    final now = ref.watch(clockProvider).now();
    final choice = choiceAsync.value;
    if (choice == null) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _Left(
              title: l.closeMonthlyReport,
              testMode: false,
              switcher: widget.switcher,
              body: choiceAsync.hasError
                  ? Text(
                      l.closeLoadFailed,
                      style: Theme.of(context).textTheme.bodyMedium!
                          .copyWith(color: c.red),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
          CloseColumn(title: l.closePeriod, content: const []),
        ],
      );
    }

    final last = choice.last;
    if (_selection == null && last != null) {
      _selection = PeriodSelection(from: last, to: last);
    }
    final year = _year ??= last?.year ?? now.year;
    final selection = _selection ?? const PeriodSelection();
    final range = selection.range;
    final report = range == null
        ? null
        : ref.watch(periodReportProvider(range));
    final loaded = report?.value;
    if (loaded != null) _shown = loaded;
    // Scheitert die Rechnung, stehen keine alten Zahlen neben dem neuen
    // Zeitraum.
    final failed = report != null && report.hasError && loaded == null;
    final shown = failed ? null : _shown;
    // Gedruckt werden nur die Zahlen des gewählten Zeitraums.
    final printable = shown != null && shown.range == range && !shown.isEmpty
        ? shown
        : null;

    // Die Karte zum Beleg gibt es nur bei "Ein Monat". Der Beleg wird schon
    // mit der Wahl geholt und nur zu dem Monat gezeigt, zu dem er gehört.
    final single = !selection.rangeMode && hasSignature;
    if (single && range != null) {
      final month = range.from;
      final beleg = ref.watch(signatureReceiptProvider(month));
      if (beleg.hasValue) _belege[month] = beleg.value;
    }
    final belegMonth = shown?.range.from;
    final beleg =
        single &&
            shown != null &&
            shown.range.single &&
            _belege.containsKey(belegMonth)
        ? (belegMonth!, _belege[belegMonth])
        : null;

    final next = choice.nextAvailable;
    final nextDate = l.closeDayMonth(next.day, monthName(l, next.month));
    final Widget body;
    if (last == null) {
      body = PeriodNote(
        l.closeFirstMonthlyReport(nextDate),
        key: const Key('no-month-yet'),
      );
    } else if (failed) {
      body = Text(
        l.closeLoadFailed,
        key: const Key('period-error'),
        style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: c.red),
      );
    } else if (shown == null) {
      body = const SizedBox.shrink();
    } else if (shown.isEmpty) {
      body = PeriodNote(
        l.closeNoReceiptsInPeriod,
        key: const Key('period-empty'),
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IncomeCard(IncomeFigures.ofPeriod(shown)),
          if (beleg != null) ...[
            const SizedBox(height: KassaTokens.spaceXxl),
            SignatureReceiptCard(
              month: beleg.$1,
              receipt: beleg.$2,
              onPrint: printerSetUp && !_reprinting && beleg.$2 != null
                  ? () => _reprint(beleg.$2!)
                  : null,
            ),
          ],
          const SizedBox(height: KassaTokens.spaceXxl),
          PeriodRowsCard(shown),
        ],
      );
    }

    final titled = shown?.range ?? range;
    final String? hint;
    if (last == null) {
      hint = null;
    } else if (selection.rangeMode) {
      hint = l.closeRangeHint;
    } else {
      hint = l.closeMonthAvailableHint(monthName(l, now.month), nextDate);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: _Left(
            title: titled == null || titled.single
                ? l.closeMonthlyReport
                : l.closeReport,
            subtitle: titled == null ? null : periodTitleText(l, titled),
            testMode: shown?.testMode ?? false,
            switcher: widget.switcher,
            body: body,
          ),
        ),
        PeriodPicker(
          choice: choice,
          selection: selection,
          year: year,
          onMode: (rangeMode) {
            if (rangeMode == selection.rangeMode) return;
            _select(selection.withMode(rangeMode: rangeMode));
          },
          onYear: (y) => setState(() => _year = y),
          onMonth: (m) => _select(selection.tap(m)),
          totalCents: shown?.revenueCents,
          hint: hint,
          printerSetUp: printerSetUp,
          onPrint: printerSetUp && !_printing && printable != null
              ? () => _print(printable)
              : null,
          printMessage: switch (_printOutcome) {
            null => null,
            PrintOutcome(:final problem?) => printProblemText(l, problem),
            _ => l.closePeriodPrinted,
          },
          printFailed: _printOutcome?.ok == false,
        ),
      ],
    );
  }
}

/// Linke Seite: Kopfzeile mit Überschrift, Pille "Testbetrieb" und dem
/// Umschalter, darunter [body], der scrollt.
class _Left extends StatelessWidget {
  const _Left({
    required this.title,
    this.subtitle,
    required this.testMode,
    required this.switcher,
    required this.body,
  });

  final String title;
  final String? subtitle;
  final bool testMode;
  final Widget switcher;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final sub = text.labelLarge!.copyWith(
      fontWeight: FontWeight.w600,
      color: c.ink2,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: KassaTokens.receiptHeaderHeight,
            child: Row(
              children: [
                Expanded(
                  child: Text.rich(
                    key: const Key('period-title'),
                    TextSpan(
                      text: title,
                      style: text.headlineMedium,
                      children: [
                        if (subtitle != null) ...[
                          // Der Abstand ist ein breites Leerzeichen, damit die
                          // Überschrift als ein Satz vorgelesen wird.
                          TextSpan(
                            text: ' ',
                            style: sub.copyWith(
                              letterSpacing: KassaTokens.spaceSm,
                            ),
                          ),
                          TextSpan(text: subtitle, style: sub),
                        ],
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (testMode) ...[
                  const SizedBox(width: KassaTokens.spaceLg),
                  const _TestModePill(),
                ],
                const SizedBox(width: KassaTokens.spaceLg),
                switcher,
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              key: const Key('period-scroll'),
              padding: const EdgeInsets.only(bottom: KassaTokens.spaceXxl),
              child: body,
            ),
          ),
        ],
      ),
    );
  }
}

/// Ruhige Pille "Testbetrieb": es gibt noch keinen echt signierten Beleg.
class _TestModePill extends StatelessWidget {
  const _TestModePill();

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    return Container(
      key: const Key('test-mode-pill'),
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: KassaTokens.spaceLg),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(KassaTokens.radiusPill),
        border: Border.all(color: c.line, width: KassaTokens.borderThin),
      ),
      child: Text(
        L10n.of(context).closeTestMode,
        style: Theme.of(context).textTheme.labelLarge!.copyWith(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: c.ink2,
        ),
      ),
    );
  }
}
