import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/money.dart';
import '../../data/providers.dart';
import '../../domain/day.dart';
import '../../rksv/rksv_state.dart';
import '../../ui/segmented.dart';
import '../../ui/tokens.dart';
import '../bons/bons_screen.dart' show germanMonths, germanWeekdays;
import '../login/session.dart';
import '../overview/overview_cards.dart' show OverviewCard;
import '../settings/rksv_task_row.dart';
import 'cash_movement_sheet.dart';
import 'count_cash_sheet.dart';
import 'day_closed_view.dart';
import 'day_summary_cards.dart';
import 'month_view.dart';
import 'report_print.dart';
import 'opening_float_sheet.dart';

const _entry = KeypadInput(maxIntDigits: 6);

/// Der Bereich Abschluss (nur Chef): links Einnahmen, Steuer und Geldlade des
/// Tages, rechts in der festen Spalte immer ein Schritt: Wechselgeld am
/// Morgen, Zählen, In der Lade lassen, eine Bargeld-Bewegung oder "Tag
/// abgeschlossen". Jedes Schreiben geht über das [DayRepository] mit der
/// angemeldeten Person. Unter den Summen stehen die offenen Aufgaben der
/// Signatur; sie sperren den Abschluss nicht.
class CloseScreen extends ConsumerStatefulWidget {
  const CloseScreen({super.key, required this.onToKassa});

  final VoidCallback onToKassa;

  @override
  ConsumerState<CloseScreen> createState() => _CloseScreenState();
}

class _CloseScreenState extends ConsumerState<CloseScreen> {
  KeypadInput _floatInput = _entry;
  KeypadInput _countInput = _entry;
  KeypadInput _leaveInput = _entry;
  KeypadInput _moveInput = _entry;
  bool _leaving = false;
  int _counted = 0;
  CashMovementKind? _move;
  CashReason? _reason;
  bool _busy = false;
  bool _failed = false;
  bool _justClosed = false;
  bool _printing = false;
  String? _printMessage;
  bool _printFailed = false;

  /// "Monat" statt "Tag". Der Bereich wird beim Verlassen verworfen, beim
  /// Öffnen ist also immer Tag gewählt.
  bool _month = false;

