import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/money.dart';
import '../../domain/cart.dart';
import '../../domain/pricing.dart';
import '../../ui/pressable.dart';
import '../../ui/primary_button.dart';
import '../../ui/theme.dart';
import '../../ui/tokens.dart';
import '../../ui/undo_toast.dart';
import 'cart_controller.dart';

/// Die Bon-Spalte, 392 dp breit: Kopf, Zeilen, Summenblock, Bar und Karte.
/// [canPay] ist `false`, solange etwas zusammengestellt wird.
class CartPanel extends ConsumerStatefulWidget {
  const CartPanel({super.key, required this.onPayCash, this.canPay = true});

  final VoidCallback onPayCash;
  final bool canPay;

  @override
  ConsumerState<CartPanel> createState() => _CartPanelState();
}

class _CartPanelState extends ConsumerState<CartPanel> {
  /// Je Zeile ein Zähler: steigt er, leuchtet die Zeile einmal auf.
  final Map<String, int> _flash = {};

  void _clear() {
    final controller = ref.read(cartProvider.notifier);
    final before = ref.read(cartProvider);
    if (before.isEmpty) return;
    controller.clear();
    showUndoToast(
      context,
      message: 'Bon geleert',
      onUndo: () => controller.restore(before),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final cart = ref.watch(cartProvider);
    ref.listen(cartProvider, (prev, next) {
      final old = {for (final l in prev?.lines ?? const <CartLine>[]) l.lineId: l};
      for (final l in next.lines) {
        final was = old[l.lineId];
        if (was == null || l.quantity > was.quantity) {
          _flash[l.lineId] = (_flash[l.lineId] ?? 0) + 1;
        }
      }
    });
    final controller = ref.read(cartProvider.notifier);
    final count = cart.lines.fold<int>(0, (sum, l) => sum + l.quantity);
    final tax = taxBreakdown(grossByRate(cart)).fold<int>(0, (s, t) => s + t.taxCents);
    return Container(
      width: KassaTokens.receiptColumnWidth,
      decoration: BoxDecoration(
        color: c.card,
        border: Border(
          left: BorderSide(color: c.line, width: KassaTokens.borderThin),
        ),
      ),
      child: Column(
        children: [
          _Header(count: count, empty: cart.isEmpty, onClear: _clear),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: c.line, width: KassaTokens.borderThin),
                ),
              ),
              child: cart.isEmpty
                  ? const _EmptyState()
                  : ListView.builder(
                      key: const Key('cart-lines'),
                      itemCount: cart.lines.length,
                      itemBuilder: (context, i) {
                        final line = cart.lines[i];
                        return _LineRow(
                          key: Key('line-${line.lineId}'),
                          line: line,
                          flash: _flash[line.lineId] ?? 0,
                          onQuantity: (q) =>
                              controller.setQuantity(line.lineId, q),
                        );
                      },
                    ),
            ),
          ),
          _Totals(cart: cart, taxCents: tax),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: PrimaryButton(
                    key: const Key('pay-cash'),
                    label: 'Bar',
                    icon: LucideIcons.banknote,
                    labelSize: 22,
                    height: KassaTokens.mainActionHeight,
                    onPressed: cart.isEmpty || !widget.canPay
                        ? null
                        : widget.onPayCash,
                  ),
                ),
                const SizedBox(width: KassaTokens.spaceLg),
                const Expanded(
                  child: PrimaryButton(
                    key: Key('pay-card'),
                    label: 'Karte',
                    sublabel: 'kommt mit Schritt 3',
                    icon: LucideIcons.creditCard,
                    solid: true,
                    labelSize: 22,
                    height: KassaTokens.mainActionHeight,
                    onPressed: null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.count,
    required this.empty,
    required this.onClear,
  });

  final int count;
  final bool empty;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    return SizedBox(
      height: KassaTokens.receiptHeaderHeight,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
        child: Row(
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('Bon', style: text.headlineMedium),
                  const SizedBox(width: KassaTokens.spaceLg),
                  Flexible(
                    child: Text(
                      '$count Artikel',
                      key: const Key('cart-count'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall!.copyWith(
                        fontSize: 14,
                        color: c.ink2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Pressable(
              key: const Key('clear-cart'),
              onTap: empty ? null : onClear,
              minTapSize: const Size(0, KassaTokens.minTap),
              child: Container(
                height: KassaTokens.minTap,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                child: Text(
                  'Bon leeren',
                  style: text.labelLarge!.copyWith(color: c.red),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Noch nichts boniert', style: text.titleLarge),
          const SizedBox(height: KassaTokens.spaceMd),
          Text(
            'Tippe links auf einen Artikel. Jeder Tipp legt ihn einmal auf den Bon.',
            style: text.bodyMedium!.copyWith(
              fontWeight: FontWeight.w400,
              height: 1.4,
              color: c.ink2,
            ),
          ),
        ],
      ),
    );
  }
}

class _LineRow extends StatefulWidget {
  const _LineRow({
    super.key,
    required this.line,
    required this.flash,
    required this.onQuantity,
  });

  final CartLine line;
  final int flash;
  final ValueChanged<int> onQuantity;

  @override
  State<_LineRow> createState() => _LineRowState();
}

class _LineRowState extends State<_LineRow>
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
  void didUpdateWidget(_LineRow old) {
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
    final sub = line.options.isNotEmpty
        ? line.options.map((o) => o.name).join(', ')
        : line.item.info;
    return AnimatedBuilder(
      animation: _glow,
      builder: (context, child) {
        final t = instant ? 1.0 : KassaTokens.motionCurve.transform(_glow.value);
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
                  Text(
                    line.item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyLarge!.copyWith(height: 1.15),
                  ),
                  if (sub != null && sub.isNotEmpty) ...[
                    const SizedBox(height: KassaTokens.spaceXxs),
                    Text(
                      sub,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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
              label: 'Eins weniger: ${line.item.name}',
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
              label: 'Eins mehr: ${line.item.name}',
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

class _Totals extends StatelessWidget {
  const _Totals({required this.cart, required this.taxCents});

  final Cart cart;
  final int taxCents;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final small = text.bodySmall!.copyWith(
      fontWeight: FontWeight.w400,
      color: c.ink2,
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: c.line, width: KassaTokens.borderThin),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (cart.depositCents != 0)
            Padding(
              padding: const EdgeInsets.only(bottom: KassaTokens.spaceSm),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Pfand', style: small.copyWith(fontSize: 14)),
                  Text(
                    formatEuro(cart.depositCents),
                    style: small.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Summe', style: text.bodyLarge),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    formatEuro(cart.totalCents),
                    key: const Key('cart-total'),
                    maxLines: 1,
                    style: KassaText.amount(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: KassaTokens.spaceXs),
          Align(
            alignment: Alignment.centerRight,
            child: Text('inkl. ${formatEuro(taxCents)} MwSt', style: small),
          ),
        ],
      ),
    );
  }
}
