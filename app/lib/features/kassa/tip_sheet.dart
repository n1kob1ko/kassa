import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/money.dart';
import '../../domain/tip.dart';
import '../../l10n/generated/l10n.dart';
import '../../ui/ltr.dart';
import '../../ui/pressable.dart';
import '../../ui/primary_button.dart';
import '../../ui/theme.dart';
import '../../ui/tokens.dart';
import 'cash_inputs.dart';
import 'cash_sheet.dart' show PayColumnFrame;

/// "Trinkgeld": die rechte Spalte vor dem Terminal, wenn Trinkgeld bei
/// Kartenzahlung eingeschaltet ist. Der Gast sagt, wie viel er zahlt (ein
/// Vorschlag oder "Anderer Betrag"); das Trinkgeld ist der Teil über der
/// Summe. "Ohne Trinkgeld" geht mit einem Tipp zum Terminal. Ist das
/// Trinkgeld auffällig hoch ([tipNeedsConfirm]), fragt die Spalte einmal
/// nach, bevor das Terminal etwas erfährt.
class TipSheet extends ConsumerStatefulWidget {
  const TipSheet({
    super.key,
    required this.dueCents,
    required this.receiptTotalCents,
    required this.onBack,
    required this.onPay,
  });

  /// Was die Karte ohne Trinkgeld bucht.
  final int dueCents;

  /// Grundlage der 30-%-Grenze.
  final int receiptTotalCents;
  final VoidCallback onBack;

  /// Trinkgeld in Cent; 0 bei "Ohne Trinkgeld". Wird höchstens einmal gerufen.
  final ValueChanged<int> onPay;

  @override
  ConsumerState<TipSheet> createState() => _TipSheetState();
}

class _TipSheetState extends ConsumerState<TipSheet> {
  /// Was der Gast zahlt; `null`, solange nichts gewählt ist.
  int? _pays;
  KeypadInput? _typing;
  bool _confirming = false;

  /// Gesetzt mit dem ersten Tipp, der zum Terminal geht: ein zweiter Tipp im
  /// selben Bild tut nichts.
  bool _sent = false;

  final _keypadKey = GlobalKey();

  int get _due => widget.dueCents;

  int get _tip {
    final pays = _pays;
    return pays == null || pays < _due ? 0 : pays - _due;
  }

  bool get _tooLow => _pays != null && _pays! < _due;

  void _choose(int cents) => setState(() {
    _pays = cents;
    _confirming = false;
  });

