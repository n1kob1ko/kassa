import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/money.dart';
import '../../domain/cart.dart';
import '../../l10n/generated/l10n.dart';
import '../../ui/ltr.dart';
import '../../ui/pressable.dart';
import '../../ui/primary_button.dart';
import '../../ui/theme.dart';
import '../../ui/tokens.dart';
import 'cart_controller.dart';
import 'cash_sheet.dart' show PayColumnFrame;
import 'more_sheet.dart' show SheetHeader;

/// "Pfand zurück": die rechte Spalte mit einer Reihe je Pfand-Betrag
/// ([amounts], aufsteigend): Betrag, Minus, Anzahl (0 bis 99) und Plus.
/// Darunter "Zurück" mit der Summe und "Auf den Bon". Das Blatt öffnet mit
/// den Mengen, die schon am Bon stehen; "Auf den Bon" ist grau, solange die
/// Mengen gleich denen am Bon sind, und setzt sonst alle Reihen in einem
/// Schritt (0 nimmt die Zeile weg).
class DepositReturnSheet extends ConsumerStatefulWidget {
  const DepositReturnSheet({
    super.key,
    required this.amounts,
    required this.onClose,
  });

  /// Die Pfand-Beträge der Speisekarte in Cent.
  final List<int> amounts;
  final VoidCallback onClose;

  @override
  ConsumerState<DepositReturnSheet> createState() => _DepositReturnSheetState();
}

class _DepositReturnSheetState extends ConsumerState<DepositReturnSheet> {
  /// Je Betrag die Menge im Blatt.
  late final Map<int, int> _counts;

  /// Die Reihen: die Beträge der Karte und, was davon fehlt, die Beträge
  /// der Zeilen am Bon.
  late final List<int> _rows;

  /// Nach dem ersten Tipp auf "Auf den Bon": ein zweiter tut nichts.
  bool _done = false;

  @override
  void initState() {
    super.initState();
    final cart = ref.read(cartProvider);
    _rows = {
      ...widget.amounts,
      for (final l in cart.lines)
        if (l.isDepositReturn) -l.item.depositCents,
    }.toList()..sort();
    _counts = {for (final c in _rows) c: cart.depositReturnQuantity(c)};
  }

  void _step(int cents, int by) => setState(() {
    _counts[cents] = (_counts[cents]! + by).clamp(0, maxQuantity);
  });

  void _add() {
    if (_done) return;
    _done = true;
    ref.read(cartProvider.notifier).setDepositReturns(Map.of(_counts));
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final l = L10n.of(context);
    final cart = ref.watch(cartProvider);
    final changed = _rows.any(
      (cents) => _counts[cents] != cart.depositReturnQuantity(cents),
    );
    final total = _rows.fold(0, (s, cents) => s + cents * _counts[cents]!);
    return PayColumnFrame(
      child: Column(
        key: const Key('deposit-return-sheet'),
        children: [
          SheetHeader(
            title: l.kassaDepositReturn,
            backKey: const Key('deposit-return-back'),
            onBack: widget.onClose,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final cents in _rows)
                    _Row(
                      cents: cents,
                      count: _counts[cents]!,
                      onStep: (by) => _step(cents, by),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(KassaTokens.spaceXxl),
                  decoration: BoxDecoration(
                    color: c.accentSoft,
                    borderRadius: BorderRadius.circular(KassaTokens.radiusXxl),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          l.depositReturnTotal,
                          style: text.bodyLarge!.copyWith(color: c.accentInk),
                        ),
                      ),
                      const SizedBox(width: KassaTokens.spaceMd),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Ltr(
                            child: Text(
                              formatEuro(-total),
                              key: const Key('deposit-return-total'),
                              maxLines: 1,
                              style: KassaText.amount(context)
                                  .copyWith(color: c.ink),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: KassaTokens.spaceXl),
                PrimaryButton(
                  key: const Key('deposit-return-add'),
                  label: l.depositReturnAdd,
                  icon: LucideIcons.check,
                  height: KassaTokens.mainActionHeight,
                  onPressed: changed ? _add : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Eine Reihe: "0,25 €", Minus, Anzahl, Plus. Minus bei 0 und Plus bei 99
/// sind grau.
class _Row extends StatelessWidget {
  const _Row({required this.cents, required this.count, required this.onStep});

  final int cents;
  final int count;
  final ValueChanged<int> onStep;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final l = L10n.of(context);
    final amount = formatEuro(cents);
    final name = '${l.kassaDepositReturn} ${ltrIsolate(context, amount)}';
    return Container(
      constraints: const BoxConstraints(
        minHeight: KassaTokens.receiptLineMinHeight,
      ),
      padding: const EdgeInsets.symmetric(vertical: KassaTokens.spaceSm),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: c.line, width: KassaTokens.borderThin),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Ltr(
              child: Text(
                amount,
                key: Key('deposit-return-amount-$cents'),
                textAlign: ltrAlign(context, TextAlign.start),
                maxLines: 1,
                style: text.titleLarge!.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          const SizedBox(width: KassaTokens.spaceMd),
          _StepKey(
            key: Key('deposit-return-minus-$cents'),
            icon: LucideIcons.minus,
            label: l.kassaOneLess(name),
            onTap: count > 0 ? () => onStep(-1) : null,
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48),
            child: Ltr(
              child: Text(
                '$count',
                key: Key('deposit-return-count-$cents'),
                textAlign: TextAlign.center,
                maxLines: 1,
                style: text.titleLarge!.copyWith(
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          _StepKey(
            key: Key('deposit-return-plus-$cents'),
            icon: LucideIcons.plus,
            label: l.kassaOneMore(name),
            onTap: count < maxQuantity ? () => onStep(1) : null,
          ),
        ],
      ),
    );
  }
}

/// Plus oder Minus im Blatt: 56 dp, ohne [onTap] grau.
class _StepKey extends StatelessWidget {
  const _StepKey({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      minTapSize: const Size(KassaTokens.minTap, KassaTokens.minTap),
      child: Container(
        width: KassaTokens.keypadKeyHeight,
        height: KassaTokens.keypadKeyHeight,
        decoration: BoxDecoration(
          color: c.fill,
          borderRadius: BorderRadius.circular(KassaTokens.radiusXl),
        ),
        child: Icon(icon, size: 22, color: c.ink),
      ),
    );
  }
}
