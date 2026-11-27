// Rechnung an Firma am Tablet (Spec 5.3): nach dem Bezahlen auf "Verkauf
// fertig" oder im Detail eines Bons einen Firmenkunden wählen oder eintragen;
// der Bon wird als Rechnung noch einmal gedruckt. Der Bon und seine Signatur
// bleiben, wie sie sind; jede Fassung des Empfängers bleibt gespeichert.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/data/customer_repository.dart';
import 'package:kassa/data/providers.dart';
import 'package:kassa/domain/catalog.dart';
import 'package:kassa/domain/customer.dart';
import 'package:kassa/features/kassa/cart_controller.dart';
import 'package:kassa/rksv/rksv_providers.dart';
import 'package:kassa/sync/wire.dart' show WireCustomer;
import 'package:kassa/ui/app_toggle.dart';
import 'package:kassa/ui/primary_button.dart';
import 'package:kassa/ui/tokens.dart';
import 'package:material_ui/material_ui.dart';

import '../support/cash_pump.dart';
import '../support/invoice_pump.dart';
import '../support/kassa_pump.dart';
import '../support/pump.dart';
import '../support/signature_pump.dart';

Finder _key(String key) => find.byKey(Key(key));

Future<void> _tap(WidgetTester t, String key) async {
  await t.ensureVisible(_key(key));
  await t.pumpAndSettle();
  await t.tap(_key(key));
  await t.pumpAndSettle();
}

bool _enabled(WidgetTester t, String key) =>
    t.widget<PrimaryButton>(_key(key)).onPressed != null;

CustomerRepository _customers(WidgetTester t) =>
    containerOf(t).read(customerRepositoryProvider);

/// Bar und passend bezahlen, bis "Verkauf fertig".
Future<void> _payCash(WidgetTester t) async {
  await _tap(t, 'pay-cash');
  await _tap(t, 'finish-sale');
  expect(_key('next-customer'), findsOneWidget);
}

/// Die vier Felder des Formulars ausfüllen.
Future<void> _fill(
  WidgetTester t, {
  String name = 'Muster GmbH',
  String address1 = 'Musterweg 1',
  String address2 = '1010 Wien',
  String vat = '',
}) async {
  await t.enterText(_key('customer-name'), name);
  await t.enterText(_key('customer-address1'), address1);
  await t.enterText(_key('customer-address2'), address2);
  await t.enterText(_key('customer-vat'), vat);
  await t.pumpAndSettle();
}

