import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/money.dart';
import '../../data/providers.dart';
import '../../domain/stats.dart';
import '../../l10n/generated/l10n.dart';
import '../../ui/dates_text.dart';
import '../../ui/primary_button.dart';
import '../../ui/segmented.dart';
import '../../ui/tokens.dart';
import 'overview_cards.dart';
import 'revenue_chart.dart';

/// Zeiträume mit Text und dem Teil des Schlüssels `range-<id>`.
List<(StatsRange, String, String)> _ranges(L10n l) => [
  (StatsRange.today, l.overviewRangeToday, 'today'),
  (StatsRange.days7, l.overviewRange7, 'days7'),
  (StatsRange.days30, l.overviewRange30, 'days30'),
];

/// Der Bereich Übersicht (nur Chef): Umsatz, Balkendiagramm, Kategorien links,
/// Zahlungsarten und Meistverkauft in der festen Spalte rechts.
class OverviewScreen extends ConsumerStatefulWidget {
  const OverviewScreen({super.key});

  @override
  ConsumerState<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends ConsumerState<OverviewScreen> {
  StatsRange _range = StatsRange.today;
  int? _picked; // vom Tipp gewählter Balken, sonst der höchste
  Overview? _shown; // zuletzt geladene Zahlen, bleiben beim Umschalten stehen

  void _selectRange(StatsRange r) => setState(() {
    _range = r;
    _picked = null;
  });

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final l = L10n.of(context);
    final now = ref.watch(clockProvider).now();
    final async = ref.watch(overviewProvider(_range));
    final loaded = async.value;
    if (loaded != null) _shown = loaded;
    final data = _shown;

    final subtitle = switch (_range) {
      StatsRange.today => weekdayDayMonth(l, now),
      StatsRange.days7 => l.overviewLast7,
      StatsRange.days30 => l.overviewLast30,
    };

    final Widget body;
    if (async.hasError && loaded == null) {
      body = _LoadError(
        onRetry: () => ref.invalidate(overviewProvider(_range)),
      );
    } else if (data == null) {
      body = const _Placeholders();
    } else {
      body = _Content(
        data: data,
        range: _range,
        now: now,
        picked: _picked,
        onPick: (i) => setState(() => _picked = i),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: KassaTokens.receiptHeaderHeight,
            child: Row(
              children: [
                Text(l.overviewTitle, style: text.headlineMedium),
                const SizedBox(width: KassaTokens.spaceLg),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.labelLarge!.copyWith(
                        fontWeight: FontWeight.w600,
                        color: c.ink2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: KassaTokens.spaceLg),
                Segmented<StatsRange>(
                  segments: [
                    for (final (r, label, _) in _ranges(l)) (r, label),
                  ],
                  selected: _range,
                  keyFor: (r) => Key(
                    'range-${_ranges(l).firstWhere((e) => e.$1 == r).$3}',
                  ),
                  onSelected: _selectRange,
                ),
              ],
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({
    required this.data,
    required this.range,
    required this.now,
    required this.picked,
    required this.onPick,
  });

  final Overview data;
  final StatsRange range;
  final DateTime now;
  final int? picked;
  final ValueChanged<int> onPick;

  bool get _empty => data.receiptCount == 0 && data.voidCount == 0;

  int get _selected {
    final n = data.buckets.length;
    if (picked != null && picked! < n) return picked!;
    var best = 0;
    for (var i = 1; i < n; i++) {
      if (data.buckets[i].cents > data.buckets[best].cents) best = i;
    }
    return best;
  }

  String _bucketLabel(L10n l, Bucket b) {
    if (range == StatsRange.today) {
      return l.overviewHourRange(b.start.hour, b.start.hour + 1);
    }
    return weekdayDayMonth(l, b.start);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: _MainCard(this)),
        const SizedBox(width: KassaTokens.spaceXxl),
        SizedBox(
          width: 376,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PaymentsCard(
                cashCents: data.cashCents,
                cardCents: data.cardCents,
                empty: _empty,
              ),
              const SizedBox(height: KassaTokens.spaceXxl),
              Expanded(child: TopItemsCard(items: data.topItems)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Unterschied zum Zeitraum davor in ganzen Prozent (halb auf), oder `null`
/// ohne Vergleichswert.
int? comparisonPercent(Overview o) {
  final prev = o.previousRevenueCents;
  if (prev <= 0) return null;
  final diff = (o.revenueCents - prev).abs();
  return (diff * 200 + prev) ~/ (2 * prev); // halb auf
}

/// Vergleichstext, oder `null` ohne Vergleichswert.
String? comparisonText(L10n l, Overview o, StatsRange range, DateTime now) {
  final percent = comparisonPercent(o);
  if (percent == null) return null;
  final more = o.revenueCents > o.previousRevenueCents;
  if (range == StatsRange.today) {
    final weekday = weekdayName(l, now.weekday);
    if (percent == 0) return l.overviewSameAsWeekday(weekday);
    return more
        ? l.overviewMoreThanWeekday(percent, weekday)
        : l.overviewLessThanWeekday(percent, weekday);
  }
  final days = range == StatsRange.days7 ? 7 : 30;
  if (percent == 0) return l.overviewSameAsDaysBefore(days);
  return more
      ? l.overviewMoreThanDaysBefore(percent, days)
      : l.overviewLessThanDaysBefore(percent, days);
}

/// Pro Bon in ganzen Cent, halb auf.
int perReceiptCents(Overview o) => o.receiptCount <= 0 || o.revenueCents <= 0
    ? 0
    : (o.revenueCents * 2 + o.receiptCount) ~/ (2 * o.receiptCount);

class _MainCard extends StatelessWidget {
  const _MainCard(this.v);

  final _Content v;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final l = L10n.of(context);
    final data = v.data;
    final sel = v._selected;
    final selected = data.buckets.isEmpty || v._empty
        ? null
        : data.buckets[sel];
    return OverviewCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          l.overviewRevenue,
                          style: text.bodyLarge!.copyWith(
                            fontWeight: FontWeight.w600,
                            color: c.ink2,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: _ComparisonPill(
                            data: data,
                            range: v.range,
                            now: v.now,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatEuro(data.revenueCents),
                      key: const Key('revenue'),
                      maxLines: 1,
                      style: text.displayLarge!.copyWith(
                        fontSize: 56,
                        letterSpacing: -0.03 * 56,
                        fontFeatures: const [],
                      ),
                    ),
                  ],
                ),
              ),
              _Figure(
                l.overviewReceipts,
                '${data.receiptCount}',
                const Key('receipt-count'),
              ),
              const SizedBox(width: 28),
              _Figure(
                l.overviewPerReceipt,
                formatEuro(perReceiptCents(data)),
                const Key('per-receipt'),
              ),
              const SizedBox(width: 28),
              _Figure(
                l.overviewVoids,
                '${data.voidCount}',
                const Key('void-count'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Text(
                v.range == StatsRange.today
                    ? l.overviewPerHour
                    : l.overviewPerDay,
                style: text.titleMedium,
              ),
              const Spacer(),
              if (selected != null) ...[
                Text(
                  v._bucketLabel(l, selected),
                  key: const Key('bar-detail-label'),
                  style: text.bodyMedium!.copyWith(
                    fontWeight: FontWeight.w600,
                    color: c.ink2,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  formatEuro(selected.cents),
                  key: const Key('bar-detail'),
                  style: text.titleLarge,
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: v._empty
                ? Center(
                    child: Text(
                      l.overviewNoneInRange,
                      style: text.bodyMedium!.copyWith(
                        fontWeight: FontWeight.w600,
                        color: c.ink2,
                      ),
                    ),
                  )
                : RevenueChart(
                    key: ValueKey(v.range),
                    buckets: data.buckets,
                    selected: sel,
                    onSelect: v.onPick,
                    semanticLabelFor: (b) => l.overviewBarLabel(
                      v._bucketLabel(l, b),
                      formatEuro(b.cents),
                    ),
                  ),
          ),
          if (!v._empty) ...[
            const SizedBox(height: 12),
            Divider(height: 1, thickness: 1, color: c.line),
            const SizedBox(height: 16),
            CategoryGrid(categories: data.byCategory),
          ],
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure(this.label, this.value, this.valueKey);

  final String label;
  final String value;
  final Key valueKey;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: text.labelMedium!.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: c.ink2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          key: valueKey,
          style: text.headlineLarge!.copyWith(fontSize: 30),
        ),
      ],
    );
  }
}

class _ComparisonPill extends StatelessWidget {
  const _ComparisonPill({
    required this.data,
    required this.range,
    required this.now,
  });

  final Overview data;
  final StatsRange range;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final label = comparisonText(L10n.of(context), data, range, now);
    if (label == null) return const SizedBox.shrink();
    final c = KassaColors.of(context);
    final more = data.revenueCents > data.previousRevenueCents;
    final less = data.revenueCents < data.previousRevenueCents;
    final percentZero = comparisonPercent(data) == 0;
    final arrow = percentZero
        ? null
        : more
        ? LucideIcons.arrowUp
        : less
        ? LucideIcons.arrowDown
        : null;
    final bg = more && !percentZero ? c.veganBg : c.fill;
    final fg = more && !percentZero ? c.veganFg : c.ink;
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(KassaTokens.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (arrow != null) ...[
            Icon(arrow, size: 18, color: fg),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              key: const Key('comparison'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge!.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Placeholders extends StatelessWidget {
  const _Placeholders();

  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: OverviewCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: 260,
                    child: PlaceholderBlock(height: 56),
                  ),
                ),
                SizedBox(height: 24),
                Expanded(child: PlaceholderBlock()),
                SizedBox(height: 24),
                PlaceholderBlock(height: 72),
              ],
            ),
          ),
        ),
        SizedBox(width: KassaTokens.spaceXxl),
        SizedBox(
          width: 376,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OverviewCard(child: PlaceholderBlock(height: 96)),
              SizedBox(height: KassaTokens.spaceXxl),
              Expanded(child: OverviewCard(child: PlaceholderBlock())),
            ],
          ),
        ),
      ],
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final l = L10n.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l.overviewLoadFailed, style: text.titleMedium),
          const SizedBox(height: 16),
          SizedBox(
            width: 280,
            child: PrimaryButton(
              label: l.overviewRetry,
              onPressed: onRetry,
              muted: true,
              height: KassaTokens.minTap + 16,
            ),
          ),
        ],
      ),
    );
  }
}
