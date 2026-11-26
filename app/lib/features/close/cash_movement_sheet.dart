import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/money.dart';
import '../../domain/day.dart';
import '../../l10n/generated/l10n.dart';
import '../../ui/pressable.dart';
import '../../ui/primary_button.dart';
import '../../ui/tokens.dart';
import 'amount_entry.dart';
import 'close_format.dart' show cashReasonText;

/// Zustand D: Bargeld einlegen oder entnehmen, mit Betrag und Grund. Speichern
/// geht, wenn der Betrag über 0 ist und ein Grund gewählt ist. "Trinkgeld"
/// gibt es nur beim Entnehmen und nur mit [showTip] (Trinkgeld bei
/// Kartenzahlung eingeschaltet): das Trinkgeld der Karte geht bar an die
/// Person.
class CashMovementSheet extends StatelessWidget {
  const CashMovementSheet({
    super.key,
    required this.kind,
    required this.input,
    required this.reason,
    required this.onKey,
    required this.onReason,
    required this.onClose,
    required this.onSave,
    required this.failed,
    this.showTip = false,
  });

  final CashMovementKind kind;
  final KeypadInput input;
  final CashReason? reason;
  final ValueChanged<String> onKey;
  final ValueChanged<CashReason> onReason;
  final VoidCallback onClose;

  /// `null`, solange Betrag oder Grund fehlen oder gerade geschrieben wird.
  final VoidCallback? onSave;
  final bool failed;

  /// Ob "Trinkgeld" als Grund beim Entnehmen da ist.
  final bool showTip;

  @override
  Widget build(BuildContext context) {
    final deposit = kind == CashMovementKind.deposit;
    final l = L10n.of(context);
    return CloseColumn(
      title: deposit ? l.closeCashIn : l.closeCashOut,
      trailing: Pressable(
        key: const Key('close-movement'),
        onTap: onClose,
        semanticLabel: l.closeCloseSheet,
        minTapSize: const Size(KassaTokens.minTap, KassaTokens.minTap),
        child: SizedBox(
          width: KassaTokens.minTap,
          height: KassaTokens.minTap,
          child: Icon(
            LucideIcons.x,
            size: 26,
            color: KassaColors.of(context).ink,
          ),
        ),
      ),
      failed: failed,
      content: [
        FieldLabel(l.closeAmount),
        const SizedBox(height: KassaTokens.spaceMd),
        AmountEntry(input: input, onKey: onKey),
        const SizedBox(height: KassaTokens.spaceXxl),
        FieldLabel(l.closeReason),
        const SizedBox(height: KassaTokens.spaceMd),
        Row(
          children: [
            _ReasonKey(CashReason.bank, reason, onReason),
            const SizedBox(width: KassaTokens.spaceMd),
            _ReasonKey(CashReason.purchase, reason, onReason),
          ],
        ),
        const SizedBox(height: KassaTokens.spaceMd),
        Row(
          children: [
            _ReasonKey(CashReason.change, reason, onReason),
            const SizedBox(width: KassaTokens.spaceMd),
            _ReasonKey(CashReason.other, reason, onReason),
          ],
        ),
        if (!deposit && showTip) ...[
          const SizedBox(height: KassaTokens.spaceMd),
          Row(
            children: [
              _ReasonKey(CashReason.tip, reason, onReason),
              const SizedBox(width: KassaTokens.spaceMd),
              const Spacer(),
            ],
          ),
        ],
      ],
      bottom: PrimaryButton(
        key: const Key('save-movement'),
        label: deposit ? l.closeSaveCashIn : l.closeSaveCashOut,
        height: KassaTokens.mainActionHeight,
        onPressed: onSave,
      ),
    );
  }
}

class _ReasonKey extends StatelessWidget {
  const _ReasonKey(this.reason, this.chosen, this.onTap);

  final CashReason reason;
  final CashReason? chosen;
  final ValueChanged<CashReason> onTap;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final selected = reason == chosen;
    return Expanded(
      child: Pressable(
        key: Key('reason-${reason.name}'),
        onTap: () => onTap(reason),
        child: Semantics(
          selected: selected,
          child: Container(
            height: 52,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: selected ? c.accentSoft : c.card,
              borderRadius: BorderRadius.circular(KassaTokens.radiusXl),
              border: Border.all(
                color: selected ? c.accent : c.line,
                width: KassaTokens.borderButton,
              ),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                cashReasonText(L10n.of(context), reason),
                maxLines: 1,
                style: Theme.of(context).textTheme.titleMedium!.copyWith(
                  fontSize: 17,
                  color: selected ? c.accentInk : c.ink,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
