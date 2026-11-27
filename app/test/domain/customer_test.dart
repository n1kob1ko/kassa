// Rechnung an Firma (Spec 5.3): Prüfung des Empfängers, Rechnungsnummer,
// Anfangsbuchstaben und wann die Taste "Rechnung an Firma" steht.

import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/domain/customer.dart';
import 'package:kassa/domain/receipt.dart';

Receipt _receipt({
  int number = 1042,
  ReceiptKind kind = ReceiptKind.sale,
  String? voidedBy,
  int total = 1820,
  List<SoldVoucher> soldVouchers = const [],
  RksvStamp? rksv = const RksvStamp(
    cashBoxId: 'KASSA-1',
    qrText: 'qr',
    damaged: false,
    probe: false,
  ),
}) => Receipt(
  id: 'r',
  number: number,
  createdAt: DateTime(2026, 11, 27, 11),
  staffId: 's',
  staffName: 'Anna',
  businessDayId: 'd',
  kind: kind,
  voidedByReceiptId: voidedBy,
  lines: const [],
  payments: const [],
  rksv: rksv,
  goodsCents: total,
  depositCents: 0,
  totalCents: total,
  soldVouchers: soldVouchers,
);

void main() {
  test('checkRecipient: Pflichtfelder, UID erst über 10.000 €, Längen', () {
    Set<RecipientProblem> c({
      String n = 'Muster GmbH',
      String a1 = 'Musterweg 1',
      String a2 = '1010 Wien',
      String v = '',
      int total = 1820,
    }) => checkRecipient(
      name: n,
      addressLine1: a1,
      addressLine2: a2,
      vatId: v,
      receiptTotalCents: total,
    );
    expect(c(), isEmpty);
    expect(c(n: '  '), {RecipientProblem.nameMissing});
    expect(c(a2: ''), {RecipientProblem.addressMissing});
    expect(c(total: 1000000), isEmpty);
    expect(c(total: 1000001), {RecipientProblem.vatIdMissing});
    expect(c(total: 1000001, v: 'ATU00000000'), isEmpty);
    expect(c(n: 'x' * 81), {RecipientProblem.tooLong});
  });

  test('checkRecipient: Grenzen genau, Leerzeichen zählen nicht, mehrere '
      'Probleme zugleich', () {
    Set<RecipientProblem> c({
      String n = 'Muster GmbH',
      String a1 = 'Musterweg 1',
      String a2 = '1010 Wien',
      String v = '',
      int total = 1820,
    }) => checkRecipient(
      name: n,
      addressLine1: a1,
      addressLine2: a2,
      vatId: v,
      receiptTotalCents: total,
    );
    expect(c(n: 'x' * customerTextMax), isEmpty);
    expect(c(n: '  ${'x' * customerTextMax}  '), isEmpty);
    expect(c(a1: 'x' * 81), {RecipientProblem.tooLong});
    expect(c(a2: 'x' * 81), {RecipientProblem.tooLong});
    expect(c(v: 'x' * customerVatIdMax), isEmpty);
    expect(c(v: 'x' * 21), {RecipientProblem.tooLong});
    expect(c(a1: ' '), {RecipientProblem.addressMissing});
    expect(c(n: '', a1: '', a2: '', total: 1000001), {
      RecipientProblem.nameMissing,
      RecipientProblem.addressMissing,
      RecipientProblem.vatIdMissing,
    });
    expect(c(v: '   ', total: 1000001), {RecipientProblem.vatIdMissing});
  });

  test('invoiceNumber: Kassen-ID und Bon-Nummer, ohne Kassen-ID nur die '
      'Nummer', () {
    expect(invoiceNumber(_receipt()), 'KASSA-1 / 1042');
    expect(invoiceNumber(_receipt(rksv: null)), '1042');
  });

  test(
    'customerInitial: erster Buchstabe groß, Ziffern und Zeichen unter #',
    () {
      expect(customerInitial('Muster GmbH'), 'M');
      expect(customerInitial('  muster GmbH'), 'M');
      expect(customerInitial('Ötztal Bau'), 'Ö');
      expect(customerInitial('1. Wiener Bau'), '#');
      expect(customerInitial('"Beispiel" KG'), '#');
      expect(customerInitial('&Co'), '#');
      expect(customerInitial(''), '#');
    },
  );

  test('invoiceAllowed: nur ein Verkauf, der gilt und kein Testbon ist', () {
    expect(invoiceAllowed(_receipt()), isTrue);
    expect(invoiceAllowed(_receipt(kind: ReceiptKind.voided)), isFalse);
    expect(invoiceAllowed(_receipt(voidedBy: 'storno')), isFalse);
    expect(invoiceAllowed(_receipt(kind: ReceiptKind.start)), isFalse);
    expect(invoiceAllowed(_receipt(kind: ReceiptKind.month)), isFalse);
    expect(invoiceAllowed(_receipt(rksv: null)), isFalse);
    expect(
      invoiceAllowed(
        _receipt(
          rksv: const RksvStamp(
            cashBoxId: 'KASSA-1',
            qrText: 'qr',
            damaged: false,
            probe: true,
          ),
        ),
      ),
      isFalse,
    );
    // Ausgefallene Signatur im echten Betrieb: der Bon gilt.
    expect(
      invoiceAllowed(
        _receipt(
          rksv: const RksvStamp(
            cashBoxId: 'KASSA-1',
            qrText: 'qr',
            damaged: true,
            probe: false,
          ),
        ),
      ),
      isTrue,
    );
  });

  test('invoiceAllowed: keine Rechnung bei Summe 0 oder darunter; ein Bon '
      'mit verkauftem Gutschein und Summe über 0 bekommt eine', () {
    expect(invoiceAllowed(_receipt(total: 1)), isTrue);
    expect(invoiceAllowed(_receipt(total: 0)), isFalse);
    // Eine Auszahlung (Pfand zurück, Summe unter 0).
    expect(invoiceAllowed(_receipt(total: -150)), isFalse);
    expect(
      invoiceAllowed(
        _receipt(
          total: 2500,
          soldVouchers: const [
            SoldVoucher(
              voucherId: 'v',
              code: '12345678',
              valueCents: 2500,
              linePosition: 0,
            ),
          ],
        ),
      ),
      isTrue,
    );
  });
}
