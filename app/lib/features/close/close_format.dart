import '../../core/money.dart';

export '../../domain/day.dart' show reasonLabel;

String clockTime(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')} Uhr';

String bonsLabel(int n) => n == 1 ? '1 Bon' : '${groupThousands(n)} Bons';

/// Betrag mit Vorzeichen: "+1,00 €", "−0,20 €", "0,00 €".
String signedEuro(int cents) =>
    cents > 0 ? '+${formatEuro(cents)}' : formatEuro(cents);
