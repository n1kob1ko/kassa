// Ein gespeicherter Bon. Reines Dart und unveränderlich. Er trägt alles, was
// zum Anzeigen und Drucken nötig ist, ohne den Katalog zu brauchen.

import 'cart.dart' show isDepositReturnItemId, isVoucherSaleItemId;
import 'catalog.dart';
import 'discount.dart';
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

/// Art einer Zahlung. In Datenbank und Abgleich steht der Name als Text
/// (`cash`, `card`, `voucher`).
enum PaymentKind { cash, card, voucher }

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

/// Ein Rabatt am gespeicherten Bon: Prozent (leer bei festem Betrag), der
/// Betrag in Cent und der Grund als Name aus [DiscountReason]. Beim Storno
/// ist der Betrag negativ, Prozent und Grund bleiben.
class ReceiptDiscount {
  const ReceiptDiscount({
    this.percent,
    required this.amountCents,
    required this.reason,
  });

  final int? percent;
  final int amountCents;
  final String reason;

  /// "Rabatt 10 % Stammgast" oder bei festem Betrag "Rabatt Stammgast".
  /// Deutsch, für Bon und Berichte.
  String get label {
    final p = percent;
    final name = discountReasonLabel(reason);
    return p == null ? 'Rabatt $name' : 'Rabatt $p % $name';
  }
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
    this.discountCents = 0,
    this.discount,
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

  /// Brutto-Warenwert der Zeile je Steuersatz nach Rabatt, ohne Pfand.
  final Map<TaxRate, int> grossByRate;

  /// Der eigene Rabatt plus der Anteil am Bon-Rabatt; beim Storno negativ.
  final int discountCents;

  /// Der eigene Rabatt der Zeile, sonst `null`.
  final ReceiptDiscount? discount;

  /// Preis mal Menge, vor Rabatt.
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
    this.voucherId,
    this.voucherCode,
    this.voucherBalanceAfterCents,
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

  /// Nur bei [PaymentKind.voucher]: Kennung und Code des Gutscheins und das
  /// Guthaben nach dieser Zahlung.
  final String? voucherId;
  final String? voucherCode;
  final int? voucherBalanceAfterCents;

  /// Was die Karte gebucht hat: Anteil plus Trinkgeld.
  int get chargedCents => amountCents + tipCents;
}

/// Ein Gutschein, der auf diesem Bon verkauft wurde. [linePosition] ist die
/// Stelle seiner Zeile; beim Storno ist [valueCents] negativ.
class SoldVoucher {
  const SoldVoucher({
    required this.voucherId,
    required this.code,
    required this.valueCents,
    required this.linePosition,
  });

  final String voucherId;
  final String code;
  final int valueCents;
  final int linePosition;
}

/// Wie ein Bon bezahlt ist: nur bar, nur Karte oder beides. Gutscheine
/// zählen hier nicht mit.
enum ReceiptPaymentKind { cash, card, mixed }

/// Ob ein Bon in einer Kette der Art [chainMode] ein Übungs-Bon ist (`null`:
/// der Bon hat keinen Eintrag in einer Kette). Echt ist nur ein Bon in einer
/// Kette mit `live`; ohne Signatur und in einer Probe-Kette ist er ein
/// Übungs-Bon. Die einzige Stelle dieser Regel, für Abgleich und Gutscheine.
bool isTestChainMode(String? chainMode) => chainMode != 'live';

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
    this.discountCents = 0,
    this.discount,
    this.publicToken,
    List<SoldVoucher> soldVouchers = const [],
  }) : lines = List.unmodifiable(lines),
       payments = List.unmodifiable(payments),
       soldVouchers = List.unmodifiable(soldVouchers),
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

  /// Warenwert nach Rabatt, ohne Pfand: [goodsCents] plus [depositCents]
  /// ergibt [totalCents].
  final int goodsCents;
  final int depositCents;
  final int totalCents;

  /// Summe aller Rabatte (der Zeilen und des Bons), positiv; beim Storno
  /// negativ.
  final int discountCents;

  /// Der Rabatt auf den ganzen Bon, sonst `null`.
  final ReceiptDiscount? discount;

  /// Schlüssel der öffentlichen Seite des Bons, leer bei Sonderbelegen und
  /// bei Bons von vor 1.12.0.
  final String? publicToken;

  /// Die Gutscheine, die auf diesem Bon verkauft wurden.
  final List<SoldVoucher> soldVouchers;

  /// Die Zwischensumme: Warenwert nach den Rabatten der Zeilen, vor dem
  /// Bon-Rabatt.
  int get subtotalCents => goodsCents + (discount?.amountCents ?? 0);

  /// Summe der Zeilen, Sätze ohne Betrag fehlen.
  final Map<TaxRate, int> grossByRate;

  bool get isVoided => voidedByReceiptId != null;

  /// Die erste Bar-Zahlung, sonst `null`.
  Payment? get cashPayment => _first(PaymentKind.cash);

  /// Die Kartenzahlung, sonst `null`.
  Payment? get cardPayment => _first(PaymentKind.card);

  /// `null` bei Sonderbelegen. Sieht Gutschein-Zahlungen nicht.
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

  /// Summe der Gutschein-Zahlungen.
  int get voucherCents => _sumOf(PaymentKind.voucher);

  /// Summe der Gutschein-Zeilen (Preis mal Menge); beim Storno negativ.
  int get voucherSaleCents => lines.fold(
    0,
    (sum, l) => isVoucherSaleItemId(l.itemId) ? sum + l.goodsCents : sum,
  );

  /// Pfand der Zeilen "Pfand zurück": im Verkauf höchstens 0.
  int get depositReturnCents => lines.fold(
    0,
    (sum, l) => isDepositReturnItemId(l.itemId) ? sum + l.depositCents : sum,
  );

  /// Stück der Zeilen "Pfand zurück"; beim Storno negativ.
  int get depositReturnQuantity => lines.fold(
    0,
    (sum, l) => isDepositReturnItemId(l.itemId) ? sum + l.quantity : sum,
  );

  /// Das verlangte Pfand: [depositCents] ohne das zurückgegebene
  /// ([depositReturnCents]). Beim Storno negativ.
  int get depositAskedCents => depositCents - depositReturnCents;

  /// Umsatz: Summe des Bons ohne verkaufte Gutscheine.
  int get revenueCents => totalCents - voucherSaleCents;

  /// Die Arten der Zahlungen dieses Bons.
  Set<PaymentKind> get paymentKinds => {for (final p in payments) p.kind};

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
