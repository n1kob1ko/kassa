// Ein gespeicherter Bon. Reines Dart und unveränderlich. Er trägt alles, was
// zum Anzeigen und Drucken nötig ist, ohne den Katalog zu brauchen.

import 'catalog.dart';
import 'pricing.dart';

/// Verkauf, Storno-Bon oder ein Sonderbeleg der Signatur (Startbeleg bis
/// Schlussbeleg). Sonderbelege haben keinen Tag, keine Zahlung, Betrag 0.
enum ReceiptKind { sale, voided, start, month, year, zero, collective, closing }

extension ReceiptKindX on ReceiptKind {
  bool get isSpecial => specialTitle != null;

  /// Bezeichnung eines Sonderbelegs, sonst `null`.
  String? get specialTitle => switch (this) {
    ReceiptKind.sale || ReceiptKind.voided => null,
    ReceiptKind.start => 'Startbeleg',
    ReceiptKind.month => 'Monatsbeleg',
    ReceiptKind.year => 'Jahresbeleg',
    ReceiptKind.zero => 'Nullbeleg',
    ReceiptKind.collective => 'Sammelbeleg',
    ReceiptKind.closing => 'Schlussbeleg',
  };
}

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

/// Was das Protokoll der Signatur zu einem Bon weiß.
final class RksvStamp {
  const RksvStamp({
    required this.cashBoxId,
    required this.qrText,
    required this.damaged,
    required this.probe,
  });

  /// Kassen-Kennung der Kette.
  final String cashBoxId;

  /// Inhalt des QR-Codes.
  final String qrText;

  /// Wahr, wenn die Signatur beim Bon ausgefallen war.
  final bool damaged;

  /// Wahr bei der Probe-Signatur.
  final bool probe;
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
    this.rksv,
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

  /// Leer bei Sonderbelegen.
  final String? businessDayId;
  final ReceiptKind kind;

  /// Beim Storno-Bon der Bon, den er storniert.
  final String? voidsReceiptId;

  /// Der Storno-Bon, der auf diesen Bon zeigt, falls es einen gibt.
  final String? voidedByReceiptId;
  final List<ReceiptLine> lines;

  /// Leer bei Sonderbelegen.
  final Payment? payment;

  /// Leer, wenn der Bon keinen Protokoll-Eintrag hat.
  final RksvStamp? rksv;
  final int goodsCents;
  final int depositCents;
  final int totalCents;

  /// Summe der Zeilen, Sätze ohne Betrag fehlen.
  final Map<TaxRate, int> grossByRate;

  bool get isVoided => voidedByReceiptId != null;

  List<TaxLine> get taxLines => taxBreakdown(grossByRate);
}
