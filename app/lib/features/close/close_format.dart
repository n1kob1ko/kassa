import '../../core/money.dart';
import '../../domain/day.dart';

/// Name eines Grundes, wie er in Tasten und Zeilen steht.
String reasonLabel(CashReason r) => switch (r) {
  CashReason.bank => 'Bank',
  CashReason.purchase => 'Einkauf',
  CashReason.change => 'Wechselgeld',
  CashReason.other => 'Sonstiges',
};

String clockTime(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')} Uhr';

String bonsLabel(int n) => n == 1 ? '1 Bon' : '$n Bons';

/// Betrag mit Vorzeichen: "+1,00 €", "−0,20 €", "0,00 €".
String signedEuro(int cents) =>
    cents > 0 ? '+${formatEuro(cents)}' : formatEuro(cents);
