// Unklare Kartenzahlung: ein Blatt über der ganzen App, das die Person fragt,
// ob eine Kartenzahlung angekommen ist, wenn die Kassa darauf keine Antwort
// bekommen hat (App geschlossen, während SumUp offen war, oder "unbekannt").

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/money.dart';
import '../../data/card_payment_repository.dart';
import '../../data/providers.dart';
import '../../data/settings_repository.dart';
import '../../devices/printer.dart';
import '../../domain/catalog.dart';
import '../../l10n/generated/l10n.dart';
import '../../ui/ltr.dart';
import '../../ui/menu_text.dart';
import '../../ui/primary_button.dart';
import '../../ui/print_problem_text.dart';
import '../../ui/theme.dart';
import '../../ui/tokens.dart';
import '../../ui/undo_toast.dart';
import '../bons/receipt_list.dart' show receiptTime;
import '../login/session.dart';
import 'cart_controller.dart';
import 'late_kitchen.dart';
import 'sale_service.dart';

/// Die Zahlungen, nach denen gefragt wird, die älteste zuerst: alle mit
/// unklarem Ausgang und alle, die nur gestartet sind und nicht in diesem Lauf
/// gerade am Terminal laufen (Rest eines Absturzes). Eine laufende Zahlung
/// zeigt die Kassa als "Warte auf Karte"; sie zu entscheiden wäre falsch.
final unclearCardPaymentsProvider = Provider<List<PendingCardPayment>>((ref) {
  final all = ref.watch(pendingCardPaymentsProvider).value ?? const [];
  final active = ref.watch(activeCardPaymentProvider);
  return [
    for (final p in all)
      if (p.unknown || p.id != active) p,
  ];
});

