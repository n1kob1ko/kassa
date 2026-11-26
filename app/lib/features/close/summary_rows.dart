import 'package:material_ui/material_ui.dart';

import '../../ui/ltr.dart';
import '../../ui/tokens.dart';

/// Eine Zeile mit Linie darüber (Mindesthöhe 44): Beschriftung, in der Mitte
/// ein ruhiger Text, am Ende der Betrag (mindestens 110 dp breit, damit die
/// Beträge untereinander am selben Rand stehen).
class SummaryLine extends StatelessWidget {
  const SummaryLine({
    super.key,
    required this.label,
    this.middle,
    this.amount,
    this.bold = false,
    this.amountKey,
    this.amountColor,
    this.amountMuted = false,
  });

  final String label;
  final String? middle;
  final String? amount;
  final bool bold;
  final Key? amountKey;
  final Color? amountColor;
  final bool amountMuted;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: c.line, width: KassaTokens.borderThin),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              label,
              style: text.bodyLarge!.copyWith(
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
          if (middle != null) ...[
            const SizedBox(width: KassaTokens.spaceMd),
            Text(
              middle!,
              style: text.bodyMedium!.copyWith(
                fontWeight: FontWeight.w600,
                color: c.ink2,
              ),
            ),
          ],
          ConstrainedBox(
            constraints: BoxConstraints(minWidth: 110),
            child: Ltr(
              child: Text(
                amount ?? '',
                key: amountKey,
                textAlign: ltrAlign(context, TextAlign.end),
                style: text.bodyLarge!.copyWith(
                  fontSize: 17,
                  fontWeight: amountMuted ? FontWeight.w700 : FontWeight.w800,
                  color: amountColor ?? (amountMuted ? c.ink2 : c.ink),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
