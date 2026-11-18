// Unklare Kartenzahlung: ein Blatt über der ganzen App, das die Person fragt,
// ob eine Kartenzahlung angekommen ist, wenn die Kassa darauf keine Antwort
// bekommen hat (App geschlossen, während SumUp offen war, oder "unbekannt").

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/money.dart';
import '../../data/card_payment_repository.dart';
import '../../data/providers.dart';
import '../../domain/catalog.dart';
import '../../ui/primary_button.dart';
import '../../ui/theme.dart';
import '../../ui/tokens.dart';
import '../bons/receipt_list.dart' show receiptTime;
import '../login/session.dart';
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
    final c = KassaColors.of(context);
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
            ModalBarrier(
              dismissible: false,
              color: c.ink.withValues(alpha: 0.5),
            ),
            Center(
              child: _UnclearSheet(
                key: ValueKey(open.first.id),
                payment: open.first,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _Stage { choose, confirmPaid, confirmNotPaid }

class _UnclearSheet extends ConsumerStatefulWidget {
  const _UnclearSheet({super.key, required this.payment});

  final PendingCardPayment payment;

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
    final p = widget.payment;
    try {
      if (paid) {
        final catalog = ref.read(catalogStreamProvider).value;
        if (catalog == null) throw const UnreadableCardPaymentException();
        await service.confirmUnclear(p, catalog: catalog);
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
    final lines = catalog == null ? const <String>[] : _lineTexts(p, catalog);
    final shown = lines.take(_maxLines).toList();
    final more = lines.length - shown.length;
    final time = receiptTime(p.startedAt);
    final amount = formatEuro(p.amountCents);
    final still = MediaQuery.disableAnimationsOf(context);

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
                  Text(
                    'War diese Kartenzahlung erfolgreich?',
                    style: text.headlineMedium,
                  ),
                  const SizedBox(height: KassaTokens.spaceXl),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      amount,
                      key: const Key('unclear-amount'),
                      maxLines: 1,
                      style: KassaText.amount(context),
                    ),
                  ),
                  const SizedBox(height: KassaTokens.spaceMd),
                  Text(
                    'Gestartet um $time von ${p.staffName}',
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
                              'und $more weitere',
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
                    message:
                        'Die Kassa hat von SumUp keine Antwort bekommen. Schau '
                        'in der SumUp-App unter Verkäufe nach, ob $amount um '
                        '$time angekommen ist.',
                  ),
                  if (unreadable) ...[
                    const SizedBox(height: KassaTokens.spaceMd),
                    _Note(
                      key: const Key('unclear-unreadable'),
                      background: c.spicyBg,
                      foreground: c.spicyFg,
                      message:
                          'Der Bon lässt sich nicht mehr zusammenstellen, weil '
                          'sich die Speisekarte geändert hat. Wähle Nein. Ist '
                          'das Geld bei SumUp angekommen, buche es in der '
                          'SumUp-App zurück und kassiere neu.',
                    ),
                  ],
                  if (_failed) ...[
                    const SizedBox(height: KassaTokens.spaceMd),
                    _Note(
                      key: const Key('unclear-failed'),
                      background: c.spicyBg,
                      foreground: c.spicyFg,
                      message: 'Das hat nicht geklappt. Bitte noch einmal.',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!unreadable) ...[
          PrimaryButton(
            key: const Key('unclear-paid'),
            label: 'Ja, ist angekommen',
            height: KassaTokens.mainActionHeight,
            onPressed: () => setState(() => _stage = _Stage.confirmPaid),
          ),
          const SizedBox(height: KassaTokens.spaceLg),
        ],
        PrimaryButton(
          key: const Key('unclear-not-paid'),
          label: 'Nein, nicht angekommen',
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
    final paid = _stage == _Stage.confirmPaid;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Note(
          key: const Key('unclear-effect'),
          background: c.accentSoft,
          foreground: c.accentInk,
          message: paid
              ? 'Die Kassa schreibt den Bon als Kartenzahlung und druckt ihn.'
              : 'Die Kassa verwirft die Zahlung und legt die Artikel wieder '
                    'auf den Bon.',
        ),
        const SizedBox(height: KassaTokens.spaceXxl),
        PrimaryButton(
          key: const Key('unclear-confirm'),
          label: 'Bestätigen',
          height: KassaTokens.mainActionHeight,
          onPressed: _busy ? null : () => _decide(paid: paid),
        ),
        const SizedBox(height: KassaTokens.spaceLg),
        PrimaryButton(
          key: const Key('unclear-back'),
          label: 'Zurück',
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

/// Die Zeilen des Bons in Kurzform: "2 × Cola", "Huhn Bowl". Lässt sich der
/// Bon nicht lesen, steht nichts da.
List<String> _lineTexts(PendingCardPayment p, Catalog catalog) {
  final cart = SaleService.cartOfPending(p, catalog);
  if (cart == null) return const [];
  return [
    for (final l in cart.lines)
      l.quantity > 1 ? '${l.quantity} × ${l.item.name}' : l.item.name,
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
