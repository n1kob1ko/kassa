import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/money.dart';
import '../../domain/cart.dart';
import '../../domain/catalog.dart';
import '../../l10n/generated/l10n.dart';
import '../../ui/ltr.dart';
import '../../ui/pressable.dart';
import '../../ui/primary_button.dart';
import '../../ui/tokens.dart';
import 'cart_controller.dart';
import 'cash_inputs.dart';
import 'cash_sheet.dart' show PayColumnFrame;

/// "Freier Betrag": die rechte Spalte für einen Betrag ohne Artikel. Oben der
/// Betrag über das Zahlenfeld (höchstens 9.999,99 €), darunter der
/// Steuersatz (20, 10, 13 oder 0 %; keiner ist vorgewählt). "Auf den Bon"
/// geht erst mit Betrag über 0 und Satz und legt eine eigene Zeile an; fehlt
/// mit Betrag nur der Satz, steht das unter der Taste.
class OpenAmountSheet extends ConsumerStatefulWidget {
  const OpenAmountSheet({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  ConsumerState<OpenAmountSheet> createState() => _OpenAmountSheetState();
}

class _OpenAmountSheetState extends ConsumerState<OpenAmountSheet> {
  KeypadInput _amount = const KeypadInput(maxIntDigits: 4);
  TaxRate? _rate;

  /// Nach dem ersten Tipp auf "Auf den Bon": ein zweiter tut nichts.
  bool _done = false;

  final _keypadKey = GlobalKey();

  void _add(int cents, TaxRate rate) {
    if (_done) return;
    _done = true;
    ref
        .read(cartProvider.notifier)
        .addOpenAmount(amountCents: cents, rate: rate);
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final l = L10n.of(context);
    final cents = _amount.cents;
    final rate = _rate;
    final ready = rate != null && cents >= 1 && cents <= openAmountMaxCents;
    return PayColumnFrame(
      child: Column(
        key: const Key('open-amount-sheet'),
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
                  key: const Key('open-amount-back'),
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
                    l.openAmountTitle,
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
                  TypedAmount(
                    label: l.openAmountAmount,
                    input: _amount,
                    keypadKey: _keypadKey,
                    onKey: (key) => setState(() => _amount = _amount.tap(key)),
                  ),
                  const SizedBox(height: KassaTokens.spaceXxl),
                  Text(
                    l.openAmountTax,
                    style: text.bodySmall!.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: c.ink2,
                    ),
                  ),
                  const SizedBox(height: KassaTokens.spaceMd),
                  Row(
                    children: [
                      for (var i = 0; i < openAmountRates.length; i++) ...[
                        if (i > 0) const SizedBox(width: KassaTokens.spaceMd),
                        Expanded(
                          child: _RateKey(
                            key: Key('open-rate-${openAmountRates[i].percent}'),
                            percent: openAmountRates[i].percent,
                            selected: rate == openAmountRates[i],
                            onTap: () =>
                                setState(() => _rate = openAmountRates[i]),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PrimaryButton(
                  key: const Key('open-amount-add'),
                  label: l.openAmountAdd,
                  icon: LucideIcons.plus,
                  height: KassaTokens.mainActionHeight,
                  onPressed: ready ? () => _add(cents, rate) : null,
                ),
                // Außerhalb der scrollenden Fläche: auf 600 dp Höhe liegen
                // die Steuersätze unter dem Rand, der Grund steht trotzdem da.
                if (cents >= 1 && rate == null) ...[
                  const SizedBox(height: KassaTokens.spaceSm),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      l.openAmountNeedTax,
                      key: const Key('open-amount-reason'),
                      textAlign: TextAlign.center,
                      style: text.bodyMedium!.copyWith(color: c.ink2),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Eine Taste eines Steuersatzes, "20 %": gewählt in der Akzentfarbe.
class _RateKey extends StatelessWidget {
  const _RateKey({
    super.key,
    required this.percent,
    required this.selected,
    required this.onTap,
  });

  final int percent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final ink = selected ? c.onAccent : c.ink;
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
          child: Ltr(
            child: Text(
              '$percent %',
              maxLines: 1,
              style: Theme.of(context).textTheme.titleLarge!.copyWith(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
