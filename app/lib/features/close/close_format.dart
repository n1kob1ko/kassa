import 'package:material_ui/material_ui.dart';

import '../../core/money.dart';
import '../../domain/day.dart';
import '../../l10n/generated/l10n.dart';
import '../../ui/ltr.dart';

/// "14:32 Uhr" (Ziffern in jeder Sprache gleich, auch in einem arabischen
/// Satz von links nach rechts).
String clockTime(
  BuildContext context,
  DateTime t,
) => L10n.of(context).closeClockTime(
  ltrIsolate(
    context,
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}',
  ),
);

/// "1 Bon", "1.234 Bons".
String bonsLabel(L10n l, int n) => l.closeBonCount(n, groupThousands(n));

/// Name eines Grundes am Bildschirm ([reasonLabel] bleibt die deutsche
/// Fassung des Zettels).
String cashReasonText(L10n l, CashReason r) => switch (r) {
  CashReason.bank => l.closeReasonBank,
  CashReason.purchase => l.closeReasonPurchase,
  CashReason.change => l.closeReasonChange,
  CashReason.other => l.closeReasonOther,
  CashReason.tip => l.closeReasonTip,
};

/// Betrag mit Vorzeichen: "+1,00 €", "−0,20 €", "0,00 €".
String signedEuro(int cents) =>
    cents > 0 ? '+${formatEuro(cents)}' : formatEuro(cents);

/// Eine Anzahl ohne Wort ("3", "1.234"), mit echtem Minuszeichen wie
/// [formatEuro].
String countText(int n) => n < 0 ? '−${groupThousands(-n)}' : groupThousands(n);
