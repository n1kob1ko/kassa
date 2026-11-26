import 'package:material_ui/material_ui.dart';

import '../../core/money.dart';
import '../../ui/keypad.dart';
import '../../ui/ltr.dart';
import '../../ui/tokens.dart';
import '../items/item_detail.dart' show FailedHint;

/// Die feste Spalte rechts (392 dp) im Bereich Abschluss: Titel mit Zeile
/// darunter, der Inhalt scrollt, [bottom] (die Aktionen) bleibt unten stehen.
/// [failed] zeigt den Hinweis über den Aktionen.
class CloseColumn extends StatelessWidget {
  const CloseColumn({
    super.key,
    required this.title,
    required this.content,
    this.trailing,
    this.bottom,
    this.failed = false,
  });

  final String title;
  final Widget? trailing;
  final List<Widget> content;
  final Widget? bottom;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    return Container(
      width: KassaTokens.receiptColumnWidth,
      decoration: BoxDecoration(
        color: c.card,
        border: BorderDirectional(
          start: BorderSide(color: c.line, width: KassaTokens.borderThin),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: KassaTokens.receiptHeaderHeight,
            padding: const EdgeInsets.symmetric(horizontal: 16),
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
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(title, maxLines: 1, style: text.headlineMedium),
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: KassaTokens.spaceMd),
                  trailing!,
                ],
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: content,
              ),
            ),
          ),
          if (failed) const FailedHint(),
          if (bottom != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: bottom,
            ),
        ],
      ),
    );
  }
}

/// Kleine Beschriftung über einem Feld (14 dp, 700, `ink2`).
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.bodySmall!.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: KassaColors.of(context).ink2,
      ),
    );
  }
}

/// Betragsfeld mit Zahlenfeld darunter, für alle Eingaben im Abschluss. Das
/// Feld hat den Schlüssel `amount-field`. Mit [over] steht der Betrag in `red`.
class AmountEntry extends StatelessWidget {
  const AmountEntry({
    super.key,
    required this.input,
    required this.onKey,
    this.over = false,
  });

  final KeypadInput input;
  final ValueChanged<String> onKey;
  final bool over;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final empty = input.isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: KassaTokens.keypadInputHeight,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          // Die Anzeige gehört zum Zahlenfeld: in jeder Sprache rechts.
          alignment: Alignment.centerRight,
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(KassaTokens.radiusXl),
            border: Border.all(
              color: over ? c.red : c.accent,
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
                  key: const Key('amount-field'),
                  maxLines: 1,
                  style: text.titleLarge!.copyWith(
                    fontSize: 30,
                    letterSpacing: -0.3,
                    color: over ? c.red : (empty ? c.ink2 : c.ink),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: KassaTokens.spaceMd),
        Keypad(onKey: onKey),
      ],
    );
  }
}

/// Zeile "Beschriftung links, Betrag rechts" in der Spalte: Beschriftung 15 dp
/// 600 in `ink2`, Betrag 16 dp 800 (oder [amountColor]).
class ColumnAmountRow extends StatelessWidget {
  const ColumnAmountRow({
    super.key,
    required this.label,
    required this.amount,
    this.amountKey,
    this.amountColor,
  });

  final String label;
  final String amount;
  final Key? amountKey;
  final Color? amountColor;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Text(
              label,
              style: text.bodyMedium!.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: c.ink2,
              ),
            ),
          ),
          Ltr(
            child: Text(
              amount,
              key: amountKey,
              style: text.bodyLarge!.copyWith(
                fontWeight: FontWeight.w800,
                color: amountColor ?? c.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
