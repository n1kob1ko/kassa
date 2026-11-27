import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/settings_repository.dart';
import '../../domain/catalog.dart';
import '../../domain/staff.dart';
import '../../l10n/generated/l10n.dart';
import '../../ui/ltr.dart';
import '../../ui/pressable.dart';
import '../../ui/primary_button.dart';
import '../../ui/tokens.dart';
import 'cash_sheet.dart' show PayColumnFrame;

/// Was im Kopf der Bon-Spalte stehen kann.
enum HeadAction { openAmount, depositReturn, voucher }

/// Die Funktionen, die [staff] im Kopf der Bon-Spalte sieht, in dieser
/// Reihenfolge: der freie Betrag, wenn er erlaubt ist (wie in 1a); "Pfand
/// zurück", wenn der Schalter die Person erlaubt und die Speisekarte einen
/// Pfand-Betrag kennt; der Gutschein, wenn er an ist (für alle Personen).
/// Eine: ihre Taste steht im Kopf; zwei oder drei: die Taste "Mehr"; keine:
/// nichts.
List<HeadAction> headActions({
  required RegisterSettings settings,
  required Staff staff,
  required Catalog catalog,
}) => [
  if (settings.openAmountAccess.allows(staff)) HeadAction.openAmount,
  if (settings.depositReturnAccess.allows(staff) &&
      depositAmounts(catalog).isNotEmpty)
    HeadAction.depositReturn,
  if (settings.voucherEnabled) HeadAction.voucher,
];

/// Beschriftung, Zeichen und Schlüssel einer Funktion im Kopf ([headKey]) und
/// im Blatt "Mehr" ([moreKey]).
({String label, IconData icon, Key headKey, Key moreKey}) headActionLook(
  L10n l,
  HeadAction action,
) => switch (action) {
  HeadAction.openAmount => (
    label: l.openAmountTitle,
    icon: LucideIcons.plus,
    headKey: const Key('open-amount-button'),
    moreKey: const Key('more-open-amount'),
  ),
  HeadAction.depositReturn => (
    label: l.kassaDepositReturn,
    icon: LucideIcons.undo2,
    headKey: const Key('deposit-return-button'),
    moreKey: const Key('more-deposit-return'),
  ),
  HeadAction.voucher => (
    label: l.kassaVoucher,
    icon: LucideIcons.gift,
    headKey: const Key('voucher-button'),
    moreKey: const Key('more-voucher'),
  ),
};

/// Der Kopf eines Blatts in der Bon-Spalte: "Zurück" und der Titel, wie bei
/// "Freier Betrag" und "Rabatt".
class SheetHeader extends StatelessWidget {
  const SheetHeader({
    super.key,
    required this.title,
    required this.backKey,
    required this.onBack,
  });

  final String title;
  final Key backKey;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final l = L10n.of(context);
    return Container(
      height: KassaTokens.receiptHeaderHeight,
      padding: const EdgeInsetsDirectional.only(start: 6, end: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: c.line, width: KassaTokens.borderThin),
        ),
      ),
      child: Row(
        children: [
          Pressable(
            key: backKey,
            onTap: onBack,
            semanticLabel: l.kassaBackToReceipt,
            minTapSize: const Size(KassaTokens.minTap, KassaTokens.minTap),
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
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.headlineMedium,
            ),
          ),
        ],
      ),
    );
  }
}

/// "Mehr": die rechte Spalte mit einer großen Taste je Funktion aus
/// [actions]; ein Tipp ruft [onChoose], "Zurück" [onClose].
class MoreSheet extends StatelessWidget {
  const MoreSheet({
    super.key,
    required this.actions,
    required this.onChoose,
    required this.onClose,
  });

  final List<HeadAction> actions;
  final ValueChanged<HeadAction> onChoose;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return PayColumnFrame(
      child: Column(
        key: const Key('more-sheet'),
        children: [
          SheetHeader(
            title: l.kassaMore,
            backKey: const Key('more-back'),
            onBack: onClose,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, action) in actions.indexed) ...[
                    if (i > 0) const SizedBox(height: KassaTokens.spaceXl),
                    _MoreKey(action: action, onTap: () => onChoose(action)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Eine große Taste im Blatt "Mehr".
class _MoreKey extends StatelessWidget {
  const _MoreKey({required this.action, required this.onTap});

  final HeadAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final look = headActionLook(L10n.of(context), action);
    return KeyedSubtree(
      key: look.moreKey,
      child: PrimaryButton(
        label: look.label,
        icon: look.icon,
        filled: false,
        height: KassaTokens.secondaryActionHeight,
        onPressed: onTap,
      ),
    );
  }
}
