// Die kleineren Teile der Übersicht: Kartenrahmen, Zahlungsarten,
// Meistverkauft, Kategorien und die ruhigen Platzhalter.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/money.dart';
import '../../domain/stats.dart';
import '../../l10n/generated/l10n.dart';
import '../../ui/ltr.dart';
import '../../ui/menu_text.dart';
import '../../ui/tokens.dart';

/// Weiße Karte mit Linie und Schatten, wie in den anderen Bereichen.
class OverviewCard extends StatelessWidget {
  const OverviewCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(KassaTokens.spaceHuge),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(KassaTokens.radiusCard),
        border: Border.all(color: c.line, width: KassaTokens.borderThin),
        boxShadow: c.cardShadow,
      ),
      child: child,
    );
  }
}

/// Dünner Balken: Bahn `fill2`, Füllung `accent`, [fraction] von 0 bis 1.
class ThinBar extends StatelessWidget {
  const ThinBar({super.key, required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(KassaTokens.radiusPill),
      child: SizedBox(
        height: 6,
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: c.fill2)),
            Positioned.fill(
              child: FractionallySizedBox(
                alignment: AlignmentDirectional.centerStart,
                widthFactor: fraction.clamp(0.0, 1.0),
                child: ColoredBox(color: c.accent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Anteil von [value] an [max] in 0 bis 1, mit ganzen Zahlen gerechnet bis auf
/// die letzte Division. Nie negativ.
double share(int value, int max) => max <= 0 || value <= 0 ? 0 : value / max;

class _MutedLine extends StatelessWidget {
  const _MutedLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.bodyMedium!.copyWith(
      fontWeight: FontWeight.w600,
      color: KassaColors.of(context).ink2,
    ),
  );
}

/// Zahlungsarten: ein geteilter Balken, darunter "Karte" und "Bar", dazu
/// "Gutschein", wenn mit Gutschein bezahlt wurde.
class PaymentsCard extends StatelessWidget {
  const PaymentsCard({
    super.key,
    required this.cashCents,
    required this.cardCents,
    this.voucherCents = 0,
    required this.empty,
  });

  final int cashCents;
  final int cardCents;
  final int voucherCents;
  final bool empty;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final l = L10n.of(context);
    final card = cardCents > 0 ? cardCents : 0;
    final cash = cashCents > 0 ? cashCents : 0;
    final voucher = voucherCents > 0 ? voucherCents : 0;
    final total = card + cash + voucher;
    return OverviewCard(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.overviewPayments, style: text.titleMedium),
          const SizedBox(height: 14),
          if (empty)
            _MutedLine(l.overviewNoReceipts)
          else ...[
            _SplitBar(card: card, cash: cash, voucher: voucher, total: total),
            const SizedBox(height: 14),
            _PaymentRow(
              color: c.solid,
              label: l.kassaCard,
              cents: cardCents,
              amountKey: const Key('payment-card-amount'),
            ),
            const SizedBox(height: 8),
            _PaymentRow(
              color: c.accent,
              label: l.kassaCash,
              cents: cashCents,
              amountKey: const Key('payment-cash-amount'),
            ),
            if (voucherCents != 0) ...[
              const SizedBox(height: 8),
              _PaymentRow(
                color: c.accentSoft,
                label: l.kassaVoucher,
                cents: voucherCents,
                amountKey: const Key('payment-voucher-amount'),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _SplitBar extends StatelessWidget {
  const _SplitBar({
    required this.card,
    required this.cash,
    this.voucher = 0,
    required this.total,
  });

  final int card;
  final int cash;
  final int voucher;
  final int total;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final radius = BorderRadius.circular(KassaTokens.radiusSm);
    if (total <= 0) {
      return Container(
        height: 30,
        decoration: BoxDecoration(color: c.fill2, borderRadius: radius),
      );
    }
    return SizedBox(
      height: 30,
      child: LayoutBuilder(
        builder: (context, box) {
          Widget part(int cents, Color fill, Color ink) {
            // Halb auf gerundeter Prozentwert, ganzzahlig.
            final percent = (cents * 200 + total) ~/ (2 * total);
            // Ein Spalt von 2 dp je Grenze (wie bisher mindestens einer).
            final gaps = voucher > 0 && card > 0 && cash > 0 ? 4 : 2;
            final width = (box.maxWidth - gaps) * cents / total;
            return Expanded(
              flex: cents,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                alignment: AlignmentDirectional.centerStart,
                decoration: BoxDecoration(color: fill, borderRadius: radius),
                child: width >= 56
                    ? Ltr(
                        child: Text(
                          '$percent %',
                          maxLines: 1,
                          style: Theme.of(context).textTheme.labelLarge!
                              .copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: ink,
                              ),
                        ),
                      )
                    : null,
              ),
            );
          }

          return Row(
            children: [
              if (card > 0) part(card, c.solid, c.solidInk),
              if (card > 0 && cash > 0) const SizedBox(width: 2),
              if (cash > 0) part(cash, c.accent, c.onAccent),
              if (voucher > 0 && card + cash > 0) const SizedBox(width: 2),
              if (voucher > 0) part(voucher, c.accentSoft, c.accentInk),
            ],
          );
        },
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({
    required this.color,
    required this.label,
    required this.cents,
    required this.amountKey,
  });

  final Color color;
  final String label;
  final int cents;
  final Key amountKey;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(KassaTokens.radiusXs),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: text.bodyLarge!.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        Ltr(
          child: Text(
            formatEuro(cents),
            key: amountKey,
            style: text.bodyLarge!.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

/// Meistverkauft: Name, dünner Balken relativ zur größten Menge, "21 ×" und
/// Betrag. Die Namen stehen in der Bediensprache.
class TopItemsCard extends ConsumerWidget {
  const TopItemsCard({super.key, required this.items});

  final List<ItemStat> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menuText = ref.watch(menuTextProvider);
    final text = Theme.of(context).textTheme;
    final l = L10n.of(context);
    final c = KassaColors.of(context);
    final maxQuantity = items.fold<int>(
      0,
      (m, i) => i.quantity > m ? i.quantity : m,
    );
    return OverviewCard(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.overviewTopItems, style: text.titleMedium),
          const SizedBox(height: 10),
          if (items.isEmpty)
            _MutedLine(l.overviewNoReceipts)
          else
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (final item in items)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                menuText(item.name),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: text.bodyLarge!.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ThinBar(
                                fraction: share(item.quantity, maxQuantity),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${item.quantity} ×',
                              style: text.bodyLarge!.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Ltr(
                              child: Text(
                                formatEuro(item.cents),
                                style: text.labelMedium!.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: c.ink2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// "Nach Kategorie": drei Spalten, jeder Eintrag mit Name, Betrag und
/// dünnem Balken relativ zum größten Eintrag. Die Namen stehen in der
/// Bediensprache.
class CategoryGrid extends StatelessWidget {
  const CategoryGrid({super.key, required this.categories});

  final List<CategoryStat> categories;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final maxCents = categories.fold<int>(
      0,
      (m, e) => e.cents > m ? e.cents : m,
    );
    final rows = <List<CategoryStat>>[
      for (var i = 0; i < categories.length; i += 3)
        categories.sublist(
          i,
          i + 3 > categories.length ? categories.length : i + 3,
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(L10n.of(context).overviewByCategory, style: text.titleMedium),
        const SizedBox(height: 10),
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: 24),
                  Expanded(
                    child: i < row.length
                        ? _CategoryEntry(row[i], maxCents)
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _CategoryEntry extends ConsumerWidget {
  const _CategoryEntry(this.stat, this.maxCents);

  final CategoryStat stat;
  final int maxCents;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                stat.deposit
                    ? L10n.of(context).bonsDeposit
                    : ref.watch(menuTextProvider)(stat.name),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.bodyMedium!.copyWith(fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(width: 8),
            Ltr(
              child: Text(
                formatEuro(stat.cents),
                style: text.bodyMedium!.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ThinBar(fraction: share(stat.cents, maxCents)),
      ],
    );
  }
}

/// Ruhiger Block in der Form einer Karte, solange die ersten Zahlen laden.
class PlaceholderBlock extends StatelessWidget {
  const PlaceholderBlock({super.key, this.height});

  final double? height;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    decoration: BoxDecoration(
      color: KassaColors.of(context).fill,
      borderRadius: BorderRadius.circular(KassaTokens.radiusMd),
    ),
  );
}
