// Gutschein an der Kassa (Spec 5.5): Das Blatt "Gutschein" hat die Reiter
// "Verkaufen" und "Prüfen". Verkaufen legt je Gutschein eine Zeile an; nach
// dem Kundenbon druckt die Kassa je Gutschein einen Abschnitt, "Verkauf
// fertig" zeigt Wert und Code. Prüfen sucht nach der achten Ziffer und zeigt
// Wert, Guthaben, Zustand und die Bewegungen.

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/data/database.dart';
import 'package:kassa/data/providers.dart';
import 'package:kassa/devices/printer.dart';
import 'package:kassa/domain/business_info.dart';
import 'package:kassa/domain/cart.dart';
import 'package:kassa/domain/feature_access.dart';
import 'package:kassa/domain/print_document.dart';
import 'package:kassa/domain/receipt.dart';
import 'package:kassa/domain/voucher.dart';
import 'package:kassa/domain/voucher_layout.dart';
import 'package:kassa/features/kassa/cart_controller.dart';
import 'package:kassa/features/login/session.dart';
import 'package:kassa/ui/primary_button.dart';
import 'package:material_ui/material_ui.dart';

import '../support/cash_pump.dart';
import '../support/demo_fixtures.dart';
import '../support/kassa_pump.dart';
import '../support/pump.dart';

PrimaryButton _button(WidgetTester t, String key) =>
    t.widget<PrimaryButton>(find.byKey(Key(key)));

Future<void> _tap(WidgetTester t, String key) async {
  await t.ensureVisible(find.byKey(Key(key)));
  await t.pumpAndSettle();
  await t.tap(find.byKey(Key(key)));
  await t.pumpAndSettle();
}

/// Kassa mit Gutschein an, angemeldet Anna, mit Drucker ([printer]); die
/// Artikel [ids] auf dem Bon.
Future<void> _open(
  WidgetTester t, {
  List<String> ids = const [],
  bool printer = true,
  FeatureAccess discount = FeatureAccess.off,
}) async {
  await pumpKassa(t);
  await setSettings(
    t,
    (s) => s.copyWith(voucherEnabled: true, discountAccess: discount),
  );
  if (printer) await setUpPrinter(t);
  for (final id in ids) {
    await tapItem(t, id);
  }
  await t.pumpAndSettle();
}

/// Öffnet das Blatt, wählt [cents] und legt den Gutschein auf den Bon.
Future<void> _sell(WidgetTester t, int cents) async {
  await _tap(t, 'voucher-button');
  await _tap(t, 'voucher-preset-$cents');
  await _tap(t, 'voucher-add');
}

/// "Bar", passend, "Fertig".
Future<void> _payCash(WidgetTester t) async {
  await _tap(t, 'pay-cash');
  await _tap(t, 'finish-sale');
}

Future<List<String>> _codes(WidgetTester t) async => [
  for (final r in await queryRows(
    t,
    'SELECT code FROM vouchers ORDER BY sold_line_position',
  ))
    r['code']! as String,
];

/// Verkauft einen Gutschein über [cents] bar, ohne Oberfläche.
Future<Receipt> _sellDirect(WidgetTester t, int cents, String saleId) {
  final staff = containerOf(t).read(sessionProvider)!;
  return containerOf(t)
      .read(receiptRepositoryProvider)
      .finalizeCashSale(
        saleId: saleId,
        cart: const Cart.empty().addVoucherSale(valueCents: cents),
        givenCents: cents,
        staff: staff,
      );
}

/// Tippt einen Code auf das Zahlenfeld des Reiters "Prüfen".
Future<void> _typeCode(WidgetTester t, String code) async {
  await tapKeys(t, code.split('').join(' '));
  await t.pumpAndSettle();
}

Finder _inKey(String key, String text) =>
    find.descendant(of: find.byKey(Key(key)), matching: find.text(text));

