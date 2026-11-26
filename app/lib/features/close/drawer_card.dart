import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/money.dart';
import '../../domain/day.dart';
import '../../l10n/generated/l10n.dart';
import '../../ui/pressable.dart';
import '../../ui/tokens.dart';
import '../overview/overview_cards.dart' show OverviewCard;
import 'close_format.dart';
import 'summary_rows.dart';

class DrawerCard extends StatelessWidget {
  const DrawerCard({
    super.key,
    required this.summary,
    required this.drawer,
    required this.movement,
    required this.canMove,
    required this.onCashIn,
    required this.onCashOut,
  });

  final DaySummary summary;
  final bool drawer;
  final bool canMove;
  final CashMovementKind? movement;
  final VoidCallback onCashIn;
  final VoidCallback onCashOut;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final l = L10n.of(context);
    final s = summary;
    final day = s.day;
    final closed = !day.isOpen;
    final floatKnown = day.openingFloatCents != null;
    final diff = day.differenceCents;
    return OverviewCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Text(
                  drawer ? l.closeDrawer : l.closeCash,
                  style: text.titleLarge,
                ),
                if (canMove)
                  Expanded(
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      spacing: KassaTokens.spaceLg,
                      runSpacing: KassaTokens.spaceMd,
                      children: [
                        _MoveButton(
                          key: const Key('cash-in'),
                          label: l.closeCashIn,
                          icon: LucideIcons.plus,
                          open: movement == CashMovementKind.deposit,
                          onTap: onCashIn,
                        ),
                        _MoveButton(
                          key: const Key('cash-out'),
                          label: l.closeCashOut,
                          icon: LucideIcons.minus,
                          open: movement == CashMovementKind.withdrawal,
                          onTap: onCashOut,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          SummaryLine(
            label: l.closeFloatMorning,
            amount: floatKnown
                ? formatEuro(day.openingFloatCents!)
                : l.closeStillOpen,
            amountMuted: !floatKnown,
            amountKey: const Key('left-float'),
          ),
          SummaryLine(
            label: l.closeCashTakings,
            amount: formatEuro(s.cashRevenueCents),
            amountKey: const Key('left-cash'),
          ),
          for (final m in s.movements)
            SummaryLine(
              label: m.kind == CashMovementKind.deposit
                  ? l.closeDeposited(cashReasonText(l, m.reason))
                  : l.closeWithdrawn(cashReasonText(l, m.reason)),
              middle: clockTime(context, m.createdAt),
              amount: formatEuro(
                m.kind == CashMovementKind.deposit
                    ? m.amountCents
                    : -m.amountCents,
              ),
            ),
          SummaryLine(
            label: drawer ? l.closeExpectedDrawer : l.closeExpectedCash,
            amount: formatEuro(s.expectedCashCents),
            bold: true,
            amountKey: const Key('left-expected'),
          ),
          SummaryLine(
            label: l.closeCounted,
            amount: closed
                ? formatEuro(day.countedCents ?? 0)
                : l.closeStillOpen,
            amountMuted: !closed,
            amountKey: const Key('left-counted'),
          ),
          SummaryLine(
            label: l.closeDifference,
            amount: closed && diff != null
                ? (diff == 0 ? formatEuro(0) : signedEuro(diff))
                : null,
            amountColor: diff == 0 ? c.green : c.red,
            amountKey: const Key('left-difference'),
          ),
        ],
      ),
    );
  }
}

class _MoveButton extends StatelessWidget {
  const _MoveButton({
    super.key,
    required this.label,
    required this.icon,
    required this.open,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final fg = open ? c.accentInk : c.ink;
    return Pressable(
      onTap: onTap,
      child: Semantics(
        selected: open,
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: open ? c.accentSoft : c.card,
            borderRadius: BorderRadius.circular(KassaTokens.radiusXl),
            border: Border.all(
              color: open ? c.accent : c.line,
              width: KassaTokens.borderButton,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: fg),
              const SizedBox(width: KassaTokens.spaceLg),
              Text(
                label,
                maxLines: 1,
                style: Theme.of(context).textTheme.bodyMedium!
                    .copyWith(fontWeight: FontWeight.w700, color: fg),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
