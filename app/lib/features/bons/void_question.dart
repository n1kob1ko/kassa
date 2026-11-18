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
    final byCard = receipt.payment.kind == PaymentKind.card;
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
          if (!byCard)
            Text(
              'Du gibst $amount bar zurück.',
              style: text.bodyMedium!.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: c.spicyFg,
              ),
            ),
          if (byCard) ...[
            const SizedBox(height: KassaTokens.spaceSm),
            Container(
              key: const Key('void-card-hint'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.warnBg,
                borderRadius: BorderRadius.circular(KassaTokens.radiusXl),
              ),
              child: Text(
                'Das Geld geht nicht von selbst zurück. Bitte die Zahlung in '
                'der SumUp-App rückbuchen.',
                style: text.bodyMedium!.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                  color: c.warnInk,
                ),
              ),
            ),
          ],
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
          if (byCard) ...[
            BonsActionButton(
              key: const Key('confirm-void'),
              label: 'Stornieren, Rückbuchung mache ich in SumUp',
              height: 76,
              maxLines: 2,
              radius: KassaTokens.radiusXl,
              bg: c.red,
              fg: c.card,
              bold: true,
              onTap: busy ? null : onConfirm,
            ),
            const SizedBox(height: KassaTokens.spaceLg),
            BonsActionButton(
              key: const Key('cancel-void'),
              label: 'Abbrechen',
              height: 60,
              radius: KassaTokens.radiusXl,
              bg: c.card,
              fg: c.ink,
              onTap: busy ? null : onCancel,
            ),
          ] else
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
    this.maxLines = 1,
  });

  final String label;
  final double height;
  final double radius;
  final Color fg;
  final Color? bg;
  final Color? border;
  final bool bold;
  final int maxLines;
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
          maxLines: maxLines,
          textAlign: TextAlign.center,
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
