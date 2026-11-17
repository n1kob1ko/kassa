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
import 'cart_line_row.dart';

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

  /// Schließt den Hinweis "Bon geleert", solange er offen ist.
  VoidCallback? _closeToast;

  /// Der leere Bon, auf den sich der Hinweis bezieht. Jede andere Änderung
  /// des Bons schließt ihn.
  Cart? _clearedCart;

  void _dismissToast() {
    _closeToast?.call();
    _closeToast = null;
    _clearedCart = null;
  }

  void _pay() {
    _dismissToast();
    widget.onPayCash();
  }

  void _clear() {
    final controller = ref.read(cartProvider.notifier);
    final before = ref.read(cartProvider);
    if (before.isEmpty) return;
    controller.clear();
    _clearedCart = ref.read(cartProvider);
    _closeToast = showUndoToast(
      context,
      message: 'Bon geleert',
      onUndo: () {
        _closeToast = null;
        _clearedCart = null;
        controller.restore(before);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final cart = ref.watch(cartProvider);
    ref.listen(cartProvider, (prev, next) {
      if (_clearedCart != null && !identical(next, _clearedCart)) {
        _dismissToast();
      }
      final old = {
        for (final l in prev?.lines ?? const <CartLine>[]) l.lineId: l,
      };
      for (final l in next.lines) {
        final was = old[l.lineId];
        if (was == null || l.quantity > was.quantity) {
          _flash[l.lineId] = (_flash[l.lineId] ?? 0) + 1;
        }
      }
    });
    final controller = ref.read(cartProvider.notifier);
    final count = cart.lines.fold<int>(0, (sum, l) => sum + l.quantity);
    final tax = taxBreakdown(grossByRate(cart))
        .fold<int>(0, (s, t) => s + t.taxCents);
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
                        return CartLineRow(
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
                        : _pay,
                  ),
                ),
                const SizedBox(width: KassaTokens.spaceLg),
                const Expanded(
                  child: PrimaryButton(
                    key: Key('pay-card'),
                    label: 'Karte',
                    sublabel: 'kommt später',
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (cart.depositCents != 0)
                Flexible(
                  child: Text(
                    'davon Pfand ${formatEuro(cart.depositCents)}',
                    key: const Key('cart-deposit'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: small,
                  ),
                )
              else
                const SizedBox.shrink(),
              const SizedBox(width: KassaTokens.spaceXl),
              Flexible(
                child: Text(
                  'inkl. ${formatEuro(taxCents)} MwSt',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: small,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
