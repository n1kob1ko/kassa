import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/providers.dart';
import '../../data/settings_repository.dart';
import '../../domain/receipt.dart';
import '../../l10n/generated/l10n.dart';
import '../../ui/dates_text.dart';
import '../../ui/segmented.dart';
import '../../ui/tokens.dart';
import 'receipt_detail.dart';
import 'receipt_list.dart';

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
    final l = L10n.of(context);
    final all = ref.watch(todayReceiptsProvider).value;
    final now = ref.watch(clockProvider).now();
    // Der Untertitel nennt den Tag, dessen Bons die Liste zeigt.
    final opened = ref.watch(openDayStreamProvider).value?.openedAt ?? now;
    final isToday =
        opened.year == now.year &&
        opened.month == now.month &&
        opened.day == now.day;
    final dayLabel = l.bonsDayLabel(
      weekdayName(l, opened.weekday),
      opened.day,
      monthName(l, opened.month),
    );
    final newestFirst = [...?all?.reversed];
    // "Gutschein" nur, wenn Gutscheine an sind oder ein Bon des Tages mit
    // Gutschein bezahlt ist; sonst die Filter wie in 1.11.0.
    final settings =
        ref.watch(settingsStreamProvider).value ?? const RegisterSettings();
    final withVoucher =
        settings.voucherEnabled ||
        newestFirst.any(BonFilter.voucher.matches) ||
        _filter == BonFilter.voucher;
    final filters = [
      for (final f in BonFilter.values)
        if (f != BonFilter.voucher || withVoucher) f,
    ];
    final shown = [
      for (final r in newestFirst)
        if (_filter.matches(r)) r,
    ];
    final subtitle = Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Text(
        isToday ? l.bonsToday(dayLabel) : dayLabel,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: text.labelLarge!.copyWith(
          fontWeight: FontWeight.w600,
          color: c.ink2,
        ),
      ),
    );
    final segmented = Segmented<BonFilter>(
      segments: [for (final f in filters) (f, f.label(l))],
      selected: _filter,
      keyFor: (f) => Key('filter-${f.id}'),
      onSelected: (f) => setState(() => _filter = f),
    );
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
                      Text(l.bonsTitle, style: text.headlineMedium),
                      const SizedBox(width: KassaTokens.spaceLg),
                      if (!withVoucher) ...[
                        Expanded(child: subtitle),
                        const SizedBox(width: KassaTokens.spaceLg),
                        segmented,
                      ] else
                        // Mit dem fünften Filter passt der Umschalter bei
                        // schmaler Spalte und großer Schrift nicht immer:
                        // dann wischt man ihn.
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, box) => Row(
                              children: [
                                Expanded(child: subtitle),
                                const SizedBox(width: KassaTokens.spaceLg),
                                ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: math.max(
                                      0,
                                      box.maxWidth - KassaTokens.spaceLg,
                                    ),
                                  ),
                                  child: SingleChildScrollView(
                                    key: const Key('filter-scroll'),
                                    scrollDirection: Axis.horizontal,
                                    child: segmented,
                                  ),
                                ),
                              ],
                            ),
                          ),
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
                              ? l.bonsNoneToday
                              : l.bonsNoneForFilter,
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
