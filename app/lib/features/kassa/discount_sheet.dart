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
import '../../ui/primary_button.dart';
import '../../ui/theme.dart';
import '../../ui/tokens.dart';
import 'cart_controller.dart';
import 'cart_line_row.dart' show discountReasonText;
import 'cash_inputs.dart';
import 'cash_sheet.dart' show PayColumnFrame;

/// "Rabatt": die rechte Spalte für den Rabatt auf eine Zeile ([lineId]) oder
/// auf den ganzen Bon (null). Oben steht, worauf der Rabatt geht, mit dem
/// Wert vor diesem Rabatt; darunter Grund und Höhe (eine Prozent-Stufe oder
/// ein Betrag über das Zahlenfeld) und der Wert danach ("Neu"). Ein Rabatt,
/// der schon da ist, ist vorgewählt. "Übernehmen" geht erst mit Grund und
/// Höhe und nur, wenn es etwas zu rabattieren gibt; ein Betrag über dem Wert
/// wird auf den Wert gekappt.
class DiscountSheet extends ConsumerStatefulWidget {
  const DiscountSheet({super.key, required this.lineId, required this.onClose});

  /// null: der ganze Bon.
  final String? lineId;
  final VoidCallback onClose;

  @override
  ConsumerState<DiscountSheet> createState() => _DiscountSheetState();
}

class _DiscountSheetState extends ConsumerState<DiscountSheet> {
  DiscountReason? _reason;
  int? _percent;

  /// Gesetzt, solange "Betrag" gewählt ist: das Zahlenfeld steht da.
  KeypadInput? _amount;

  /// Nach dem ersten Tipp auf "Übernehmen" oder "Entfernen": ein zweiter tut
  /// nichts.
  bool _done = false;

