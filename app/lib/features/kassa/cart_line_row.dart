import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/money.dart';
import '../../domain/cart.dart';
import '../../domain/discount.dart';
import '../../l10n/generated/l10n.dart';
import '../../ui/ltr.dart';
import '../../ui/menu_text.dart';
import '../../ui/pressable.dart';
import '../../ui/tokens.dart';

/// Eine Zeile des Bons: Name mit Zusatzzeile, Minus, Menge, Plus, Preis.
/// Steigt [flash], leuchtet die Zeile einmal auf. Die Namen stehen in der
/// Bediensprache und brechen um, statt gekürzt zu werden; der Bon selbst hält
/// die Namen der Speisekarte. Ein freier Betrag heißt "Diverses 20 %" in der
/// Bediensprache, eine Zeile "Pfand zurück" ebenso; sie zeigt das
/// zurückgegebene Pfand mit Minus ("−0,75 €"), und ihr Plus ist bei 99 grau.
/// Eine Gutschein-Zeile heißt "Gutschein" in der Bediensprache, zeigt den
/// Wert und hat kein Plus (Menge immer 1); Minus nimmt sie weg.
///
/// Hat die Zeile einen Rabatt, steht darunter eine kleine Reihe mit Höhe,
/// Grund und dem Betrag des Rabatts ([discountCents]). Mit [onDiscount] sind
/// Name, Preis und diese Reihe eine Tippfläche; ohne ist die Zeile genau die
/// von 1.10.0.
class CartLineRow extends ConsumerStatefulWidget {
  const CartLineRow({
    super.key,
    required this.line,
    required this.flash,
    required this.onQuantity,
    this.onDiscount,
    this.discountCents = 0,
    this.onRaiseDenied,
  });

  final CartLine line;
  final int flash;
  final ValueChanged<int> onQuantity;

  /// Bei einer Zeile "Pfand zurück", wenn die angemeldete Person sie nicht
  /// erhöhen darf ("Nur Chef"): das Plus ruft dies statt mehr zu zählen.
  /// Weniger geht immer.
  final VoidCallback? onRaiseDenied;

  /// Öffnet das Blatt "Rabatt" für diese Zeile; null: der Tipp auf Name und
  /// Preis tut nichts.
  final VoidCallback? onDiscount;

  /// Der eigene Rabatt der Zeile in Cent, für die Reihe darunter.
  final int discountCents;

  @override
  ConsumerState<CartLineRow> createState() => _CartLineRowState();
}

