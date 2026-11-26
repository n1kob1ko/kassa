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
    this.position = 0,
    required this.kind,
    required this.amountCents,
    required this.givenCents,
    required this.changeCents,
    this.tipCents = 0,
    this.tipStaffId,
    this.tipStaffName,
    this.provider,
    this.providerTxCode,
    this.cardScheme,
    this.cardLast4,
  });

  /// Stelle der Zahlung im Bon, ab 0.
  final int position;
  final PaymentKind kind;

  /// Anteil an der Summe des Bons, ohne Trinkgeld.
  final int amountCents;
  final int givenCents;
  final int changeCents;

  /// Nur bei Karte ungleich 0.
  final int tipCents;

  /// Wem das Trinkgeld gehört, leer ohne Trinkgeld.
  final String? tipStaffId;
  final String? tipStaffName;

  /// Nur bei Kartenzahlung: Anbieter, dessen Beleg-Code, Kartenart und die
  /// letzten vier Ziffern (soweit bekannt).
  final String? provider;
  final String? providerTxCode;
  final String? cardScheme;
  final String? cardLast4;

  /// Was die Karte gebucht hat: Anteil plus Trinkgeld.
  int get chargedCents => amountCents + tipCents;
}

/// Wie ein Bon bezahlt ist: nur bar, nur Karte oder beides.
enum ReceiptPaymentKind { cash, card, mixed }

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
    required List<Payment> payments,
    this.rksv,
    required this.goodsCents,
    required this.depositCents,
    required this.totalCents,
  }) : lines = List.unmodifiable(lines),
       payments = List.unmodifiable(payments),
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

  /// Die Zahlungen nach Stelle, leer bei Sonderbelegen.
  final List<Payment> payments;

  /// Leer, wenn der Bon keinen Protokoll-Eintrag hat.
  final RksvStamp? rksv;
  final int goodsCents;
  final int depositCents;
  final int totalCents;

  /// Summe der Zeilen, Sätze ohne Betrag fehlen.
  final Map<TaxRate, int> grossByRate;

  bool get isVoided => voidedByReceiptId != null;

  /// Die erste Bar-Zahlung, sonst `null`.
  Payment? get cashPayment => _first(PaymentKind.cash);

  /// Die Kartenzahlung, sonst `null`.
  Payment? get cardPayment => _first(PaymentKind.card);

  /// `null` bei Sonderbelegen.
  ReceiptPaymentKind? get paymentKind {
    final cash = cashPayment != null, card = cardPayment != null;
    if (cash && card) return ReceiptPaymentKind.mixed;
    if (cash) return ReceiptPaymentKind.cash;
    if (card) return ReceiptPaymentKind.card;
    return null;
  }

  /// Summe der Bar-Anteile.
  int get cashCents => _sumOf(PaymentKind.cash);

  /// Summe der Karten-Anteile, ohne Trinkgeld.
  int get cardCents => _sumOf(PaymentKind.card);

  /// Summe der Trinkgelder.
  int get tipCents => payments.fold(0, (sum, p) => sum + p.tipCents);

  Payment? _first(PaymentKind kind) {
    for (final p in payments) {
      if (p.kind == kind) return p;
    }
    return null;
  }

  int _sumOf(PaymentKind kind) =>
      payments.fold(0, (sum, p) => p.kind == kind ? sum + p.amountCents : sum);

  List<TaxLine> get taxLines => taxBreakdown(grossByRate);
}
