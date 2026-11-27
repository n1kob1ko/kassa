// Der Abschnitt eines verkauften Gutscheins: Kopf des Betriebs, "GUTSCHEIN",
// Wert und Code groß, Datum, wo er gilt; ein Übungs-Gutschein trägt den
// Vermerk. Immer Deutsch.

import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/domain/business_info.dart';
import 'package:kassa/domain/print_document.dart';
import 'package:kassa/domain/receipt.dart';
import 'package:kassa/domain/voucher_layout.dart';

const business = BusinessInfo(
  name: 'Beispiel-Imbiss',
  addressLines: ['Musterstraße 1', '1010 Wien'],
  vatId: 'ATU12345678',
  receiptFooter: 'Danke und bis bald!',
);

List<String> linesOf(List<PrintOp> ops) => [
  for (final o in ops)
    if (o is PrintText) o.text,
];

PrintText _lineWith(List<PrintOp> ops, String text) =>
    ops.whereType<PrintText>().firstWhere((o) => o.text.contains(text));

const _sold = SoldVoucher(
  voucherId: 'v',
  code: '12345678',
  valueCents: 2500,
  linePosition: 2,
);

void main() {
  test('Abschnitt Gutschein: Betrieb, GUTSCHEIN, Wert, Code in Gruppen, '
      'Datum; Übung trägt den Vermerk', () {
    final ops = layoutVoucher(
      _sold,
      business,
      soldAt: DateTime(2026, 11, 27, 12, 3),
      isTest: false,
    );
    expect(
      linesOf(ops),
      containsAllInOrder([
        contains('Beispiel-Imbiss'),
        contains('GUTSCHEIN'),
        contains('25,00'),
        contains('1234 5678'),
        contains('27.11.2026'),
      ]),
    );
    expect(linesOf(ops).join('\n'), isNot(contains('ÜBUNG')));
    expect(ops.last, isA<PrintCut>());

    final test = layoutVoucher(
      _sold,
      business,
      soldAt: DateTime(2026, 11, 27, 12, 3),
      isTest: true,
    );
    expect(
      linesOf(test),
      containsAllInOrder([
        contains('GUTSCHEIN'),
        contains('1234 5678'),
        contains('ÜBUNG'),
        contains('Kein gültiger Gutschein'),
      ]),
    );
    expect(test.last, isA<PrintCut>());
  });

  test('GUTSCHEIN fett und mittig, Wert und Code in doppelter Höhe, '
      '"Einlösbar bei" mit dem Namen des Betriebs', () {
    final ops = layoutVoucher(
      _sold,
      business,
      soldAt: DateTime(2026, 11, 27, 12, 3),
      isTest: false,
    );
    final title = _lineWith(ops, 'GUTSCHEIN');
    expect(title.bold, isTrue);
    expect(title.align, PrintAlign.center);
    expect(_lineWith(ops, '25,00').size, PrintSize.doubleHeight);
    expect(_lineWith(ops, '1234 5678').size, PrintSize.doubleHeight);
    expect(linesOf(ops), contains(contains('Code')));
    expect(linesOf(ops), contains(contains('Einlösbar bei Beispiel-Imbiss')));
    // Kein Bon: keine UID, kein Schlusstext, kein TESTBON.
    expect(linesOf(ops).join('\n'), isNot(contains('TESTBON')));
    expect(linesOf(ops).join('\n'), isNot(contains('Danke und bis bald!')));
    // Jede Zeile passt in die Breite.
    for (final columns in [32, 48]) {
      for (final line in linesOf(
        layoutVoucher(
          _sold,
          business,
          soldAt: DateTime(2026, 11, 27),
          isTest: true,
          columns: columns,
        ),
      )) {
        expect(line.length, lessThanOrEqualTo(columns), reason: line);
      }
    }
  });
}