void main() {
  testWidgets('Verkauf fertig: Rechnung an Firma, Neuer Kunde, drucken: '
      'Empfänger gespeichert, Ausdruck trägt RECHNUNG und den Namen', (
    t,
  ) async {
    await openInvoiceKassa(t, ['cola']);
    await _payCash(t);
    final receipt = await lastReceipt(t);
    final receiptRow = await queryRows(
      t,
      "SELECT * FROM receipts WHERE id = '${receipt.id}'",
    );
    final protocol = await queryRows(t, 'SELECT * FROM rksv_entries');
    final jobs = printerOf(t).printedJobs.length;
    final drawer = printerOf(t).drawerOpened;

    expect(_key('invoice-hint'), findsNothing);
    await _tap(t, 'invoice-button');
    expect(_key('customer-picker'), findsOneWidget);
    expect(find.text('Noch kein Firmenkunde gespeichert.'), findsOneWidget);
    await _tap(t, 'customer-new');
    expect(_key('customer-form'), findsOneWidget);
    await _fill(t);
    await _tap(t, 'customer-save');
    expect(_key('customer-form'), findsNothing);
    expect(textOf(t, const Key('invoice-recipient')), 'Muster GmbH');
    expect(_key('invoice-button'), findsNothing);
    await _tap(t, 'invoice-print');

    expect(
      await queryRows(
        t,
        'SELECT version, name, address_line1, address_line2, '
        'customer_id IS NOT NULL AS kept FROM receipt_recipients',
      ),
      [
        {
          'version': 0,
          'name': 'Muster GmbH',
          'address_line1': 'Musterweg 1',
          'address_line2': '1010 Wien',
          'kept': 1,
        },
      ],
    );
    expect(
      printerOf(t).lastText,
      allOf(contains('RECHNUNG'), contains('Muster GmbH')),
    );
    expect(
      printerOf(t).lastText,
      contains('Rechnung Nr. ${receipt.rksv!.cashBoxId} / ${receipt.number}'),
    );
    // Ein Auftrag, der Bon selbst; keine Lade, kein Küchenbon.
    expect(printerOf(t).printedJobs.sublist(jobs), [
      (kind: 'receipt', id: receipt.id),
    ]);
    expect(printerOf(t).drawerOpened, drawer);
    expect(find.text('Rechnung gedruckt.'), findsOneWidget);
    // Der Firmenkunde ist gespeichert und gilt als zuletzt verwendet.
    final saved = (await _customers(t).list()).single;
    expect(saved.name, 'Muster GmbH');
    expect(saved.lastUsedAt, isNotNull);
    // Der Bon und das Protokoll sind unverändert.
    expect(
      await queryRows(t, "SELECT * FROM receipts WHERE id = '${receipt.id}'"),
      receiptRow,
    );
    expect(await queryRows(t, 'SELECT * FROM rksv_entries'), protocol);
    expect(
      await queryRows(
        t,
        "SELECT kind FROM outbox WHERE kind IN ('customer', 'recipient') "
        'ORDER BY id',
      ),
      [
        {'kind': 'customer'},
        {'kind': 'recipient'},
      ],
    );
  });

  testWidgets('gespeicherten Kunden wählen: ein Tipp, kein Formular; '
      'Anfangsbuchstabe filtert', (t) async {
    await openInvoiceKassa(t, ['cola']);
    final repo = _customers(t);
    final muster = await repo.save(
      name: 'Muster GmbH',
      addressLine1: 'Musterweg 1',
      addressLine2: '1010 Wien',
      vatId: 'ATU00000000',
    );
    final beispiel = await repo.save(
      name: 'beispiel KG',
      addressLine1: 'Beispielgasse 2',
      addressLine2: '1020 Wien',
    );
    final digit = await repo.save(
      name: '1. Wiener Bau',
      addressLine1: 'Musterweg 3',
      addressLine2: '1030 Wien',
    );
    await _payCash(t);
    await _tap(t, 'invoice-button');

    for (final key in [
      'customer-initial-all',
      'customer-initial-B',
      'customer-initial-M',
      'customer-initial-#',
    ]) {
      expect(_key(key), findsOneWidget, reason: key);
    }
    expect(_key('customer-initial-W'), findsNothing);
    // Name und erste Adress-Zeile.
    expect(
      find.descendant(
        of: _key('customer-row-${muster.id}'),
        matching: find.text('Musterweg 1'),
      ),
      findsOneWidget,
    );
    for (final c in [muster, beispiel, digit]) {
      expect(_key('customer-row-${c.id}'), findsOneWidget);
    }

    await _tap(t, 'customer-initial-M');
    expect(_key('customer-row-${muster.id}'), findsOneWidget);
    expect(_key('customer-row-${beispiel.id}'), findsNothing);
    expect(_key('customer-row-${digit.id}'), findsNothing);
    await _tap(t, 'customer-initial-#');
    expect(_key('customer-row-${digit.id}'), findsOneWidget);
    expect(_key('customer-row-${muster.id}'), findsNothing);
    await _tap(t, 'customer-initial-all');
    expect(_key('customer-row-${beispiel.id}'), findsOneWidget);

    await _tap(t, 'customer-row-${muster.id}');
    expect(_key('customer-form'), findsNothing);
    expect(_key('customer-picker'), findsNothing);
    expect(textOf(t, const Key('invoice-recipient')), 'Muster GmbH');
    expect(
      await queryRows(
        t,
        'SELECT version, customer_id, vat_id FROM receipt_recipients',
      ),
      [
        {'version': 0, 'customer_id': muster.id, 'vat_id': 'ATU00000000'},
      ],
    );
    await _tap(t, 'invoice-print');
    expect(printerOf(t).lastText, contains('UID ATU00000000'));

    // Beim nächsten Mal steht der zuletzt verwendete oben.
    await _tap(t, 'next-customer');
    await tapItem(t, 'cola');
    await t.pumpAndSettle();
    await _payCash(t);
    await _tap(t, 'invoice-button');
    final rows = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('customer-row-'),
    );
    expect(
      (t.widget(rows.first).key! as ValueKey<String>).value,
      'customer-row-${muster.id}',
    );
  });

  testWidgets('"Als Firmenkunde speichern" aus: Empfänger ohne Firmenkunde', (
    t,
  ) async {
    await openInvoiceKassa(t, ['cola']);
    await _payCash(t);
    await _tap(t, 'invoice-button');
    await _tap(t, 'customer-new');
    await _fill(t);
    await _tap(t, 'customer-keep');
    await _tap(t, 'customer-save');
    expect(
      await queryRows(
        t,
        'SELECT version, name, customer_id FROM receipt_recipients',
      ),
      [
        {'version': 0, 'name': 'Muster GmbH', 'customer_id': null},
      ],
    );
    expect(await queryRows(t, 'SELECT id FROM customers'), isEmpty);
    expect(
      await queryRows(t, "SELECT kind FROM outbox WHERE kind = 'customer'"),
      isEmpty,
    );
    expect(textOf(t, const Key('invoice-recipient')), 'Muster GmbH');
  });

  testWidgets('Ändern: zweite Fassung, die erste bleibt, gedruckt wird die '
      'letzte', (t) async {
    await openInvoiceKassa(t, ['cola']);
    await _payCash(t);
    await _tap(t, 'invoice-button');
    await _tap(t, 'customer-new');
    await _fill(t, address1: 'Musterwg 1');
    await _tap(t, 'customer-save');

    await _tap(t, 'invoice-change');
    expect(_key('customer-form'), findsOneWidget);
    // Die Werte der letzten Fassung stehen da.
    expect(find.text('Muster GmbH'), findsOneWidget);
    expect(find.text('Musterwg 1'), findsOneWidget);
    expect(find.text('1010 Wien'), findsOneWidget);
    await t.enterText(_key('customer-address1'), 'Musterweg 1');
    await t.pumpAndSettle();
    await _tap(t, 'customer-save');
    await _tap(t, 'invoice-print');

    expect(
      await queryRows(
        t,
        'SELECT version, address_line1 FROM receipt_recipients '
        'ORDER BY version',
      ),
      [
        {'version': 0, 'address_line1': 'Musterwg 1'},
        {'version': 1, 'address_line1': 'Musterweg 1'},
      ],
    );
    expect(printerOf(t).lastText, contains('Musterweg 1'));
    expect(printerOf(t).lastText, isNot(contains('Musterwg 1')));
    // "Ändern" ändert keinen Firmenkunden: er bleibt, wie er war, und die
    // neue Fassung hängt an keinem.
    final saved = (await _customers(t).list()).single;
    expect(saved.addressLine1, 'Musterwg 1');
    expect(
      await queryRows(
        t,
        'SELECT version, customer_id IS NULL AS free FROM receipt_recipients '
        'ORDER BY version',
      ),
      [
        {'version': 0, 'free': 0},
        {'version': 1, 'free': 1},
      ],
    );
  });

  /// Kunde A gespeichert, bar bezahlt, A gewählt, "Ändern" offen; liefert A
  /// und seine Zeile in `customers` und die Einträge `customer` vorher.
  Future<
    ({
      Customer a,
      List<Map<String, Object?>> row,
      List<Map<String, Object?>> outbox,
    })
  >
  changeAfterWrongPick(WidgetTester t) async {
    await openInvoiceKassa(t, ['cola']);
    final a = await _customers(t).save(
      name: 'Muster GmbH',
      addressLine1: 'Musterweg 1',
      addressLine2: '1010 Wien',
    );
    final row = await queryRows(
      t,
      'SELECT name, address_line1, address_line2, vat_id, updated_at '
      "FROM customers WHERE id = '${a.id}'",
    );
    await _payCash(t);
    await _tap(t, 'invoice-button');
    await _tap(t, 'customer-row-${a.id}');
    final outbox = await queryRows(
      t,
      "SELECT ref, rev FROM outbox WHERE kind = 'customer' ORDER BY id",
    );
    await _tap(t, 'invoice-change');
    expect(_key('customer-form'), findsOneWidget);
    await t.enterText(_key('customer-name'), 'Beispiel KG');
    await t.enterText(_key('customer-address1'), 'Beispielgasse 2');
    await t.enterText(_key('customer-address2'), '1020 Wien');
    await t.pumpAndSettle();
    return (a: a, row: row, outbox: outbox);
  }

  testWidgets('falschen Kunden gewählt, "Ändern" mit den Daten eines anderen: '
      'der gespeicherte Kunde bleibt, die neue Fassung hat keinen', (t) async {
    final (:a, :row, :outbox) = await changeAfterWrongPick(t);
    // Aus "Ändern" ist "Als Firmenkunde speichern" aus.
    expect(t.widget<AppToggle>(_key('customer-keep')).value, isFalse);
    await _tap(t, 'customer-save');

    expect(
      await queryRows(
        t,
        'SELECT name, address_line1, address_line2, vat_id, updated_at '
        "FROM customers WHERE id = '${a.id}'",
      ),
      row,
    );
    expect(await queryRows(t, 'SELECT id FROM customers'), hasLength(1));
    expect(
      await queryRows(
        t,
        "SELECT ref, rev FROM outbox WHERE kind = 'customer' ORDER BY id",
      ),
      outbox,
    );
    expect(
      await queryRows(
        t,
        'SELECT version, name, address_line1, customer_id '
        'FROM receipt_recipients ORDER BY version',
      ),
      [
        {
          'version': 0,
          'name': 'Muster GmbH',
          'address_line1': 'Musterweg 1',
          'customer_id': a.id,
        },
        {
          'version': 1,
          'name': 'Beispiel KG',
          'address_line1': 'Beispielgasse 2',
          'customer_id': null,
        },
      ],
    );
  });

  testWidgets('"Ändern" mit "Als Firmenkunde speichern" an: ein neuer '
      'Firmenkunde, der gewählte bleibt', (t) async {
    final (:a, :row, :outbox) = await changeAfterWrongPick(t);
    await _tap(t, 'customer-keep');
    await _tap(t, 'customer-save');

    expect(
      await queryRows(
        t,
        'SELECT name, address_line1, address_line2, vat_id, updated_at '
        "FROM customers WHERE id = '${a.id}'",
      ),
      row,
    );
    final others = await queryRows(
      t,
      "SELECT id, name FROM customers WHERE id <> '${a.id}'",
    );
    expect(others, hasLength(1));
    expect(others.single['name'], 'Beispiel KG');
    final b = others.single['id']! as String;
    expect(
      await queryRows(
        t,
        'SELECT version, customer_id FROM receipt_recipients ORDER BY version',
      ),
      [
        {'version': 0, 'customer_id': a.id},
        {'version': 1, 'customer_id': b},
      ],
    );
    // Kein neuer Eintrag für A, einer für den neuen.
    expect(
      await queryRows(
        t,
        "SELECT ref, rev FROM outbox WHERE kind = 'customer' "
        "AND ref = '${a.id}'",
      ),
      [
        for (final r in outbox)
          if (r['ref'] == a.id) r,
      ],
    );
    expect(
      await queryRows(
        t,
        "SELECT ref FROM outbox WHERE kind = 'customer' AND ref = '$b'",
      ),
      hasLength(1),
    );
  });

  testWidgets('Übungsmodus (Probe-Signatur): auf "Verkauf fertig" und in '
      '"Bons" keine Rechnung an Firma und kein Hinweis', (t) async {
    await openInvoiceKassa(t, const [], live: false);
    // Ohne AES-Schlüssel entstünde kein Eintrag im Protokoll.
    await containerOf(t)
        .read(rksvSecretsProvider)
        .writeAesKey(1, Uint8List(32));
    await seedProbe(t);
    containerOf(t)
        .read(cartProvider.notifier)
        .addOpenAmount(
          amountCents: invoiceHintAboveCents + 100,
          rate: TaxRate.normal,
        );
    await t.pumpAndSettle();
    await _payCash(t);
    final receipt = await lastReceipt(t);
    expect(receipt.rksv?.probe, isTrue);
    expect(_key('invoice-button'), findsNothing);
    expect(_key('invoice-hint'), findsNothing);
    await _tap(t, 'next-customer');
    await _tap(t, 'tab-Bons');
    await _tap(t, 'receipt-${receipt.number}');
    expect(_key('invoice-button'), findsNothing);
  });

  testWidgets('im Detail eines Bons; fehlt bei Storno, storniertem Bon, '
      'Testbon und bei Schalter aus', (t) async {
    // Bon 1 entsteht vor der Inbetriebnahme: ein Testbon.
    await openInvoiceKassa(t, ['cola'], live: false);
    await _payCash(t);
    await _tap(t, 'next-customer');
    await goLiveForInvoice(t);
    await tapItem(t, 'cola');
    await t.pumpAndSettle();
    await _payCash(t);
    await _tap(t, 'next-customer');
    await _customers(t).save(
      name: 'Muster GmbH',
      addressLine1: 'Musterweg 1',
      addressLine2: '1010 Wien',
    );

    await _tap(t, 'tab-Bons');
    await _tap(t, 'receipt-1');
    expect(_key('invoice-button'), findsNothing);
    await _tap(t, 'receipt-2');
    expect(_key('invoice-button'), findsOneWidget);
    await _tap(t, 'invoice-button');
    expect(_key('customer-picker'), findsOneWidget);
    final muster = (await _customers(t).list()).single;
    await _tap(t, 'customer-row-${muster.id}');
    expect(textOf(t, const Key('invoice-recipient')), 'Muster GmbH');
    final jobs = printerOf(t).printedJobs.length;
    final drawer = printerOf(t).drawerOpened;
    await _tap(t, 'invoice-print');
    expect(printerOf(t).printedJobs.length, jobs + 1);
    expect(printerOf(t).lastText, contains('RECHNUNG'));
    expect(printerOf(t).drawerOpened, drawer);
    expect(find.text('Rechnung gedruckt.'), findsOneWidget);

    // Schalter aus: weder Taste noch Empfänger.
    await setSettings(t, (s) => s.copyWith(invoiceEnabled: false));
    expect(_key('invoice-button'), findsNothing);
    expect(_key('invoice-recipient'), findsNothing);
    expect(_key('invoice-print'), findsNothing);
    await setSettings(t, (s) => s.copyWith(invoiceEnabled: true));

    // Stornieren: der stornierte Bon und der Storno-Bon haben keine Taste.
    await _tap(t, 'void-receipt');
    await _tap(t, 'confirm-void');
    expect(_key('invoice-button'), findsNothing);
    expect(_key('invoice-print'), findsNothing);
    await _tap(t, 'receipt-3');
    expect(_key('invoice-button'), findsNothing);
  });

  testWidgets('Summe über 400 €: Hinweis auf Verkauf fertig, weg sobald ein '
      'Empfänger da ist', (t) async {
    await openInvoiceKassa(t, const []);
    containerOf(t)
        .read(cartProvider.notifier)
        .addOpenAmount(
          amountCents: invoiceHintAboveCents,
          rate: TaxRate.normal,
        );
    await t.pumpAndSettle();
    await _payCash(t);
    // Genau 400,00 €: kein Hinweis.
    expect(_key('invoice-hint'), findsNothing);
    await _tap(t, 'next-customer');

    containerOf(t)
        .read(cartProvider.notifier)
        .addOpenAmount(
          amountCents: invoiceHintAboveCents + 1,
          rate: TaxRate.normal,
        );
    await t.pumpAndSettle();
    await _payCash(t);
    expect(
      textOf(t, const Key('invoice-hint')),
      'Über 400 €: Eine Rechnung braucht Name und Adresse des Kunden.',
    );
    await _tap(t, 'invoice-button');
    await _tap(t, 'customer-new');
    await _fill(t);
    await _tap(t, 'customer-save');
    expect(_key('invoice-hint'), findsNothing);
    expect(_key('invoice-recipient'), findsOneWidget);
  });

  testWidgets('Formular: Übernehmen grau mit dem Grund unter dem Feld, '
      'angesagt; Grenzen ohne Abschneiden; UID erst über 10.000 €', (t) async {
    final semantics = t.ensureSemantics();
    await openInvoiceKassa(t, const []);
    final cart = containerOf(t).read(cartProvider.notifier);
    cart.addOpenAmount(amountCents: 600000, rate: TaxRate.normal);
    cart.addOpenAmount(amountCents: 400001, rate: TaxRate.normal);
    await t.pumpAndSettle();
    await _payCash(t);
    await _tap(t, 'invoice-button');
    await _tap(t, 'customer-new');

    expect(_enabled(t, 'customer-save'), isFalse);
    expect(
      textOf(t, const Key('customer-name-problem')),
      'Bitte den Namen eintragen.',
    );
    expect(
      t.getSemantics(_key('customer-name-problem')),
      isSemantics(label: 'Bitte den Namen eintragen.', isLiveRegion: true),
    );
    // Die Beschriftung steht sichtbar über dem Feld.
    expect(find.text('Name der Firma'), findsOneWidget);
    expect(
      t.getRect(find.text('Name der Firma')).bottom,
      lessThanOrEqualTo(t.getRect(_key('customer-name')).top),
    );

    final long = 'M' * (customerTextMax + 1);
    await _fill(t, name: long);
    // Nichts wird abgeschnitten.
    expect(find.text(long), findsOneWidget);
    expect(
      textOf(t, const Key('customer-name-problem')),
      'Der Text ist zu lang.',
    );
    expect(
      textOf(t, const Key('customer-vat-problem')),
      'Über 10.000 € braucht die Rechnung die UID des Kunden.',
    );
    expect(_key('customer-address1-problem'), findsNothing);
    expect(_enabled(t, 'customer-save'), isFalse);

    await t.enterText(_key('customer-vat'), 'ATU00000000');
    await t.pumpAndSettle();
    expect(_key('customer-vat-problem'), findsNothing);
    expect(_enabled(t, 'customer-save'), isFalse);
    await t.enterText(_key('customer-name'), 'Muster GmbH');
    await t.enterText(_key('customer-address2'), '');
    await t.pumpAndSettle();
    expect(
      textOf(t, const Key('customer-address2-problem')),
      'Bitte die Adresse eintragen.',
    );
    expect(_enabled(t, 'customer-save'), isFalse);
    await t.enterText(_key('customer-address2'), '1010 Wien');
    await t.pumpAndSettle();
    expect(_enabled(t, 'customer-save'), isTrue);
    await _tap(t, 'customer-save');
    expect(await queryRows(t, 'SELECT vat_id FROM receipt_recipients'), [
      {'vat_id': 'ATU00000000'},
    ]);
    semantics.dispose();
  });

  testWidgets('über 10.000 €: ein gespeicherter Kunde ohne UID öffnet das '
      'Formular mit seinen Werten, ändert ihn aber nicht; eine andere Firma '
      'dort ersetzt ihn nie', (t) async {
    await openInvoiceKassa(t, const []);
    final muster = await _customers(t).save(
      name: 'Muster GmbH',
      addressLine1: 'Musterweg 1',
      addressLine2: '1010 Wien',
    );
    final cart = containerOf(t).read(cartProvider.notifier);
    cart.addOpenAmount(amountCents: 600000, rate: TaxRate.normal);
    cart.addOpenAmount(amountCents: 400001, rate: TaxRate.normal);
    await t.pumpAndSettle();
    await _payCash(t);
    await _tap(t, 'invoice-button');
    await _tap(t, 'customer-row-${muster.id}');
    expect(_key('customer-form'), findsOneWidget);
    expect(find.text('Muster GmbH'), findsOneWidget);
    expect(t.widget<AppToggle>(_key('customer-keep')).value, isFalse);

    await _fill(
      t,
      name: 'Andere AG',
      address1: 'Andere Gasse 5',
      vat: 'ATU00000000',
    );
    await _tap(t, 'customer-save');
    final stored = await _customers(t).list();
    expect(
      [for (final c in stored) (c.id, c.name, c.addressLine1, c.vatId)],
      [(muster.id, 'Muster GmbH', 'Musterweg 1', null)],
    );
    expect(
      await queryRows(
        t,
        'SELECT customer_id, name, vat_id FROM receipt_recipients',
      ),
      [
        {'customer_id': null, 'name': 'Andere AG', 'vat_id': 'ATU00000000'},
      ],
    );
  });

  testWidgets('Formular: "Weiter" springt ins nächste Feld, "Fertig" '
      'übernimmt; Großschreibung und Autokorrektur je Feld', (t) async {
    await openInvoiceKassa(t, ['cola']);
    await _payCash(t);
    await _tap(t, 'invoice-button');
    await _tap(t, 'customer-new');

    TextField field(String key) => t.widget<TextField>(
      find.descendant(of: _key(key), matching: find.byType(TextField)),
    );
    for (final key in [
      'customer-name',
      'customer-address1',
      'customer-address2',
    ]) {
      expect(field(key).textCapitalization, TextCapitalization.words);
      expect(field(key).textInputAction, TextInputAction.next);
      expect(field(key).maxLength, isNull);
      expect(field(key).inputFormatters, isNull);
    }
    expect(
      field('customer-vat').textCapitalization,
      TextCapitalization.characters,
    );
    expect(field('customer-vat').autocorrect, isFalse);
    expect(field('customer-vat').textInputAction, TextInputAction.done);

    await t.showKeyboard(_key('customer-name'));
    t.testTextInput.enterText('Muster GmbH');
    await t.testTextInput.receiveAction(TextInputAction.next);
    await t.pumpAndSettle();
    expect(field('customer-address1').focusNode!.hasFocus, isTrue);
    t.testTextInput.enterText('Musterweg 1');
    await t.testTextInput.receiveAction(TextInputAction.next);
    await t.pumpAndSettle();
    expect(field('customer-address2').focusNode!.hasFocus, isTrue);
    t.testTextInput.enterText('1010 Wien');
    await t.testTextInput.receiveAction(TextInputAction.next);
    await t.pumpAndSettle();
    expect(field('customer-vat').focusNode!.hasFocus, isTrue);
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pumpAndSettle();
    expect(_key('customer-form'), findsNothing);
    expect(textOf(t, const Key('invoice-recipient')), 'Muster GmbH');
  });

  testWidgets('Formular über der Tastatur: es rollt, "Übernehmen" bleibt '
      'erreichbar; "Abbrechen" fragt nichts und speichert nichts', (t) async {
    await openInvoiceKassa(t, ['cola']);
    await _payCash(t);
    await _tap(t, 'invoice-button');
    await _tap(t, 'customer-new');
    await _fill(t);
    t.view.viewInsets = const FakeViewPadding(bottom: 400);
    addTearDown(t.view.resetViewInsets);
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    await t.ensureVisible(_key('customer-save'));
    await t.pumpAndSettle();
    expect(t.getRect(_key('customer-save')).bottom, lessThanOrEqualTo(400));
    t.view.resetViewInsets();
    await t.pumpAndSettle();

    await _tap(t, 'customer-cancel');
    expect(_key('customer-form'), findsNothing);
    expect(_key('customer-picker'), findsOneWidget);
    expect(await queryRows(t, 'SELECT * FROM receipt_recipients'), isEmpty);
    expect(await queryRows(t, 'SELECT * FROM customers'), isEmpty);
  });

  testWidgets('Formular über der Tastatur: ganz nach unten gerollt endet es '
      'genau über der Tastatur, ohne doppelten Platz', (t) async {
    await openInvoiceKassa(t, ['cola']);
    await _payCash(t);
    await _tap(t, 'invoice-button');
    await _tap(t, 'customer-new');
    t.view.viewInsets = const FakeViewPadding(bottom: 400);
    addTearDown(t.view.resetViewInsets);
    await t.pumpAndSettle();
    await t.drag(_key('customer-form-scroll'), const Offset(0, -3000));
    await t.pumpAndSettle();
    // Unter "Übernehmen" bleibt nur der Rand des Formulars (24 dp), dann
    // kommt die Tastatur.
    final bottom = t.getRect(_key('customer-save')).bottom;
    expect(bottom, lessThanOrEqualTo(400));
    expect(bottom, greaterThanOrEqualTo(400 - KassaTokens.spaceHuge - 1));
  });

  testWidgets('zweimal schnell auf "Übernehmen" und auf "Rechnung drucken": '
      'eine Fassung, ein Ausdruck', (t) async {
    await openInvoiceKassa(t, ['cola']);
    await _payCash(t);
    await _tap(t, 'invoice-button');
    await _tap(t, 'customer-new');
    await _fill(t);
    await t.ensureVisible(_key('customer-save'));
    await t.pumpAndSettle();
    await t.tap(_key('customer-save'));
    await t.tap(_key('customer-save'), warnIfMissed: false);
    await t.pumpAndSettle();
    expect(await queryRows(t, 'SELECT version FROM receipt_recipients'), [
      {'version': 0},
    ]);
    expect(await queryRows(t, 'SELECT id FROM customers'), hasLength(1));

    final printer = printerOf(t);
    final jobs = printer.printedJobs.length;
    final hold = Completer<void>();
    printer.hold = hold;
    await t.ensureVisible(_key('invoice-print'));
    await t.pumpAndSettle();
    await t.tap(_key('invoice-print'));
    await t.tap(_key('invoice-print'), warnIfMissed: false);
    await t.pump();
    // Solange gedruckt wird, ist die Taste grau.
    expect(_enabled(t, 'invoice-print'), isFalse);
    printer.hold = null;
    hold.complete();
    await t.pumpAndSettle();
    expect(printer.printedJobs.length, jobs + 1);
  });
  testWidgets('Firmenkunden ändern sich beim Abgleich, während die Auswahl '
      'offen ist: sie liest neu, ein archivierter verschwindet', (t) async {
    await openInvoiceKassa(t, ['cola']);
    final repo = _customers(t);
    final muster = await repo.save(
      name: 'Muster GmbH',
      addressLine1: 'Musterweg 1',
      addressLine2: '1010 Wien',
    );
    await _payCash(t);
    await _tap(t, 'invoice-button');
    expect(_key('customer-row-${muster.id}'), findsOneWidget);

    const neu = 'c0000000-0000-4000-8000-00000000000e';
    await t.runAsync(
      () => repo.applyServer(const [
        WireCustomer(
          id: neu,
          name: 'Neu KG',
          addressLine1: 'Musterweg 5',
          addressLine2: '1010 Wien',
          vatId: null,
          archived: false,
        ),
      ]),
    );
    await t.pumpAndSettle();
    expect(_key('customer-row-$neu'), findsOneWidget);
    expect(_key('customer-initial-N'), findsOneWidget);

    // Der eigene Eintrag ist gesendet: jetzt gilt der Stand des Servers.
    await t.runAsync(
      () =>
          containerOf(t)
              .read(databaseProvider)
              .customStatement('DELETE FROM outbox'),
    );
    await t.runAsync(
      () => repo.applyServer([
        WireCustomer(
          id: muster.id,
          name: 'Muster GmbH',
          addressLine1: 'Musterweg 1',
          addressLine2: '1010 Wien',
          vatId: null,
          archived: true,
        ),
      ]),
    );
    await t.pumpAndSettle();
    expect(_key('customer-row-${muster.id}'), findsNothing);
    expect(_key('customer-row-$neu'), findsOneWidget);
    expect(_key('customer-picker'), findsOneWidget);
  });
  testWidgets('während die Auswahl nach einem Abgleich neu liest, bleibt die '
      'alte Liste stehen, kein Flackern', (t) async {
    await openInvoiceKassa(t, ['cola']);
    final repo = _customers(t);
    final muster = await repo.save(
      name: 'Muster GmbH',
      addressLine1: 'Musterweg 1',
      addressLine2: '1010 Wien',
    );
    await _payCash(t);
    await _tap(t, 'invoice-button');
    expect(_key('customer-row-${muster.id}'), findsOneWidget);

    // Jeder Frame zwischen der Änderung und der neuen Liste zeigt die alte.
    var missing = 0;
    var frames = 0;
    await t.runAsync(
      () => repo.applyServer(const [
        WireCustomer(
          id: 'c0000000-0000-4000-8000-00000000000f',
          name: 'Neu KG',
          addressLine1: 'Musterweg 5',
          addressLine2: '1010 Wien',
          vatId: null,
          archived: false,
        ),
      ]),
    );
    for (var i = 0; i < 20; i++) {
      await t.pump();
      frames++;
      if (find.byKey(Key('customer-row-${muster.id}')).evaluate().isEmpty) {
        missing++;
      }
      await t.runAsync(() => Future<void>.delayed(Duration.zero));
    }
    expect(frames, 20);
    expect(missing, 0);
    await t.pumpAndSettle();
    expect(
      _key('customer-row-c0000000-0000-4000-8000-00000000000f'),
      findsOneWidget,
    );
    expect(_key('customer-row-${muster.id}'), findsOneWidget);
  });
}
