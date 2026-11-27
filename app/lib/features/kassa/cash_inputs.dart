import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/money.dart';
import '../../l10n/generated/l10n.dart';
import '../../ui/keypad.dart';
import '../../ui/ltr.dart';
import '../../ui/pressable.dart';
import '../../ui/theme.dart';
import '../../ui/tokens.dart';

// Die Bausteine des Bezahlens: Vorschläge, getippter Betrag, Rückgeld-Feld.

class Suggestions extends StatelessWidget {
  const Suggestions({
    super.key,
    required this.amounts,
    required this.given,
    required this.onGiven,
    required this.onOther,
  });

  final List<int> amounts;
  final int given;
  final ValueChanged<int> onGiven;
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
          l.kassaGiven,
          style: text.bodySmall!.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: c.ink2,
          ),
        ),
        const SizedBox(height: KassaTokens.spaceMd),
        LayoutBuilder(
          builder: (context, box) {
            final w = (box.maxWidth - 2 * KassaTokens.spaceMd) / 3;
            return Wrap(
              spacing: KassaTokens.spaceMd,
              runSpacing: KassaTokens.spaceMd,
              children: [
                for (var i = 0; i < amounts.length; i++)
                  SizedBox(
                    width: w,
                    child: GivenKey(
                      key: Key('given-${amounts[i]}'),
                      label: i == 0
                          ? l.kassaExact
                          : formatEuro(amounts[i]).replaceFirst(',00', ''),
                      selected: given == amounts[i],
                      onTap: () => onGiven(amounts[i]),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: KassaTokens.spaceMd),
        Pressable(
          key: const Key('other-amount'),
          onTap: onOther,
          child: Container(
            height: 60,
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

class GivenKey extends StatelessWidget {
  const GivenKey({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    return Pressable(
      onTap: onTap,
      child: Semantics(
        selected: selected,
        child: AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : KassaTokens.motionFast,
          height: 66,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 6),
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
            // Meist ein Betrag; ein Wort in einer Zeile steht so gleich.
            child: Ltr(
              child: Text(
                label,
                maxLines: 1,
                style: Theme.of(context).textTheme.titleLarge!.copyWith(
                  fontSize: 19,
                  color: selected ? c.onAccent : c.ink,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TypedAmount extends StatelessWidget {
  const TypedAmount({
    super.key,
    required this.input,
    required this.keypadKey,
    required this.onKey,
    this.onSuggestions,
    this.label,
  });

  final KeypadInput input;
  final Key keypadKey;
  final ValueChanged<String> onKey;

  /// "Vorschläge"; ohne steht die Taste nicht da.
  final VoidCallback? onSuggestions;

  /// Die Überschrift über dem Feld; ohne steht "Gegeben".
  final String? label;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final empty = input.isEmpty;
    final l = L10n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 28,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label ?? l.kassaGiven,
                style: text.bodySmall!.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: c.ink2,
                ),
              ),
              if (onSuggestions != null)
                Pressable(
                  key: const Key('show-suggestions'),
                  onTap: onSuggestions,
                  minTapSize: const Size(0, KassaTokens.minTap),
                  child: Container(
                    height: KassaTokens.drawnControlHeight,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.center,
                    child: Text(
                      l.kassaShowSuggestions,
                      style: text.labelLarge!.copyWith(color: c.accentInk),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: KassaTokens.spaceMd),
        Container(
          height: KassaTokens.keypadInputHeight,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          // Die Anzeige gehört zum Zahlenfeld: in jeder Sprache rechts.
          alignment: Alignment.centerRight,
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(KassaTokens.radiusXl),
            border: Border.all(
              color: c.accent,
              width: KassaTokens.borderStrong,
            ),
          ),
          child: Semantics(
            liveRegion: true,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Ltr(
                child: Text(
                  '${empty ? '0' : input.text} €',
                  key: const Key('given-field'),
                  maxLines: 1,
                  style: text.titleLarge!.copyWith(
                    fontSize: 30,
                    letterSpacing: -0.3,
                    color: empty ? c.ink2 : c.ink,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: KassaTokens.spaceMd),
        KeyedSubtree(
          key: keypadKey,
          child: Keypad(onKey: onKey),
        ),
      ],
    );
  }
}

class ChangeField extends StatelessWidget {
  const ChangeField({super.key, required this.missing, required this.cents});

  final bool missing;
  final int cents;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final labelColor = missing ? c.warnInk : c.accentInk;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: missing ? c.warnBg : c.accentSoft,
        borderRadius: BorderRadius.circular(KassaTokens.radiusXxl),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            missing
                ? L10n.of(context).kassaStillMissing
                : L10n.of(context).kassaChange,
            style: text.bodyLarge!.copyWith(color: labelColor),
          ),
          const SizedBox(width: KassaTokens.spaceMd),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Ltr(
                child: Text(
                  formatEuro(cents),
                  key: const Key('change'),
                  maxLines: 1,
                  style: KassaText.amount(context)
                      .copyWith(color: missing ? c.warnInk : c.ink),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