void main() {
  testWidgets('25 € auf den Bon, bar bezahlt: Verkauf fertig zeigt Wert und '
      'Code, der Drucker bekommt Bon und einen Abschnitt', (t) async {
    await _open(t);
    expect(find.byKey(const Key('voucher-button')), findsOneWidget);
    expect(find.byKey(const Key('more-button')), findsNothing);
    await _tap(t, 'voucher-button');
    expect(find.byKey(const Key('voucher-sheet')), findsOneWidget);
    for (final cents in voucherPresetCents) {
      expect(find.byKey(Key('voucher-preset-$cents')), findsOneWidget);
    }
    // Ohne Wert ist "Auf den Bon" grau und sagt, warum.
    expect(_button(t, 'voucher-add').onPressed, isNull);
    expect(
      textOf(t, const Key('voucher-add-reason')),
      'Von 1,00 € bis 500,00 €',
    );
    await _tap(t, 'voucher-preset-2500');
    expect(_button(t, 'voucher-add').onPressed, isNotNull);
    expect(find.byKey(const Key('voucher-add-reason')), findsNothing);
    await _tap(t, 'voucher-add');

    expect(find.byKey(const Key('voucher-sheet')), findsNothing);
    final line = cartOf(t).lines.single;
    expect(line.isVoucherSale, isTrue);
    expect(line.item.priceCents, 2500);
    expect(_inKey('line-${line.lineId}', 'Gutschein'), findsOneWidget);
    expect(_inKey('line-${line.lineId}', '25,00 €'), findsOneWidget);
    expect(textOf(t, const Key('cart-total')), '25,00 €');

    await _payCash(t);
    final code =
        (await queryRows(t, 'SELECT code FROM vouchers')).single['code']!
            as String;
    expect(find.byKey(const Key('sold-voucher-0')), findsOneWidget);
    expect(_inKey('sold-voucher-0', '25,00 €'), findsOneWidget);
    expect(
      textOf(t, const Key('sold-voucher-code-0')),
      formatVoucherCode(code),
    );
    expect(find.byKey(const Key('sold-voucher-print-0')), findsOneWidget);
    expect(printerOf(t).printedJobs.map((p) => p.kind), ['receipt', 'voucher']);
    final slip = printerOf(t).voucherSlips.single;
    expect(slip.voucher.code, code);
    expect(slip.voucher.valueCents, 2500);
    expect(slip.soldAt, DateTime(2026, 11, 17, 11));

    // "Gutschein drucken" druckt den Abschnitt noch einmal, ohne Bon.
    await _tap(t, 'sold-voucher-print-0');
    expect(printerOf(t).printedJobs.map((p) => p.kind), [
      'receipt',
      'voucher',
      'voucher',
    ]);
    expect(find.byKey(const Key('sold-voucher-problem-0')), findsNothing);
  });

  testWidgets('zwei Gutscheine auf einem Bon: zwei Zeilen, zwei Codes, zwei '
      'Abschnitte in der Reihenfolge der Zeilen', (t) async {
    await _open(t);
    await _sell(t, 1000);
    await tapItem(t, 'cola');
    await t.pumpAndSettle();
    await _sell(t, 5000);
    expect(
      [for (final l in cartOf(t).lines) (l.isVoucherSale, l.item.priceCents)],
      [(true, 1000), (false, 290), (true, 5000)],
    );
    expect(textOf(t, const Key('cart-total')), '63,15 €');

    await _payCash(t);
    final codes = await _codes(t);
    expect(codes, hasLength(2));
    expect(codes.toSet(), hasLength(2));
    expect(
      textOf(t, const Key('sold-voucher-code-0')),
      formatVoucherCode(codes[0]),
    );
    expect(
      textOf(t, const Key('sold-voucher-code-1')),
      formatVoucherCode(codes[1]),
    );
    expect(_inKey('sold-voucher-0', '10,00 €'), findsOneWidget);
    expect(_inKey('sold-voucher-1', '50,00 €'), findsOneWidget);
    expect(printerOf(t).printedJobs.map((p) => p.kind), [
      'receipt',
      'voucher',
      'voucher',
    ]);
    expect(
      [for (final s in printerOf(t).voucherSlips) s.voucher.valueCents],
      [1000, 5000],
    );
    expect([for (final s in printerOf(t).voucherSlips) s.voucher.code], codes);
  });

  testWidgets('Anderer Betrag: 0,99 € und 500,01 € lassen "Auf den Bon" '
      'grau, 37,50 € geht', (t) async {
    await _open(t);
    await _tap(t, 'voucher-button');
    await _tap(t, 'voucher-preset-1000');
    await _tap(t, 'voucher-other');
    // Das Zahlenfeld ersetzt den Vorschlag.
    expect(find.byKey(const Key('amount-field')), findsOneWidget);
    expect(_button(t, 'voucher-add').onPressed, isNull);

    await tapKeys(t, '0 , 9 9');
    await t.pumpAndSettle();
    expect(textOf(t, const Key('amount-field')), '0,99 €');
    expect(_button(t, 'voucher-add').onPressed, isNull);
    expect(
      textOf(t, const Key('voucher-add-reason')),
      'Von 1,00 € bis 500,00 €',
    );

    await tapKeys(t, 'back back back back');
    await tapKeys(t, '5 0 0 , 0 1');
    await t.pumpAndSettle();
    expect(textOf(t, const Key('amount-field')), '500,01 €');
    expect(_button(t, 'voucher-add').onPressed, isNull);
    expect(find.byKey(const Key('voucher-add-reason')), findsOneWidget);

    await tapKeys(t, 'back back back back back back');
    await tapKeys(t, '3 7 , 5 0');
    await t.pumpAndSettle();
    expect(_button(t, 'voucher-add').onPressed, isNotNull);
    expect(find.byKey(const Key('voucher-add-reason')), findsNothing);
    await _tap(t, 'voucher-add');
    expect(cartOf(t).lines.single.item.priceCents, 3750);
    expect(textOf(t, const Key('cart-total')), '37,50 €');
  });

  testWidgets('die Gutschein-Zeile hat kein Plus und ist kein Ziel im '
      'Rabatt-Blatt; Minus nimmt sie weg', (t) async {
    await _open(t, ids: ['cola'], discount: FeatureAccess.all);
    await _sell(t, 2000);
    final voucher = cartOf(t).lines.singleWhere((l) => l.isVoucherSale);
    final cola = cartOf(t).lines.singleWhere((l) => !l.isVoucherSale);
    expect(find.byKey(Key('qty-plus-${voucher.lineId}')), findsNothing);
    expect(find.byKey(Key('qty-plus-${cola.lineId}')), findsOneWidget);
    expect(find.byKey(Key('qty-minus-${voucher.lineId}')), findsOneWidget);

    // Name und Preis sind keine Tippfläche für den Rabatt.
    await t.tap(_inKey('line-${voucher.lineId}', 'Gutschein'));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('discount-sheet')), findsNothing);
    await t.tap(_inKey('line-${voucher.lineId}', '20,00 €'));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('discount-sheet')), findsNothing);
    // Die Cola schon.
    await t.tap(_inKey('line-${cola.lineId}', '2,90 €'));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('discount-sheet')), findsOneWidget);
    await _tap(t, 'discount-back');

    await _tap(t, 'qty-minus-${voucher.lineId}');
    expect(cartOf(t).lines.where((l) => l.isVoucherSale), isEmpty);
    expect(cartOf(t).lines.single.lineId, cola.lineId);
  });

  testWidgets('ohne Drucker: kein Druck, der Code steht am Bildschirm', (
    t,
  ) async {
    await _open(t, printer: false);
    await _sell(t, 2500);
    await _payCash(t);
    final code = (await _codes(t)).single;
    expect(
      textOf(t, const Key('sold-voucher-code-0')),
      formatVoucherCode(code),
    );
    expect(find.byKey(const Key('sold-voucher-print-0')), findsNothing);
    expect(printerOf(t).log, isEmpty);
  });

  testWidgets('scheitert der Abschnitt, steht der Grund in seiner Reihe', (
    t,
  ) async {
    await _open(t);
    await _sell(t, 2500);
    await _payCash(t);
    expect(printerOf(t).printedJobs.map((p) => p.kind), ['receipt', 'voucher']);
    printerOf(t).next = const PrintOutcome.failed(PrintProblem.paperOut);
    await _tap(t, 'sold-voucher-print-0');
    expect(
      textOf(t, const Key('sold-voucher-problem-0')),
      'Drucker nicht bereit. Das Papier ist leer.',
    );
    printerOf(t).next = const PrintOutcome.ok();
    await _tap(t, 'sold-voucher-print-0');
    expect(find.byKey(const Key('sold-voucher-problem-0')), findsNothing);
  });

  testWidgets('scheitert der Kundenbon, druckt die Kassa keinen Abschnitt '
      'von selbst', (t) async {
    await _open(t);
    printerOf(t).next = const PrintOutcome.failed(PrintProblem.coverOpen);
    await _sell(t, 2500);
    await _payCash(t);
    expect(printerOf(t).printedJobs.map((p) => p.kind), ['receipt']);
    expect(find.byKey(const Key('sold-voucher-code-0')), findsOneWidget);
    expect(find.byKey(const Key('sold-voucher-print-0')), findsOneWidget);
  });

  testWidgets('mit Karte bezahlt: Bon und Abschnitt wie bar', (t) async {
    await _open(t);
    await _sell(t, 2500);
    await t.tap(find.byKey(const Key('pay-card')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('paid-by-card')), findsOneWidget);
    final code = (await _codes(t)).single;
    expect(
      textOf(t, const Key('sold-voucher-code-0')),
      formatVoucherCode(code),
    );
    expect(printerOf(t).printedJobs.map((p) => p.kind), ['receipt', 'voucher']);
  });

  testWidgets('liegen am Bon Gutscheine zum Bezahlen, ist "Auf den Bon" grau '
      'mit dem Grund', (t) async {
    await _open(t);
    containerOf(t)
        .read(cartProvider.notifier)
        .restore(
          const Cart.empty()
              .add(cola)
              .applyVoucher(
                const AppliedVoucher(
                  voucherId: 'v',
                  code: '11112222',
                  balanceCents: 500,
                ),
              ),
        );
    await t.pumpAndSettle();
    await _tap(t, 'voucher-button');
    await _tap(t, 'voucher-preset-2000');
    expect(_button(t, 'voucher-add').onPressed, isNull);
    expect(
      textOf(t, const Key('voucher-add-reason')),
      'Dieser Bon wird mit einem Gutschein bezahlt.',
    );
  });

  testWidgets('Prüfen: Code tippen zeigt Wert, Guthaben, Zustand und die '
      'Bewegungen; unbekannter Code sagt es', (t) async {
    await _open(t);
    final sold = await _sellDirect(t, 2500, 'verkauf-1');
    final v = sold.soldVouchers.single;
    // Teil eingelöst: Cola 3,15 € mit dem Gutschein bezahlt.
    final staff = containerOf(t).read(sessionProvider)!;
    await containerOf(t)
        .read(receiptRepositoryProvider)
        .finalizeVoucherSale(
          saleId: 'einloesen-1',
          cart: const Cart.empty()
              .add(cola)
              .applyVoucher(
                AppliedVoucher(
                  voucherId: v.voucherId,
                  code: v.code,
                  balanceCents: 2500,
                ),
              ),
          staff: staff,
        );
    // Ein zweiter, dessen Verkauf storniert ist.
    final voided = await _sellDirect(t, 1000, 'verkauf-2');
    await containerOf(t)
        .read(receiptRepositoryProvider)
        .voidReceipt(voided.id, staff: staff);
    await t.pumpAndSettle();

    await _tap(t, 'voucher-button');
    await _tap(t, 'voucher-tab-check');
    expect(find.byKey(const Key('voucher-code')), findsOneWidget);
    await tapKeys(t, '1 2 3 4 5');
    await t.pumpAndSettle();
    expect(textOf(t, const Key('voucher-code')), '1234 5');
    await tapKeys(t, 'back back back back back');
    await t.pumpAndSettle();

    await _typeCode(t, v.code);
    expect(textOf(t, const Key('voucher-code')), formatVoucherCode(v.code));
    expect(textOf(t, const Key('voucher-check-value')), '25,00 €');
    expect(textOf(t, const Key('voucher-check-balance')), '21,85 €');
    expect(textOf(t, const Key('voucher-check-state')), 'Gültig');
    // Neueste oben: die Einlösung, dann der Verkauf.
    expect(_inKey('voucher-check-movement-0', 'Eingelöst'), findsOneWidget);
    expect(_inKey('voucher-check-movement-0', '−3,15 €'), findsOneWidget);
    expect(
      _inKey('voucher-check-movement-0', '17.11.2026 11:00'),
      findsOneWidget,
    );
    expect(_inKey('voucher-check-movement-1', 'Verkauft'), findsOneWidget);
    expect(_inKey('voucher-check-movement-1', '25,00 €'), findsOneWidget);
    expect(find.byKey(const Key('voucher-check-movement-2')), findsNothing);
    // Eine Ziffer weg: das Ergebnis geht weg.
    await tapKeys(t, 'back');
    await t.pumpAndSettle();
    expect(find.byKey(const Key('voucher-check-value')), findsNothing);
    await tapKeys(t, 'back back back back back back back');

    // Der stornierte.
    await _typeCode(t, voided.soldVouchers.single.code);
    expect(textOf(t, const Key('voucher-check-state')), 'Storniert');
    expect(textOf(t, const Key('voucher-check-balance')), '0,00 €');
    expect(
      _inKey('voucher-check-movement-0', 'Verkauf storniert'),
      findsOneWidget,
    );
    expect(_inKey('voucher-check-movement-0', '−10,00 €'), findsOneWidget);
    await tapKeys(t, 'back back back back back back back back');

    // Unbekannt (kein Code beginnt mit 0000 0000 und ist zugleich in der
    // Datenbank, außer die Zufallszahl trifft ihn genau).
    final known = await _codes(t);
    final unknown = [
      '00000000',
      '99999999',
    ].firstWhere((c) => !known.contains(c));
    await _typeCode(t, unknown);
    expect(
      textOf(t, const Key('voucher-code-problem')),
      'Diesen Gutschein kennt die Kassa nicht.',
    );
    expect(find.byKey(const Key('voucher-check-value')), findsNothing);
    await tapKeys(t, 'back');
    await t.pumpAndSettle();
    expect(find.byKey(const Key('voucher-code-problem')), findsNothing);
  });

  testWidgets('Prüfen: zwei Gutscheine mit demselben Code stehen zur Wahl', (
    t,
  ) async {
    await _open(t);
    final sold = await _sellDirect(t, 2500, 'verkauf-1');
    final code = sold.soldVouchers.single.code;
    // Derselbe Code von einer anderen Kasse, über den Abgleich gekommen.
    final db = containerOf(t).read(databaseProvider);
    await db
        .into(db.voucherRows)
        .insert(
          VoucherRowsCompanion.insert(
            id: 'fremd',
            code: code,
            valueCents: 4000,
            createdAt: DateTime(2026, 11, 3, 9, 30),
            soldReceiptId: const Value('bon-der-anderen-kasse'),
            soldLinePosition: const Value(0),
            isTest: false,
          ),
        );
    await db
        .into(db.voucherMovementRows)
        .insert(
          VoucherMovementRowsCompanion.insert(
            voucherId: 'fremd',
            receiptId: 'bon-der-anderen-kasse',
            kind: VoucherMovementKind.sale.dbName,
            amountCents: 4000,
            createdAt: DateTime(2026, 11, 3, 9, 30),
          ),
        );

    await _tap(t, 'voucher-button');
    await _tap(t, 'voucher-tab-check');
    await _typeCode(t, code);
    // Nach dem Datum: der fremde ist älter.
    expect(_inKey('voucher-pick-0', '40,00 €'), findsOneWidget);
    expect(_inKey('voucher-pick-0', '03.11.2026'), findsOneWidget);
    expect(_inKey('voucher-pick-1', '25,00 €'), findsOneWidget);
    expect(_inKey('voucher-pick-1', '17.11.2026'), findsOneWidget);
    expect(find.byKey(const Key('voucher-check-value')), findsNothing);
    for (final key in ['voucher-pick-0', 'voucher-pick-1']) {
      expect(t.getSize(find.byKey(Key(key))).height, greaterThanOrEqualTo(48));
    }

    await _tap(t, 'voucher-pick-0');
    expect(find.byKey(const Key('voucher-pick-0')), findsNothing);
    expect(textOf(t, const Key('voucher-check-value')), '40,00 €');
    expect(textOf(t, const Key('voucher-check-balance')), '40,00 €');
    expect(textOf(t, const Key('voucher-check-state')), 'Gültig');
    // Ein echter Gutschein: kein Vermerk.
    expect(find.byKey(const Key('voucher-check-test')), findsNothing);
  });

  testWidgets('Übungsmodus: der Abschnitt trägt ÜBUNG, Prüfen zeigt '
      '"Übungs-Gutschein"', (t) async {
    // Ohne laufende Signatur ist die Kassa im Probebetrieb: jeder Bon ist
    // ein Übungs-Bon.
    await _open(t);
    await _sell(t, 2500);
    await _payCash(t);
    final slip = printerOf(t).voucherSlips.single;
    expect(slip.isTest, isTrue);
    final lines = [
      for (final o in layoutVoucher(
        slip.voucher,
        const BusinessInfo(name: 'Beispiel-Imbiss'),
        soldAt: slip.soldAt,
        isTest: slip.isTest,
      ))
        if (o is PrintText) o.text,
    ];
    expect(lines, contains('ÜBUNG'));
    expect(lines, contains('Kein gültiger Gutschein'));
    expect(
      (await queryRows(t, 'SELECT is_test FROM vouchers')).single['is_test'],
      1,
    );

    await _tap(t, 'next-customer');
    await _tap(t, 'voucher-button');
    await _tap(t, 'voucher-tab-check');
    await _typeCode(t, slip.voucher.code);
    expect(textOf(t, const Key('voucher-check-state')), 'Gültig');
    expect(textOf(t, const Key('voucher-check-test')), 'Übungs-Gutschein');
  });

  testWidgets('Tippflächen im Blatt sind mindestens 48 dp', (t) async {
    await _open(t);
    await _tap(t, 'voucher-button');
    for (final key in [
      'voucher-back',
      'voucher-tab-sell',
      'voucher-tab-check',
      for (final c in voucherPresetCents) 'voucher-preset-$c',
      'voucher-other',
      'voucher-add',
    ]) {
      final size = t.getSize(find.byKey(Key(key)));
      expect(size.height, greaterThanOrEqualTo(48), reason: key);
      expect(size.width, greaterThanOrEqualTo(48), reason: key);
    }
  });
}
