// Digitaler Beleg an der Kassa (Spec 5.4): der Schalter "Kundenbon" mit
// seinen drei Werten, der QR-Code auf "Verkauf fertig", der Druck nach 3
// Sekunden ohne Internet und die Belegerteilung.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/core/app_language.dart';
import 'package:kassa/data/providers.dart';
import 'package:kassa/devices/card_terminal.dart';
import 'package:kassa/domain/cart.dart';
import 'package:kassa/domain/discount.dart';
import 'package:kassa/features/kassa/kitchen_service.dart';
import 'package:kassa/features/kassa/sale_service.dart';
import 'package:kassa/features/login/session.dart';
import 'package:material_ui/material_ui.dart';

import '../support/cash_pump.dart';
import '../support/demo_fixtures.dart';
import '../support/digital_pump.dart';
import '../support/fake_devices.dart';
import '../support/kassa_pump.dart';
import '../support/pump.dart';

/// Kassa mit Server und Drucker, Kundenbon [mode], mit [paired] gekoppelt.
/// Der Küchenbon kommt am Bondrucker (falscher Dienst, siehe [kitchenOf]).
Future<FakeKitchenService> _pump(
  WidgetTester t, {
  required ReceiptMode mode,
  bool paired = true,
  bool printer = true,
}) async {
  final kitchen = FakeKitchenService();
  await pumpKassa(
    t,
    overrides: await serverKassaOverrides(
      base: [
        ...await memoryOverrides(),
        kitchenServiceProvider.overrideWithValue(kitchen),
      ],
    ),
  );
  if (printer) await setUpPrinter(t);
  await setSettings(
    t,
    (s) => s.copyWith(
      receiptMode: mode,
      cashDrawerEnabled: true,
      kitchenMode: KitchenMode.receiptPrinter,
    ),
  );
  if (paired) await pairRegister(t);
  return kitchen;
}

/// Bonniert eine Cola und eine Teigtasche, "Bar", passend abschließen.
Future<void> _sellCash(WidgetTester t) async {
  await tapItem(t, 'cola');
  await tapItem(t, 'teigtaschen');
  await t.tap(find.byKey(const Key('pay-cash')));
  await t.pumpAndSettle();
  await t.tap(find.byKey(const Key('finish-sale')));
  await t.pump();
  await t.pump();
}

Iterable<({String kind, String? id})> _receiptPrints(WidgetTester t) =>
    printerOf(t).printedJobs.where((p) => p.kind == 'receipt');

Future<List<Map<String, Object?>>> _deliveries(WidgetTester t) => queryRows(
  t,
  'SELECT receipt_id, kind FROM receipt_deliveries ORDER BY kind',
);

/// Lässt die Uhr des Verkaufs sicher ablaufen.
Future<void> _pastFallback(WidgetTester t) async {
  await t.pump(receiptFallbackDelay);
  await t.pump();
  await t.pump();
}

