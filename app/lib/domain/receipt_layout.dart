// Setzt einen gespeicherten Bon zu Druckzeilen fester Breite. Reines Dart,
// ohne Flutter und ohne Datenbank.

import '../rksv/setup_facts.dart';
import 'business_info.dart';
import 'cart.dart' show isDepositReturnItemId, isVoucherSaleItemId;
import 'customer.dart';
import 'pricing.dart';
import 'print_builder.dart';
import 'print_document.dart';
import 'receipt.dart';
import 'voucher.dart' show formatVoucherCode;

export 'print_builder.dart' show amount, printable;

String _optionText(ReceiptLineOption o) {
  if (o.surchargeCents == 0) return o.optionName;
  final sign = o.surchargeCents > 0 ? '+' : '';
  return '${o.optionName} ($sign${amount(o.surchargeCents)})';
}

String _taxText(TaxLine t) =>
    '${t.rate.percent} % MwSt ${amount(t.taxCents)}  '
    'Netto ${amount(t.netCents)}';

/// Setzt [r] zu Druckzeilen für Papier mit [columns] Zeichen je Zeile.
/// [voidedNumber] ist bei einem Storno-Bon die Nummer des stornierten Bons.
/// Mit [recipient] ist es die Rechnung: nach dem Kopf des Betriebs
/// "RECHNUNG", die Rechnungsnummer ([invoiceNumber]) und "An:" mit dem
/// Empfänger, dann der Bon, wie er ist (gleiche Nummer, gleicher QR-Code).
/// Ohne [recipient] ist jede Zeile wie vorher.
List<PrintOp> layoutReceipt(
  Receipt r,
  BusinessInfo business, {
  int columns = 48,
  int? voidedNumber,
  ReceiptRecipient? recipient,
}) {
  final b = PrintBuilder(columns);

  // 1. Kopf
  b.businessHead(business);
  final vatId = business.vatId;
  if (vatId != null && vatId.isNotEmpty) b.centered('UID $vatId');
  b.rule();

  // 2. Rechnung: Nummer und Empfänger
  if (recipient != null) {
    b.centered('RECHNUNG', bold: true);
    b.centered('Rechnung Nr. ${invoiceNumber(r)}');
    b.text('An:');
    b.indented(recipient.name);
    b.indented(recipient.addressLine1);
    b.indented(recipient.addressLine2);
    final customerVat = recipient.vatId;
    if (customerVat != null && customerVat.isNotEmpty) {
      b.indented('UID $customerVat');
    }
    b.rule();
  }

  // 3. Storno oder Sonderbeleg
  // Das Wort steht immer da, die Nummer des stornierten Bons nur, wenn sie
  // bekannt ist.
  final special = r.kind.specialTitle;
  if (r.kind == ReceiptKind.voided) {
    b.text('STORNO', align: PrintAlign.center, bold: true);
    if (voidedNumber != null) {
      b.text('zu Bon Nr. $voidedNumber', align: PrintAlign.center);
    }
  } else if (special != null) {
    b.text(special.toUpperCase(), align: PrintAlign.center, bold: true);
  }

  // 4. Bon-Kopf
  b.row('Bon Nr. ${r.number}', dateTimeText(r.createdAt));
  b.row('Bedienung: ${r.staffName}', '');
  final rksv = r.rksv;
  if (rksv != null) b.row('Kassen-ID: ${rksv.cashBoxId}', '');
  b.rule();

  // 5. Zeilen
  for (final line in r.lines) {
    final many = line.quantity > 1 || line.quantity < -1;
    // "Pfand zurück": der Betrag ist das Pfand der Zeile, nicht der
    // Warenwert 0.
    if (isDepositReturnItemId(line.itemId)) {
      b.row('${line.quantity} x ${line.name}', amount(line.depositCents));
      if (many) b.indented('je ${amount(line.unitDepositCents)}');
      continue;
    }
    // Ein Gutschein: der Code ("Code 1234 5678") eingerückt darunter.
    final voucherSale = isVoucherSaleItemId(line.itemId);
    final info = line.info;
    final label = voucherSale || info == null || info.isEmpty
        ? line.name
        : '${line.name} $info';
    b.row('${line.quantity} x $label', amount(line.goodsCents));
    if (voucherSale && info != null && info.isNotEmpty) b.indented(info);
    if (many) {
      b.indented('je ${amount(line.unitPriceCents)}');
    }
    for (final o in line.options) {
      b.indented(_optionText(o));
    }
    // Der eigene Rabatt der Zeile, nach ihren Optionen; einer über 0,00 €
    // steht nicht da.
    final discount = line.discount;
    if (discount != null && discount.amountCents != 0) {
      b.row('  ${discount.label}', amount(-discount.amountCents));
    }
  }

  // 6. Bon-Rabatt, Pfand und Summe. Ein Sonderbeleg hat keine Zeilen: die
  // Linie unter dem Bon-Kopf genügt.
  if (!r.kind.isSpecial) b.rule();
  final discount = r.discount;
  if (discount != null && discount.amountCents != 0) {
    b.row('Zwischensumme', amount(r.subtotalCents));
    b.row(discount.label, amount(-discount.amountCents));
  }
  // Nur das verlangte Pfand; das zurückgegebene steht bei seinen Zeilen.
  final depositAsked = r.depositAskedCents;
  if (depositAsked != 0) b.row('Pfand', amount(depositAsked));
  b.row(
    'SUMME EUR',
    amount(r.totalCents),
    bold: true,
    size: PrintSize.doubleHeight,
  );
  b.rule();

  // 7. Steuer
  for (final t in r.taxLines) {
    b.row(_taxText(t), amount(t.grossCents));
  }
  // Verkaufte Gutscheine zählen zum Satz 0, sind aber kein Umsatz. Der
  // Betrag steht schon in der Zeile zum Satz 0: eingerückt als "davon".
  final voucherSaleCents = r.voucherSaleCents;
  if (voucherSaleCents != 0) {
    b.row('  davon Gutschein (kein Umsatz)', amount(voucherSaleCents));
  }

  // 8. Zahlungen in ihrer Reihenfolge, bei Sonderbelegen keine. "Gegeben"
  // und "Rückgeld" nur, wenn die Bar-Zahlung die einzige ist, oder bei einem
  // Verkauf, wenn neben ihr nur Gutscheine bezahlen (keine Karte). Eine
  // Auszahlung (Summe unter 0, beim Storno darüber) heißt "Bar ausbezahlt",
  // mit dem Betrag ohne Minus (beim Storno mit), ohne "Gegeben".
  final payout = isPayoutReceipt(r);
  final given = givenChangePayment(r);
  for (final p in r.payments) {
    switch (p.kind) {
      case PaymentKind.cash when payout:
        b.row('Bar ausbezahlt', amount(-p.amountCents));
      case PaymentKind.cash:
        b.row('Bar', amount(p.amountCents));
        if (identical(p, given) && p.givenCents != p.amountCents) {
          b.row('Gegeben', amount(p.givenCents));
          b.row('Rückgeld', amount(p.changeCents));
        }
      case PaymentKind.card:
        // Was die Karte gebucht hat, mit dem Trinkgeld.
        b.row('Karte', amount(p.chargedCents));
        if (p.tipCents != 0) {
          b.row('  davon Trinkgeld', amount(p.tipCents));
        }
        final scheme = p.cardScheme;
        final last4 = p.cardLast4;
        if (last4 != null && last4.isNotEmpty) {
          b.indented(
            scheme == null || scheme.isEmpty
                ? '**** $last4'
                : '$scheme **** $last4',
          );
        }
        final tx = p.providerTxCode;
        if (tx != null && tx.isNotEmpty) b.indented('Beleg $tx');
      case PaymentKind.voucher:
        // Der ganze Code, darunter, was am Gutschein bleibt (beim Storno:
        // nach dem Storno).
        final code = p.voucherCode;
        b.row(
          code == null || code.isEmpty
              ? 'Gutschein'
              : 'Gutschein ${formatVoucherCode(code)}',
          amount(p.amountCents),
        );
        final left = p.voucherBalanceAfterCents;
        if (left != null) b.row('  Restguthaben', amount(left));
    }
  }

  // QR-Code der Signatur, bei Sonderbelegen nach der Summe
  if (rksv != null) {
    b.blank();
    b.ops.add(PrintQr(rksv.qrText));
    if (rksv.damaged) {
      b.text('Sicherheitseinrichtung ausgefallen', align: PrintAlign.center);
    }
  }

  // 9. Schlusstext
  final footer = business.receiptFooter;
  if (footer != null && footer.trim().isNotEmpty) {
    b.blank();
    b.centered(footer);
  }

  // 10. Testbon: ohne Eintrag im Protokoll und bei der Probe-Signatur
  if (isTestReceipt(r)) {
    b.blank();
    b.text('TESTBON', align: PrintAlign.center, bold: true);
    b.text('Keine gültige Rechnung', align: PrintAlign.center);
  }

  // 11. Ende
  b.ops
    ..add(const PrintFeed(3))
    ..add(const PrintCut());
  return b.ops;
}

