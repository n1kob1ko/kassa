// Helfer für Tests der Rechnung an Firma: eine Kassa im echten Betrieb (ein
// Testbon bekommt keine Rechnung), Rechnung an, Drucker und Lade
// eingerichtet.

import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/core/app_language.dart';
import 'package:kassa/data/providers.dart';
import 'package:kassa/domain/receipt.dart';
import 'package:material_ui/material_ui.dart';

import 'cash_pump.dart';
import 'kassa_pump.dart';
import 'pump.dart';
import 'signature_pump.dart';

/// Startet die Kassa (angemeldet [pin], Standard Anna), mit [live] in
/// Betrieb (Kette `live`, signiert mit der Attrappe), mit Rechnung an Firma,
/// Bondrucker und Lade, in [language]; tippt die Artikel [ids].
Future<void> openInvoiceKassa(
  WidgetTester t,
  List<String> ids, {
  bool live = true,
  AppLanguage language = AppLanguage.de,
  Size size = const Size(1280, 800),
  double textScale = 1.0,
  String pin = '1234',
}) async {
  await pumpKassa(
    t,
    size: size,
    textScale: textScale,
    pin: pin,
    overrides: [
      ...await memoryOverrides(),
      ...fakeSignatureOverrides(FakeSignatureUnit()),
    ],
  );
  if (live) await goLiveForInvoice(t);
  await setSettings(
    t,
    (s) => s.copyWith(
      language: language,
      invoiceEnabled: true,
      cashDrawerEnabled: true,
    ),
  );
  await setUpPrinter(t);
  for (final id in ids) {
    await tapItem(t, id);
  }
  await t.pumpAndSettle();
}

/// Nimmt die laufende Kassa in Betrieb (fester Stand, siehe [seedLive]).
Future<void> goLiveForInvoice(WidgetTester t) => seedLive(t);

/// Der Bon mit der höchsten Nummer.
Future<Receipt> lastReceipt(WidgetTester t) async {
  final id =
      (await queryRows(
            t,
            'SELECT id FROM receipts ORDER BY number DESC LIMIT 1',
          )).single['id']!
          as String;
  return containerOf(t).read(receiptRepositoryProvider).byId(id);
}
