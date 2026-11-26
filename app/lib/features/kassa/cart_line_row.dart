import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/money.dart';
import '../../domain/cart.dart';
import '../../l10n/generated/l10n.dart';
import '../../ui/menu_text.dart';
import '../../ui/pressable.dart';
import '../../ui/tokens.dart';

/// Eine Zeile des Bons: Name mit Zusatzzeile, Minus, Menge, Plus, Preis.
/// Steigt [flash], leuchtet die Zeile einmal auf. Die Namen stehen in der
/// Bediensprache und brechen um, statt gekürzt zu werden; der Bon selbst hält
/// die Namen der Speisekarte.
class CartLineRow extends ConsumerStatefulWidget {
  const CartLineRow({
    super.key,
    required this.line,
    required this.flash,
    required this.onQuantity,
  });

  final CartLine line;
  final int flash;
  final ValueChanged<int> onQuantity;

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
    final name = menuText(line.item.name);
    final info = line.item.info;
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
        padding: const EdgeInsets.fromLTRB(16, 6, 14, 6),
        child: Row(
          children: [
            Expanded(
              child: Column(
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
            _StepButton(
              key: Key('qty-plus-$id'),
              icon: LucideIcons.plus,
              label: l.kassaOneMore(name),
              onTap: () => widget.onQuantity(line.quantity + 1),
            ),
            const SizedBox(width: KassaTokens.spaceSm),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 62),
              child: Text(
                formatEuro(line.goodsCents),
                textAlign: TextAlign.right,
                maxLines: 1,
                style: text.bodyLarge!.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Plus und Minus: 44 dp gezeichnet, 48 dp Antippfläche.
class _StepButton extends StatelessWidget {
  const _StepButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

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
