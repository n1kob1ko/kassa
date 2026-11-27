import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:drift/drift.dart' show InsertMode, Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/data/card_payment_repository.dart';
import 'package:kassa/data/database.dart';
import 'package:kassa/data/day_repository.dart';
import 'package:kassa/data/receipt_repository.dart';
import 'package:kassa/data/settings_repository.dart';
import 'package:kassa/domain/cart.dart';
import 'package:kassa/domain/catalog.dart';
import 'package:kassa/domain/discount.dart';
import 'package:kassa/domain/receipt.dart';
import 'package:kassa/domain/receipt_rules.dart';
import 'package:kassa/domain/voucher.dart';
import 'package:kassa/data/voucher_repository.dart';

import '../support/demo_fixtures.dart';
import '../support/rksv_rig.dart';
import '../support/sales.dart';

void main() {
  late TestShop shop;
  late ReceiptRepository receipts;

  setUp(() async {
    shop = await TestShop.open();
    receipts = shop.receipts;
  });
  tearDown(() => shop.close());

  test('Abschließen löscht den Bon-Entwurf im selben Schritt', () async {
    final settings = SettingsRepository(shop.db);
    await settings.writeDraft('{"x":1}');
    await shop.receipts.finalizeCashSale(
      saleId: 's1',
      cart: cart,
      givenCents: 2000,
      staff: shop.anna,
    );
    expect(await settings.readDraft(), isNull);
  });

  test('scheitert das Speichern, bleibt der Entwurf', () async {
    final settings = SettingsRepository(shop.db);
    await settings.writeDraft('{"x":1}');
    await expectLater(
      shop.receipts.finalizeCashSale(
        saleId: 's1',
        cart: const Cart.empty(),
        givenCents: 0,
        staff: shop.anna,
      ),
      throwsA(isA<EmptyCartException>()),
    );
    expect(await settings.readDraft(), '{"x":1}');
  });

  test('Bon bekommt Nummer 1, Zeilen, Summen, Zahlung', () async {
    final cart = const Cart.empty()
        .add(cola)
        .add(cola)
        .add(huhnBowl, options: [xxl, nudeln]);
    final r = await receipts.finalizeCashSale(
      saleId: 's1',
      cart: cart,
      givenCents: 2000,
      staff: shop.anna,
    );
    expect((r.number, r.kind, r.staffName), (1, ReceiptKind.sale, 'Anna'));
    expect(r.staffId, shop.anna.id);
    expect((r.goodsCents, r.depositCents, r.totalCents), (1770, 50, 1820));
    expect(r.grossByRate, {TaxRate.normal: 580, TaxRate.reduced1: 1190});
    expect(
      (
        r.payments.single.kind,
        r.payments.single.givenCents,
        r.payments.single.changeCents,
      ),
      (PaymentKind.cash, 2000, 180),
    );
    expect(
      r.lines.last.options.map(
        (o) => (o.groupName, o.optionName, o.surchargeCents),
      ),
      [('Größe', 'XXL', 200), ('Basis', 'Nudeln', 0)],
    );
    expect(r.createdAt, DateTime(2026, 11, 17, 11));
    expect(
      r.lines.map(
        (l) => (
          l.position,
          l.itemId,
          l.unitPriceCents,
          l.quantity,
          l.unitDepositCents,
        ),
      ),
      [(0, 'cola', 290, 2, 25), (1, 'huhn-bowl', 1190, 1, 0)],
    );
    expect(r.lines.last.grossByRate, {TaxRate.reduced1: 1190});
    expect(r.taxLines.map((t) => (t.rate, t.grossCents)), [
      (TaxRate.normal, 580),
      (TaxRate.reduced1, 1190),
    ]);
    final again = await receipts.byId(r.id);
    expect((again.number, again.totalCents, again.lines.length), (1, 1820, 2));
    expect(again.grossByRate, r.grossByRate);
  });

  test('gleiche saleId zweimal ergibt genau einen Bon', () async {
    final a = await shop.sell('s1');
    final b = await shop.sell('s1');
    expect(b.id, a.id);
    expect(await shop.count('receipts'), 1);
  });

  test('gleiche saleId gleichzeitig ergibt genau einen Bon', () async {
    final both = await Future.wait([shop.sell('s1'), shop.sell('s1')]);
    expect(both[0].id, both[1].id);
    expect(both.map((r) => r.number), [1, 1]);
    expect(await shop.count('receipts'), 1);
    expect(await shop.count('payments'), 1);
  });

  test(
    'verschiedene saleIds gleichzeitig bekommen die Nummern 1 und 2',
    () async {
      final both = await Future.wait([shop.sell('a'), shop.sell('b')]);
      expect(both.map((r) => r.number).toList()..sort(), [1, 2]);
    },
  );

  test('Nummern steigen lückenlos, auch wenn die Uhr zurückspringt', () async {
    await shop.sell('s1');
    shop.clock.value = DateTime(2026, 11, 17, 9);
    await shop.sell('s2');
    await shop.sell('s3');
    final day = await shop.dayId();
    expect((await receipts.watchDay(day).first).map((r) => r.number).toList(), [
      1,
      2,
      3,
    ]);
  });

  test('watchDay meldet jeden neuen Bon', () async {
    await shop.sell('s1');
    final day = await shop.dayId();
    final emitted = <List<int>>[];
    final sub = receipts
        .watchDay(day)
        .listen((l) => emitted.add([for (final r in l) r.number]));
    await pumpEventQueue();
    await shop.sell('s2');
    await pumpEventQueue();
    await sub.cancel();
    expect(emitted.first, [1]);
    expect(emitted.last, [1, 2]);
  });

  test('leerer Bon und zu wenig Geld werden abgelehnt', () async {
    await expectLater(
      receipts.finalizeCashSale(
        saleId: 'x',
        cart: const Cart.empty(),
        givenCents: 0,
        staff: shop.anna,
      ),
      throwsA(isA<EmptyCartException>()),
    );
    await expectLater(
      receipts.finalizeCashSale(
        saleId: 'y',
        cart: cart,
        givenCents: 100,
        staff: shop.anna,
      ),
      throwsA(isA<InsufficientCashException>()),
    );
    expect(await shop.count('receipts'), 0);
  });

  test('Summe 0 mit gegeben 0 geht', () async {
    final r = await receipts.finalizeCashSale(
      saleId: 'z',
      cart: const Cart.empty().add(leitungswasser),
      givenCents: 0,
      staff: shop.anna,
    );
    expect(r.totalCents, 0);
  });

  test('Storno erzeugt einen eigenen Bon mit negativen Beträgen', () async {
    final r = await shop.sell('s1');
    final v = await receipts.voidReceipt(r.id, staff: shop.chef);
    expect(
      (v.number, v.kind, v.voidsReceiptId, v.totalCents),
      (2, ReceiptKind.voided, r.id, -r.totalCents),
    );
    expect(v.staffName, 'Chef');
    expect(v.lines.first.quantity, -r.lines.first.quantity);
    expect(v.lines.last.options.map((o) => o.optionName), ['XXL', 'Nudeln']);
    expect(v.payments.single.amountCents, -r.totalCents);
    expect(
      (
        v.payments.single.kind,
        v.payments.single.givenCents,
        v.payments.single.changeCents,
      ),
      (PaymentKind.cash, 0, 0),
    );
    expect(v.businessDayId, r.businessDayId);
    expect((await receipts.byId(r.id)).isVoided, isTrue);
    expect((await receipts.byId(r.id)).voidedByReceiptId, v.id);
    expect(v.isVoided, isFalse);
    await expectLater(
      receipts.voidReceipt(r.id, staff: shop.chef),
      throwsA(isA<AlreadyVoidedException>()),
    );
    await expectLater(
      receipts.voidReceipt(v.id, staff: shop.chef),
      throwsA(isA<CannotVoidAVoidException>()),
    );
  });

  test('Storno-Bon hat negierte Steuerbeträge und negiertes Pfand', () async {
    final r = await shop.sell('s1');
    final v = await receipts.voidReceipt(r.id, staff: shop.chef);
    expect(v.grossByRate, {TaxRate.normal: -580, TaxRate.reduced1: -1190});
    expect(v.grossByRate, {
      for (final e in r.grossByRate.entries) e.key: -e.value,
    });
    expect((v.goodsCents, v.depositCents), (-1770, -50));
    expect(
      v.taxLines.map((t) => (t.rate, t.grossCents, t.netCents, t.taxCents)),
      r.taxLines.map((t) => (t.rate, -t.grossCents, -t.netCents, -t.taxCents)),
    );
  });

  test('Storno kopiert die Zeilen vom Bon, nicht aus dem Katalog', () async {
    final r = await shop.sell('s1');
    await shop.catalogRepo.updateItem('cola', priceCents: 999);
    final v = await receipts.voidReceipt(r.id, staff: shop.chef);
    expect(v.lines.first.unitPriceCents, 290);
    expect(v.totalCents, -1820);
  });

  test('Storno gehört zum Tag, der beim Storno offen ist', () async {
    final r = await shop.sell('s1');
    await shop.db.customStatement(
      "UPDATE business_days SET closed_at = 1 WHERE id = '${r.businessDayId}'",
    );
    final v = await receipts.voidReceipt(r.id, staff: shop.chef);
    expect(v.businessDayId, isNot(r.businessDayId));
    expect(v.businessDayId, await shop.dayId());
  });

  test('byId mit unbekannter Id wirft StateError', () async {
    await expectLater(receipts.byId('gibt-es-nicht'), throwsStateError);
  });

  test(
    'ein Bon behält Namen und Preis, auch wenn der Artikel sich ändert',
    () async {
      final r = await shop.sell('s1');
      await shop.catalogRepo.updateItem('cola', priceCents: 999);
      final stored = await receipts.byId(r.id);
      expect(stored.lines.first.unitPriceCents, 290);
      expect(stored.lines.first.name, 'Cola 0,33 l');
    },
  );

  test('die Datenbank weist Ändern und Löschen von Bons ab', () async {
    await shop.sell('s1');
    for (final sql in [
      'UPDATE receipts SET total_cents = 1',
      'DELETE FROM receipts',
      'UPDATE receipt_lines SET quantity = 5',
      'DELETE FROM receipt_lines',
      'UPDATE receipt_line_options SET surcharge_cents = 5',
      'DELETE FROM receipt_line_options',
      'UPDATE payments SET amount_cents = 1',
      'DELETE FROM payments',
    ]) {
      await expectLater(
        shop.db.customStatement(sql),
        throwsA(
          predicate((e) => e.toString().contains('Bons sind unveränderlich')),
        ),
        reason: sql,
      );
    }
    expect(await shop.count('receipt_line_options'), 2);
  });

  test('Storno eines Bons mit falschen Summen (von Hand geschrieben): die '
      'Geld-Regeln weisen ihn ab, kein Bon kommt dazu', () async {
    final r = await shop.sell('s1');
    // Ware 2,90 €, Summe 3,00 €: Summe ≠ Ware nach Rabatt plus Pfand.
    await shop.db.customStatement(
      "INSERT INTO receipts (id, number, created_at, staff_id, staff_name, business_day_id, kind, goods_cents, deposit_cents, total_cents) "
      "VALUES ('bad', 99, 1, 'a', 'Anna', '${r.businessDayId}', 'sale', 290, 0, 300)",
    );
    await shop.db.customStatement(
      "INSERT INTO receipt_lines (receipt_id, position, item_id, name, unit_price_cents, quantity, unit_deposit_cents, gross20_cents) "
      "VALUES ('bad', 0, 'cola', 'Cola 0,33 l', 290, 1, 0, 290)",
    );
    await shop.db.customStatement(
      "INSERT INTO payments (receipt_id, position, kind, amount_cents, given_cents, change_cents) "
      "VALUES ('bad', 0, 'cash', 300, 300, 0)",
    );
    final before = await shop.count('receipts');
    await expectLater(
      receipts.voidReceipt('bad', staff: shop.chef),
      throwsA(isA<ReceiptRuleViolation>()),
    );
    expect(await shop.count('receipts'), before);
  });

  test('zwei Stornos desselben Bons scheitern an der Datenbank', () async {
    final r = await shop.sell('s1');
    await receipts.voidReceipt(r.id, staff: shop.chef);
    await expectLater(
      shop.db.customStatement(
        "INSERT INTO receipts (id, number, created_at, staff_id, staff_name, business_day_id, kind, voids_receipt_id, goods_cents, deposit_cents, total_cents) "
        "VALUES ('x', 99, 1, 'a', 'A', '${r.businessDayId}', 'voided', '${r.id}', 0, 0, 0)",
      ),
      throwsA(anything),
    );
  });

  test('Kartenbon: Zahlung mit Anbieter, Beleg-Code und Karte, Entwurf und '
      'offene Zahlung im selben Schritt weg', () async {
    final cards = CardPaymentRepository(shop.db, shop.clock);
    await cards.begin(paymentId: 'c1', cart: cart, staff: shop.anna);
    final settings = SettingsRepository(shop.db);
    await settings.writeDraft('{"lines":[]}');
    final r = await receipts.finalizeCardSale(
      saleId: 'c1',
      cart: cart,
      staff: shop.anna,
      provider: 'sumup',
      txCode: 'TX9',
      cardScheme: 'VISA',
      cardLast4: '4242',
    );
    expect(r.payments.single.kind, PaymentKind.card);
    expect(
      (
        r.payments.single.amountCents,
        r.payments.single.givenCents,
        r.payments.single.changeCents,
      ),
      (1820, 0, 0),
    );
    final back = await receipts.byId('c1');
    expect(
      (
        back.payments.single.provider,
        back.payments.single.providerTxCode,
        back.payments.single.cardScheme,
        back.payments.single.cardLast4,
      ),
      ('sumup', 'TX9', 'VISA', '4242'),
    );
    expect(await cards.pending(), isEmpty);
    expect(await settings.readDraft(), isNull);
  });

  test('Kartenbon: gleiche saleId zweimal ergibt einen Bon', () async {
    final a = await shop.sellCard('c1');
    final b = await shop.sellCard('c1');
    expect(b.id, a.id);
    expect(await shop.count('receipts'), 1);
  });

  test(
    'Kartenbon: leerer Bon wird abgelehnt, die offene Zahlung bleibt',
    () async {
      final cards = CardPaymentRepository(shop.db, shop.clock);
      await cards.begin(paymentId: 'c1', cart: cart, staff: shop.anna);
      await expectLater(
        receipts.finalizeCardSale(
          saleId: 'c1',
          cart: const Cart.empty(),
          staff: shop.anna,
          provider: 'sumup',
        ),
        throwsA(isA<EmptyCartException>()),
      );
      expect(await cards.pending(), hasLength(1));
      expect(await shop.count('receipts'), 0);
    },
  );

  test('Storno eines Karten-Bons: Storno-Bon mit Zahlungsart Karte und '
      'negativem Betrag', () async {
    final sale = await shop.sellCard('c1');
    final v = await receipts.voidReceipt(sale.id, staff: shop.chef);
    expect(v.payments.single.kind, PaymentKind.card);
    expect(v.payments.single.amountCents, -sale.totalCents);
    expect(v.payments.single.providerTxCode, 'TX-c1');
    expect(v.totalCents, -sale.totalCents);
  });

  group('Sonderbelege', () {
    /// Kompakte JWS-Form mit erfundener Nutzlast und Signatur 01 02 03.
    String jws(String payload) =>
        'eyJhbGciOiJFUzI1NiJ9.'
        '${base64Url.encode(utf8.encode(payload)).replaceAll('=', '')}.AQID';

    Future<void> insertChain(int chain, String mode, String cashBoxId) async {
      await shop.db
          .into(shop.db.rksvCertificateRows)
          .insert(
            RksvCertificateRowsCompanion.insert(
              serialHex: '0a1b',
              certificate: Uint8List.fromList([0x30, 0x82]),
            ),
            mode: InsertMode.insertOrIgnore,
          );
      await shop.db
          .into(shop.db.rksvChainRows)
          .insert(
            RksvChainRowsCompanion.insert(
              chain: Value(chain),
              mode: mode,
              cashBoxId: cashBoxId,
              zdaId: 'R1-AT100',
              certSerial: '0a1b',
              startedAt: DateTime(2026, 11, 1),
            ),
          );
    }

    Future<void> insertEntry(
      int chain,
      int position,
      String receiptId,
      String jws, {
      bool damaged = false,
    }) => shop.db
        .into(shop.db.rksvEntryRows)
        .insert(
          RksvEntryRowsCompanion.insert(
            chain: chain,
            position: position,
            receiptId: receiptId,
            jws: jws,
            damaged: damaged,
            certSerial: '0a1b',
          ),
        );

    test('ein Bon ohne Tag und ohne Zahlung wird gelesen', () async {
      await shop.insertSpecialReceipt('m1', 1, ReceiptKind.month);
      final r = await receipts.byId('m1');
      expect(r.kind, ReceiptKind.month);
      expect(r.businessDayId, isNull);
      expect(r.payments, isEmpty);
      expect(r.lines, isEmpty);
      expect((r.goodsCents, r.depositCents, r.totalCents), (0, 0, 0));
      expect(r.rksv, isNull);
      expect(r.isVoided, isFalse);
    });

    test('Arten: Sonderbelege und ihre Bezeichnungen', () {
      expect(
        {for (final k in ReceiptKind.values) k.name: k.specialTitle},
        {
          'sale': null,
          'voided': null,
          'start': 'Startbeleg',
          'month': 'Monatsbeleg',
          'year': 'Jahresbeleg',
          'zero': 'Nullbeleg',
          'collective': 'Sammelbeleg',
          'closing': 'Schlussbeleg',
        },
      );
      expect(
        [
          for (final k in ReceiptKind.values)
            if (k.isSpecial) k.name,
        ],
        ['start', 'month', 'year', 'zero', 'collective', 'closing'],
      );
    });

    test('rksv kommt aus Protokoll-Eintrag und Kette', () async {
      await insertChain(1, 'probe', 'BSPIMB01');
      await insertChain(2, 'live', 'BSPIMB02');
      await shop.insertSpecialReceipt('st', 1, ReceiptKind.start);
      await shop.sell('s1');
      final sale = (await shop.db.select(shop.db.receiptRows).get())
          .singleWhere((r) => r.number == 2);
      await insertEntry(1, 1, 'st', jws('_R1-AT100_BSPIMB01_1'));
      await insertEntry(
        2,
        1,
        sale.id,
        jws('_R1-AT100_BSPIMB02_2'),
        damaged: true,
      );
      await shop.sell('s2'); // ohne Eintrag

      final start = (await receipts.byId('st')).rksv!;
      expect(
        (start.cashBoxId, start.qrText, start.damaged, start.probe),
        ('BSPIMB01', '_R1-AT100_BSPIMB01_1_AQID', false, true),
      );
      final day = await receipts.watchDay(await shop.dayId()).first;
      final signed = day.singleWhere((r) => r.number == 2).rksv!;
      expect(
        (signed.cashBoxId, signed.qrText, signed.damaged, signed.probe),
        ('BSPIMB02', '_R1-AT100_BSPIMB02_2_AQID', true, false),
      );
      expect(day.singleWhere((r) => r.number == 3).rksv, isNull);
    });

    test('ein kaputter JWS im Protokoll: dieser Bon kommt ohne rksv, die '
        'anderen mit', () async {
      await insertChain(1, 'probe', 'BSPIMB01');
      await shop.sell('s1');
      await shop.sell('s2');
      await shop.sell('s3');
      await insertEntry(1, 1, 's1', jws('_R1-AT100_BSPIMB01_1'));
      await insertEntry(1, 2, 's2', 'kein-jws');
      await insertEntry(1, 3, 's3', 'eyJhbGciOiJFUzI1NiJ9.%%%.AQID');
      expect((await receipts.byId('s2')).rksv, isNull);
      expect((await receipts.byId('s3')).rksv, isNull);
      final day = await receipts.watchDay(await shop.dayId()).first;
      expect(
        [for (final r in day) r.rksv?.qrText],
        ['_R1-AT100_BSPIMB01_1_AQID', null, null],
      );
    });

    test('ein Sonderbeleg lässt sich nicht stornieren, nichts wird '
        'geschrieben', () async {
      await shop.insertSpecialReceipt('st', 1, ReceiptKind.start);
      await expectLater(
        receipts.voidReceipt('st', staff: shop.chef),
        throwsA(isA<CannotVoidSpecialException>()),
      );
      expect(await shop.count('receipts'), 1);
    });

    test('watchDay ordnet Sonderbelege nach der Zeit den Tagen zu', () async {
      await shop.insertDay(
        'a',
        DateTime(2026, 11, 10, 8),
        closedAt: DateTime(2026, 11, 10, 20),
      );
      await shop.insertDay(
        'b',
        DateTime(2026, 11, 12, 8),
        closedAt: DateTime(2026, 11, 12, 20),
      );
      await shop.insertDay('c', DateTime(2026, 11, 14, 8));
      // Sonderbelege: vor dem ersten Tag, zwischen den Tagen, genau beim
      // Beginn eines Tages und nach dem Beginn des neuesten Tages.
      await shop.insertSpecialReceipt(
        'start',
        1,
        ReceiptKind.start,
        at: DateTime(2026, 11, 9, 12),
      );
      await shop.insertCardReceipt(
        'a1',
        2,
        500,
        day: 'a',
        at: DateTime(2026, 11, 10, 9),
      );
      await shop.insertSpecialReceipt(
        'zero-a',
        3,
        ReceiptKind.zero,
        at: DateTime(2026, 11, 11, 12),
      );
      await shop.insertSpecialReceipt(
        'month-b',
        4,
        ReceiptKind.month,
        at: DateTime(2026, 11, 12, 8),
      );
      await shop.insertCardReceipt(
        'b1',
        5,
        500,
        day: 'b',
        at: DateTime(2026, 11, 12, 8),
      );
      await shop.insertSpecialReceipt(
        'zero-b',
        6,
        ReceiptKind.zero,
        at: DateTime(2026, 11, 13, 12),
      );
      await shop.insertCardReceipt(
        'c1',
        7,
        500,
        day: 'c',
        at: DateTime(2026, 11, 14, 9),
      );
      await shop.insertSpecialReceipt(
        'closing',
        8,
        ReceiptKind.closing,
        at: DateTime(2026, 11, 20, 12),
      );

      Future<List<int>> numbersOf(String day) async => [
        for (final r in await receipts.watchDay(day).first) r.number,
      ];
      expect(await numbersOf('a'), [1, 2, 3]);
      expect(await numbersOf('b'), [4, 5, 6]);
      expect(await numbersOf('c'), [7, 8]);
    });

    test('watchDay meldet einen neuen Sonderbeleg', () async {
      await shop.sell('s1');
      final day = await shop.dayId();
      final emitted = <List<int>>[];
      final sub = receipts
          .watchDay(day)
          .listen((l) => emitted.add([for (final r in l) r.number]));
      await pumpEventQueue();
      await shop.insertSpecialReceipt('z', 2, ReceiptKind.zero);
      await pumpEventQueue();
      await sub.cancel();
      expect(emitted.first, [1]);
      expect(emitted.last, [1, 2]);
    });
  });

  group('Zahlungen als Liste', () {
    test(
      'Teil bar, Rest Karte mit Trinkgeld: zwei Zahlungen, Karte zuletzt',
      () async {
        final r = await shop.receipts.finalizeCardSale(
          saleId: 'm1',
          cart: cart,
          staff: shop.anna,
          provider: 'sumup',
          txCode: 'TX1',
          cashPartCents: 1000,
          tipCents: 80,
        );
        expect(r.totalCents, 1820);
        expect(
          [
            for (final p in r.payments)
              (p.position, p.kind, p.amountCents, p.tipCents),
          ],
          [(0, PaymentKind.cash, 1000, 0), (1, PaymentKind.card, 820, 80)],
        );
        expect(
          (r.payments[1].tipStaffId, r.payments[1].chargedCents),
          (shop.anna.id, 900),
        );
        expect(
          (r.cashCents, r.cardCents, r.tipCents, r.paymentKind),
          (1000, 820, 80, ReceiptPaymentKind.mixed),
        );
        expect(
          (await shop.db.select(shop.db.receiptRows).getSingle()).tipCents,
          80,
        );
      },
    );

    test('Storno spiegelt jede Zahlung und das Trinkgeld; es bleibt bei der '
        'Person, die kassiert hat', () async {
      await shop.receipts.finalizeCardSale(
        saleId: 'm1',
        cart: cart,
        staff: shop.anna,
        provider: 'sumup',
        cashPartCents: 1000,
        tipCents: 80,
      );
      final v = await shop.receipts.voidReceipt('m1', staff: shop.chef);
      expect(
        [
          for (final p in v.payments)
            (p.kind, p.amountCents, p.tipCents, p.givenCents, p.changeCents),
        ],
        [
          (PaymentKind.cash, -1000, 0, 0, 0),
          (PaymentKind.card, -820, -80, 0, 0),
        ],
      );
      expect(
        (v.payments[1].tipStaffId, v.staffId),
        (shop.anna.id, shop.chef.id),
      );
    });

    test('Bar-Teil gleich der Summe, negativ, oder Trinkgeld negativ: '
        'ArgumentError, nichts gespeichert', () async {
      Future<Receipt> sale({int cashPart = 0, int tip = 0}) =>
          shop.receipts.finalizeCardSale(
            saleId: 'm1',
            cart: cart,
            staff: shop.anna,
            provider: 'sumup',
            cashPartCents: cashPart,
            tipCents: tip,
          );
      await expectLater(sale(cashPart: 1820), throwsArgumentError);
      await expectLater(sale(cashPart: -1), throwsArgumentError);
      await expectLater(sale(tip: -1), throwsArgumentError);
      expect(await shop.count('receipts'), 0);
      expect(await shop.count('payments'), 0);
    });

    test('ein Bon aus 1.10.0 (eine Zahlung, Stelle 0) lässt sich lesen und '
        'stornieren', () async {
      final day = await shop.days.openOrCreateDay();
      await shop.db
          .into(shop.db.receiptRows)
          .insert(
            ReceiptRowsCompanion.insert(
              id: 'alt',
              number: 1,
              createdAt: shop.clock.now(),
              staffId: shop.anna.id,
              staffName: shop.anna.name,
              businessDayId: Value(day.id),
              kind: ReceiptKind.sale.name,
              goodsCents: 590,
              depositCents: 0,
              totalCents: 590,
            ),
          );
      await shop.db
          .into(shop.db.receiptLineRows)
          .insert(
            ReceiptLineRowsCompanion.insert(
              receiptId: 'alt',
              position: 0,
              itemId: teigtaschen.id,
              name: teigtaschen.name,
              unitPriceCents: 590,
              quantity: 1,
              unitDepositCents: 0,
              gross10Cents: const Value(590),
            ),
          );
      await shop.db
          .into(shop.db.paymentRows)
          .insert(
            PaymentRowsCompanion.insert(
              receiptId: 'alt',
              kind: PaymentKind.card.name,
              amountCents: 590,
              givenCents: 0,
              changeCents: 0,
              provider: const Value('sumup'),
            ),
          );
      final r = await shop.receipts.byId('alt');
      expect(
        [
          for (final p in r.payments)
            (p.position, p.kind, p.amountCents, p.tipCents, p.tipStaffId),
        ],
        [(0, PaymentKind.card, 590, 0, null)],
      );
      expect(
        (r.paymentKind, r.cardCents, r.tipCents),
        (ReceiptPaymentKind.card, 590, 0),
      );
      final v = await shop.receipts.voidReceipt('alt', staff: shop.chef);
      expect(
        [
          for (final p in v.payments)
            (p.position, p.kind, p.amountCents, p.provider),
        ],
        [(0, PaymentKind.card, -590, 'sumup')],
      );
    });
  });

  group('Rabatt', () {
    test('Bon mit Zeilen-Rabatt und Bon-Rabatt', () async {
      final r = await shop.receipts.finalizeCashSale(
        saleId: 'r1',
        cart: discounted,
        givenCents: 2000,
        staff: shop.anna,
      );
      expect(
        (
          r.goodsCents,
          r.depositCents,
          r.totalCents,
          r.discountCents,
          r.subtotalCents,
        ),
        (1486, 50, 1536, 284, 1651),
      );
      expect(
        (
          r.discount!.percent,
          r.discount!.amountCents,
          r.discount!.reason,
          r.discount!.label,
        ),
        (10, 165, 'promotion', 'Rabatt 10 % Aktion'),
      );
      expect(
        [
          for (final l in r.lines)
            (l.goodsCents, l.discountCents, l.discount?.amountCents),
        ],
        [(580, 58, null), (1190, 226, 119)],
      );
      expect(
        (r.lines[1].discount!.percent, r.lines[1].discount!.reason),
        (10, 'regular'),
      );
      expect(r.grossByRate, {TaxRate.normal: 522, TaxRate.reduced1: 964});
      expect(
        (r.payments.single.amountCents, r.payments.single.changeCents),
        (1536, 464),
      );
    });

    test('Storno ist das genaue Spiegelbild, auch der Rabatte', () async {
      final r = await shop.receipts.finalizeCashSale(
        saleId: 'r1',
        cart: discounted,
        givenCents: 2000,
        staff: shop.anna,
      );
      final v = await shop.receipts.voidReceipt('r1', staff: shop.chef);
      expect(
        (v.goodsCents, v.totalCents, v.discountCents, v.discount!.amountCents),
        (-1486, -1536, -284, -165),
      );
      expect(
        (v.discount!.percent, v.discount!.reason, v.subtotalCents),
        (10, 'promotion', -1651),
      );
      expect(
        [
          for (final l in v.lines)
            (l.quantity, l.discountCents, l.discount?.amountCents),
        ],
        [(-2, -58, null), (-1, -226, -119)],
      );
      expect(
        (v.lines[1].discount!.percent, v.lines[1].discount!.reason),
        (10, 'regular'),
      );
      expect(v.grossByRate, {
        for (final e in r.grossByRate.entries) e.key: -e.value,
      });
    });

    test(
      'Storno eines Bons ohne Rabatt: alle Rabatt-Felder 0 oder leer',
      () async {
        await shop.sell('s1');
        final v = await shop.receipts.voidReceipt('s1', staff: shop.chef);
        expect(
          (v.discountCents, v.discount, v.subtotalCents),
          (0, null, -1770),
        );
        expect(
          [for (final l in v.lines) (l.discountCents, l.discount)],
          [(0, null), (0, null)],
        );
      },
    );

    test(
      'Einladung ohne Pfand: Bon über 0,00 € mit einer Bar-Zahlung über 0',
      () async {
        final free = const Cart.empty()
            .add(teigtaschen)
            .setReceiptDiscount(
              const Discount.percent(100, DiscountReason.invitation),
            );
        final r = await shop.receipts.finalizeCashSale(
          saleId: 'f1',
          cart: free,
          givenCents: 0,
          staff: shop.anna,
        );
        expect(
          (
            r.totalCents,
            r.discountCents,
            r.payments.single.kind,
            r.payments.single.amountCents,
          ),
          (0, 650, PaymentKind.cash, 0),
        );
        expect(r.discount!.label, 'Rabatt 100 % Einladung');
      },
    );

    test('mit Signatur: der Bon mit Rabatt besteht die Summenprüfung, die '
        'signierten Beträge je Satz sind die nach Rabatt', () async {
      final rig = await RksvRig.open();
      addTearDown(rig.close);
      await rig.service.enableProbe(staff: rig.chef);
      String euro(int c) =>
          '${c < 0 ? '-' : ''}${c.abs() ~/ 100},'
          '${(c.abs() % 100).toString().padLeft(2, '0')}';
      List<String> expected(Receipt r) => [
        for (final rate in [
          TaxRate.normal,
          TaxRate.reduced1,
          TaxRate.reduced2,
          TaxRate.zero,
          TaxRate.special,
        ])
          euro(
            (r.grossByRate[rate] ?? 0) +
                (rate == TaxRate.zero ? r.depositCents + r.tipCents : 0),
          ),
      ];

      final r = await rig.sell('d1', discounted);
      expect(r.rksv, isNotNull);
      expect(r.grossByRate, {TaxRate.normal: 522, TaxRate.reduced1: 964});
      expect((await rig.codeFieldsOf('d1')).sublist(5, 10), expected(r));
      expect((await rig.codeFieldsOf('d1')).sublist(5, 10), [
        '5,22',
        '9,64',
        '0,00',
        '0,50',
        '0,00',
      ]);

      final c = await rig.sellCard('d2', discounted, tipCents: 80);
      expect((await rig.codeFieldsOf('d2')).sublist(5, 10), expected(c));

      final v = await rig.receipts.voidReceipt('d1', staff: rig.chef);
      expect((await rig.codeFieldsOf(v.id)).sublist(5, 10), expected(v));
      await rig.verifyChain(1);
    });
  });

  group('Pfand zurück und Gutscheine', () {
    test(
      'Pfand zurück auf einem Bon mit Ware: Summe 17,45 €, bar bezahlt',
      () async {
        final r = await shop.receipts.finalizeCashSale(
          saleId: 'p1',
          cart: cart.setDepositReturn(depositCents: 25, quantity: 3),
          givenCents: 2000,
          staff: shop.anna,
        );
        expect(
          (
            r.goodsCents,
            r.depositCents,
            r.totalCents,
            r.depositReturnCents,
            r.depositReturnQuantity,
          ),
          (1770, -25, 1745, -75, 3),
        );
        expect(
          (r.payments.single.amountCents, r.payments.single.changeCents),
          (1745, 255),
        );
        expect(r.publicToken, hasLength(22));
      },
    );

    test(
      'nur Pfand zurück: Auszahlung über 0,75 €, Storno ist das Spiegelbild',
      () async {
        final back = const Cart.empty().setDepositReturn(
          depositCents: 25,
          quantity: 3,
        );
        final r = await shop.receipts.finalizePayout(
          saleId: 'p2',
          cart: back,
          staff: shop.anna,
        );
        expect(
          (
            r.totalCents,
            r.payments.single.kind,
            r.payments.single.amountCents,
            r.payments.single.givenCents,
            r.payments.single.changeCents,
          ),
          (-75, PaymentKind.cash, -75, 0, 0),
        );
        final v = await shop.receipts.voidReceipt('p2', staff: shop.chef);
        expect(
          (
            v.totalCents,
            v.payments.single.amountCents,
            v.lines.single.quantity,
          ),
          (75, 75, -3),
        );
        expect(
          () => shop.receipts.finalizePayout(
            saleId: 'p3',
            cart: cart,
            staff: shop.anna,
          ),
          throwsArgumentError,
        );
      },
    );

    test('Gutschein verkaufen: Gutschein mit Code und Bewegung, die Zeile trägt den Code, kein Umsatz', () async {
      final r = await shop.receipts.finalizeCashSale(
        saleId: 'g1',
        cart: cartCard.addVoucherSale(valueCents: 2500),
        givenCents: 4000,
        staff: shop.anna,
      );
      final sold = r.soldVouchers.single;
      expect(
        (
          r.totalCents,
          r.voucherSaleCents,
          r.revenueCents,
          sold.valueCents,
          sold.linePosition,
        ),
        (3465, 2500, 965, 2500, 2),
      );
      expect(isVoucherCode(sold.code), isTrue);
      expect(r.lines.last.info, 'Code ${formatVoucherCode(sold.code)}');
      final voucher = (await shop.vouchers.findByCode(sold.code)).single;
      expect(
        (
          voucher.balanceCents,
          voucher.state,
          voucher.untouched,
          voucher.soldReceiptId,
        ),
        (2500, VoucherState.active, true, 'g1'),
      );
    });

    test('mit Gutschein bezahlen: ganz, mit Rest bar, mit Rest Karte; das Guthaben sinkt', () async {
      final v = await sellVoucher(
        shop,
        2500,
      ); // Helfer: verkauft bar, gibt den Voucher zurück
      final all = await shop.receipts.finalizeVoucherSale(
        saleId: 'e1',
        cart: cartCard.applyVoucher(applied(v)),
        staff: shop.anna,
      );
      expect(
        [
          for (final p in all.payments)
            (p.kind, p.amountCents, p.voucherCode, p.voucherBalanceAfterCents),
        ],
        [(PaymentKind.voucher, 965, v.code, 1535)],
      );
      final small = await sellVoucher(shop, 500);
      final cash = await shop.receipts.finalizeCashSale(
        saleId: 'e2',
        cart: cartCard.applyVoucher(applied(small)),
        givenCents: 500,
        staff: shop.anna,
      );
      expect(
        [for (final p in cash.payments) (p.kind, p.amountCents, p.changeCents)],
        [(PaymentKind.voucher, 500, 0), (PaymentKind.cash, 465, 35)],
      );
      final small2 = await sellVoucher(shop, 500);
      final card = await shop.receipts.finalizeCardSale(
        saleId: 'e3',
        cart: cartCard.applyVoucher(applied(small2)),
        staff: shop.anna,
        provider: 'sumup',
        tipCents: 35,
      );
      expect(
        [for (final p in card.payments) (p.kind, p.amountCents, p.tipCents)],
        [(PaymentKind.voucher, 500, 0), (PaymentKind.card, 465, 35)],
      );
      expect(await shop.vouchers.balanceOf(v.id), 1535);
    });

    test('Guthaben reicht nicht mehr: VoucherBalanceException, nichts gespeichert; mit allowOverdraw entsteht der Kartenbon und der Gutschein ist überzogen', () async {
      final v = await sellVoucher(shop, 500);
      final stale = cartCard.applyVoucher(applied(v));
      await shop.receipts.finalizeVoucherSale(
        saleId: 'x1',
        cart: Cart.empty().add(cola).applyVoucher(applied(v)),
        staff: shop.anna,
      ); // verbraucht 3,15 €
      await expectLater(
        shop.receipts.finalizeCashSale(
          saleId: 'x2',
          cart: stale,
          givenCents: 500,
          staff: shop.anna,
        ),
        throwsA(
          isA<VoucherBalanceException>().having(
            (e) => e.balanceCents,
            'balanceCents',
            185,
          ),
        ),
      );
      expect(await shop.receipts.find('x2'), isNull);
      await shop.receipts.finalizeCardSale(
        saleId: 'x3',
        cart: stale,
        staff: shop.anna,
        provider: 'sumup',
        allowOverdraw: true,
      );
      expect((await shop.vouchers.byId(v.id))!.state, VoucherState.overdrawn);
    });

    test('Storno gibt das Guthaben zurück; ein Gutschein-Verkauf lässt sich nur unberührt stornieren', () async {
      final v = await sellVoucher(shop, 2500, saleId: 'g2');
      await shop.receipts.finalizeVoucherSale(
        saleId: 'e4',
        cart: cartCard.applyVoucher(applied(v)),
        staff: shop.anna,
      );
      await expectLater(
        shop.receipts.voidReceipt('g2', staff: shop.chef),
        throwsA(isA<VoucherSaleRedeemedException>()),
      );
      final back = await shop.receipts.voidReceipt('e4', staff: shop.chef);
      expect(
        (
          back.payments.single.amountCents,
          back.payments.single.voucherBalanceAfterCents,
        ),
        (-965, 2500),
      );
      final gone = await shop.receipts.voidReceipt('g2', staff: shop.chef);
      expect(
        (
          gone.soldVouchers.single.valueCents,
          (await shop.vouchers.byId(v.id))!.state,
        ),
        (-2500, VoucherState.voided),
      );
    });

    test(
      'Übungs-Gutschein gilt nicht im echten Betrieb und umgekehrt',
      () async {
        final rig = await RksvRig.open();
        addTearDown(rig.close);
        final vouchers = VoucherRepository(rig.db);
        Future<Voucher> sell(String saleId) async {
          final r = await rig.sell(
            saleId,
            const Cart.empty().addVoucherSale(valueCents: 2000),
          );
          return (await vouchers.byId(r.soldVouchers.single.voucherId))!;
        }

        // Kette 1 im Modus probe: Übungs-Bons, Übungs-Gutschein.
        await rig.service.enableProbe(staff: rig.chef);
        final probe = await sell('probe-g');
        expect(probe.isTest, isTrue);

        // Kette 2 im Modus live: echte Bons, echter Gutschein.
        final info = await rig.fake.info();
        await rig.secrets.writeAesKey(
          2,
          Uint8List.fromList(List.generate(32, (i) => i)),
        );
        await rig.db
            .into(rig.db.rksvChainRows)
            .insert(
              RksvChainRowsCompanion.insert(
                chain: const Value(2),
                mode: 'live',
                cashBoxId: 'LIVETEST02',
                zdaId: 'AT100',
                certSerial: info.serialHex,
                startedAt: rig.clock.now(),
              ),
            );
        await (rig.db.update(
          rig.db.rksvStateRows,
        )..where((t) => t.id.equals(1))).write(
          const RksvStateRowsCompanion(mode: Value('live'), chain: Value(2)),
        );
        final live = await sell('live-g');
        expect(live.isTest, isFalse);

        final rows = await rig.count('receipts');
        final moves = await rig.count('voucher_movements');
        await expectLater(
          rig.receipts.finalizeVoucherSale(
            saleId: 'live-e',
            cart: Cart.empty().add(cola).applyVoucher(applied(probe)),
            staff: rig.anna,
          ),
          throwsA(
            isA<VoucherBalanceException>()
                .having((e) => e.voucherId, 'voucherId', probe.id)
                .having((e) => e.balanceCents, 'balanceCents', 0),
          ),
        );
        expect(
          (await rig.count('receipts'), await rig.count('voucher_movements')),
          (rows, moves),
        );
        final ok = await rig.receipts.finalizeVoucherSale(
          saleId: 'live-ok',
          cart: Cart.empty().add(cola).applyVoucher(applied(live)),
          staff: rig.anna,
        );
        expect(ok.payments.single.voucherBalanceAfterCents, 1685);

        // Ohne Signatur ist jeder Bon ein Übungs-Bon: dort gilt nur der
        // Übungs-Gutschein.
        final practice = ReceiptRepository(
          rig.db,
          rig.clock,
          DayRepository(rig.db, rig.clock),
        );
        await expectLater(
          practice.finalizeVoucherSale(
            saleId: 'test-e',
            cart: Cart.empty().add(cola).applyVoucher(applied(live)),
            staff: rig.anna,
          ),
          throwsA(
            isA<VoucherBalanceException>().having(
              (e) => e.balanceCents,
              'balanceCents',
              0,
            ),
          ),
        );
        expect(await practice.find('test-e'), isNull);
        final used = await practice.finalizeVoucherSale(
          saleId: 'test-ok',
          cart: Cart.empty().add(cola).applyVoucher(applied(probe)),
          staff: rig.anna,
        );
        expect(used.payments.single.voucherBalanceAfterCents, 1685);
      },
    );

    test('dieselbe saleId zweimal: ein Bon, eine Bewegung', () async {
      final v = await sellVoucher(shop, 1000, saleId: 'g3');
      final again = await sellVoucher(shop, 1000, saleId: 'g3');
      expect(again.id, v.id);
      final pay = cartCard.applyVoucher(applied(v));
      final first = await shop.receipts.finalizeVoucherSale(
        saleId: 'e5',
        cart: pay,
        staff: shop.anna,
      );
      // Das Guthaben reicht jetzt nicht mehr, und keine der Prüfungen gilt
      // mehr: Jeder Weg gibt den gespeicherten Bon zurück.
      final second = await shop.receipts.finalizeVoucherSale(
        saleId: 'e5',
        cart: pay,
        staff: shop.anna,
      );
      final cash = await shop.receipts.finalizeCashSale(
        saleId: 'e5',
        cart: pay,
        givenCents: 0,
        staff: shop.anna,
      );
      final card = await shop.receipts.finalizeCardSale(
        saleId: 'e5',
        cart: pay,
        staff: shop.anna,
        provider: 'sumup',
      );
      final payout = await shop.receipts.finalizePayout(
        saleId: 'e5',
        cart: pay,
        staff: shop.anna,
      );
      expect(
        {
          for (final r in [first, second, cash, card, payout]) r.id,
        },
        {'e5'},
      );
      expect(
        (
          await shop.count('receipts'),
          await shop.count('payments'),
          await shop.count('vouchers'),
          await shop.count('voucher_movements'),
        ),
        (2, 2, 1, 2),
      );
      expect(await shop.vouchers.balanceOf(v.id), 35);
    });

    test('Gutschein bezahlt den ganzen Bon: bar und Karte gehen nicht, '
        'finalizeVoucherSale nur dann', () async {
      final v = await sellVoucher(shop, 2500);
      final all = cartCard.applyVoucher(applied(v));
      await expectLater(
        shop.receipts.finalizeCashSale(
          saleId: 'n1',
          cart: all,
          givenCents: 0,
          staff: shop.anna,
        ),
        throwsA(isA<NothingDueException>()),
      );
      await expectLater(
        shop.receipts.finalizeCardSale(
          saleId: 'n2',
          cart: all,
          staff: shop.anna,
          provider: 'sumup',
        ),
        throwsArgumentError,
      );
      await expectLater(
        shop.receipts.finalizeVoucherSale(
          saleId: 'n3',
          cart: cartCard,
          staff: shop.anna,
        ),
        throwsArgumentError,
      );
      final small = await sellVoucher(shop, 500);
      await expectLater(
        shop.receipts.finalizeVoucherSale(
          saleId: 'n4',
          cart: cartCard.applyVoucher(applied(small)),
          staff: shop.anna,
        ),
        throwsArgumentError,
      );
      await expectLater(
        shop.receipts.finalizeCashSale(
          saleId: 'n5',
          cart: cartCard.applyVoucher(applied(small)),
          givenCents: 464,
          staff: shop.anna,
        ),
        throwsA(isA<InsufficientCashException>()),
      );
      // Karte: der Bar-Teil muss unter dem Rest nach dem Gutschein liegen.
      await expectLater(
        shop.receipts.finalizeCardSale(
          saleId: 'n6',
          cart: cartCard.applyVoucher(applied(small)),
          staff: shop.anna,
          provider: 'sumup',
          cashPartCents: 465,
        ),
        throwsArgumentError,
      );
      final mixed = await shop.receipts.finalizeCardSale(
        saleId: 'n7',
        cart: cartCard.applyVoucher(applied(small)),
        staff: shop.anna,
        provider: 'sumup',
        cashPartCents: 100,
      );
      expect(
        [for (final p in mixed.payments) (p.position, p.kind, p.amountCents)],
        [
          (0, PaymentKind.voucher, 500),
          (1, PaymentKind.cash, 100),
          (2, PaymentKind.card, 365),
        ],
      );
      for (final id in ['n1', 'n2', 'n3', 'n4', 'n5', 'n6']) {
        expect(await shop.receipts.find(id), isNull, reason: id);
      }
      // Ein Bon mit Summe 0 ohne Gutschein geht wie bisher bar.
      final zero = await shop.receipts.finalizeCashSale(
        saleId: 'n8',
        cart: const Cart.empty().add(leitungswasser),
        givenCents: 0,
        staff: shop.anna,
      );
      expect(
        (
          zero.totalCents,
          zero.payments.single.kind,
          zero.payments.single.amountCents,
        ),
        (0, PaymentKind.cash, 0),
      );
      // Ein Bon unter 0 ist eine Auszahlung, kein Barverkauf.
      final back = const Cart.empty().setDepositReturn(
        depositCents: 25,
        quantity: 3,
      );
      await expectLater(
        shop.receipts.finalizeCashSale(
          saleId: 'n9',
          cart: back,
          givenCents: 0,
          staff: shop.anna,
        ),
        throwsArgumentError,
      );
    });

    test('zwei Gutscheine auf einem Bon: zwei Zahlungen, zwei Bewegungen, der '
        'Storno gibt beiden ihr Guthaben zurück', () async {
      final a = await sellVoucher(shop, 500);
      final b = await sellVoucher(shop, 300);
      final r = await shop.receipts.finalizeCashSale(
        saleId: 'z1',
        cart: cartCard.applyVoucher(applied(a)).applyVoucher(applied(b)),
        givenCents: 200,
        staff: shop.anna,
      );
      expect(
        [
          for (final p in r.payments)
            (
              p.position,
              p.kind,
              p.voucherId,
              p.amountCents,
              p.voucherBalanceAfterCents,
            ),
        ],
        [
          (0, PaymentKind.voucher, a.id, 500, 0),
          (1, PaymentKind.voucher, b.id, 300, 0),
          (2, PaymentKind.cash, null, 165, null),
        ],
      );
      final v = await shop.receipts.voidReceipt('z1', staff: shop.chef);
      expect(
        [
          for (final p in v.payments)
            (
              p.kind,
              p.voucherId,
              p.voucherCode,
              p.amountCents,
              p.givenCents,
              p.voucherBalanceAfterCents,
            ),
        ],
        [
          (PaymentKind.voucher, a.id, a.code, -500, 0, 500),
          (PaymentKind.voucher, b.id, b.code, -300, 0, 300),
          (PaymentKind.cash, null, null, -165, 0, null),
        ],
      );
      final movements = await (shop.db.select(
        shop.db.voucherMovementRows,
      )..where((t) => t.receiptId.equals(v.id))).get();
      expect(
        {for (final m in movements) (m.voucherId, m.kind, m.amountCents)},
        {(a.id, 'void_redeem', 500), (b.id, 'void_redeem', 300)},
      );
      expect(
        (
          await shop.vouchers.balanceOf(a.id),
          await shop.vouchers.balanceOf(b.id),
        ),
        (500, 300),
      );
    });

    test(
      'Storno eines Gutschein-Verkaufs scheitert: nichts bleibt stehen',
      () async {
        final v = await sellVoucher(shop, 2500, saleId: 'g4');
        await shop.receipts.finalizeVoucherSale(
          saleId: 'e6',
          cart: cartCard.applyVoucher(applied(v)),
          staff: shop.anna,
        );
        final rows = (
          await shop.count('receipts'),
          await shop.count('payments'),
          await shop.count('voucher_movements'),
        );
        await expectLater(
          shop.receipts.voidReceipt('g4', staff: shop.chef),
          throwsA(isA<VoucherSaleRedeemedException>()),
        );
        expect((
          await shop.count('receipts'),
          await shop.count('payments'),
          await shop.count('voucher_movements'),
        ), rows);
        expect((await shop.receipts.byId('g4')).isVoided, isFalse);
      },
    );

    test('zwei Gutschein-Zeilen: zwei Gutscheine mit eigenem Code; '
        'soldOn und der Storno-Bon zeigen beide', () async {
      final r = await shop.receipts.finalizeCashSale(
        saleId: 'g5',
        cart: const Cart.empty()
            .addVoucherSale(valueCents: 1000)
            .add(cola)
            .addVoucherSale(valueCents: 2000),
        givenCents: 3315,
        staff: shop.anna,
      );
      expect(
        [for (final s in r.soldVouchers) (s.linePosition, s.valueCents)],
        [(0, 1000), (2, 2000)],
      );
      expect(r.soldVouchers[0].code, isNot(r.soldVouchers[1].code));
      expect(
        [
          for (final v in await shop.vouchers.soldOn('g5'))
            (v.soldReceiptId, v.valueCents, v.isTest),
        ],
        [('g5', 1000, true), ('g5', 2000, true)],
      );
      final v = await shop.receipts.voidReceipt('g5', staff: shop.chef);
      expect(
        [
          for (final s in v.soldVouchers)
            (s.voucherId, s.code, s.valueCents, s.linePosition),
        ],
        [
          for (final s in r.soldVouchers)
            (s.voucherId, s.code, -s.valueCents, s.linePosition),
        ],
      );
      expect(v.lines[2].info, r.lines[2].info);
      expect(v.publicToken, allOf(hasLength(22), isNot(r.publicToken)));
      expect(await shop.vouchers.soldOn(v.id), isEmpty);
      for (final s in r.soldVouchers) {
        final voucher = (await shop.vouchers.byId(s.voucherId))!;
        expect(
          (
            voucher.state,
            voucher.movements.last.kind,
            voucher.movements.last.receiptId,
          ),
          (VoucherState.voided, VoucherMovementKind.voidSale, v.id),
        );
      }
    });

    test('der Code eines neuen Gutscheins ist noch frei: bei gleichem Code wird neu gezogen', () async {
      final random = _ScriptedDigits([
        1,
        2,
        3,
        4,
        5,
        6,
        7,
        8,
        1,
        2,
        3,
        4,
        5,
        6,
        7,
        8,
        8,
        7,
        6,
        5,
        4,
        3,
        2,
        1,
      ]);
      final repo = ReceiptRepository(
        shop.db,
        shop.clock,
        shop.days,
        random: random,
      );
      final one = Cart.empty().addVoucherSale(valueCents: 1000);
      final a = await repo.finalizeCashSale(
        saleId: 'c1',
        cart: one,
        givenCents: 1000,
        staff: shop.anna,
      );
      final b = await repo.finalizeCashSale(
        saleId: 'c2',
        cart: one,
        givenCents: 1000,
        staff: shop.anna,
      );
      expect(
        (a.soldVouchers.single.code, b.soldVouchers.single.code),
        ('12345678', '87654321'),
      );
      expect(random.digits, isEmpty);
    });

    test('publicToken: Verkauf und Storno je ein eigener, Sonderbeleg '
        'keiner', () async {
      final rig = await RksvRig.open();
      addTearDown(rig.close);
      final start = await rig.service.enableProbe(staff: rig.chef);
      expect(start.publicToken, isNull);
      final r = await rig.sell('t1', cart);
      expect(r.publicToken, matches(RegExp(r'^[A-Za-z0-9_-]{22}$')));
      final v = await rig.receipts.voidReceipt('t1', staff: rig.chef);
      expect(v.publicToken, matches(RegExp(r'^[A-Za-z0-9_-]{22}$')));
      expect(v.publicToken, isNot(r.publicToken));
    });
  });

  group('Gutschein einlösen (Task 11)', () {
    test('finalizeCardSale bei dueCents 0 mit Gutschein: '
        'NothingDueException, nichts gespeichert, die offene Zahlung bleibt',
        () async {
      final v = await sellVoucher(shop, 2500);
      final all = cartCard.applyVoucher(applied(v));
      expect(all.pricing.dueCents, 0);
      final pending = CardPaymentRepository(shop.db, shop.clock);
      await pending.begin(paymentId: 'k0', cart: all, staff: shop.anna);
      final receipts = await shop.count('receipts');
      await expectLater(
        shop.receipts.finalizeCardSale(
          saleId: 'k0',
          cart: all,
          staff: shop.anna,
          provider: 'sumup',
          allowOverdraw: true,
        ),
        throwsA(isA<NothingDueException>()),
      );
      expect(await shop.count('receipts'), receipts);
      expect(await shop.receipts.find('k0'), isNull);
      expect(await pending.pending(), hasLength(1));
      expect((await shop.vouchers.byId(v.id))!.balanceCents, 2500);
    });

    test('checkVoucherBalances prüft wie das Abschließen und schreibt nichts',
        () async {
      final v = await sellVoucher(shop, 500);
      final paying = cartCard.applyVoucher(applied(v));
      final moves = await shop.count('voucher_movements');
      await shop.receipts.checkVoucherBalances(paying);
      await shop.receipts.checkVoucherBalances(cartCard);
      await shop.receipts.finalizeVoucherSale(
        saleId: 'c1',
        cart: Cart.empty().add(cola).applyVoucher(applied(v)),
        staff: shop.anna,
      );
      await expectLater(
        shop.receipts.checkVoucherBalances(paying),
        throwsA(
          isA<VoucherBalanceException>()
              .having((e) => e.voucherId, 'voucherId', v.id)
              .having((e) => e.balanceCents, 'balanceCents', 185),
        ),
      );
      expect(await shop.count('voucher_movements'), moves + 1);
      expect(await shop.receipts.isTestReceiptNow(), isTrue);
    });
  });
}

/// Zieht die Ziffern der Reihe nach aus [digits] (für `nextInt(10)`), alles
/// andere ist 0.
class _ScriptedDigits implements Random {
  _ScriptedDigits(List<int> digits) : digits = [...digits];

  final List<int> digits;

  @override
  int nextInt(int max) => max == 10 ? digits.removeAt(0) : 0;

  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;
}
