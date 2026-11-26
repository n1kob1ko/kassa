import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/money.dart';
import '../../domain/day.dart';
import '../../l10n/generated/l10n.dart';
import '../../ui/ltr.dart';
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
    this.onPrint,
    this.printing = false,
    this.printMessage,
    this.printFailed = false,
  });

  final BusinessDay day;
  final bool drawer;
  final bool justClosed;
  final VoidCallback onToKassa;

  /// "Bericht drucken"; ohne Wert (kein Drucker eingerichtet) gibt es die
  /// Taste und die Ergebniszeile nicht.
  final VoidCallback? onPrint;

  /// Ein Bericht ist unterwegs: die Taste ist gesperrt.
  final bool printing;

  /// Das Ergebnis des letzten Drucks ([printFailed]: der Fehlertext).
  final String? printMessage;
  final bool printFailed;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final l = L10n.of(context);
    final counted = day.countedCents ?? 0;
    final left = day.leftInDrawerCents ?? 0;
    final by = day.closedByName;
    final at = day.closedAt;
    final body = text.bodyLarge!.copyWith(fontSize: 17);
    return CloseColumn(
      title: l.closeDayClosed,
      content: [
        const SizedBox(height: KassaTokens.spaceHuge),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: c.green, shape: BoxShape.circle),
            child: Icon(LucideIcons.check, size: 34, color: c.card),
          ),
        ),
        const SizedBox(height: KassaTokens.spaceXxl),
        Text(
          justClosed ? l.closeDayIsClosed : l.closeNoOpenDay,
          style: text.headlineLarge!.copyWith(fontSize: 28),
        ),
        if (!justClosed) ...[
          const SizedBox(height: KassaTokens.spaceMd),
          Text(
            l.closeNextDayStarts,
            style: text.bodyMedium!.copyWith(
              fontWeight: FontWeight.w600,
              color: c.ink2,
            ),
          ),
        ],
        const SizedBox(height: KassaTokens.spaceHuge),
        Text(
          l.closeTakenOut(ltrIsolate(context, formatEuro(counted - left))),
          style: body,
        ),
        const SizedBox(height: KassaTokens.spaceMd),
        Text(
          drawer
              ? l.closeTomorrowDrawer(ltrIsolate(context, formatEuro(left)))
              : l.closeTomorrow(ltrIsolate(context, formatEuro(left))),
          style: body,
        ),
        if (by != null && at != null) ...[
          const SizedBox(height: KassaTokens.spaceXxl),
          Text(
            l.closeClosedBy(nameIsolateIn(context, by), clockTime(context, at)),
            style: text.bodySmall!.copyWith(
              fontWeight: FontWeight.w600,
              color: c.ink2,
            ),
          ),
        ],
      ],
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (onPrint != null) ...[
            if (printMessage != null) ...[
              PrintResult(
                key: const Key('day-report-result'),
                message: printMessage!,
                failed: printFailed,
              ),
              const SizedBox(height: KassaTokens.spaceXl),
            ],
            PrimaryButton(
              key: const Key('print-day-report'),
              label: l.closePrintReport,
              filled: false,
              icon: LucideIcons.printer,
              height: KassaTokens.mainActionHeight,
              onPressed: printing ? null : onPrint,
            ),
            const SizedBox(height: KassaTokens.spaceXl),
          ],
          PrimaryButton(
            key: const Key('to-kassa'),
            label: l.closeToKassa,
            solid: true,
            height: KassaTokens.mainActionHeight,
            onPressed: onToKassa,
          ),
        ],
      ),
    );
  }
}

/// Das Ergebnis eines Berichtsdrucks über der Taste (Tag und Monat): grün
/// "Bericht gedruckt." oder "Abrechnung gedruckt.", sonst der Fehlertext in
/// `red`.
class PrintResult extends StatelessWidget {
  const PrintResult({super.key, required this.message, required this.failed});

  final String message;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final fg = failed ? c.red : c.veganFg;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KassaTokens.spaceXxl,
        vertical: KassaTokens.spaceXl,
      ),
      decoration: BoxDecoration(
        color: failed ? c.spicyBg : c.veganBg,
        borderRadius: BorderRadius.circular(KassaTokens.radiusXl),
      ),
      child: Row(
        children: [
          Icon(
            failed ? LucideIcons.triangleAlert : LucideIcons.check,
            size: 20,
            color: fg,
          ),
          const SizedBox(width: KassaTokens.spaceLg),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium!
                  .copyWith(fontWeight: FontWeight.w700, color: fg),
            ),
          ),
        ],
      ),
    );
  }
}
