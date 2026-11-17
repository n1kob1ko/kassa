import 'package:material_ui/material_ui.dart';

import '../../core/money.dart';
import '../../domain/receipt.dart';
import '../../ui/pressable.dart';
import '../../ui/tokens.dart';

const _failText =
    'Der Storno konnte nicht gespeichert werden. Bitte noch einmal.';

/// Die Rückfrage vor dem Storno: rote Fläche mit zwei Knöpfen.
class VoidQuestion extends StatelessWidget {
  const VoidQuestion({
    super.key,
    required this.receipt,
    required this.busy,
    required this.failed,
    required this.onCancel,
    required this.onConfirm,
  });

  final Receipt receipt;
  final bool busy;
  final bool failed;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final amount = formatEuro(receipt.totalCents);
    final hint = receipt.payment.kind == PaymentKind.cash
        ? 'Du gibst $amount bar zurück.'
        : '$amount gehen zurück auf die Karte.';
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.spicyBg,
        borderRadius: BorderRadius.circular(KassaTokens.radiusXxl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Bon Nr. ${receipt.number} wirklich stornieren?',
            style: text.titleLarge!.copyWith(fontSize: 17, color: c.spicyFg),
          ),
          const SizedBox(height: KassaTokens.spaceXxs),
          Text(
            hint,
            style: text.bodyMedium!.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: c.spicyFg,
            ),
          ),
          if (failed) ...[
            const SizedBox(height: KassaTokens.spaceSm),
            Text(
              _failText,
              style: text.bodyMedium!.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: c.spicyFg,
              ),
            ),
          ],
          const SizedBox(height: KassaTokens.spaceXl),
          Row(
            children: [
              Expanded(
                child: BonsActionButton(
                  key: const Key('cancel-void'),
                  label: 'Abbrechen',
                  height: 60,
                  radius: KassaTokens.radiusXl,
                  bg: c.card,
                  fg: c.ink,
                  onTap: busy ? null : onCancel,
                ),
              ),
              const SizedBox(width: KassaTokens.spaceLg),
              Expanded(
                child: BonsActionButton(
                  key: const Key('confirm-void'),
                  label: 'Ja, stornieren',
                  height: 60,
                  radius: KassaTokens.radiusXl,
                  bg: c.red,
                  fg: c.card,
                  bold: true,
                  onTap: busy ? null : onConfirm,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Knopf der Bons-Spalte (DESIGN.md, "Bons-Knöpfe" und "Rückfrage Stornieren").
class BonsActionButton extends StatelessWidget {
  const BonsActionButton({
    super.key,
    required this.label,
    required this.height,
    required this.radius,
    required this.fg,
    required this.onTap,
    this.bg,
    this.border,
    this.bold = false,
  });

  final String label;
  final double height;
  final double radius;
  final Color fg;
  final Color? bg;
  final Color? border;
  final bool bold;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        height: height,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: KassaTokens.spaceMd),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(radius),
          border: border == null
              ? null
              : Border.all(color: border!, width: KassaTokens.borderButton),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium!.copyWith(
            fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
            color: fg,
          ),
        ),
      ),
    );
  }
}
