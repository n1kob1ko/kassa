// Setzt den Abschnitt eines verkauften Gutscheins zu Druckzeilen fester
// Breite (Spec 5.5). Immer Deutsch, wie der Kundenbon. Reines Dart, ohne
// Flutter und ohne Datenbank.

import 'business_info.dart';
import 'print_builder.dart';
import 'print_document.dart';
import 'receipt.dart';
import 'voucher.dart';

/// Der Abschnitt zu [voucher] für Papier mit [columns] Zeichen je Zeile:
/// Kopf des Betriebs wie am Bon, "GUTSCHEIN" fett und mittig, der Wert und
/// der Code ("1234 5678") in doppelter Höhe, das Datum des Verkaufs
/// ([soldAt]) und wo er gilt. Ein Übungs-Gutschein ([isTest]) trägt darunter
/// "ÜBUNG" und "Kein gültiger Gutschein". Am Ende Vorschub und Schnitt.
List<PrintOp> layoutVoucher(
  SoldVoucher voucher,
  BusinessInfo business, {
  required DateTime soldAt,
  required bool isTest,
  int columns = 48,
}) {
  final b = PrintBuilder(columns);

  b.businessHead(business);
  b.rule();

  b.blank();
  b.text('GUTSCHEIN', align: PrintAlign.center, bold: true);
  b.blank();
  b.text(
    '${amount(voucher.valueCents)} EUR',
    align: PrintAlign.center,
    bold: true,
    size: PrintSize.doubleHeight,
  );
  b.blank();
  b.text('Code', align: PrintAlign.center);
  b.text(
    formatVoucherCode(voucher.code),
    align: PrintAlign.center,
    bold: true,
    size: PrintSize.doubleHeight,
  );
  b.blank();
  b.centered(dateText(soldAt));
  b.centered('Einlösbar bei ${business.name}');

  if (isTest) {
    b.blank();
    b.text('ÜBUNG', align: PrintAlign.center, bold: true);
    b.text('Kein gültiger Gutschein', align: PrintAlign.center);
  }

  b.ops
    ..add(const PrintFeed(3))
    ..add(const PrintCut());
  return b.ops;
}