/// Ob [r] eine Auszahlung ist: ein Verkauf mit Summe unter 0 oder der
/// Storno davon (Summe über 0).
bool isPayoutReceipt(Receipt r) => switch (r.kind) {
  ReceiptKind.sale => r.totalCents < 0,
  ReceiptKind.voided => r.totalCents > 0,
  _ => false,
};

/// Die Bar-Zahlung von [r], unter der "Gegeben" und "Rückgeld" stehen
/// dürfen (Papier und Bildschirm in "Bons"): die einzige Zahlung, wenn sie
/// bar ist, oder bei einem Verkauf die eine Bar-Zahlung, neben der nur
/// Gutscheine bezahlen (keine Karte). Bei einer Auszahlung keine, dort
/// steht "Bar ausbezahlt". Das Papier druckt die Reihen nur, wenn gegeben
/// nicht gleich dem Betrag ist.
Payment? givenChangePayment(Receipt r) {
  if (isPayoutReceipt(r)) return null;
  final cash = [
    for (final p in r.payments)
      if (p.kind == PaymentKind.cash) p,
  ];
  if (cash.length != 1) return null;
  if (r.payments.length == 1) return cash.single;
  final onlyVouchersBeside =
      r.kind == ReceiptKind.sale &&
      r.payments.every(
        (p) => p.kind == PaymentKind.cash || p.kind == PaymentKind.voucher,
      );
  return onlyVouchersBeside ? cash.single : null;
}

