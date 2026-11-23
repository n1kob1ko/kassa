import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/german_dates.dart';
import '../../data/providers.dart';
import '../../domain/receipt.dart';
import '../../ui/segmented.dart';
import '../../ui/tokens.dart';
import 'receipt_detail.dart';
import 'receipt_list.dart';

export '../../core/german_dates.dart';

/// Der Bereich Bons: die Bons des offenen Tages links (neuester zuerst, mit
/// Filter), der gewählte Bon rechts in der festen Spalte. Ein Bon wird hier
/// nie geändert, nur durch einen Storno-Bon storniert.
class BonsScreen extends ConsumerStatefulWidget {
  const BonsScreen({super.key});

  @override
  ConsumerState<BonsScreen> createState() => _BonsScreenState();
}

class _BonsScreenState extends ConsumerState<BonsScreen> {
  BonFilter _filter = BonFilter.all;
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final all = ref.watch(todayReceiptsProvider).value;
    final now = ref.watch(clockProvider).now();
    // Der Untertitel nennt den Tag, dessen Bons die Liste zeigt.
    final opened = ref.watch(openDayStreamProvider).value?.openedAt ?? now;
    final isToday =
        opened.year == now.year &&
        opened.month == now.month &&
        opened.day == now.day;
    final dayLabel =
        '${germanWeekdays[opened.weekday - 1]} ${opened.day}. ${germanMonths[opened.month - 1]}';
    final newestFirst = [...?all?.reversed];
    final shown = [
      for (final r in newestFirst)
        if (_filter.matches(r)) r,
    ];
    Receipt? selected;
    for (final r in newestFirst) {
      if (r.id == _selectedId) selected = r;
    }
    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: KassaTokens.receiptHeaderHeight,
                  child: Row(
                    children: [
                      Text('Bons', style: text.headlineMedium),
                      const SizedBox(width: KassaTokens.spaceLg),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            isToday ? 'Heute, $dayLabel' : dayLabel,
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
                      Segmented<BonFilter>(
                        segments: [
                          for (final f in BonFilter.values) (f, f.label),
                        ],
                        selected: _filter,
                        keyFor: (f) => Key('filter-${f.id}'),
                        onSelected: (f) => setState(() => _filter = f),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: all == null
                      ? const SizedBox.shrink()
                      : ReceiptList(
                          receipts: shown,
                          selectedId: selected?.id,
                          onSelect: (r) => setState(() => _selectedId = r.id),
                          emptyText: newestFirst.isEmpty
                              ? 'Heute gibt es noch keine Bons.'
                              : 'Keine Bons mit diesem Filter.',
                        ),
                ),
              ],
            ),
          ),
        ),
        ReceiptDetail(
          key: ValueKey(selected?.id),
          receipt: selected,
          all: newestFirst,
        ),
      ],
    );
  }
}