  void _showKeypad() {
    setState(() {
      _typing = const KeypadInput(maxIntDigits: 6);
      _pays = null;
      _confirming = false;
    });
    // Auf kleinen Bildschirmen scrollt die Spalte: das Zahlenfeld soll
    // gleich ganz zu sehen sein.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _keypadKey.currentContext;
      if (context != null) Scrollable.ensureVisible(context);
    });
  }

  void _showSuggestions() => setState(() {
    _typing = null;
    _pays = null;
    _confirming = false;
  });

  void _setKey(String key) {
    final typing = _typing;
    if (typing == null) return;
    final next = typing.tap(key);
    setState(() {
      _typing = next;
      _pays = next.isEmpty ? null : next.cents;
      _confirming = false;
    });
  }

  void _go() {
    if (_pays == null || _tooLow) return;
    if (tipNeedsConfirm(totalCents: widget.receiptTotalCents, tipCents: _tip)) {
      setState(() => _confirming = true);
      return;
    }
    _send(_tip);
  }

  void _send(int tipCents) {
    if (_sent) return;
    _sent = true;
    widget.onPay(tipCents);
  }

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final l = L10n.of(context);
    final typing = _typing;
    final pays = _pays;
    final canGo = pays != null && !_tooLow;
    final still = MediaQuery.disableAnimationsOf(context);
    return PayColumnFrame(
      child: Column(
        key: const Key('tip-sheet'),
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
                  key: const Key('tip-back'),
                  onTap: widget.onBack,
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
                    l.tipTip,
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(l.kassaAmountDue, style: text.bodyLarge),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Ltr(
                            child: Text(
                              formatEuro(_due),
                              key: const Key('tip-due'),
                              maxLines: 1,
                              style: KassaText.amount(context),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: KassaTokens.spaceXxl),
                  if (typing == null)
                    _GuestPays(
                      amounts: tipSuggestions(_due),
                      pays: pays,
                      onPays: _choose,
                      onOther: _showKeypad,
                    )
                  else
                    TypedAmount(
                      label: l.tipGuestPays,
                      input: typing,
                      keypadKey: _keypadKey,
                      onKey: _setKey,
                      onSuggestions: _showSuggestions,
                    ),
                  const SizedBox(height: KassaTokens.spaceXxl),
                  _TipField(tipCents: _tip, tooLow: _tooLow),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: AnimatedSwitcher(
              duration: still ? Duration.zero : KassaTokens.motionSwitch,
              child: KeyedSubtree(
                key: ValueKey(_confirming),
                child: _confirming ? _confirm(context) : _actions(canGo),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actions(bool canGo) {
    final l = L10n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PrimaryButton(
          key: const Key('tip-none'),
          label: l.tipNone,
          filled: false,
          height: KassaTokens.secondaryActionHeight,
          onPressed: () => _send(0),
        ),
        const SizedBox(height: KassaTokens.spaceLg),
        PrimaryButton(
          key: const Key('tip-go'),
          label: l.tipToTerminal(
            ltrIsolate(context, formatEuro(_pays ?? _due)),
          ),
          height: KassaTokens.mainActionHeight,
          onPressed: canGo ? _go : null,
        ),
        // Außerhalb der scrollenden Fläche: auch auf 600 dp Höhe zu sehen.
        if (_tooLow) ...[
          const SizedBox(height: KassaTokens.spaceSm),
          Semantics(
            liveRegion: true,
            child: Text(
              l.tipTooLow,
              key: const Key('tip-too-low'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                color: KassaColors.of(context).warnInk,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _confirm(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final l = L10n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(KassaTokens.spaceXl),
          decoration: BoxDecoration(
            color: c.warnBg,
            borderRadius: BorderRadius.circular(KassaTokens.radiusXl),
          ),
          child: Semantics(
            liveRegion: true,
            child: Text(
              l.tipConfirm(ltrIsolate(context, formatEuro(_tip))),
              key: const Key('tip-confirm'),
              style: text.titleLarge!.copyWith(color: c.warnInk),
            ),
          ),
        ),
        const SizedBox(height: KassaTokens.spaceLg),
        Row(
          children: [
            Expanded(
              child: PrimaryButton(
                key: const Key('tip-confirm-no'),
                label: l.tipConfirmNo,
                filled: false,
                height: KassaTokens.mainActionHeight,
                onPressed: () => setState(() => _confirming = false),
              ),
            ),
            const SizedBox(width: KassaTokens.spaceLg),
            Expanded(
              child: PrimaryButton(
                key: const Key('tip-confirm-yes'),
                label: l.tipConfirmYes,
                height: KassaTokens.mainActionHeight,
                onPressed: () => _send(_tip),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// "Gast zahlt": eine große Taste je Vorschlag in einer Reihe, darunter
/// "Anderer Betrag".
class _GuestPays extends StatelessWidget {
  const _GuestPays({
    required this.amounts,
    required this.pays,
    required this.onPays,
    required this.onOther,
  });

  final List<int> amounts;
  final int? pays;
  final ValueChanged<int> onPays;
  final VoidCallback onOther;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final l = L10n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l.tipGuestPays,
          style: text.bodySmall!.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: c.ink2,
          ),
        ),
        const SizedBox(height: KassaTokens.spaceMd),
        Row(
          children: [
            for (var i = 0; i < amounts.length; i++) ...[
              if (i > 0) const SizedBox(width: KassaTokens.spaceMd),
              Expanded(
                child: GivenKey(
                  key: Key('tip-pays-${amounts[i]}'),
                  label: formatEuro(amounts[i]).replaceFirst(',00', ''),
                  selected: pays == amounts[i],
                  onTap: () => onPays(amounts[i]),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: KassaTokens.spaceMd),
        Pressable(
          key: const Key('tip-other'),
          onTap: onOther,
          child: Container(
            height: KassaTokens.keypadInputHeight,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.fill,
              borderRadius: BorderRadius.circular(KassaTokens.radiusXl),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.calculator, size: 22, color: c.ink),
                const SizedBox(width: KassaTokens.spaceLg),
                Text(
                  l.kassaOtherAmount,
                  style: text.titleLarge!.copyWith(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Die Zeile "Trinkgeld" mit dem Betrag über der Summe. Liegt der getippte
/// Betrag darunter, steht sie in der Warnfarbe; warum "Zum Terminal" aus
/// ist, steht bei den Tasten.
class _TipField extends StatelessWidget {
  const _TipField({required this.tipCents, required this.tooLow});

  final int tipCents;
  final bool tooLow;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final l = L10n.of(context);
    final ink = tooLow ? c.warnInk : c.accentInk;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tooLow ? c.warnBg : c.accentSoft,
        borderRadius: BorderRadius.circular(KassaTokens.radiusXxl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l.tipTip, style: text.bodyLarge!.copyWith(color: ink)),
              const SizedBox(width: KassaTokens.spaceMd),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Ltr(
                    child: Text(
                      formatEuro(tipCents),
                      key: const Key('tip-amount'),
                      maxLines: 1,
                      style: KassaText.amount(context)
                          .copyWith(color: tooLow ? c.warnInk : c.ink),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
