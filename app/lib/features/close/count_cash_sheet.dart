import 'package:material_ui/material_ui.dart';

import '../../core/money.dart';
import '../../ui/primary_button.dart';
import '../../ui/theme.dart';
import '../../ui/tokens.dart';
import 'amount_entry.dart';
import 'day_summary_cards.dart' show signedEuro;

/// Zustand B, Schritt 1: Soll, gezählter Betrag und was fehlt oder zu viel ist.
class CountCashSheet extends StatelessWidget {
  const CountCashSheet({
    super.key,
    required this.drawer,
    required this.expectedCents,
    required this.input,
    required this.onKey,
    required this.onNext,
    required this.failed,
  });

  final bool drawer;
  final int expectedCents;
  final KeypadInput input;
  final ValueChanged<String> onKey;
  final VoidCallback onNext;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final diff = input.cents - expectedCents;
    final Color bg;
    final Color fg;
    final String label;
    String? amount;
    if (input.isEmpty) {
      bg = c.fill;
      fg = c.ink2;
      label = 'Noch nichts eingetippt';
    } else if (diff == 0) {
      bg = c.veganBg;
      fg = c.veganFg;
      label = 'Stimmt genau';
    } else {
      bg = c.warnBg;
      fg = c.warnInk;
      label = diff < 0
          ? 'Es fehlen'
          : (drawer ? 'Zu viel in der Lade' : 'Zu viel Bargeld');
      amount = formatEuro(diff.abs());
    }
    return CloseColumn(
      title: drawer ? 'Geldlade zählen' : 'Bargeld zählen',
      trailing: const _StepLabel('Schritt 1 von 2'),
      failed: failed,
      content: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                drawer ? 'Soll in der Lade' : 'Soll in bar',
                style: text.bodyLarge!.copyWith(fontSize: 17),
              ),
            ),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  formatEuro(expectedCents),
                  key: const Key('expected-cash'),
                  maxLines: 1,
                  style: KassaText.amount(context),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: KassaTokens.spaceXl),
        const FieldLabel('Gezählt'),
        const SizedBox(height: KassaTokens.spaceMd),
        AmountEntry(input: input, onKey: onKey),
        const SizedBox(height: KassaTokens.spaceMd),
        Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(KassaTokens.radiusXxl),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  key: const Key('difference-label'),
                  style: text.bodyLarge!.copyWith(color: fg),
                ),
              ),
              if (amount != null)
                Text(
                  amount,
                  key: const Key('difference'),
                  style: text.titleLarge!.copyWith(fontSize: 24, color: fg),
                ),
            ],
          ),
        ),
      ],
      bottom: PrimaryButton(
        key: const Key('count-next'),
        label: 'Weiter',
        height: KassaTokens.mainActionHeight,
        onPressed: input.isEmpty ? null : onNext,
      ),
    );
  }
}

/// Zustand C, Schritt 2: Wie viel bleibt als Wechselgeld in der Lade?
class LeaveInDrawerSheet extends StatelessWidget {
  const LeaveInDrawerSheet({
    super.key,
    required this.drawer,
    required this.countedCents,
    required this.expectedCents,
    required this.input,
    required this.onKey,
    required this.onBack,
    required this.onClose,
    required this.failed,
  });

  final bool drawer;
  final int countedCents;
  final int expectedCents;
  final KeypadInput input;
  final ValueChanged<String> onKey;
  final VoidCallback onBack;

  /// `null`, solange nichts getippt ist, zu viel getippt ist oder gerade
  /// geschrieben wird.
  final VoidCallback? onClose;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final diff = countedCents - expectedCents;
    final over = input.cents > countedCents;
    return CloseColumn(
      title: drawer ? 'In der Lade lassen' : 'Wechselgeld für morgen',
      trailing: const _StepLabel('Schritt 2 von 2'),
      failed: failed,
      content: [
        ColumnAmountRow(label: 'Gezählt', amount: formatEuro(countedCents)),
        ColumnAmountRow(
          label: 'Unterschied zum Soll',
          amount: diff == 0 ? formatEuro(0) : signedEuro(diff),
          amountKey: const Key('difference-signed'),
          amountColor: diff == 0 ? c.green : c.red,
        ),
        const SizedBox(height: KassaTokens.spaceMd),
        FieldLabel(
          drawer
              ? 'Wie viel bleibt als Wechselgeld in der Lade?'
              : 'Wie viel bleibt als Wechselgeld?',
        ),
        const SizedBox(height: KassaTokens.spaceMd),
        AmountEntry(input: input, onKey: onKey, over: over),
        const SizedBox(height: KassaTokens.spaceMd),
        Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: over ? c.warnBg : c.fill,
            borderRadius: BorderRadius.circular(KassaTokens.radiusXxl),
          ),
          child: over
              ? Text(
                  'Mehr als gezählt kann nicht in der Lade bleiben.',
                  style: text.bodyLarge!.copyWith(color: c.warnInk),
                )
              : input.isEmpty
              ? Text(
                  'Noch nichts eingetippt',
                  style: text.bodyLarge!.copyWith(color: c.ink2),
                )
              : Row(
                  children: [
                    Expanded(
                      child: Text('Du nimmst heraus', style: text.bodyLarge),
                    ),
                    Text(
                      formatEuro(countedCents - input.cents),
                      key: const Key('take-out'),
                      style: text.titleLarge!.copyWith(fontSize: 28),
                    ),
                  ],
                ),
        ),
      ],
      bottom: Row(
        children: [
          Expanded(
            flex: 2,
            child: PrimaryButton(
              key: const Key('count-back'),
              label: 'Zurück',
              filled: false,
              height: KassaTokens.mainActionHeight,
              onPressed: onBack,
            ),
          ),
          const SizedBox(width: KassaTokens.spaceXl),
          Expanded(
            flex: 5,
            child: PrimaryButton(
              key: const Key('close-day'),
              label: 'Tag abschließen',
              height: KassaTokens.mainActionHeight,
              onPressed: input.isEmpty || over ? null : onClose,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepLabel extends StatelessWidget {
  const _StepLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.bodySmall!.copyWith(
        fontWeight: FontWeight.w700,
        color: KassaColors.of(context).ink2,
      ),
    );
  }
}