/// Das Blatt, ganz oben im Stapel der Oberfläche: eine Fläche, die alles
/// darunter abdeckt, nicht wegzutippen und nicht mit "Zurück" zu schließen.
/// Ohne angemeldete Person oder ohne offene Zahlung ist sie leer.
class UnclearCardOverlay extends ConsumerWidget {
  const UnclearCardOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staff = ref.watch(sessionProvider);
    final open = ref.watch(unclearCardPaymentsProvider);
    if (staff == null || open.isEmpty) return const SizedBox.shrink();
    final fade = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : KassaTokens.motionFade;
    return PopScope(
      canPop: false,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: fade,
        curve: KassaTokens.motionCurve,
        builder: (context, t, child) => Opacity(opacity: t, child: child),
        child: Stack(
          children: [
            ModalBarrier(dismissible: false, color: KassaTokens.scrim),
            Center(
              child: _UnclearSheet(
                key: ValueKey(open.first.id),
                payment: open.first,
                // Das Blatt ist weg, sobald der Bon geschrieben ist; den
                // Ausgang des Druckens meldet darum diese Fläche, die bleibt.
                onPrint: (print) => _announcePrint(context, print),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Zeigt das Ergebnis des Druckens als Hinweis unten, wie das Bon-Detail.
/// Ohne Drucker gibt es nichts zu melden.
Future<void> _announcePrint(
  BuildContext context,
  Future<PrintOutcome> print,
) async {
  final outcome = await print;
  if (!context.mounted || outcome.problem == PrintProblem.notSetUp) return;
  final l = L10n.of(context);
  showUndoToast(
    context,
    message: outcome.ok
        ? l.kassaPrinted
        : printProblemText(l, outcome.problem!),
  );
}

enum _Stage { choose, confirmPaid, confirmNotPaid }

class _UnclearSheet extends ConsumerStatefulWidget {
  const _UnclearSheet({
    super.key,
    required this.payment,
    required this.onPrint,
  });

  final PendingCardPayment payment;

  /// Bekommt das Drucken des Bons nach "Ja".
  final void Function(Future<PrintOutcome> print) onPrint;

  @override
  ConsumerState<_UnclearSheet> createState() => _UnclearSheetState();
}

class _UnclearSheetState extends ConsumerState<_UnclearSheet> {
  _Stage _stage = _Stage.choose;

  /// Gesetzt mit dem ersten Tipp auf "Bestätigen", noch vor dem nächsten Bild:
  /// ein zweiter Tipp tut nichts. Das Blatt verschwindet, sobald die Zahlung
  /// aus der Datenbank weg ist.
  bool _busy = false;

  /// Beim Bestätigen hat sich gezeigt, dass der Bon nicht mehr zu bauen ist.
  bool _unreadable = false;
  bool _failed = false;

  Future<void> _decide({required bool paid}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    final service = ref.read(saleServiceProvider);
    // Vor dem Warten gelesen: danach kann das Blatt schon weg sein.
    final lateKitchen = ref.read(lateKitchenProvider.notifier);
    final p = widget.payment;
    try {
      if (paid) {
        final catalog = ref.read(catalogStreamProvider).value;
        if (catalog == null) throw const UnreadableCardPaymentException();
        final sale = await service.confirmUnclear(p, catalog: catalog);
        widget.onPrint(sale.print);
        // Das Blatt ist gleich weg: einen gescheiterten Küchenbon meldet der
        // Hinweis über dem Bon der Kassa, mit "Küchenbon drucken".
        lateKitchen.follow(sale.receipt, sale.kitchen);
      } else {
        await service.discardUnclear(p);
      }
    } on UnreadableCardPaymentException {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _unreadable = true;
        _stage = _Stage.choose;
      });
    } on CardPaymentRunningException {
      // Die Zahlung läuft gerade: das Blatt verschwindet von selbst wieder.
      if (mounted) setState(() => _busy = false);
    } on CardPaymentGoneException {
      // Schon erledigt: der Strom nimmt das Blatt gleich weg.
      if (mounted) setState(() => _busy = false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final p = widget.payment;
    final catalog = ref.watch(catalogStreamProvider).value;
    final cart = catalog == null ? null : SaleService.cartOfPending(p, catalog);
    final unreadable = _unreadable || cart == null;
    final lines = catalog == null
        ? const <String>[]
        : _lineTexts(p, catalog, ref.watch(menuTextProvider));
    final shown = lines.take(_maxLines).toList();
    final more = lines.length - shown.length;
    final time = receiptTime(p.startedAt);
    final amount = formatEuro(p.amountCents);
    final still = MediaQuery.disableAnimationsOf(context);
    final l = L10n.of(context);

    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Padding(
          padding: const EdgeInsets.all(KassaTokens.spaceXxl),
          child: Material(
            key: const Key('unclear-card'),
            color: c.card,
            borderRadius: BorderRadius.circular(KassaTokens.radiusCard),
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(KassaTokens.spaceHuge),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l.unclearTitle, style: text.headlineMedium),
                  const SizedBox(height: KassaTokens.spaceXl),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Ltr(
                      child: Text(
                        amount,
                        key: const Key('unclear-amount'),
                        maxLines: 1,
                        style: KassaText.amount(context),
                      ),
                    ),
                  ),
                  if (p.tipCents > 0) ...[
                    const SizedBox(height: KassaTokens.spaceXs),
                    Text(
                      l.unclearTip(ltrIsolate(context, formatEuro(p.tipCents))),
                      key: const Key('unclear-tip'),
                      style: text.bodyLarge!.copyWith(color: c.ink2),
                    ),
                  ],
                  if (p.cashPartCents > 0) ...[
                    const SizedBox(height: KassaTokens.spaceXs),
                    Text(
                      l.unclearCashPart(
                        ltrIsolate(context, formatEuro(p.cashPartCents)),
                      ),
                      key: const Key('unclear-cash-part'),
                      style: text.bodyLarge!.copyWith(
                        fontWeight: FontWeight.w600,
                        color: c.ink,
                      ),
                    ),
                  ],
                  const SizedBox(height: KassaTokens.spaceMd),
                  Text(
                    l.unclearStarted(
                      ltrIsolate(context, time),
                      nameIsolateIn(context, p.staffName),
                    ),
                    style: text.bodyLarge!.copyWith(color: c.ink2),
                  ),
                  if (shown.isNotEmpty) ...[
                    const SizedBox(height: KassaTokens.spaceXl),
                    Container(
                      padding: const EdgeInsets.all(KassaTokens.spaceXl),
                      decoration: BoxDecoration(
                        color: c.fill,
                        borderRadius: BorderRadius.circular(
                          KassaTokens.radiusXl,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final (i, l) in shown.indexed)
                            Text(
                              l,
                              key: Key('unclear-line-$i'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.bodyMedium,
                            ),
                          if (more > 0)
                            Text(
                              l.unclearMore(more),
                              style: text.bodyMedium!.copyWith(color: c.ink2),
                            ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: KassaTokens.spaceXl),
                  _Note(
                    background: c.warnBg,
                    foreground: c.warnInk,
                    message: l.unclearNoAnswer(
                      ltrIsolate(context, amount),
                      ltrIsolate(context, time),
                    ),
                  ),
                  if (unreadable) ...[
                    const SizedBox(height: KassaTokens.spaceMd),
                    _Note(
                      key: const Key('unclear-unreadable'),
                      background: c.spicyBg,
                      foreground: c.spicyFg,
                      message: l.unclearUnreadable,
                    ),
                  ],
                  if (_failed) ...[
                    const SizedBox(height: KassaTokens.spaceMd),
                    _Note(
                      key: const Key('unclear-failed'),
                      background: c.spicyBg,
                      foreground: c.spicyFg,
                      message: l.unclearFailed,
                    ),
                  ],
                  const SizedBox(height: KassaTokens.spaceXxl),
                  AnimatedSwitcher(
                    duration: still ? Duration.zero : KassaTokens.motionSwitch,
                    child: KeyedSubtree(
                      key: ValueKey(_stage),
                      child: _stage == _Stage.choose
                          ? _choice(unreadable)
                          : _confirm(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _choice(bool unreadable) {
    final l = L10n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!unreadable) ...[
          PrimaryButton(
            key: const Key('unclear-paid'),
            label: l.unclearYes,
            height: KassaTokens.mainActionHeight,
            onPressed: () => setState(() => _stage = _Stage.confirmPaid),
          ),
          const SizedBox(height: KassaTokens.spaceLg),
        ],
        PrimaryButton(
          key: const Key('unclear-not-paid'),
          label: l.unclearNo,
          height: KassaTokens.mainActionHeight,
          filled: unreadable,
          solid: !unreadable,
          onPressed: () => setState(() => _stage = _Stage.confirmNotPaid),
        ),
      ],
    );
  }

  Widget _confirm() {
    final c = KassaColors.of(context);
    final l = L10n.of(context);
    final paid = _stage == _Stage.confirmPaid;
    final settings =
        ref.watch(settingsStreamProvider).value ?? const RegisterSettings();
    final printing = settings.printerKind != PrinterKind.none;
    final catalog = ref.watch(catalogStreamProvider).value;
    // "Nein" legt die Artikel nur auf eine leere Kassa zurück, und nur, wenn
    // sich der Bon der Zahlung lesen lässt.
    final comesBack =
        catalog != null &&
        ref.watch(cartProvider).isEmpty &&
        SaleService.cartToRestore(widget.payment, catalog) != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Note(
          key: const Key('unclear-effect'),
          background: c.accentSoft,
          foreground: c.accentInk,
          message: paid
              ? (printing ? l.unclearEffectPaidPrint : l.unclearEffectPaid)
              : (comesBack ? l.unclearEffectRestore : l.unclearEffectDiscard),
        ),
        if (!paid && widget.payment.cashPartCents > 0) ...[
          const SizedBox(height: KassaTokens.spaceMd),
          _Note(
            key: const Key('unclear-return-cash'),
            background: c.warnBg,
            foreground: c.warnInk,
            message: l.unclearReturnCash(
              ltrIsolate(context, formatEuro(widget.payment.cashPartCents)),
            ),
          ),
        ],
        const SizedBox(height: KassaTokens.spaceXxl),
        PrimaryButton(
          key: const Key('unclear-confirm'),
          label: l.unclearConfirm,
          height: KassaTokens.mainActionHeight,
          onPressed: _busy ? null : () => _decide(paid: paid),
        ),
        const SizedBox(height: KassaTokens.spaceLg),
        PrimaryButton(
          key: const Key('unclear-back'),
          label: l.unclearBack,
          filled: false,
          height: KassaTokens.secondaryActionHeight,
          onPressed: _busy
              ? null
              : () => setState(() => _stage = _Stage.choose),
        ),
      ],
    );
  }
}

/// Höchstens so viele Zeilen des Bons stehen auf dem Blatt.
const _maxLines = 4;

/// Die Zeilen des Bons in Kurzform: "2 × Cola", "Huhn Bowl", die Namen in
/// der Bediensprache ([text], nur für die Anzeige). Lässt sich der Bon nicht
/// lesen, steht nichts da.
List<String> _lineTexts(
  PendingCardPayment p,
  Catalog catalog,
  String Function(String source) text,
) {
  final cart = SaleService.cartOfPending(p, catalog);
  if (cart == null) return const [];
  return [
    for (final l in cart.lines)
      l.quantity > 1
          ? '${l.quantity} × ${text(l.item.name)}'
          : text(l.item.name),
  ];
}

class _Note extends StatelessWidget {
  const _Note({
    super.key,
    required this.background,
    required this.foreground,
    required this.message,
  });

  final Color background;
  final Color foreground;
  final String message;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(KassaTokens.spaceXl),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(KassaTokens.radiusXl),
      ),
      child: Text(
        message,
        style: text.bodyLarge!.copyWith(
          color: foreground,
          fontWeight: FontWeight.w600,
          height: 1.35,
        ),
      ),
    );
  }
}
