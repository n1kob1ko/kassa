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
  });

  final BusinessDay day;

  /// Verkaufs-Bons minus Storno-Bons, die an diesem Tag gebucht wurden.
  final int receiptCount;

  /// Wie [receiptCount], nur für Bons mit dieser Zahlungsart.
  final int cashReceiptCount;
  final int cardReceiptCount;

  /// Anzahl der Storno-Bons und Summe der stornierten Bons (positiv).
  final int voidCount;
  final int voidedCents;

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

/// Der Abschluss wurde vergessen: der offene Tag [open] begann an einem
/// früheren Kalendertag als [now].
bool isForgottenClose(BusinessDay? open, DateTime now) {
  if (open == null) return false;
  final opened = open.openedAt;
  return DateTime(opened.year, opened.month, opened.day)
      .isBefore(DateTime(now.year, now.month, now.day));
}
