// Digitaler Beleg an der Kassa (Spec 5.4): der Schalter "Kundenbon" mit
// seinen drei Werten, der QR-Code auf "Verkauf fertig", der Druck nach 3
// Sekunden ohne Internet und die Belegerteilung.

import 'dart:async';

import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/core/app_language.dart';
import 'package:kassa/data/providers.dart';
import 'package:kassa/domain/cart.dart';
import 'package:kassa/domain/customer.dart' show isTestReceipt;
import 'package:kassa/devices/printer.dart';
import 'package:kassa/domain/discount.dart';
import 'package:kassa/features/kassa/kitchen_service.dart';
import 'package:kassa/features/kassa/sale_service.dart';
import 'package:kassa/features/login/session.dart';
import 'package:kassa/ui/tokens.dart';
import 'package:material_ui/material_ui.dart';

import '../support/cash_pump.dart';
import '../support/demo_fixtures.dart';
import '../support/digital_pump.dart';
import '../support/fake_devices.dart';
import '../support/fake_server.dart';
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
    // Der Satz zum Handy steht erst mit dem Code da, nicht unter dem
    // leeren Platzhalter (Schlussprüfung B-M4).
    expect(find.byKey(const Key('receipt-qr-caption')), findsNothing);
    expect(await _deliveries(t), [
      {'receipt_id': id, 'kind': 'printed'},
    ]);
    await serverConfirms(t, id);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('receipt-qr-wait')), findsNothing);
    expect(find.byKey(const Key('receipt-qr-caption')), findsOneWidget);
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

  testWidgets('Übungs-Bon (ohne Signatur in Betrieb) folgt dem Schalter '
      '"Kundenbon": '
      'bei "Digital, Druck auf Wunsch" der Code, kein Druck; bei "Drucken '
      'und digital" Druck und Code', (t) async {
    await _pump(t, mode: ReceiptMode.digitalOnRequest);
    await _sellCash(t);
    final practice = await lastReceipt(t);
    expect(isTestReceipt(practice), isTrue);
    expect(practice.publicToken, isNotNull);
    await serverConfirms(t, practice.id);
    await t.pump();
    expect(
      qrTextOf(t, 'receipt-qr'),
      endsWith('/beleg/${practice.publicToken}'),
    );
    await _pastFallback(t);
    expect(_receiptPrints(t), isEmpty);

    await t.tap(find.byKey(const Key('next-customer')));
    await t.pumpAndSettle();
    await setSettings(
      t,
      (s) => s.copyWith(receiptMode: ReceiptMode.printAndDigital),
    );
    await _sellCash(t);
    await t.pumpAndSettle();
    final second = await lastReceipt(t);
    expect(isTestReceipt(second), isTrue);
    expect(_receiptPrints(t).map((p) => p.id), [second.id]);
    await serverConfirms(t, second.id);
    await t.pumpAndSettle();
    expect(qrTextOf(t, 'receipt-qr'), endsWith('/beleg/${second.publicToken}'));
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

  testWidgets('Nächster Kunde getippt, bevor der Code da war, Server '
      'bestätigt nach 0,8 s: nach 3 Sekunden druckt die Kassa genau einmal', (
    t,
  ) async {
    await _pump(t, mode: ReceiptMode.digitalOnRequest);
    await _sellCash(t);
    final id = await lastReceiptId(t);
    await t.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('receipt-qr-wait')), findsOneWidget);
    await t.tap(find.byKey(const Key('next-customer')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    await serverConfirms(t, id);
    expect(_receiptPrints(t), isEmpty);
    await _pastFallback(t);
    expect(_receiptPrints(t).map((p) => p.id), [id]);
    await t.pump(const Duration(seconds: 5));
    expect(_receiptPrints(t), hasLength(1));
    expect(await _deliveries(t), [
      {'receipt_id': id, 'kind': 'printed'},
    ]);
  });

  testWidgets('"Bon drucken" getippt, dann ein zweiter Verkauf: der Dienst '
      'vergisst den ersten nicht, solange seine Uhr läuft; kein zweiter '
      'Druck', (t) async {
    await _pump(t, mode: ReceiptMode.digitalOnRequest);
    await _sellCash(t);
    final first = await lastReceiptId(t);
    await t.pump(const Duration(milliseconds: 500));
    await t.tap(find.byKey(const Key('print-receipt-now')));
    await t.pump();
    await t.pump();
    expect(_receiptPrints(t).map((p) => p.id), [first]);
    final second = await containerOf(t)
        .read(saleServiceProvider)
        .completeCash(
          saleId: 'zweiter',
          cart: const Cart.empty().add(cola),
          givenCents: const Cart.empty().add(cola).totalCents,
          staff: containerOf(t).read(sessionProvider)!,
        );
    await _pastFallback(t);
    await t.pump(const Duration(seconds: 1));
    await t.pump();
    // Der zweite zeigte seinen Code nie: er druckt nach seinen 3 Sekunden.
    expect(_receiptPrints(t).map((p) => p.id), [first, second.receipt.id]);
    await t.pump(const Duration(seconds: 5));
    expect(_receiptPrints(t), hasLength(2));
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
    // Die bestätigte unklare Kartenzahlung druckt immer von selbst
    // (unclear_card_test.dart).
    final sales = [
      voucherSale,
      (card as CardSaleDone).sale,
      byVoucher,
      payout,
      free,
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

  group('mit dem echten Abgleich (Spec 5.4: der Bon geht sofort zum '
      'Server)', () {
    /// Gekoppelte Kassa mit Drucker, Kundenbon [mode]; der Server antwortet
    /// auf jedes Senden nach [answer].
    Future<FakeServer> pumpSynced(
      WidgetTester t, {
      required ReceiptMode mode,
      Duration answer = const Duration(milliseconds: 1200),
    }) async {
      final server = await pumpSyncedKassa(t);
      await setUpPrinter(t);
      await setSettings(t, (s) => s.copyWith(receiptMode: mode));
      server.pushDelay = (_) => answer;
      return server;
    }

    Future<void> sellCola(WidgetTester t) async {
      await tapItem(t, 'cola');
      await t.tap(find.byKey(const Key('pay-cash')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('finish-sale')));
      await t.pump();
    }

    bool pushed(FakeServer server, String receiptId, {int from = 0}) => [
      for (final r in server.pushRequests.skip(from))
        for (final e in r)
          if (e['kind'] == 'receipt' && (e['receipt']! as Map)['id'] == receiptId)
            e,
    ].isNotEmpty;

    /// Am Ende: nichts mehr unterwegs (die Antwort des Servers ist eine Uhr).
    Future<void> settle(WidgetTester t) async {
      await t.pump(const Duration(seconds: 10));
      await t.pumpAndSettle();
    }

    testWidgets('digital und Druck auf Wunsch, der Server antwortet nach gut '
        '1 Sekunde: kein Kundenbon, der QR-Code erscheint', (t) async {
      final server = await pumpSynced(t, mode: ReceiptMode.digitalOnRequest);
      final before = server.pushRequests.length;
      await sellCola(t);
      final id = await lastReceiptId(t);
      expect(find.byKey(const Key('receipt-qr-wait')), findsOneWidget);
      await t.pump(const Duration(milliseconds: 100));
      // Gesendet sofort, nicht erst nach der Ruhe von 2 Sekunden.
      expect(pushed(server, id, from: before), isTrue);
      await t.pump(const Duration(milliseconds: 1300));
      await t.pump();
      expect(find.byKey(const Key('receipt-qr')), findsOneWidget);
      await t.pump(receiptFallbackDelay);
      await t.pump();
      expect(_receiptPrints(t), isEmpty);
      expect(find.byKey(const Key('receipt-offline-note')), findsNothing);
      await settle(t);
      expect(_receiptPrints(t), isEmpty);
    });

    testWidgets('ein zweiter Verkauf 1 Sekunde später verzögert die '
        'Bestätigung des ersten nicht über seine 3 Sekunden', (t) async {
      final server = await pumpSynced(t, mode: ReceiptMode.digitalOnRequest);
      await sellCola(t);
      final first = await lastReceiptId(t);
      await t.pump(const Duration(seconds: 1));
      final staff = containerOf(t).read(sessionProvider)!;
      final second = await containerOf(t)
          .read(saleServiceProvider)
          .completeCash(
            saleId: 'zweiter',
            cart: const Cart.empty().add(cola),
            givenCents: const Cart.empty().add(cola).totalCents,
            staff: staff,
          );
      await t.pump(const Duration(milliseconds: 500));
      await t.pump();
      expect(pushed(server, first), isTrue);
      expect(find.byKey(const Key('receipt-qr')), findsOneWidget);
      await t.pump(receiptFallbackDelay);
      await t.pump();
      expect(pushed(server, second.receipt.id), isTrue);
      // Der erste zeigte seinen Code: kein Druck. Der zweite kam am Dienst
      // vorbei, sein Code stand nie da: er druckt genau einmal
      // (Schlussprüfung B-I2).
      expect(_receiptPrints(t).map((p) => p.id), [second.receipt.id]);
      expect(await second.fallback.first, ReceiptFallback.printed);
      await settle(t);
      expect(_receiptPrints(t).map((p) => p.id), [second.receipt.id]);
    });

    testWidgets('der Server antwortet nie: nach 3 Sekunden druckt die Kassa '
        'den Bon genau einmal', (t) async {
      final server = await pumpSynced(t, mode: ReceiptMode.digitalOnRequest);
      server.mode = FakeMode.offline;
      await sellCola(t);
      final id = await lastReceiptId(t);
      await t.pump(const Duration(seconds: 2));
      expect(_receiptPrints(t), isEmpty);
      await t.pump(const Duration(seconds: 1));
      await t.pump();
      expect(_receiptPrints(t).map((p) => p.id), [id]);
      expect(find.byKey(const Key('receipt-offline-note')), findsOneWidget);
      await settle(t);
      expect(_receiptPrints(t), hasLength(1));
    });

    testWidgets('immer drucken: kein sofortiges Senden, die Ruhe von 2 '
        'Sekunden bleibt wie in 1.11.0', (t) async {
      final server = await pumpSynced(
        t,
        mode: ReceiptMode.alwaysPrint,
        answer: Duration.zero,
      );
      final before = server.pushRequests.length;
      await sellCola(t);
      final id = await lastReceiptId(t);
      expect(_receiptPrints(t).map((p) => p.id), [id]);
      await t.pump(const Duration(milliseconds: 1500));
      expect(pushed(server, id, from: before), isFalse);
      await t.pump(const Duration(seconds: 1));
      await t.pump();
      expect(pushed(server, id, from: before), isTrue);
      await settle(t);
    });
  });

  testWidgets('als Rechnung gedruckt: "Bon drucken" ist erledigt, der '
      'Druck-Zustand steht da, die Uhr druckt keinen zweiten', (t) async {
    await _pump(t, mode: ReceiptMode.digitalOnRequest);
    await _sellCash(t);
    final receipt = await lastReceipt(t);
    expect(find.byKey(const Key('print-receipt-now')), findsOneWidget);
    await t.pump(const Duration(seconds: 1));
    final recipient = await containerOf(t)
        .read(customerRepositoryProvider)
        .setRecipient(
          receiptId: receipt.id,
          name: 'Muster GmbH',
          addressLine1: 'Musterweg 1',
          addressLine2: '1010 Wien',
          staff: containerOf(t).read(sessionProvider)!,
        );
    final outcome = await containerOf(
      t,
    ).read(saleServiceProvider).printInvoice(receipt, recipient);
    expect(outcome.ok, isTrue);
    await t.pump();
    expect(find.byKey(const Key('print-receipt-now')), findsNothing);
    expect(textOf(t, const Key('print-state')), 'Bon gedruckt');
    await _pastFallback(t);
    expect(_receiptPrints(t), hasLength(1));
    expect(printerOf(t).receiptJobs.single.recipient, isNotNull);
    expect(find.byKey(const Key('receipt-offline-note')), findsNothing);
    expect(await _deliveries(t), [
      {'receipt_id': receipt.id, 'kind': 'printed'},
    ]);
  });

  testWidgets('"Bon drucken" nach einem Druckfehler druckt wieder; '
      '"gedruckt" steht einmal', (t) async {
    await _pump(t, mode: ReceiptMode.digitalOnRequest);
    await _sellCash(t);
    final receipt = await lastReceipt(t);
    final service = containerOf(t).read(saleServiceProvider);
    printerOf(t).next = const PrintOutcome.failed(PrintProblem.unreachable);
    expect((await service.printNow(receipt)).ok, isFalse);
    expect(await _deliveries(t), isEmpty);
    printerOf(t).next = const PrintOutcome.ok();
    expect((await service.printNow(receipt)).ok, isTrue);
    expect((await service.printNow(receipt)).ok, isTrue);
    expect(_receiptPrints(t).map((p) => p.id), [
      receipt.id,
      receipt.id,
      receipt.id,
    ]);
    expect(await receiptCount(t), 1);
    expect(await _deliveries(t), [
      {'receipt_id': receipt.id, 'kind': 'printed'},
    ]);
    await _pastFallback(t);
    expect(_receiptPrints(t), hasLength(3));
  });

  testWidgets('fallback liefert seinen einen Wert an zwei Zuhörer', (t) async {
    await _pump(t, mode: ReceiptMode.digitalOnRequest);
    final staff = containerOf(t).read(sessionProvider)!;
    final sale = await containerOf(t)
        .read(saleServiceProvider)
        .completeCash(
          saleId: 'zwei-zuhoerer',
          cart: const Cart.empty().add(teigtaschen),
          givenCents: 650,
          staff: staff,
        );
    final a = sale.fallback.toList();
    final b = sale.fallback.toList();
    await _pastFallback(t);
    expect(await a, [ReceiptFallback.printed]);
    expect(await b, [ReceiptFallback.printed]);
    expect(await sale.fallback.toList(), [ReceiptFallback.printed]);
    expect(_receiptPrints(t), hasLength(1));
  });

  group('"Bon drucken" und "Nächster Kunde"', () {
    for (final language in AppLanguage.values) {
      for (final scale in [1.0, KassaTokens.maxTextScale]) {
        testWidgets('${language.name}, Textskala $scale, 1024 x 600: beide '
            'mindestens 48 dp hoch, keine Beschriftung gekürzt', (t) async {
          await pumpKassa(
            t,
            size: const Size(1024, 600),
            textScale: scale,
            overrides: await serverKassaOverrides(),
          );
          await setUpPrinter(t);
          await setSettings(
            t,
            (s) => s.copyWith(
              receiptMode: ReceiptMode.digitalOnRequest,
              language: language,
            ),
          );
          await pairRegister(t);
          await _sellCash(t);
          final keys = ['print-receipt-now', 'next-customer'];
          for (final k in keys) {
            final finder = find.byKey(Key(k));
            expect(t.getSize(finder).height, greaterThanOrEqualTo(48), reason: k);
            for (final e in find
                .descendant(of: finder, matching: find.byType(RichText))
                .evaluate()) {
              final box = e.renderObject! as RenderParagraph;
              expect(box.didExceedMaxLines, isFalse, reason: k);
              expect(
                box.getMaxIntrinsicWidth(double.infinity),
                lessThanOrEqualTo(box.size.width + 0.5),
                reason: '$k: "${box.text.toPlainText()}" ist gekürzt',
              );
            }
          }
          final print = t.getRect(find.byKey(Key(keys[0])));
          final next = t.getRect(find.byKey(Key(keys[1])));
          // Nebeneinander (Skizze in Spec 5.4), wenn es passt; sonst darüber.
          if (print.top == next.top) {
            expect(print.overlaps(next), isFalse);
          } else {
            expect(print.bottom, lessThanOrEqualTo(next.top));
            expect(print.width, next.width);
          }
          if (language == AppLanguage.de && scale == 1.0) {
            expect(print.top, next.top, reason: 'Deutsch passt nebeneinander');
          }
          await _pastFallback(t);
        });
      }
    }
  });
}

