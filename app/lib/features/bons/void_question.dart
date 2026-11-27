import 'package:material_ui/material_ui.dart';

import '../../core/money.dart';
import '../../domain/receipt.dart';
import '../../domain/voucher.dart' show formatVoucherCode;
import '../../l10n/generated/l10n.dart';
import '../../ui/ltr.dart';
import '../../ui/pressable.dart';
import '../../ui/tokens.dart';

/// Warum ein Storno nicht geklappt hat.
enum VoidFailure {
  /// Nicht gespeichert.
  failed,

  /// Der Bon gehört nicht zur laufenden Kette der Signatur (in der Probe).
  olderThanProbe,

  /// Der Bon gehört nicht zur laufenden Kette, und die Kassa ist in Betrieb.
  fromTestTime,

  /// Auf dem Bon wurde ein Gutschein verkauft, der schon eingelöst ist.
  voucherRedeemed;

  String text(L10n l) => switch (this) {
    VoidFailure.failed => l.bonsVoidFailed,
    VoidFailure.olderThanProbe => l.bonsVoidOlderThanProbe,
    VoidFailure.fromTestTime => l.bonsVoidFromTestTime,
    VoidFailure.voucherRedeemed => l.bonsVoidVoucherRedeemed,
  };
}

/// Die Rückfrage vor dem Storno: rote Fläche mit zwei Knöpfen. [failure] sagt,
/// warum der letzte Versuch nicht geklappt hat. Ein Bon mit nur einer
/// Bar-Zahlung oder nur einer Kartenzahlung ohne Trinkgeld zeigt die Texte von
/// 1.10.0. Sonst nennt die Frage in dieser Reihenfolge, was davon zutrifft:
/// den Bar-Teil zum Zurückgeben (oder bei einer Auszahlung, was bar
/// hereinkommt), was jeder Gutschein zurückbekommt, den Betrag, der bei SumUp
/// zurückzubuchen ist (mit Trinkgeld), und jeden verkauften Gutschein, der
/// danach nicht mehr gilt.
class VoidQuestion extends StatelessWidget {
  const VoidQuestion({
    super.key,
    required this.receipt,
    required this.busy,
    required this.failure,
    required this.onCancel,
    required this.onConfirm,
  });

  final Receipt receipt;
  final bool busy;
  final VoidFailure? failure;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final l = L10n.of(context);
    final card = receipt.cardPayment;
    final byCard = card != null;
    final vouchers = [
      for (final p in receipt.payments)
        if (p.kind == PaymentKind.voucher) p,
    ];
    final cashCents = receipt.cashCents;
    // Nur bar (oder gar keine Zahlung) und nicht unter 0: der Text von
    // 1.10.0 mit dem Bar-Betrag.
    final onlyCash = !byCard && vouchers.isEmpty && cashCents >= 0;
    final onlyCashCents = receipt.cashPayment == null
        ? receipt.totalCents
        : cashCents;
    // Bar-Teil, Gutschein oder Trinkgeld: die Frage nennt die Beträge
    // einzeln.
    final detailed =
        card != null &&
        (cashCents != 0 || card.tipCents > 0 || vouchers.isNotEmpty);
    final cardHint = switch (card) {
      null => '',
      _ when !detailed => l.bonsVoidCardHint,
      Payment(tipCents: > 0) => l.bonsVoidCardBackTip(
        ltrIsolate(context, formatEuro(card.chargedCents)),
        ltrIsolate(context, formatEuro(card.tipCents)),
      ),
      _ => l.bonsVoidCardBack(
        ltrIsolate(context, formatEuro(card.chargedCents)),
      ),
    };
    final cashStyle = text.bodyMedium!.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: c.spicyFg,
    );
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
            l.bonsVoidQuestion(receipt.number),
            style: text.titleLarge!.copyWith(fontSize: 17, color: c.spicyFg),
          ),
          const SizedBox(height: KassaTokens.spaceXxs),
          if (onlyCash)
            Text(
              l.bonsVoidCashBack(
                ltrIsolate(context, formatEuro(onlyCashCents)),
              ),
              style: cashStyle,
            )
          else if (cashCents > 0)
            Text(
              l.bonsVoidMixedCash(ltrIsolate(context, formatEuro(cashCents))),
              key: const Key('void-cash-back'),
              style: cashStyle,
            )
          else if (cashCents < 0)
            Text(
              l.bonsVoidCashIn(ltrIsolate(context, formatEuro(-cashCents))),
              key: const Key('void-cash-in'),
              style: cashStyle,
            ),
          for (final (i, p) in vouchers.indexed)
            Text(
              l.bonsVoidVoucherBack(
                ltrIsolate(context, formatVoucherCode(p.voucherCode ?? '')),
                ltrIsolate(context, formatEuro(p.amountCents)),
              ),
              key: Key('void-voucher-back-$i'),
              style: cashStyle,
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
                cardHint,
                style: text.bodyMedium!.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                  color: c.warnInk,
                ),
              ),
            ),
          ],
          for (final (i, v) in receipt.soldVouchers.indexed) ...[
            const SizedBox(height: KassaTokens.spaceXxs),
            Text(
              l.bonsVoidVoucherSold(
                ltrIsolate(context, formatVoucherCode(v.code)),
              ),
              key: Key('void-voucher-sold-$i'),
              style: cashStyle,
            ),
          ],
          if (failure case final failure?) ...[
            const SizedBox(height: KassaTokens.spaceSm),
            Text(
              failure.text(l),
              key: const Key('void-failure'),
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
              label: l.bonsVoidConfirmCard,
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
              label: l.kassaCancel,
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
                    label: l.kassaCancel,
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
                    label: l.bonsVoidConfirm,
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