class _CartLineRowState extends ConsumerState<CartLineRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: KassaTokens.receiptLineFlash,
  );

  @override
  void initState() {
    super.initState();
    if (widget.flash > 0) _play();
  }

  @override
  void didUpdateWidget(CartLineRow old) {
    super.didUpdateWidget(old);
    if (widget.flash != old.flash) _play();
  }

  void _play() {
    // Bei "Animationen entfernen" gibt es kein Aufleuchten.
    final instant = WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations;
    if (instant) return;
    _glow.forward(from: 0);
  }

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final line = widget.line;
    final id = line.lineId;
    final instant = MediaQuery.disableAnimationsOf(context);
    final l = L10n.of(context);
    final menuText = ref.watch(menuTextProvider);
    final name = cartLineName(l, menuText, line);
    final info = line.isVoucherSale ? null : line.item.info;
    final sub = line.options.isNotEmpty
        ? line.options.map((o) => menuText(o.name)).join(l.uiListSeparator)
        : (info == null ? null : menuText(info));
    return AnimatedBuilder(
      animation: _glow,
      builder: (context, child) {
        final t = instant
            ? 1.0
            : KassaTokens.motionCurve.transform(_glow.value);
        // Läuft nichts, steht der Wert auf 0 oder 1: dann ohne Farbe.
        final glowing = !instant && _glow.isAnimating;
        return Container(
          decoration: BoxDecoration(
            color: glowing
                ? Color.lerp(c.accentSoft, c.accentSoft.withValues(alpha: 0), t)
                : null,
            border: Border(
              bottom: BorderSide(color: c.line, width: KassaTokens.borderThin),
            ),
          ),
          child: child,
        );
      },
      child: Container(
        constraints: const BoxConstraints(
          minHeight: KassaTokens.receiptLineMinHeight,
        ),
        padding: const EdgeInsetsDirectional.fromSTEB(16, 6, 14, 6),
        child: _withDiscountRow(
          context,
          Row(
            children: [
              Expanded(
                child: _discountTarget(
                  AlignmentDirectional.centerStart,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: text.bodyLarge!.copyWith(height: 1.15)),
                      if (sub != null && sub.isNotEmpty) ...[
                        const SizedBox(height: KassaTokens.spaceXxs),
                        Text(
                          sub,
                          style: text.bodySmall!.copyWith(
                            fontWeight: FontWeight.w400,
                            height: 1.2,
                            color: c.ink2,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: KassaTokens.spaceSm),
              _StepButton(
                key: Key('qty-minus-$id'),
                icon: LucideIcons.minus,
                label: l.kassaOneLess(name),
                onTap: () => widget.onQuantity(line.quantity - 1),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 24),
                child: Text(
                  '${line.quantity}',
                  key: Key('qty-$id'),
                  textAlign: TextAlign.center,
                  style: text.bodyLarge!.copyWith(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (line.isVoucherSale)
                // Kein Plus: jeder Gutschein ist eine eigene Zeile. Der Platz
                // bleibt, damit die Preise untereinander stehen.
                const SizedBox(width: KassaTokens.minTap)
              else
                _StepButton(
                  key: Key('qty-plus-$id'),
                  icon: LucideIcons.plus,
                  label: l.kassaOneMore(name),
                  onTap: line.isDepositReturn && line.quantity >= maxQuantity
                      ? null
                      : line.isDepositReturn && widget.onRaiseDenied != null
                      ? widget.onRaiseDenied
                      : () => widget.onQuantity(line.quantity + 1),
                ),
              const SizedBox(width: KassaTokens.spaceSm),
              _discountTarget(
                AlignmentDirectional.centerEnd,
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 62),
                  child: Ltr(
                    child: Text(
                      formatEuro(
                        line.isDepositReturn
                            ? line.depositCents
                            : line.goodsCents,
                      ),
                      textAlign: ltrAlign(context, TextAlign.end),
                      maxLines: 1,
                      style: text.bodyLarge!.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Name oder Preis: mit [CartLineRow.onDiscount] eine Tippfläche von
  /// mindestens 48 dp Höhe, sonst unverändert.
  Widget _discountTarget(AlignmentGeometry alignment, Widget child) {
    final onDiscount = widget.onDiscount;
    if (onDiscount == null) return child;
    return Pressable(
      onTap: onDiscount,
      child: Container(
        constraints: const BoxConstraints(minHeight: KassaTokens.minTap),
        alignment: alignment,
        child: child,
      ),
    );
  }

  /// Ohne Rabatt bleibt [row] allein; mit Rabatt steht die Reihe darunter.
  Widget _withDiscountRow(BuildContext context, Widget row) {
    final discount = widget.line.discount;
    if (discount == null) return row;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        row,
        DiscountRow(
          key: Key('line-discount-${widget.line.lineId}'),
          discount: discount,
          cents: widget.discountCents,
          onTap: widget.onDiscount,
        ),
      ],
    );
  }
}

/// Eine kleine Reihe für einen gesetzten Rabatt: links "−10 % Stammgast"
/// oder "Rabatt Stammgast", rechts der Betrag mit Minus. Mit [onTap] eine
/// Tippfläche von mindestens 48 dp, sonst nur Text.
class DiscountRow extends StatelessWidget {
  const DiscountRow({
    super.key,
    required this.discount,
    required this.cents,
    this.onTap,
  });

  final Discount discount;
  final int cents;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final style = text.bodySmall!.copyWith(
      fontWeight: FontWeight.w600,
      color: c.accentInk,
    );
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(child: Text(discountLabel(context, discount), style: style)),
        const SizedBox(width: KassaTokens.spaceMd),
        Ltr(
          child: Text(
            '\u2212${formatEuro(cents)}',
            maxLines: 1,
            style: style.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
    final tap = onTap;
    if (tap == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: KassaTokens.spaceXs),
        child: row,
      );
    }
    return Pressable(
      onTap: tap,
      child: Container(
        constraints: const BoxConstraints(minHeight: KassaTokens.minTap),
        alignment: AlignmentDirectional.centerStart,
        child: row,
      ),
    );
  }
}

/// Der Name einer Bon-Zeile am Bildschirm, in der Bediensprache: ein freier
/// Betrag heißt [L10n.openAmountLine] ("Diverses 20 %"), eine Zeile "Pfand
/// zurück" [L10n.kassaDepositReturn], eine Gutschein-Zeile [L10n.kassaVoucher],
/// sonst der Name aus der Speisekarte über [menuText].
String cartLineName(
  L10n l,
  String Function(String source) menuText,
  CartLine line,
) => line.isOpenAmount
    ? l.openAmountLine(line.item.taxRate.percent)
    : line.isDepositReturn
    ? l.kassaDepositReturn
    : line.isVoucherSale
    ? l.kassaVoucher
    : menuText(line.item.name);

/// "−10 % Stammgast" oder "Rabatt Stammgast", in der Bediensprache.
String discountLabel(BuildContext context, Discount discount) {
  final l = L10n.of(context);
  final reason = discountReasonText(l, discount.reason);
  final percent = discount.percent;
  return percent != null
      ? l.discountRowPercent(percent, reason)
      : l.discountRowAmount(reason);
}

/// Der Grund eines Rabatts in der Bediensprache.
String discountReasonText(L10n l, DiscountReason reason) => switch (reason) {
  DiscountReason.regular => l.discountReasonRegular,
  DiscountReason.staff => l.discountReasonStaff,
  DiscountReason.complaint => l.discountReasonComplaint,
  DiscountReason.promotion => l.discountReasonPromotion,
  DiscountReason.invitation => l.discountReasonInvitation,
};

/// Plus und Minus: 44 dp gezeichnet, 48 dp Antippfläche; ohne [onTap] grau.
class _StepButton extends StatelessWidget {
  const _StepButton({
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
        width: KassaTokens.drawnControlHeight,
        height: KassaTokens.drawnControlHeight,
        decoration: BoxDecoration(
          color: c.fill,
          borderRadius: BorderRadius.circular(KassaTokens.radiusLg),
        ),
        child: Icon(icon, size: 18, color: c.ink),
      ),
    );
  }
}
