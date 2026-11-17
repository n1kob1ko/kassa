// Geschäftstag, Bargeld-Bewegungen und Tageszusammenfassung. Reines Dart.

import 'pricing.dart';

enum CashMovementKind { deposit, withdrawal }

enum CashReason { bank, purchase, change, other }

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

class DaySummary {
  const DaySummary({
    required this.day,
    required this.receiptCount,
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
  });

  final BusinessDay day;

  /// Verkaufs-Bons minus Storno-Bons, die an diesem Tag gebucht wurden.
  final int receiptCount;

  /// Summe aller Bons des Tages, Storno negativ, mit Pfand.
  final int revenueCents;
  final int cashRevenueCents;
  final int cardRevenueCents;
  final int depositCents;
  final List<TaxLine> taxLines;
  final int openingFloatCents;
  final int cashInCents;
  final int cashOutCents;

  /// Wechselgeld + Bar-Einnahmen + Einlagen - Entnahmen.
  final int expectedCashCents;

  /// Nach Zeit aufsteigend.
  final List<CashMovement> movements;
}
