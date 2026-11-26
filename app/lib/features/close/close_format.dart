import '../../core/money.dart';
import '../../domain/day.dart';
import '../../l10n/generated/l10n.dart';

/// "14:32 Uhr" (Ziffern in jeder Sprache gleich).
String clockTime(L10n l, DateTime t) => l.closeClockTime(
  '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}',
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
};

/// Betrag mit Vorzeichen: "+1,00 €", "−0,20 €", "0,00 €".
String signedEuro(int cents) =>
    cents > 0 ? '+${formatEuro(cents)}' : formatEuro(cents);
