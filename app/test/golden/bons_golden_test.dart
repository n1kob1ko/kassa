import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/app.dart';
import 'package:kassa/data/database.dart';
import 'package:kassa/data/providers.dart';
import 'package:kassa/domain/cart.dart';
import 'package:kassa/domain/receipt.dart';
import 'package:kassa/features/login/session.dart';
import 'package:material_ui/material_ui.dart';

import '../support/bons_pump.dart';
import '../support/cash_pump.dart' show setUpPrinter;
import '../support/demo_fixtures.dart';
import '../support/kassa_pump.dart' show containerOf;
import '../support/pump.dart' show memoryOverrides;
import '../support/signature_pump.dart';

// Bildvergleich des Bereichs Bons gegen den freigegebenen Entwurf. Neu
// erzeugen mit `flutter test --update-goldens test/golden/bons_golden_test.dart`.

/// Drei Barverkäufe, der mittlere ist gewählt.
Future<void> _threeReceipts(
  WidgetTester t, {
  Brightness brightness = Brightness.light,
}) async {
  await pumpBonsWithSales(t, 0, brightness: brightness);
  await sellCash(
    t,
    cart: const Cart.empty()
        .add(cola)
        .add(cola)
        .add(huhnBowl, options: [xxl, nudeln]),
  );
  await sellCash(t, cart: const Cart.empty().add(teigtaschen).add(cola));
  await sellCash(
    t,
    cart: const Cart.empty()
        .add(catalog.item('pommes'))
        .add(catalog.item('edamame'))
        .add(catalog.item('mochi')),
  );
  await t.pumpAndSettle();
  await openReceipt(t, 2);
}

void main() {
  testWidgets('Bons mit drei Bons, einer gewählt (hell)', (t) async {
    await _threeReceipts(t);
    expect(t.takeException(), isNull);
    await expectLater(
      find.byType(KassaApp),
      matchesGoldenFile('goldens/bons_liste_hell.png'),
    );
  });

  testWidgets('Rückfrage vor dem Storno (hell)', (t) async {
    await _threeReceipts(t);
    await t.tap(find.byKey(const Key('void-receipt')));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    await expectLater(
      find.byType(KassaApp),
      matchesGoldenFile('goldens/bons_storno_frage_hell.png'),
    );
  });

  testWidgets('Bons mit stornierter Auswahl (dunkel)', (t) async {
    await _threeReceipts(t, brightness: Brightness.dark);
    await t.tap(find.byKey(const Key('void-receipt')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('confirm-void')));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    await expectLater(
      find.byType(KassaApp),
      matchesGoldenFile('goldens/bons_storniert_dunkel.png'),
    );
  });

  for (final dark in [false, true]) {
    testWidgets('Bons mit Taste Drucken (${dark ? 'dunkel' : 'hell'})', (
      t,
    ) async {
      await _threeReceipts(
        t,
        brightness: dark ? Brightness.dark : Brightness.light,
      );
      await setUpPrinter(t);
      expect(t.takeException(), isNull);
      await expectLater(
        find.byType(KassaApp),
        matchesGoldenFile(
          'goldens/bons_drucken_${dark ? 'dunkel' : 'hell'}.png',
        ),
      );
    });
  }

  for (final dark in [false, true]) {
    testWidgets('Bon mit QR-Code der Probe-Signatur und ein Monatsbeleg '
        '(${dark ? 'dunkel' : 'hell'})', (t) async {
      await pumpBonsWithSales(
        t,
        0,
        brightness: dark ? Brightness.dark : Brightness.light,
        overrides: [...await memoryOverrides(), ...signatureOverrides()],
      );
      final sale = await sellCash(
        t,
        cart: const Cart.empty().add(teigtaschen).add(cola),
      );
      await seedProbe(t);
      await stampReceipt(t, sale.id);
      final c = containerOf(t);
      final db = c.read(databaseProvider);
      final staff = c.read(sessionProvider)!;
      await db
          .into(db.receiptRows)
          .insert(
            ReceiptRowsCompanion.insert(
              id: 'm1',
              number: 2,
              createdAt: c.read(clockProvider).now(),
              staffId: staff.id,
              staffName: staff.name,
              kind: ReceiptKind.month.name,
              goodsCents: 0,
              depositCents: 0,
              totalCents: 0,
            ),
          );
      await t.pumpAndSettle();
      await openReceipt(t, 1);
      expect(t.takeException(), isNull);
      await expectLater(
        find.byType(KassaApp),
        matchesGoldenFile('goldens/bons_qr_${dark ? 'dunkel' : 'hell'}.png'),
      );
    });
  }
}
