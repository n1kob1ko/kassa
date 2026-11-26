import 'package:material_ui/material_ui.dart';

import '../../core/money.dart';
import '../../l10n/generated/l10n.dart';
import '../../ui/keypad.dart';
import '../../ui/primary_button.dart';
import '../../ui/tokens.dart';
import 'item_detail.dart';

/// Neuer Preis über das Zahlenfeld: Zeile "Neuer Preis, bisher ...", Anzeige,
/// Zahlenfeld und unten "Abbrechen" und "Übernehmen". [header] (Bild und Name
/// des Artikels) steht oben und scrollt mit. "Übernehmen" geht erst, wenn ein
/// Betrag über 0 getippt ist.
class PriceEntry extends StatefulWidget {
  const PriceEntry({
    super.key,
    required this.header,
    required this.currentCents,
    required this.failed,
    required this.onSave,
    required this.onCancel,
  });

  final Widget header;
  final int currentCents;
  final bool failed;
  final ValueChanged<int> onSave;
  final VoidCallback onCancel;

  @override
  State<PriceEntry> createState() => _PriceEntryState();
}

class _PriceEntryState extends State<PriceEntry> {
  KeypadInput _input = const KeypadInput(maxIntDigits: 4);

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final l = L10n.of(context);
    final empty = _input.isEmpty;
    final canSave = _input.cents > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                widget.header,
                const SizedBox(height: KassaTokens.spaceXxl),
                Text(
                  l.itemsNewPrice(formatEuro(widget.currentCents)),
                  style: text.bodySmall!.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: c.ink2,
                  ),
                ),
                const SizedBox(height: KassaTokens.spaceMd),
                Container(
                  height: KassaTokens.keypadInputHeight,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
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
                      child: Text(
                        '${empty ? '0' : _input.text} €',
                        key: const Key('price-field'),
                        maxLines: 1,
                        style: text.titleLarge!.copyWith(
                          fontSize: 30,
                          letterSpacing: -0.3,
                          color: empty ? c.ink2 : c.ink,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: KassaTokens.spaceMd),
                Keypad(onKey: (k) => setState(() => _input = _input.tap(k))),
              ],
            ),
          ),
        ),
        if (widget.failed) const FailedHint(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  key: const Key('cancel-price'),
                  label: l.kassaCancel,
                  filled: false,
                  height: KassaTokens.secondaryActionHeight,
                  onPressed: widget.onCancel,
                ),
              ),
              const SizedBox(width: KassaTokens.spaceMd),
              Expanded(
                child: PrimaryButton(
                  key: const Key('save-price'),
                  label: l.itemsApply,
                  labelSize: 17,
                  height: KassaTokens.secondaryActionHeight,
                  onPressed: canSave ? () => widget.onSave(_input.cents) : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