void main() {
  testWidgets('immer drucken, gekoppelt: kein QR-Code, Druck wie bisher, '
      '"gedruckt" festgehalten', (t) async {
    await _pump(t, mode: ReceiptMode.alwaysPrint);
    await _sellCash(t);
    await t.pumpAndSettle();
    final id = await lastReceiptId(t);
    expect(printerOf(t).log.first, 'print+drawer:$id');
    expect(find.byKey(const Key('print-state')), findsOneWidget);
    for (final k in [
      'receipt-qr',
      'receipt-qr-wait',
      'receipt-qr-caption',
      'print-receipt-now',
      'receipt-offline-note',
    ]) {
      expect(find.byKey(Key(k)), findsNothing, reason: k);
    }
    expect(await _deliveries(t), [
      {'receipt_id': id, 'kind': 'printed'},
    ]);
    expect(
      await queryRows(t, "SELECT ref FROM outbox WHERE kind = 'delivery'"),
      [
        {'ref': '$id/printed'},
      ],
    );
  });

  testWidgets('digital gewählt, aber nicht gekoppelt: wie immer drucken', (
    t,
  ) async {
    await _pump(t, mode: ReceiptMode.digitalOnRequest, paired: false);
    await _sellCash(t);
    await t.pumpAndSettle();
    final id = await lastReceiptId(t);
    expect(_receiptPrints(t).map((p) => p.id), [id]);
    expect(printerOf(t).drawerOpened, 1);
    expect(find.byKey(const Key('print-state')), findsOneWidget);
    expect(find.byKey(const Key('receipt-qr')), findsNothing);
    expect(find.byKey(const Key('receipt-qr-wait')), findsNothing);
    expect(find.byKey(const Key('print-receipt-now')), findsNothing);
    expect(await _deliveries(t), [
      {'receipt_id': id, 'kind': 'printed'},
    ]);
    // Keine Uhr: nach 3 Sekunden geschieht nichts mehr.
    await _pastFallback(t);
    expect(_receiptPrints(t), hasLength(1));
  });

  testWidgets('drucken und digital: Druck und QR-Code; "gedruckt" und '
      '"digital" festgehalten', (t) async {
    await _pump(t, mode: ReceiptMode.printAndDigital);
    await _sellCash(t);
    await t.pumpAndSettle();
    final id = await lastReceiptId(t);
    expect(_receiptPrints(t).map((p) => p.id), [id]);
    expect(find.byKey(const Key('print-state')), findsOneWidget);
    expect(find.byKey(const Key('print-receipt-now')), findsNothing);
    expect(find.byKey(const Key('receipt-qr-wait')), findsOneWidget);
    expect(find.byKey(const Key('receipt-qr-caption')), findsOneWidget);
    expect(await _deliveries(t), [
      {'receipt_id': id, 'kind': 'printed'},
    ]);
    await serverConfirms(t, id);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('receipt-qr-wait')), findsNothing);
    expect(
      qrTextOf(t, 'receipt-qr'),
      '$testServerUrl/beleg/${(await lastReceipt(t)).publicToken}',
    );
    expect(await _deliveries(t), [
      {'receipt_id': id, 'kind': 'digital'},
      {'receipt_id': id, 'kind': 'printed'},
    ]);
    // Keine Uhr bei "Drucken und digital".
    await _pastFallback(t);
    expect(_receiptPrints(t), hasLength(1));
  });

  testWidgets('digital und Druck auf Wunsch, Server bestätigt: Platzhalter, '
      'dann QR-Code mit der Adresse des Bons; kein Druck; Lade offen bei Bar; '
      'Küchenbon gedruckt', (t) async {
    final kitchen = await _pump(t, mode: ReceiptMode.digitalOnRequest);
    await _sellCash(t);
    expect(find.byKey(const Key('receipt-qr-wait')), findsOneWidget);
    expect(find.byKey(const Key('receipt-qr')), findsNothing);
    expect(find.byKey(const Key('receipt-qr-caption')), findsOneWidget);
    expect(find.byKey(const Key('print-receipt-now')), findsOneWidget);
    expect(find.byKey(const Key('print-state')), findsNothing);
    final placeholder = t.getSize(find.byKey(const Key('receipt-qr-wait')));
    expect(placeholder.width, greaterThanOrEqualTo(200));
    expect(await _deliveries(t), isEmpty);

    await serverConfirms(t, await lastReceiptId(t));
    await t.pump();
    expect(find.byKey(const Key('receipt-qr-wait')), findsNothing);
    expect(
      qrTextOf(t, 'receipt-qr'),
      endsWith('/beleg/${(await lastReceipt(t)).publicToken}'),
    );
    expect(qrTextOf(t, 'receipt-qr'), startsWith(testServerUrl));
    // Dieselbe Größe wie der Platzhalter, mindestens 200 dp.
    expect(t.getSize(find.byKey(const Key('receipt-qr'))), placeholder);
    expect(textOf(t, const Key('receipt-qr-caption')),
        'Bon mit dem Handy mitnehmen');
    expect(textOf(t, const Key('print-receipt-now')), 'Bon drucken');
    await t.pump();
    expect(_receiptPrints(t), isEmpty);
    expect(printerOf(t).drawerOpened, 1);
    expect(printerOf(t).log.first, 'drawer');
    expect(kitchen.calls, ['for:1']);
    expect(await queryRows(t, 'SELECT kind FROM receipt_deliveries'), [
      {'kind': 'digital'},
    ]);

    // Die Uhr läuft ab: bestätigt, also kein Druck.
    await _pastFallback(t);
    expect(_receiptPrints(t), isEmpty);
    expect(find.byKey(const Key('receipt-offline-note')), findsNothing);
    expect(find.byKey(const Key('print-receipt-now')), findsOneWidget);
  });

  testWidgets('"Bon drucken" druckt einmal und hält "gedruckt" fest', (
    t,
  ) async {
    await _pump(t, mode: ReceiptMode.digitalOnRequest);
    await _sellCash(t);
    final receipt = await lastReceipt(t);
    await serverConfirms(t, receipt.id);
    await t.pump();
    await t.tap(find.byKey(const Key('print-receipt-now')));
    await t.pump();
    await t.pump();
    expect(_receiptPrints(t).map((p) => p.id), [receipt.id]);
    expect(find.byKey(const Key('print-receipt-now')), findsNothing);
    expect(textOf(t, const Key('print-state')), 'Bon gedruckt');
    expect(await _deliveries(t), [
      {'receipt_id': receipt.id, 'kind': 'digital'},
      {'receipt_id': receipt.id, 'kind': 'printed'},
    ]);

    // Höchstens einmal zugleich: solange der Druck läuft, druckt ein
    // zweiter Aufruf nicht noch einmal; danach wieder.
    final service = containerOf(t).read(saleServiceProvider);
    printerOf(t).hold = Completer<void>();
    final a = service.printNow(receipt);
    final b = service.printNow(receipt);
    await t.pump();
    expect(_receiptPrints(t), hasLength(2));
    printerOf(t).hold!.complete();
    printerOf(t).hold = null;
    expect((await a).ok, isTrue);
    expect((await b).ok, isTrue);
    await service.printNow(receipt);
    expect(_receiptPrints(t), hasLength(3));

    await _pastFallback(t);
    expect(_receiptPrints(t), hasLength(3));
  });

  testWidgets('kein Internet: nach 3 Sekunden druckt die Kassa von selbst, '
      'genau einmal, mit Hinweis; späte Bestätigung druckt nichts mehr', (
    t,
  ) async {
    await _pump(t, mode: ReceiptMode.digitalOnRequest);
    await _sellCash(t);
    await t.pump(const Duration(seconds: 2));
    expect(_receiptPrints(t), isEmpty);
    expect(find.byKey(const Key('receipt-offline-note')), findsNothing);
    await t.pump(const Duration(seconds: 1));
    await t.pump();
    expect(_receiptPrints(t), hasLength(1));
    expect(find.byKey(const Key('receipt-offline-note')), findsOneWidget);
    expect(
      textOf(t, const Key('receipt-offline-note')),
      'Kein Internet, Bon wird gedruckt.',
    );
    expect(find.byKey(const Key('print-state')), findsOneWidget);
    expect(find.byKey(const Key('print-receipt-now')), findsNothing);
    final id = await lastReceiptId(t);
    expect(_receiptPrints(t).single.id, id);
    // Die Lade ging schon beim Abschließen auf, nicht noch einmal.
    expect(printerOf(t).drawerOpened, 1);
    expect(await _deliveries(t), [
      {'receipt_id': id, 'kind': 'printed'},
    ]);

    await serverConfirms(t, id);
    await t.pump(const Duration(seconds: 5));
    expect(_receiptPrints(t), hasLength(1));
  });

  testWidgets('kein Internet und schon "Nächster Kunde" getippt: der Bon '
      'druckt trotzdem nach 3 Sekunden, genau einmal', (t) async {
    await _pump(t, mode: ReceiptMode.digitalOnRequest);
    await _sellCash(t);
    final id = await lastReceiptId(t);
    await t.tap(find.byKey(const Key('next-customer')));
    await t.pump();
    expect(find.byKey(const Key('next-customer')), findsNothing);
    expect(_receiptPrints(t), isEmpty);
    await _pastFallback(t);
    expect(_receiptPrints(t).map((p) => p.id), [id]);
    await t.pump(const Duration(seconds: 5));
    expect(_receiptPrints(t), hasLength(1));
    expect(await _deliveries(t), [
      {'receipt_id': id, 'kind': 'printed'},
    ]);
  });

  testWidgets('kein Internet, "Bon drucken" nach 1 Sekunde getippt: ein '
      'Druck, nicht zwei', (t) async {
    await _pump(t, mode: ReceiptMode.digitalOnRequest);
    await _sellCash(t);
    await t.pump(const Duration(seconds: 1));
    await t.tap(find.byKey(const Key('print-receipt-now')));
    await t.pump();
    expect(_receiptPrints(t), hasLength(1));
    await _pastFallback(t);
    await t.pump(const Duration(seconds: 5));
    expect(_receiptPrints(t), hasLength(1));
    // Gedruckt auf Wunsch, nicht wegen der Uhr: kein Hinweis.
    expect(find.byKey(const Key('receipt-offline-note')), findsNothing);
    expect(find.byKey(const Key('print-state')), findsOneWidget);
  });

  testWidgets('kein Internet, kein Drucker: Hinweis "erst später abrufbar", '
      'der QR-Code steht trotzdem da', (t) async {
    await _pump(t, mode: ReceiptMode.digitalOnRequest, printer: false);
    await _sellCash(t);
    final receipt = await lastReceipt(t);
    expect(find.byKey(const Key('receipt-qr-wait')), findsOneWidget);
    expect(find.byKey(const Key('print-receipt-now')), findsNothing);
    await _pastFallback(t);
    expect(
      textOf(t, const Key('receipt-offline-note')),
      'Kein Internet: Der digitale Bon ist erst später abrufbar.',
    );
    expect(find.byKey(const Key('receipt-qr-wait')), findsNothing);
    expect(
      qrTextOf(t, 'receipt-qr'),
      '$testServerUrl/beleg/${receipt.publicToken}',
    );
    expect(printerOf(t).log, isEmpty);
    expect(await _deliveries(t), [
      {'receipt_id': receipt.id, 'kind': 'digital'},
    ]);
  });

  testWidgets('Karte, nur Gutschein, Auszahlung und Abschließen bei 0: '
      'dieselbe Regel für den Kundenbon', (t) async {
    await _pump(t, mode: ReceiptMode.digitalOnRequest);
    await setSettings(t, (s) => s.copyWith(voucherEnabled: true));
    final service = containerOf(t).read(saleServiceProvider);
    final staff = containerOf(t).read(sessionProvider)!;

    // Ein Gutschein über 20,00 €, bar verkauft: sein Abschnitt druckt wie
    // immer, der Kundenbon nicht.
    final voucherSale = await service.completeCash(
      saleId: 'gutschein',
      cart: const Cart.empty().addVoucherSale(valueCents: 2000),
      givenCents: 2000,
      staff: staff,
    );
    expect(voucherSale.autoPrinted, isFalse);
    expect([for (final o in await voucherSale.voucherPrints) o.ok], [true]);
    final voucher = (await containerOf(t)
        .read(voucherRepositoryProvider)
        .byId(voucherSale.receipt.soldVouchers.single.voucherId))!;

    final card = await service.payByCard(
      paymentId: 'karte',
      cart: const Cart.empty().add(teigtaschen),
      staff: staff,
    );
    final byVoucher = await service.completeVoucher(
      saleId: 'nur-gutschein',
      cart: const Cart.empty().add(cola).applyVoucher(
        AppliedVoucher(
          voucherId: voucher.id,
          code: voucher.code,
          balanceCents: voucher.balanceCents,
        ),
      ),
      staff: staff,
    );
    final payout = await service.completePayout(
      saleId: 'auszahlung',
      cart: const Cart.empty().setDepositReturn(depositCents: 25, quantity: 2),
      staff: staff,
    );
    final free = await service.completeFree(
      saleId: 'frei',
      cart: const Cart.empty().add(teigtaschen).setReceiptDiscount(
        const Discount.percent(100, DiscountReason.invitation),
      ),
      staff: staff,
    );
    // Eine unklare Kartenzahlung, später als bezahlt bestätigt.
    terminalOf(t).next = const CardUnknown();
    final unclear = await service.payByCard(
      paymentId: 'unklar',
      cart: const Cart.empty().add(teigtaschen),
      staff: staff,
    );
    expect(unclear, isA<CardSaleUnclear>());
    final pending = (await containerOf(
      t,
    ).read(cardPaymentRepositoryProvider).pending()).single;
    final confirmed = await service.confirmUnclear(
      pending,
      catalog: (await containerOf(t).read(catalogRepositoryProvider).current())!,
    );

    final sales = [
      voucherSale,
      (card as CardSaleDone).sale,
      byVoucher,
      payout,
      free,
      confirmed,
    ];
    for (final s in sales) {
      expect(s.autoPrinted, isFalse, reason: s.receipt.id);
      expect(s.receiptMode, ReceiptMode.digitalOnRequest);
    }
    await t.pump();
    expect(_receiptPrints(t), isEmpty);
    // Die Lade geht nur bei Bargeld auf: Gutschein bar und Auszahlung.
    expect(printerOf(t).drawerOpened, 2);

    // Ohne Bestätigung druckt die Uhr jeden Bon genau einmal.
    await _pastFallback(t);
    await t.pump(const Duration(seconds: 1));
    expect(
      _receiptPrints(t).map((p) => p.id).toSet(),
      {for (final s in sales) s.receipt.id},
    );
    expect(_receiptPrints(t), hasLength(sales.length));
    for (final s in sales) {
      expect(await s.fallback.first, ReceiptFallback.printed);
    }
    // Der Abschnitt des Gutscheins kam nur einmal.
    expect(printerOf(t).printedJobs.where((p) => p.kind == 'voucher'),
        hasLength(1));
  });

  testWidgets('die Uhr gehört dem Dienst: geht er weg, hält sie an und '
      'druckt nichts', (t) async {
    await _pump(t, mode: ReceiptMode.digitalOnRequest);
    await _sellCash(t);
    final printer = printerOf(t);
    // Die Oberfläche und mit ihr der Dienst gehen weg. Liefe die Uhr weiter,
    // stünde sie am Ende des Tests noch aus, und der Test scheiterte.
    await t.pumpWidget(const SizedBox());
    await t.pump();
    expect(printer.printedJobs.where((p) => p.kind == 'receipt'), isEmpty);
  });
}
