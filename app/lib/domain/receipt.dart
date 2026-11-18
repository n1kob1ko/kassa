// Ein gespeicherter Bon. Reines Dart und unveränderlich. Er trägt alles, was
// zum Anzeigen und Drucken nötig ist, ohne den Katalog zu brauchen.

import 'catalog.dart';
import 'pricing.dart';

enum ReceiptKind { sale, voided }

enum PaymentKind { cash, card }

class ReceiptLineOption {
  const ReceiptLineOption({
    required this.groupName,
    required this.optionName,
    required this.surchargeCents,
  });

  final String groupName;
  final String optionName;
  final int surchargeCents;
}

class ReceiptLine {
  const ReceiptLine({
    required this.position,
    required this.itemId,
    required this.name,
    this.info,
    required this.unitPriceCents,
    required this.quantity,
    required this.unitDepositCents,
    this.options = const [],
    this.grossByRate = const {},
  });

  final int position;
  final String itemId;
  final String name;
  final String? info;

  /// Einzelpreis inklusive Aufpreisen der Optionen.
  final int unitPriceCents;

  /// Beim Storno-Bon negativ.
  final int quantity;
  final int unitDepositCents;
  final List<ReceiptLineOption> options;

  /// Brutto-Warenwert der Zeile je Steuersatz, ohne Pfand.
  final Map<TaxRate, int> grossByRate;

  int get goodsCents => unitPriceCents * quantity;

  int get depositCents => unitDepositCents * quantity;
}

class Payment {
  const Payment({
    required this.kind,
    required this.amountCents,
    required this.givenCents,
    required this.changeCents,
    this.provider,
    this.providerTxCode,
    this.cardScheme,
    this.cardLast4,
  });

  final PaymentKind kind;
  final int amountCents;
  final int givenCents;
  final int changeCents;

  /// Nur bei Kartenzahlung: Anbieter, dessen Beleg-Code, Kartenart und die
  /// letzten vier Ziffern (soweit bekannt).
  final String? provider;
  final String? providerTxCode;
  final String? cardScheme;
  final String? cardLast4;
}

class Receipt {
  Receipt({
    required this.id,
    required this.number,
    required this.createdAt,
    required this.staffId,
    required this.staffName,
    required this.businessDayId,
    required this.kind,
    this.voidsReceiptId,
    this.voidedByReceiptId,
    required List<ReceiptLine> lines,
    required this.payment,
    required this.goodsCents,
    required this.depositCents,
    required this.totalCents,
  }) : lines = List.unmodifiable(lines),
       grossByRate = Map.unmodifiable(
         sumByRate([for (final l in lines) l.grossByRate]),
       );

  final String id;
  final int number;
  final DateTime createdAt;
  final String staffId;
  final String staffName;
  final String businessDayId;
  final ReceiptKind kind;

  /// Beim Storno-Bon der Bon, den er storniert.
  final String? voidsReceiptId;

  /// Der Storno-Bon, der auf diesen Bon zeigt, falls es einen gibt.
  final String? voidedByReceiptId;
  final List<ReceiptLine> lines;
  final Payment payment;
  final int goodsCents;
  final int depositCents;
  final int totalCents;

  /// Summe der Zeilen, Sätze ohne Betrag fehlen.
  final Map<TaxRate, int> grossByRate;

  bool get isVoided => voidedByReceiptId != null;

  List<TaxLine> get taxLines => taxBreakdown(grossByRate);
}