/// Ein Testdruck: Betrieb, Zeit, ein Lineal über die volle Breite und die
/// Umlaute.
List<PrintOp> layoutTestPrint(
  BusinessInfo business,
  DateTime now, {
  int columns = 48,
}) {
  final b = PrintBuilder(columns);
  b.text('Testdruck', align: PrintAlign.center, bold: true);
  b.centered(business.name);
  b.centered(dateTimeText(now));
  b.rule();
  b.text([for (var i = 1; i <= columns; i++) i % 10].join());
  b.text('ä ö ü ß € sind lesbar');
  b.ops
    ..add(const PrintFeed(3))
    ..add(const PrintCut());
  return b.ops;
}

/// Zettel "Angaben drucken" (Entwurf 6.7, Schritt 3): Überschrift, Betrieb,
/// Datum und Uhrzeit, dann je Angabe Name und Wert in eigenen Zeilen. Lange
/// Werte brechen um, der AES-Schlüssel steht in zwei Zeilen zu je 22
/// Zeichen. Kein QR-Code und kein TESTBON: Der Zettel ist kein Beleg.
List<PrintOp> layoutSetupFacts(
  SetupFacts facts,
  BusinessInfo business,
  DateTime now, {
  int columns = 48,
}) {
  final b = PrintBuilder(columns);
  void value(String s) {
    for (final line in wrapText(printable(s), columns, columns)) {
      b.text(line);
    }
  }

  void fact(String name, List<String> values) {
    value(name);
    values.forEach(value);
  }

  final key = facts.aesKeyBase64;
  final half = (key.length + 1) ~/ 2;
  b.centered('Angaben für FinanzOnline', bold: true);
  b.centered(business.name);
  b.centered(dateTimeText(now));
  b.rule();
  fact('Art der Sicherheitseinrichtung', [facts.kind]);
  fact('Anbieter', [facts.provider]);
  fact('Seriennummer des Zertifikats', [
    facts.certSerialHex,
    'dezimal ${facts.certSerialDecimal}',
  ]);
  fact('Kassenidentifikationsnummer', [facts.cashBoxId]);
  fact('AES-Schlüssel', [key.substring(0, half), key.substring(half)]);
  fact('Prüfwert', [facts.aesChecksum]);
  b.rule();
  value('Diesen Zettel sicher aufheben. Der AES-Schlüssel ist geheim.');
  b.ops
    ..add(const PrintFeed(3))
    ..add(const PrintCut());
  return b.ops;
}
