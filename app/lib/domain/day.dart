// Geschäftstag, Bargeld-Bewegungen und Tageszusammenfassung. Reines Dart.

import 'pricing.dart';

enum CashMovementKind { deposit, withdrawal }

/// Gespeichert und im Abgleich gesendet als [Enum.name]: neue Gründe kommen
/// ans Ende.
enum CashReason { bank, purchase, change, other, tip }

/// Name eines Grundes, wie er in Tasten und Zeilen steht.
String reasonLabel(CashReason r) => switch (r) {
  CashReason.bank => 'Bank',
  CashReason.purchase => 'Einkauf',
  CashReason.change => 'Wechselgeld',
  CashReason.other => 'Sonstiges',
  CashReason.tip => 'Trinkgeld',
};

class BusinessDay {
  const BusinessDay({
    required this.id,
    required this.openedAt,
    this.closedAt,
    this.openingFloatCents,
    this.countedCents,
    this.leftInDrawerCents,
    this.expectedCents,
    this.differenceCents,
    this.closedByName,
  });

  final String id;
  final DateTime openedAt;
  final DateTime? closedAt;

  /// `null`, solange das Wechselgeld des Tages nicht bekannt ist.
  final int? openingFloatCents;
  final int? countedCents;
  final int? leftInDrawerCents;
  final int? expectedCents;
  final int? differenceCents;
  final String? closedByName;

  bool get isOpen => closedAt == null;
}

class CashMovement {
  const CashMovement({
    required this.id,
    required this.kind,
    required this.amountCents,
    required this.reason,
    required this.createdAt,
    required this.staffName,
  });

  final String id;
  final CashMovementKind kind;
  final int amountCents;
  final CashReason reason;
  final DateTime createdAt;
  final String staffName;
}

/// Karten-Trinkgeld einer Person in einem Tag oder Zeitraum. Die Person
/// steht in der Zahlung ([staffId] ist ihre Id, [staffName] der Name der
/// spätesten Zahlung). Storno zieht bei derselben Person ab, deshalb kann
/// [cents] auch negativ sein.
class StaffTip {
  const StaffTip({
    required this.staffId,
    required this.staffName,
    required this.cents,
  });

  final String staffId;
  final String staffName;
  final int cents;

  @override
  bool operator ==(Object other) =>
      other is StaffTip &&
      other.staffId == staffId &&
      other.staffName == staffName &&
      other.cents == cents;

  @override
  int get hashCode => Object.hash(staffId, staffName, cents);

  @override
  String toString() => 'StaffTip($staffId, $staffName, $cents)';
}

class DaySummary {
  const DaySummary({
    required this.day,
    required this.receiptCount,
    required this.cashReceiptCount,
    required this.cardReceiptCount,
    required this.voidCount,
    required this.voidedCents,
    required this.revenueCents,
    required this.cashRevenueCents,
    required this.cardRevenueCents,
    required this.depositCents,
    required this.taxLines,
    required this.openingFloatCents,
    required this.cashInCents,
    required this.cashOutCents,
    required this.expectedCashCents,
    required this.movements,
    this.firstNumber,
    this.lastNumber,
    this.discountCount = 0,
    this.discountCents = 0,
    this.cardTipCents = 0,
    this.tipsByStaff = const [],
    this.voucherPaidCents = 0,
    this.voucherSoldCount = 0,
    this.voucherSoldCents = 0,
    this.depositReturnCount = 0,
    this.depositReturnCents = 0,
  });

  final BusinessDay day;

  /// Verkaufs-Bons minus Storno-Bons, die an diesem Tag gebucht wurden.
  final int receiptCount;

  /// Bons mit mindestens einer Zahlung bar bzw. mit Karte (Verkauf +1,
  /// Storno −1). Ein gemischter Bon zählt bei beiden, in [receiptCount] einmal.
  final int cashReceiptCount;
  final int cardReceiptCount;

  /// Anzahl der Storno-Bons und Summe der stornierten Bons (positiv).
  final int voidCount;
  final int voidedCents;

  /// Summe aller Bons des Tages, Storno negativ, mit Pfand, ohne Trinkgeld,
  /// ohne verkaufte Gutscheine.
  final int revenueCents;

  /// Summe der Zahlungen bar bzw. mit Karte, ohne Trinkgeld, Storno negativ.
  /// Sie enthalten das Geld für verkaufte Gutscheine und die Auszahlung von
  /// Pfand (mit Minus). Es gilt: bar + Karte + [voucherPaidCents] −
  /// [voucherSoldCents] = [revenueCents].
  final int cashRevenueCents;
  final int cardRevenueCents;
  final int depositCents;
  final List<TaxLine> taxLines;
  final int openingFloatCents;
  final int cashInCents;
  final int cashOutCents;

  /// Wechselgeld + Bar-Zahlungen + Einlagen - Entnahmen.
  final int expectedCashCents;

  /// Nach Zeit aufsteigend.
  final List<CashMovement> movements;

  /// Kleinste und größte Nummer der Verkaufs- und Storno-Bons des Tages,
  /// `null` ohne Bon.
  final int? firstNumber;
  final int? lastNumber;

  /// Bons mit Rabatt (Verkauf +1, Storno −1) und die Summe ihrer Rabatte,
  /// positiv; ein Storno zieht ab.
  final int discountCount;
  final int discountCents;

  /// Trinkgeld der Kartenzahlungen; ein Storno zieht ab.
  final int cardTipCents;

  /// Dasselbe je Person, nach Name; Personen mit 0 fehlen.
  final List<StaffTip> tipsByStaff;

  /// Mit Gutschein bezahlt (Summe der Gutschein-Zahlungen); ein Storno
  /// zieht ab.
  final int voucherPaidCents;

  /// Verkaufte Gutscheine (Anzahl und Summe); ein Storno zieht ab.
  final int voucherSoldCount;
  final int voucherSoldCents;

  /// Pfand zurück: Stück und ausbezahltes oder verrechnetes Pfand, positiv;
  /// ein Storno zieht ab.
  final int depositReturnCount;
  final int depositReturnCents;

  /// Was am Kartenkonto ankommt: Kartenumsatz und Trinkgeld.
  int get cardAccountCents => cardRevenueCents + cardTipCents;
}

/// Ab dieser Uhrzeit (am Kalendertag nach dem Beginn des Tages) gilt der
/// Abschluss als vergessen. Davor wird in Lokalen mit langen Öffnungszeiten
/// noch bedient.
const int forgottenCloseHour = 4;

/// Der Abschluss wurde vergessen: der offene Tag [open] begann an einem
/// früheren Kalendertag, und die Uhr ist an einem späteren Kalendertag über
/// [forgottenCloseHour] Uhr hinaus.
bool isForgottenClose(BusinessDay? open, DateTime now) {
  if (open == null) return false;
  final opened = open.openedAt;
  final cutoff = DateTime(
    opened.year,
    opened.month,
    opened.day + 1,
    forgottenCloseHour,
  );
  return !now.isBefore(cutoff);
}