  final _keypadKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    final current = _currentOf(ref.read(cartProvider));
    if (current == null) return;
    _reason = current.reason;
    _percent = current.percent;
    if (current.percent == null) {
      _amount = KeypadInput(
        text: _amountText(current.amountCents),
        maxIntDigits: 6,
      );
    }
  }

  /// "5" für 500 Cent, "1,50" für 150 Cent: so, wie man es tippt.
  static String _amountText(int cents) {
    final euros = cents ~/ 100;
    final rest = cents % 100;
    return rest == 0 ? '$euros' : '$euros,${rest.toString().padLeft(2, '0')}';
  }

  CartLine? _lineOf(Cart cart) {
    final id = widget.lineId;
    if (id == null) return null;
    for (final l in cart.lines) {
      if (l.lineId == id) return l;
    }
    return null;
  }

  Discount? _currentOf(Cart cart) =>
      widget.lineId == null ? cart.discount : _lineOf(cart)?.discount;

  void _chooseReason(DiscountReason reason) => setState(() {
    _reason = reason;
    // Eine Einladung ist meist ganz aufs Haus.
    if (reason == DiscountReason.invitation) {
      _percent = 100;
      _amount = null;
    }
  });

  void _choosePercent(int percent) => setState(() {
    _percent = percent;
    _amount = null;
  });

  void _chooseAmount() {
    setState(() {
      _percent = null;
      _amount ??= const KeypadInput(maxIntDigits: 6);
    });
    // Auf kleinen Bildschirmen scrollt die Spalte: das Zahlenfeld soll
    // gleich ganz zu sehen sein.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _keypadKey.currentContext;
      if (context != null) Scrollable.ensureVisible(context);
    });
  }

  void _setKey(String key) {
    final amount = _amount;
    if (amount == null) return;
    setState(() => _amount = amount.tap(key));
  }

  /// Wie viel von [baseCents] die gewählte Höhe abzieht; 0 ohne Höhe.
  int _cutOf(int baseCents) {
    if (baseCents <= 0) return 0;
    final percent = _percent;
    if (percent != null) {
      return Discount.percent(percent, DiscountReason.regular).of(baseCents);
    }
    final cents = _amount?.cents ?? 0;
    return cents < baseCents ? cents : baseCents;
  }

  /// Der Rabatt, den "Übernehmen" setzt; null, solange Grund oder Höhe fehlen
  /// oder es nichts zu rabattieren gibt.
  Discount? _chosen(int baseCents) {
    final reason = _reason;
    if (reason == null || baseCents <= 0) return null;
    final percent = _percent;
    if (percent != null) return Discount.percent(percent, reason);
    final cut = _cutOf(baseCents);
    return cut > 0 ? Discount.amount(cut, reason) : null;
  }

  void _set(Discount? discount) {
    if (_done) return;
    _done = true;
    final cart = ref.read(cartProvider);
    // Derselbe Rabatt noch einmal ändert den Bon nicht.
    if (discount != _currentOf(cart)) {
      final controller = ref.read(cartProvider.notifier);
      final id = widget.lineId;
      if (id == null) {
        controller.setReceiptDiscount(discount);
      } else {
        controller.setLineDiscount(id, discount);
      }
    }
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final l = L10n.of(context);
    final cart = ref.watch(cartProvider);
    final line = _lineOf(cart);
    final forLine = widget.lineId != null;
    if (forLine && line == null) {
      // Die Zeile gibt es nicht mehr (etwa nach einer neuen Speisekarte).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_done) {
          _done = true;
          widget.onClose();
        }
      });
      return const PayColumnFrame(child: SizedBox.expand());
    }
    final base = line == null ? cart.pricing.subtotalCents : line.goodsCents;
    final String what;
    if (line == null) {
      what = l.discountWholeReceipt;
    } else {
      final name = nameIsolateIn(
        context,
        ref.watch(menuTextProvider)(line.item.name),
      );
      what = line.quantity > 1 ? '${line.quantity} × $name' : name;
    }
    final current = _currentOf(cart);
    final chosen = _chosen(base);
    final amount = _amount;
    final label = text.bodySmall!.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      color: c.ink2,
    );
    return PayColumnFrame(
      child: Column(
        key: const Key('discount-sheet'),
        children: [
          Container(
            height: KassaTokens.receiptHeaderHeight,
            padding: const EdgeInsetsDirectional.only(start: 6, end: 16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: c.line,
                  width: KassaTokens.borderThin,
                ),
              ),
            ),
            child: Row(
              children: [
                Pressable(
                  key: const Key('discount-back'),
                  onTap: widget.onClose,
                  semanticLabel: l.kassaBackToReceipt,
                  minTapSize: const Size(
                    KassaTokens.minTap,
                    KassaTokens.minTap,
                  ),
                  child: Icon(
                    directionalIcon(
                      context,
                      ltr: LucideIcons.chevronLeft,
                      rtl: LucideIcons.chevronRight,
                    ),
                    size: 28,
                    color: c.ink,
                  ),
                ),
                const SizedBox(width: KassaTokens.spaceXs),
                Expanded(
                  child: Text(
                    l.discountTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.headlineMedium,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: Text(l.discountOn(what), style: text.bodyLarge),
                      ),
                      const SizedBox(width: KassaTokens.spaceMd),
                      Ltr(
                        child: Text(
                          formatEuro(base),
                          key: const Key('discount-target'),
                          maxLines: 1,
                          style: text.titleLarge,
                        ),
                      ),
                    ],
                  ),
                  if (!forLine) ...[
                    const SizedBox(height: KassaTokens.spaceMd),
                    Text(
                      l.discountLineHint,
                      key: const Key('discount-hint'),
                      style: text.bodyMedium!.copyWith(
                        fontWeight: FontWeight.w400,
                        height: 1.3,
                        color: c.ink2,
                      ),
                    ),
                  ],
                  const SizedBox(height: KassaTokens.spaceXxl),
                  Text(l.discountReason, style: label),
                  const SizedBox(height: KassaTokens.spaceMd),
                  _Grid(
                    children: [
                      for (final r in DiscountReason.values)
                        _ChoiceKey(
                          key: Key('discount-reason-${r.name}'),
                          label: discountReasonText(l, r),
                          selected: _reason == r,
                          onTap: () => _chooseReason(r),
                        ),
                    ],
                  ),
                  const SizedBox(height: KassaTokens.spaceXxl),
                  Text(l.discountHeight, style: label),
                  const SizedBox(height: KassaTokens.spaceMd),
                  _Grid(
                    children: [
                      for (final p in discountPercents)
                        _ChoiceKey(
                          key: Key('discount-percent-$p'),
                          label: '$p %',
                          ltr: true,
                          selected: _percent == p,
                          onTap: () => _choosePercent(p),
                        ),
                    ],
                  ),
                  const SizedBox(height: KassaTokens.spaceMd),
                  _ChoiceKey(
                    key: const Key('discount-amount'),
                    label: l.discountAmount,
                    icon: LucideIcons.calculator,
                    selected: amount != null,
                    onTap: _chooseAmount,
                  ),
                  if (amount != null) ...[
                    const SizedBox(height: KassaTokens.spaceXxl),
                    TypedAmount(
                      label: l.discountAmount,
                      input: amount,
                      keypadKey: _keypadKey,
                      onKey: _setKey,
                    ),
                  ],
                  const SizedBox(height: KassaTokens.spaceXxl),
                  _NewValue(cents: base - _cutOf(base)),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                if (current != null) ...[
                  Expanded(
                    child: PrimaryButton(
                      key: const Key('discount-remove'),
                      label: l.discountRemove,
                      filled: false,
                      height: KassaTokens.mainActionHeight,
                      onPressed: () => _set(null),
                    ),
                  ),
                  const SizedBox(width: KassaTokens.spaceLg),
                ],
                Expanded(
                  child: PrimaryButton(
                    key: const Key('discount-apply'),
                    label: l.discountApply,
                    height: KassaTokens.mainActionHeight,
                    onPressed: chosen == null ? null : () => _set(chosen),
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

/// Drei Tasten in einer Reihe, über die ganze Breite.
class _Grid extends StatelessWidget {
  const _Grid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final w = (box.maxWidth - 2 * KassaTokens.spaceMd) / 3;
        return Wrap(
          spacing: KassaTokens.spaceMd,
          runSpacing: KassaTokens.spaceMd,
          children: [
            for (final child in children) SizedBox(width: w, child: child),
          ],
        );
      },
    );
  }
}

/// Eine Taste einer Auswahl: gewählt in der Akzentfarbe.
class _ChoiceKey extends StatelessWidget {
  const _ChoiceKey({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.ltr = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  /// Die Beschriftung ist eine Zahl und steht in jeder Sprache von links nach
  /// rechts.
  final bool ltr;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final ink = selected ? c.onAccent : c.ink;
    final style = Theme.of(context).textTheme.titleLarge!
        .copyWith(fontSize: 17, fontWeight: FontWeight.w700, color: ink);
    Widget caption = Text(label, maxLines: 1, style: style);
    if (ltr) caption = Ltr(child: caption);
    final iconData = icon;
    return Pressable(
      onTap: onTap,
      selected: selected,
      child: AnimatedContainer(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : KassaTokens.motionFast,
        height: KassaTokens.keypadKeyHeight,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: KassaTokens.spaceSm),
        decoration: BoxDecoration(
          color: selected ? c.accent : c.card,
          borderRadius: BorderRadius.circular(KassaTokens.radiusXl),
          border: Border.all(
            color: selected ? c.accent : c.line,
            width: KassaTokens.borderButton,
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: iconData == null
              ? caption
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(iconData, size: 22, color: ink),
                    const SizedBox(width: KassaTokens.spaceLg),
                    caption,
                  ],
                ),
        ),
      ),
    );
  }
}

/// "Neu": der Wert nach dem Rabatt, im Feld des Rückgelds.
class _NewValue extends StatelessWidget {
  const _NewValue({required this.cents});

  final int cents;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    return Container(
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
              L10n.of(context).discountNew,
              style: text.bodyLarge!.copyWith(color: c.accentInk),
            ),
          ),
          const SizedBox(width: KassaTokens.spaceMd),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Ltr(
                child: Text(
                  formatEuro(cents),
                  key: const Key('discount-new'),
                  maxLines: 1,
                  style: KassaText.amount(context).copyWith(color: c.ink),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
