import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/money.dart';
import '../../devices/card_terminal.dart';
import '../../devices/device_providers.dart';
import '../../domain/cart.dart';
import '../../domain/pricing.dart';
import '../../l10n/generated/l10n.dart';
import '../../ui/pressable.dart';
import '../../ui/primary_button.dart';
import '../../ui/theme.dart';
import '../../ui/tokens.dart';
import '../../ui/undo_toast.dart';
import 'cart_controller.dart';
import 'cart_line_row.dart';

/// Die Bon-Spalte, 392 dp breit: Kopf, Zeilen, Summenblock, Bar und Karte.
/// [canPay] ist `false`, solange etwas zusammengestellt wird. "Karte" ist nur
/// aktiv, wenn das Terminal angemeldet ist, Internet da ist und die Summe
/// mindestens den Kleinstbetrag des Terminals erreicht; sonst nennt eine Zeile
/// unter dem Wort den ersten Grund. [notice] steht über dem Kopf (der
/// Hinweis zum Ausfall der Signatur).
class CartPanel extends ConsumerStatefulWidget {
  const CartPanel({
    super.key,
    required this.onPayCash,
    required this.onPayCard,
    this.canPay = true,
    this.notice,
  });

  final VoidCallback onPayCash;
  final VoidCallback onPayCard;
  final bool canPay;
  final Widget? notice;

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

  void _payCard() {
    _dismissToast();
    widget.onPayCard();
  }

  void _clear() {
    final controller = ref.read(cartProvider.notifier);
    final before = ref.read(cartProvider);
    if (before.isEmpty) return;
    controller.clear();
    _clearedCart = ref.read(cartProvider);
    _closeToast = showUndoToast(
      context,
      message: L10n.of(context).kassaCartCleared,
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
    final l = L10n.of(context);
    final card = _cardAvailability(l, cart);
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
          ?widget.notice,
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
            padding: EdgeInsets.fromLTRB(
              12,
              0,
              12,
              12 + MediaQuery.paddingOf(context).bottom,
            ),
            child: Row(
              children: [
                Expanded(
                  child: PrimaryButton(
                    key: const Key('pay-cash'),
                    label: l.kassaCash,
                    icon: LucideIcons.banknote,
                    labelSize: 22,
                    height: KassaTokens.mainActionHeight,
                    onPressed: cart.isEmpty || !widget.canPay ? null : _pay,
                  ),
                ),
                const SizedBox(width: KassaTokens.spaceLg),
                Expanded(
                  child: PrimaryButton(
                    key: const Key('pay-card'),
                    label: l.kassaCard,
                    sublabel: card.reason,
                    icon: LucideIcons.creditCard,
                    solid: true,
                    // Ausgeschaltet ohne Abdunkeln, damit die Zeile lesbar
                    // bleibt.
                    muted: !card.enabled || !widget.canPay,
                    labelSize: 22,
                    height: KassaTokens.mainActionHeight,
                    onPressed: card.enabled && widget.canPay ? _payCard : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  ({bool enabled, String? reason}) _cardAvailability(L10n l, Cart cart) {
    if (cart.isEmpty) return (enabled: false, reason: null);
    final status = ref.watch(cardStatusProvider).value;
    // Solange der Stand noch nicht da ist, bleibt die Taste still aus.
    if (status == null) return (enabled: false, reason: null);
    final minimum = ref.read(cardTerminalProvider).minimumCents;
    final online = ref.watch(internetProvider).value ?? true;
    return switch (status.state) {
      CardTerminalState.notConfigured => (
        enabled: false,
        reason: l.kassaCardNotSetUp,
      ),
      CardTerminalState.loggedOut => (
        enabled: false,
        reason: l.kassaCardLoggedOut,
      ),
      CardTerminalState.ready when !online => (
        enabled: false,
        reason: l.kassaCardNoInternet,
      ),
      CardTerminalState.ready when cart.totalCents < minimum => (
        enabled: false,
        reason: l.kassaCardFrom(formatEuro(minimum)),
      ),
      CardTerminalState.ready => (enabled: true, reason: null),
    };
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
    final l = L10n.of(context);
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
                  Text(l.kassaReceipt, style: text.headlineMedium),
                  const SizedBox(width: KassaTokens.spaceLg),
                  Flexible(
                    child: Text(
                      l.kassaItemCount(count),
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
                  l.kassaClearCart,
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
    final l = L10n.of(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.kassaEmptyTitle, style: text.titleLarge),
          const SizedBox(height: KassaTokens.spaceMd),
          Text(
            l.kassaEmptyHint,
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
    final l = L10n.of(context);
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
              Text(l.kassaTotal, style: text.bodyLarge),
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
                    l.kassaDepositIncluded(formatEuro(cart.depositCents)),
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
                  l.kassaTaxIncluded(formatEuro(taxCents)),
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