  /// Führt einen Schreibvorgang aus, höchstens einen zugleich. Danach werden
  /// die Zahlen neu geholt. Antwort: ob es geklappt hat. Bei einem Fehler
  /// bleibt die Eingabe stehen.
  Future<bool> _write(Future<void> Function() job) async {
    if (_busy) return false;
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      await job();
      ref.invalidate(closeSummaryProvider);
      await ref.read(closeSummaryProvider.future);
      return true;
    } catch (_) {
      if (mounted) setState(() => _failed = true);
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveFloat() async {
    final cents = _floatInput.cents;
    final ok = await _write(
      () => ref.read(dayRepositoryProvider).setOpeningFloat(cents),
    );
    if (ok && mounted) setState(() => _floatInput = _entry);
  }

  Future<void> _saveMovement() async {
    final kind = _move;
    final reason = _reason;
    final staff = ref.read(sessionProvider);
    if (kind == null || reason == null || staff == null) return;
    final ok = await _write(
      () => ref
          .read(dayRepositoryProvider)
          .addMovement(
            kind: kind,
            amountCents: _moveInput.cents,
            reason: reason,
            staff: staff,
          ),
    );
    if (ok && mounted) {
      setState(() {
        _move = null;
        _reason = null;
        _moveInput = _entry;
      });
    }
  }

  /// Druckt den Tagesbericht und merkt sich das Ergebnis für die Zeile in der
  /// Spalte. Höchstens ein Druck zugleich; wirft nie.
  Future<void> _printReport(DaySummary summary) async {
    if (_printing) return;
    setState(() {
      _printing = true;
      _printMessage = null;
    });
    final outcome = await ref.read(reportPrintProvider).printDay(summary);
    if (!mounted) return;
    setState(() {
      _printing = false;
      _printFailed = !outcome.ok;
      _printMessage = outcome.ok ? 'Bericht gedruckt.' : outcome.message;
    });
  }

  /// "Bericht drucken": der zuletzt abgeschlossene Tag noch einmal.
  Future<void> _printAgain() async {
    final summary = ref.read(closeSummaryProvider).value;
    if (summary == null || summary.day.isOpen) return;
    await _printReport(summary);
  }

  Future<void> _closeDay() async {
    final staff = ref.read(sessionProvider);
    if (_busy || staff == null) return;
    final left = _leaveInput.cents;
    final counted = _counted;
    // Schon vor dem Schreiben merken: die neuen Zahlen zeigen den Tag als
    // abgeschlossen und sollen gleich die Bestätigung bekommen.
    setState(() => _justClosed = true);
    final ok = await _write(
      () => ref
          .read(dayRepositoryProvider)
          .close(countedCents: counted, leftInDrawerCents: left, staff: staff),
    );
    if (!mounted) return;
    setState(() {
      if (!ok) _justClosed = false;
      if (ok) {
        _leaving = false;
        _countInput = _entry;
        _leaveInput = _entry;
        _printMessage = null;
      }
    });
    if (!ok || !ref.read(printerSetUpProvider)) return;
    // Der Bericht druckt von selbst, der Abschluss wartet nicht darauf.
    final summary = ref.read(closeSummaryProvider).value;
    if (summary != null) unawaited(_printReport(summary));
  }

  void _toggleMove(CashMovementKind kind) => setState(() {
    _move = _move == kind ? null : kind;
    _failed = false;
  });

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final async = ref.watch(closeSummaryProvider);
    final drawer =
        ref.watch(settingsStreamProvider).value?.cashDrawerEnabled ?? true;
    final printerSetUp = ref.watch(printerSetUpProvider);
    final now = ref.watch(clockProvider).now();
    final switcher = Segmented<bool>(
      segments: const [(false, 'Tag'), (true, 'Monat')],
      selected: _month,
      onSelected: (month) => setState(() => _month = month),
    );
    if (_month) return MonthView(switcher: switcher);
    if (!async.hasValue) {
      return ColoredBox(
        color: c.ground,
        child: async.hasError ? const _LoadError() : null,
      );
    }
    final summary = async.value;
    final day = summary?.day;
    final open = day != null && day.isOpen;
    final needsFloat =
        summary == null || (open && day.openingFloatCents == null);
    final shown = day?.openedAt ?? now;

    final Widget column;
    if (needsFloat) {
      column = OpeningFloatSheet(
        drawer: drawer,
        input: _floatInput,
        onKey: (k) => setState(() => _floatInput = _floatInput.tap(k)),
        onSave: _busy ? null : _saveFloat,
        failed: _failed,
      );
    } else if (!open) {
      column = DayClosedView(
        day: day!,
        drawer: drawer,
        justClosed: _justClosed,
        onToKassa: widget.onToKassa,
        onPrint: printerSetUp ? _printAgain : null,
        printing: _printing,
        printMessage: printerSetUp ? _printMessage : null,
        printFailed: _printFailed,
      );
    } else if (_move != null) {
      column = CashMovementSheet(
        kind: _move!,
        input: _moveInput,
        reason: _reason,
        onKey: (k) => setState(() => _moveInput = _moveInput.tap(k)),
        onReason: (r) => setState(() => _reason = r),
        onClose: () => setState(() {
          _move = null;
          _failed = false;
        }),
        onSave: _moveInput.cents > 0 && _reason != null && !_busy
            ? _saveMovement
            : null,
        failed: _failed,
      );
    } else if (_leaving) {
      column = LeaveInDrawerSheet(
        drawer: drawer,
        countedCents: _counted,
        expectedCents: summary.expectedCashCents,
        input: _leaveInput,
        onKey: (k) => setState(() => _leaveInput = _leaveInput.tap(k)),
        onBack: () => setState(() {
          _leaving = false;
          _failed = false;
        }),
        onClose: _closeDay,
        failed: _failed,
      );
    } else {
      column = CountCashSheet(
        drawer: drawer,
        expectedCents: summary.expectedCashCents,
        input: _countInput,
        onKey: (k) => setState(() => _countInput = _countInput.tap(k)),
        onNext: () => setState(() {
          _counted = _countInput.cents;
          _leaveInput = _entry;
          _leaving = true;
          _failed = false;
        }),
        failed: _failed,
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: KassaTokens.receiptHeaderHeight,
                  child: Row(
                    children: [
                      Text('Tagesabschluss', style: text.headlineMedium),
                      const SizedBox(width: KassaTokens.spaceLg),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            '${germanWeekdays[shown.weekday - 1]}, ${shown.day}. ${germanMonths[shown.month - 1]}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.labelLarge!.copyWith(
                              fontWeight: FontWeight.w600,
                              color: c.ink2,
                            ),
                          ),
                        ),
                      ),
                      if (day != null && !day.isOpen) const _ClosedPill(),
                      const SizedBox(width: KassaTokens.spaceLg),
                      switcher,
                    ],
                  ),
                ),
                if (summary != null)
                  Expanded(
                    child: SingleChildScrollView(
                      key: const Key('close-scroll'),
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          DaySummaryCards(
                            summary: summary,
                            drawer: drawer,
                            movement: open ? _move : null,
                            canMove: open && !needsFloat,
                            onCashIn: () =>
                                _toggleMove(CashMovementKind.deposit),
                            onCashOut: () =>
                                _toggleMove(CashMovementKind.withdrawal),
                          ),
                          const _RksvTasksCard(),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        column,
      ],
    );
  }
}

/// Die offenen Aufgaben der Signatur als Karte, wie in den Einstellungen
/// ([RksvTaskBlock]); "Erledigt" nur für den Chef. Ohne Aufgabe ist nichts
/// da.
class _RksvTasksCard extends ConsumerStatefulWidget {
  const _RksvTasksCard();

  @override
  ConsumerState<_RksvTasksCard> createState() => _RksvTasksCardState();
}

class _RksvTasksCardState extends ConsumerState<_RksvTasksCard> {
  bool _busy = false;

  Future<void> _complete(RksvTask task) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(rksvRepositoryProvider).completeTask(task.id);
    } catch (_) {
      // Die Aufgabe bleibt stehen und lässt sich noch einmal erledigen.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(rksvStateProvider).value ?? const RksvState();
    if (state.tasks.isEmpty) return const SizedBox.shrink();
    final isChef = ref.watch(sessionProvider)?.isChef ?? false;
    return Padding(
      padding: const EdgeInsets.only(top: KassaTokens.spaceXxl),
      child: OverviewCard(
        padding: const EdgeInsets.fromLTRB(24, 6, 24, 14),
        child: RksvTaskBlock(
          tasks: state.tasks,
          practice: state.onlyProbeTasks,
          busy: _busy,
          onDone: isChef ? _complete : null,
        ),
      ),
    );
  }
}

class _ClosedPill extends StatelessWidget {
  const _ClosedPill();

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.veganBg,
        borderRadius: BorderRadius.circular(KassaTokens.radiusPill),
      ),
      child: Text(
        'Abgeschlossen',
        style: Theme.of(context).textTheme.labelLarge!
            .copyWith(fontSize: 12.5, color: c.veganFg),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Das hat nicht geklappt. Bitte den Bereich nochmal öffnen.',
        style: Theme.of(context).textTheme.bodyMedium!
            .copyWith(color: KassaColors.of(context).red),
      ),
    );
  }
}
