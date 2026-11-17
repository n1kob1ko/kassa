import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/money.dart';
import '../../domain/day.dart';
import '../../ui/primary_button.dart';
import '../../ui/tokens.dart';
import 'amount_entry.dart';
import 'close_format.dart' show clockTime;

/// Zustand E: der Tag ist abgeschlossen. Direkt nach dem Abschluss
/// ([justClosed]) mit der Bestätigung, sonst mit dem Hinweis, dass es keinen
/// offenen Tag gibt. Darunter, was entnommen wurde und was morgen in der Lade
/// liegt, und "Zur Kassa".
class DayClosedView extends StatelessWidget {
  const DayClosedView({
    super.key,
    required this.day,
    required this.drawer,
    required this.justClosed,
    required this.onToKassa,
  });

  final BusinessDay day;
  final bool drawer;
  final bool justClosed;
  final VoidCallback onToKassa;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final counted = day.countedCents ?? 0;
    final left = day.leftInDrawerCents ?? 0;
    final by = day.closedByName;
    final at = day.closedAt;
    final body = text.bodyLarge!.copyWith(fontSize: 17);
    return CloseColumn(
      title: 'Tag abgeschlossen',
      content: [
        const SizedBox(height: KassaTokens.spaceHuge),
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: c.green, shape: BoxShape.circle),
            child: Icon(LucideIcons.check, size: 34, color: c.card),
          ),
        ),
        const SizedBox(height: KassaTokens.spaceXxl),
        Text(
          justClosed ? 'Der Tag ist abgeschlossen.' : 'Es gibt keinen offenen Tag.',
          style: text.headlineLarge!.copyWith(fontSize: 28),
        ),
        if (!justClosed) ...[
          const SizedBox(height: KassaTokens.spaceMd),
          Text(
            'Der nächste Tag beginnt mit dem ersten Bon.',
            style: text.bodyMedium!.copyWith(
              fontWeight: FontWeight.w600,
              color: c.ink2,
            ),
          ),
        ],
        const SizedBox(height: KassaTokens.spaceHuge),
        Text('Entnommen: ${formatEuro(counted - left)}', style: body),
        const SizedBox(height: KassaTokens.spaceMd),
        Text(
          drawer
              ? 'Morgen liegen ${formatEuro(left)} Wechselgeld in der Lade.'
              : 'Morgen sind ${formatEuro(left)} Wechselgeld da.',
          style: body,
        ),
        if (by != null && at != null) ...[
          const SizedBox(height: KassaTokens.spaceXxl),
          Text(
            'Abgeschlossen von $by um ${clockTime(at)}',
            style: text.bodySmall!.copyWith(
              fontWeight: FontWeight.w600,
              color: c.ink2,
            ),
          ),
        ],
      ],
      bottom: PrimaryButton(
        key: const Key('to-kassa'),
        label: 'Zur Kassa',
        solid: true,
        height: KassaTokens.mainActionHeight,
        onPressed: onToKassa,
      ),
    );
  }
}
