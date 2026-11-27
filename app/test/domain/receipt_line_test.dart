// ReceiptLine.withInfo: eine Kopie der Zeile mit anderem Hinweis, jedes
// andere Feld bleibt (so geht beim Gutschein-Code kein Feld verloren).

import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/domain/catalog.dart';
import 'package:kassa/domain/receipt.dart';

void main() {
  test('withInfo ändert nur den Hinweis', () {
    const discount = ReceiptDiscount(
      percent: 10,
      amountCents: 50,
      reason: 'promotion',
    );
    const option = ReceiptLineOption(
      groupName: 'Größe',
      optionName: 'Groß',
      surchargeCents: 100,
    );
    const line = ReceiptLine(
      position: 3,
      itemId: 'voucher-sale',
      name: 'Gutschein',
      unitPriceCents: 2500,
      quantity: 1,
      unitDepositCents: 7,
      options: [option],
      grossByRate: {TaxRate.zero: 2450},
      discountCents: 50,
      discount: discount,
    );
    final copy = line.withInfo('Code 1234 5678');
    expect(copy.info, 'Code 1234 5678');
    expect(
      (
        copy.position,
        copy.itemId,
        copy.name,
        copy.unitPriceCents,
        copy.quantity,
        copy.unitDepositCents,
        copy.discountCents,
      ),
      (3, 'voucher-sale', 'Gutschein', 2500, 1, 7, 50),
    );
    expect(identical(copy.options, line.options), isTrue);
    expect(identical(copy.grossByRate, line.grossByRate), isTrue);
    expect(identical(copy.discount, line.discount), isTrue);
  });
}
