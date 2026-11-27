import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/money.dart';
import '../../domain/cart.dart';
import '../../domain/pricing.dart';
import '../../l10n/generated/l10n.dart';
import '../../ui/ltr.dart';
import '../../ui/pressable.dart';
import '../../ui/primary_button.dart';
import '../../ui/theme.dart';
import '../../ui/tokens.dart';
import '../../ui/undo_toast.dart';
import 'card_availability.dart';
import 'cart_controller.dart';
import 'cart_line_row.dart';

/// Die Bon-Spalte, 392 dp breit: Kopf, Zeilen, Summenblock, Bar und Karte.
/// [canPay] ist `false`, solange etwas zusammengestellt wird. "Karte" ist nur
/// aktiv, wenn das Terminal angemeldet ist, Internet da ist und die Summe
/// mindestens den Kleinstbetrag des Terminals erreicht; sonst nennt eine Zeile
/// unter dem Wort den ersten Grund. [notice] steht über dem Kopf (der
/// Hinweis zum Ausfall der Signatur), [payNotice] über dem Summenblock (der
/// Hinweis nach einer gescheiterten Karte mit Bar-Teil).
///
/// Ein gesetzter Rabatt steht immer da: unter seiner Zeile und im
/// Summenblock. Mit [onLineDiscount] öffnet ein Tipp auf Name, Preis oder
/// Rabatt einer Zeile das Blatt "Rabatt", mit [onReceiptDiscount] steht im
/// Summenblock die Taste "Rabatt". Ist die Summe 0,00 € und der Bon hat einen
/// Rabatt oder "Pfand zurück", steht mit [onFinishFree] statt "Bar" und
/// "Karte" "Abschließen". Liegt die Summe unter 0 (Pfand zurück), steht mit
/// [onPayOut] dort nur "Bar auszahlen" mit dem Betrag.
///
/// Im Kopf steht höchstens eine Taste, auch am leeren Bon: mit
/// [onOpenAmount] "Freier Betrag", mit [onDepositReturn] "Pfand zurück",
/// mit [onVoucher] "Gutschein", mit [onMore] "Mehr" (die Kassa setzt genau
/// eine davon). Ohne alle vier ist der Kopf genau der von 1.10.0. Eine Zeile
/// "Pfand zurück" ist keine Tippfläche für den Rabatt; ihre Menge geht über
/// "Pfand zurück". Eine Gutschein-Zeile auch nicht.
class CartPanel extends ConsumerStatefulWidget {
  const CartPanel({
    super.key,
    required this.onPayCash,
    required this.onPayCard,
    this.canPay = true,
    this.notice,
    this.payNotice,
    this.onLineDiscount,
    this.onReceiptDiscount,
    this.onFinishFree,
    this.onOpenAmount,
    this.onDepositReturn,
    this.onVoucher,
    this.onMore,
    this.onPayOut,
  });

  final VoidCallback onPayCash;
  final VoidCallback onPayCard;
  final bool canPay;
  final Widget? notice;
  final Widget? payNotice;

  /// Rabatt für die Zeile mit dieser Kennung; null: keine Tippfläche.
  final ValueChanged<String>? onLineDiscount;

  /// Rabatt auf den ganzen Bon; null: keine Taste "Rabatt".
  final VoidCallback? onReceiptDiscount;

  /// "Abschließen" bei Summe 0,00 € mit Rabatt.
  final VoidCallback? onFinishFree;

  /// Öffnet das Blatt "Freier Betrag"; null: keine Taste im Kopf.
  final VoidCallback? onOpenAmount;

  /// Öffnet das Blatt "Pfand zurück"; null: keine Taste im Kopf.
  final VoidCallback? onDepositReturn;

  /// Öffnet das Blatt "Gutschein"; null: keine Taste im Kopf.
  final VoidCallback? onVoucher;

  /// Öffnet das Blatt "Mehr"; null: keine Taste im Kopf.
  final VoidCallback? onMore;

  /// "Bar auszahlen" bei einer Summe unter 0.
  final VoidCallback? onPayOut;

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

  void _finishFree() {
    _dismissToast();
    widget.onFinishFree?.call();
  }

  void _payOut() {
    _dismissToast();
    widget.onPayOut?.call();
  }

  /// Die Taste im Kopf: "Freier Betrag", "Pfand zurück", "Gutschein" oder
  /// "Mehr"; null: keine.
  _HeadAction? _headAction(L10n l) {
    VoidCallback tap(VoidCallback f) => () {
      _dismissToast();
      f();
    };
    if (widget.onMore case final f?) {
      return (
        key: const Key('more-button'),
        label: l.kassaMore,
        icon: LucideIcons.ellipsis,
        onTap: tap(f),
        halfAtMost: false,
      );
    }
    if (widget.onDepositReturn case final f?) {
      return (
        key: const Key('deposit-return-button'),
        label: l.kassaDepositReturn,
        icon: LucideIcons.undo2,
        onTap: tap(f),
        halfAtMost: false,
      );
    }
    if (widget.onVoucher case final f?) {
      return (
        key: const Key('voucher-button'),
        label: l.kassaVoucher,
        icon: LucideIcons.gift,
        onTap: tap(f),
        halfAtMost: false,
      );
    }
    if (widget.onOpenAmount case final f?) {
      return (
        key: const Key('open-amount-button'),
        label: l.openAmountTitle,
        icon: LucideIcons.plus,
        onTap: tap(f),
        halfAtMost: true,
      );
    }
    return null;
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
    final card = cart.isEmpty
        ? (enabled: false, reason: null)
        : cardAvailability(ref, context, cart.totalCents);
    final count = cart.lines.fold<int>(0, (sum, l) => sum + l.quantity);
    final tax = taxBreakdown(grossByRate(cart))
        .fold<int>(0, (s, t) => s + t.taxCents);
    final pricing = cart.pricing;
    final onLineDiscount = widget.onLineDiscount;
    final onReceiptDiscount = widget.onReceiptDiscount;
    // Summe 0,00 € durch einen Rabatt oder "Pfand zurück": nichts zu
    // kassieren, nur abschließen.
    final free =
        widget.onFinishFree != null &&
        !cart.isEmpty &&
        cart.totalCents == 0 &&
        (pricing.discountCents > 0 || cart.lines.any((l) => l.isDepositReturn));
    // Summe unter 0: nur bar auszahlen.
    final payOut =
        widget.onPayOut != null && !cart.isEmpty && cart.totalCents < 0;
    return Container(
      width: KassaTokens.receiptColumnWidth,
      decoration: BoxDecoration(
        color: c.card,
        border: BorderDirectional(
          start: BorderSide(color: c.line, width: KassaTokens.borderThin),
        ),
      ),
      child: Column(
        children: [
          ?widget.notice,
          _Header(
            count: count,
            empty: cart.isEmpty,
            onClear: _clear,
            action: _headAction(l),
          ),
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
                          discountCents: pricing.lines[i].ownDiscountCents,
                          onDiscount:
                              onLineDiscount == null ||
                                  line.isDepositReturn ||
                                  line.isVoucherSale
                              ? null
                              : () => onLineDiscount(line.lineId),
                        );
                      },
                    ),
            ),
          ),
          ?widget.payNotice,
          _Totals(
            cart: cart,
            taxCents: tax,
            receiptDiscountCents: pricing.receiptDiscountCents,
            onDiscount: cart.isEmpty ? null : onReceiptDiscount,
          ),
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              12,
              0,
              12,
              12 + MediaQuery.paddingOf(context).bottom,
            ),
            child: payOut
                ? SizedBox(
                    width: double.infinity,
                    child: PrimaryButton(
                      key: const Key('pay-out'),
                      label: l.kassaPayOut(
                        ltrIsolate(context, formatEuro(-cart.totalCents)),
                      ),
                      icon: LucideIcons.banknote,
                      labelSize: 22,
                      height: KassaTokens.mainActionHeight,
                      onPressed: widget.canPay ? _payOut : null,
                    ),
                  )
                : free
                ? SizedBox(
                    width: double.infinity,
                    child: PrimaryButton(
                      key: const Key('finish-free'),
                      label: l.kassaFinish,
                      icon: LucideIcons.check,
                      labelSize: 22,
                      height: KassaTokens.mainActionHeight,
                      onPressed: widget.canPay ? _finishFree : null,
                    ),
                  )
                : Row(
                    children: [
                      Expanded(
                        child: PrimaryButton(
                          key: const Key('pay-cash'),
                          label: l.kassaCash,
                          icon: LucideIcons.banknote,
                          labelSize: 22,
                          height: KassaTokens.mainActionHeight,
                          onPressed: cart.isEmpty || !widget.canPay
                              ? null
                              : _pay,
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
                          onPressed: card.enabled && widget.canPay
                              ? _payCard
                              : null,
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

/// Eine Taste im Kopf der Bon-Spalte.
/// [halfAtMost]: die Taste nimmt höchstens die Hälfte des Kopfs ("Freier
/// Betrag", wie in 1.11.0); sonst darf sie bis an den Titel "Bon" reichen.
typedef _HeadAction = ({
  Key key,
  String label,
  IconData icon,
  VoidCallback onTap,
  bool halfAtMost,
});

class _Header extends StatelessWidget {
  const _Header({
    required this.count,
    required this.empty,
    required this.onClear,
    this.action,
  });

  final int count;
  final bool empty;
  final VoidCallback onClear;

  /// "Freier Betrag", "Pfand zurück", "Gutschein" oder "Mehr"; null: keine.
  final _HeadAction? action;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final l = L10n.of(context);
    final titleRow = Row(
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
            style: text.bodySmall!.copyWith(fontSize: 14, color: c.ink2),
          ),
        ),
      ],
    );
    return SizedBox(
      height: KassaTokens.receiptHeaderHeight,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 8, 0),
        child: Row(
          children: [
            Expanded(
              child: switch (action) {
                null => titleRow,
                // Die Taste im Kopf nimmt, was sie braucht: "Freier Betrag"
                // höchstens die Hälfte, die anderen bis an den Titel "Bon";
                // den Rest behalten der Titel und die Zahl der Artikel.
                final action => LayoutBuilder(
                  builder: (context, box) {
                    final half = box.maxWidth / 2;
                    final title = _titleWidth(context, l.kassaReceipt);
                    final room = box.maxWidth - title - KassaTokens.spaceLg;
                    return Row(
                      children: [
                        Expanded(child: titleRow),
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: action.halfAtMost || room < half
                                ? half
                                : room,
                          ),
                          child: _HeadButton(action: action),
                        ),
                      ],
                    );
                  },
                ),
              },
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
  const _Totals({
    required this.cart,
    required this.taxCents,
    this.receiptDiscountCents = 0,
    this.onDiscount,
  });

  final Cart cart;
  final int taxCents;
  final int receiptDiscountCents;

  /// Die Taste "Rabatt"; null: keine Taste, die Reihe des Bon-Rabatts ist
  /// keine Tippfläche.
  final VoidCallback? onDiscount;

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
          if (onDiscount case final onDiscount?)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: _DiscountButton(onTap: onDiscount),
            ),
          if (cart.discount case final discount?) ...[
            DiscountRow(
              key: const Key('receipt-discount'),
              discount: discount,
              cents: receiptDiscountCents,
              onTap: onDiscount,
            ),
            const SizedBox(height: KassaTokens.spaceXs),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l.kassaTotal, style: text.bodyLarge),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Ltr(
                    child: Text(
                      formatEuro(cart.totalCents),
                      key: const Key('cart-total'),
                      maxLines: 1,
                      style: KassaText.amount(context),
                    ),
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
                    l.kassaDepositIncluded(
                      ltrIsolate(context, formatEuro(cart.depositCents)),
                    ),
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
                  l.kassaTaxIncluded(ltrIsolate(context, formatEuro(taxCents))),
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

/// Die Taste im Kopf der Bon-Spalte ("Freier Betrag", "Pfand zurück" oder
/// "Mehr"): öffnet ihr Blatt.
class _HeadButton extends StatelessWidget {
  const _HeadButton({required this.action});

  final _HeadAction action;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    return Pressable(
      key: action.key,
      onTap: action.onTap,
      minTapSize: const Size(KassaTokens.minTap, KassaTokens.minTap),
      // "Freier Betrag" genau wie in 1.11.0; die anderen Tasten brechen bei
      // großer Schrift in eine zweite Zeile um und wachsen mit ihr.
      child: Container(
        height: action.halfAtMost ? KassaTokens.drawnControlHeight : null,
        constraints: action.halfAtMost
            ? null
            : const BoxConstraints(minHeight: KassaTokens.drawnControlHeight),
        padding: const EdgeInsets.symmetric(horizontal: KassaTokens.spaceSm),
        decoration: BoxDecoration(
          color: c.fill,
          borderRadius: BorderRadius.circular(KassaTokens.radiusLg),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(action.icon, size: 18, color: c.ink),
            const SizedBox(width: KassaTokens.spaceXs),
            Flexible(
              child: Text(
                action.label,
                maxLines: action.halfAtMost ? 1 : 2,
                overflow: TextOverflow.ellipsis,
                style: action.halfAtMost
                    ? text.labelLarge
                    : text.labelLarge!.copyWith(height: 1.15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Rabatt" im Summenblock: öffnet das Blatt für den ganzen Bon.
class _DiscountButton extends StatelessWidget {
  const _DiscountButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    return Pressable(
      key: const Key('discount-button'),
      onTap: onTap,
      minTapSize: const Size(KassaTokens.minTap, KassaTokens.minTap),
      child: Container(
        height: KassaTokens.drawnControlHeight,
        padding: const EdgeInsets.symmetric(horizontal: KassaTokens.spaceXl),
        decoration: BoxDecoration(
          color: c.fill,
          borderRadius: BorderRadius.circular(KassaTokens.radiusLg),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.percent, size: 18, color: c.ink),
            const SizedBox(width: KassaTokens.spaceSm),
            Flexible(
              child: Text(
                L10n.of(context).discountTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.labelLarge,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Wie breit der Titel "Bon" im Kopf ist, mit der Schriftgröße des Geräts.
double _titleWidth(BuildContext context, String title) {
  final painter = TextPainter(
    text: TextSpan(
      text: title,
      style: Theme.of(context).textTheme.headlineMedium,
    ),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}
