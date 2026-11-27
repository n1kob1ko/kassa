import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/data/database.dart';
import 'package:kassa/data/outbox_repository.dart';
import 'package:kassa/sync/push_wire.dart';

import '../support/sales.dart' show TestShop, cart, discounted;
import '../support/sales.dart' show applied, sellVoucher;

/// Das Paket eines Tablets mit Bon `v: 2` (die App baut seit 1.11.0 nur
/// noch diese Form; `push_request.json` ist das Paket von 1.10.0).
Map<String, dynamic> pushRequest() => jsonDecode(
  File('../shared/fixtures/sync/push_request_v2.json').readAsStringSync(),
) as Map<String, dynamic>;

/// Der Bon-Eintrag aus `push_request_v2.json`, gehoben auf die Form `v: 3`,
/// in der die App seit 1.12.0 sendet: dieselben Werte, dazu die neuen Felder
/// leer (kein Schlüssel der Seite, keine Gutscheine, an jeder Zahlung kein
/// Gutschein).
Map<String, dynamic> asV3Entry(Map<String, dynamic> entry) {
  final r = entry['receipt'] as Map<String, dynamic>;
  return {
    ...entry,
    'receipt': {
      ...r,
      'v': 3,
      'publicToken': null,
      'vouchers': <Object?>[],
      'payments': [
        for (final p in (r['payments'] as List).cast<Map<String, dynamic>>())
          {
            ...p,
            'voucherId': null,
            'voucherCode': null,
            'voucherBalanceAfterCents': null,
          },
      ],
    },
  };
}

/// Schreibt die Daten eines Bons aus der Beispieldatei in die Tabellen.
Future<void> insertReceiptOf(
  KassaDatabase db,
  Map<String, dynamic> r, {
  bool withProtocol = true,
}) async {
  DateTime time(String s) => DateTime.parse(s);
  final discount = r['discount'] as Map<String, dynamic>?;
  await db
      .into(db.receiptRows)
      .insert(
        ReceiptRowsCompanion.insert(
          id: r['id'] as String,
          number: r['number'] as int,
          createdAt: time(r['createdAt'] as String),
          staffId: r['staffId'] as String,
          staffName: r['staffName'] as String,
          businessDayId: Value(r['businessDayId'] as String?),
          kind: r['kind'] as String,
          voidsReceiptId: Value(r['voidsReceiptId'] as String?),
          goodsCents: r['goodsCents'] as int,
          depositCents: r['depositCents'] as int,
          totalCents: r['totalCents'] as int,
          tipCents: Value(r['tipCents'] as int),
          discountCents: Value(r['discountCents'] as int),
          discountPercent: Value(discount?['percent'] as int?),
          discountAmountCents: Value(discount?['amountCents'] as int? ?? 0),
          discountReason: Value(discount?['reason'] as String?),
          publicToken: Value(r['publicToken'] as String?),
        ),
      );
  for (final l in (r['lines'] as List).cast<Map<String, dynamic>>()) {
    final gross = l['gross'] as Map<String, dynamic>;
    final own = l['discount'] as Map<String, dynamic>?;
    await db
        .into(db.receiptLineRows)
        .insert(
          ReceiptLineRowsCompanion.insert(
            receiptId: r['id'] as String,
            position: l['position'] as int,
            itemId: l['itemId'] as String,
            name: l['name'] as String,
            info: Value(l['info'] as String?),
            unitPriceCents: l['unitPriceCents'] as int,
            quantity: l['quantity'] as int,
            unitDepositCents: l['unitDepositCents'] as int,
            gross20Cents: Value(gross['20'] as int),
            gross10Cents: Value(gross['10'] as int),
            gross13Cents: Value(gross['13'] as int),
            gross0Cents: Value(gross['0'] as int),
            gross19Cents: Value(gross['19'] as int),
            discountCents: Value(l['discountCents'] as int),
            ownDiscountPercent: Value(own?['percent'] as int?),
            ownDiscountCents: Value(own?['amountCents'] as int? ?? 0),
            ownDiscountReason: Value(own?['reason'] as String?),
          ),
        );
    final options = (l['options'] as List).cast<Map<String, dynamic>>();
    for (var i = 0; i < options.length; i++) {
      await db
          .into(db.receiptLineOptionRows)
          .insert(
            ReceiptLineOptionRowsCompanion.insert(
              receiptId: r['id'] as String,
              linePosition: l['position'] as int,
              position: i,
              groupName: options[i]['groupName'] as String,
              optionName: options[i]['optionName'] as String,
              surchargeCents: options[i]['surchargeCents'] as int,
            ),
          );
    }
  }
  // Rückwärts eingetragen: die Reihenfolge im Abgleich kommt aus `position`.
  final payments = (r['payments'] as List).cast<Map<String, dynamic>>();
  for (final p in payments.reversed) {
    await db
        .into(db.paymentRows)
        .insert(
          PaymentRowsCompanion.insert(
            receiptId: r['id'] as String,
            position: Value(p['position'] as int),
            kind: p['kind'] as String,
            amountCents: p['amountCents'] as int,
            givenCents: p['givenCents'] as int,
            changeCents: p['changeCents'] as int,
            tipCents: Value(p['tipCents'] as int),
            tipStaffId: Value(p['tipStaffId'] as String?),
            tipStaffName: Value(p['tipStaffName'] as String?),
            provider: Value(p['provider'] as String?),
            providerTxCode: Value(p['providerTxCode'] as String?),
            cardScheme: Value(p['cardScheme'] as String?),
            cardLast4: Value(p['cardLast4'] as String?),
            voucherId: Value(p['voucherId'] as String?),
            voucherCode: Value(p['voucherCode'] as String?),
            voucherBalanceAfterCents: Value(
              p['voucherBalanceAfterCents'] as int?,
            ),
          ),
        );
  }
  final e = r['rksv'] as Map<String, dynamic>?;
  // Verkaufte Gutscheine stehen beim Verkauf; ein Storno zeigt sie aus dem
  // Verkauf mit negativem Wert.
  if (r['kind'] == 'sale') {
    for (final v in (r['vouchers'] as List? ?? const []).cast<Map>()) {
      await db
          .into(db.voucherRows)
          .insert(
            VoucherRowsCompanion.insert(
              id: v['id'] as String,
              code: v['code'] as String,
              valueCents: v['valueCents'] as int,
              createdAt: time(r['createdAt'] as String),
              soldReceiptId: Value(r['id'] as String),
              soldLinePosition: Value(v['linePosition'] as int),
              isTest: r['test'] as bool,
            ),
          );
    }
  }
  if (e != null && withProtocol) {
    await db
        .into(db.rksvEntryRows)
        .insert(
          RksvEntryRowsCompanion.insert(
            chain: e['chain'] as int,
            position: e['position'] as int,
            receiptId: r['id'] as String,
            jws: e['jws'] as String,
            damaged: e['damaged'] as bool,
            certSerial: e['certSerial'] as String,
          ),
        );
  }
}

void main() {
  late KassaDatabase db;
  late PushPayloads payloads;
  late List<Map<String, dynamic>> entries;

  OutboxEntry entry(int seq, String kind, String ref) =>
      OutboxEntry(id: seq, kind: kind, ref: ref, rev: 0);

  setUp(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = KassaDatabase(NativeDatabase.memory());
    payloads = PushPayloads(db);
    entries = (pushRequest()['entries'] as List).cast<Map<String, dynamic>>();
    final cert = entries[0]['certificate'] as Map<String, dynamic>;
    await db
        .into(db.rksvCertificateRows)
        .insert(
          RksvCertificateRowsCompanion.insert(
            serialHex: cert['serialHex'] as String,
            certificate: Uint8List.fromList(
              base64Decode(cert['certificate'] as String),
            ),
            issuers: Value(jsonEncode(cert['issuers'])),
          ),
        );
    final chain = entries[1]['chain'] as Map<String, dynamic>;
    await db
        .into(db.rksvChainRows)
        .insert(
          RksvChainRowsCompanion.insert(
            chain: Value(chain['chain'] as int),
            mode: chain['mode'] as String,
            cashBoxId: chain['cashBoxId'] as String,
            zdaId: chain['zdaId'] as String,
            certSerial: chain['certSerial'] as String,
            startedAt: DateTime.parse(chain['startedAt'] as String),
          ),
        );
    final day = entries[2]['day'] as Map<String, dynamic>;
    await db
        .into(db.businessDayRows)
        .insert(
          BusinessDayRowsCompanion.insert(
            id: day['id'] as String,
            openedAt: DateTime.parse(day['openedAt'] as String),
            openingFloatCents: Value(day['openingFloatCents'] as int),
          ),
        );
    final m = entries[3]['movement'] as Map<String, dynamic>;
    await db
        .into(db.cashMovementRows)
        .insert(
          CashMovementRowsCompanion.insert(
            id: m['id'] as String,
            businessDayId: m['businessDayId'] as String,
            kind: m['kind'] as String,
            amountCents: m['amountCents'] as int,
            reason: m['reason'] as String,
            createdAt: DateTime.parse(m['createdAt'] as String),
            staffId: m['staffId'] as String,
            staffName: m['staffName'] as String,
          ),
        );
    await insertReceiptOf(db, entries[4]['receipt'] as Map<String, dynamic>);
  });
  tearDown(() => db.close());

  test('App baut dieselbe Anfrage wie die Beispieldatei', () async {
    final refs = {
      'rksv_certificate': '1a2b',
      'rksv_chain': '1',
      'day': '7c1e0d34-2a5b-4c86-8d19-0f3e6b9a7d21',
      'cash_movement': 'a4d92f10-6b3e-4a58-b7c1-92e4d0f5a863',
      'receipt': 'e5b7c3a9-1f48-4d62-a0b6-3c8d9e2f1470',
    };
    var checked = 0;
    for (final expected in entries) {
      final kind = expected['kind'] as String;
      if (!refs.containsKey(kind)) continue;
      final built = await payloads.build(
        entry(expected['seq'] as int, kind, refs[kind]!),
      );
      // Über JSON, wie es hinausgeht: so zählen auch die Arten der Zahlen.
      expect(
        jsonDecode(jsonEncode(built)),
        kind == 'receipt' ? asV3Entry(expected) : expected,
        reason: kind,
      );
      checked++;
    }
    expect(checked, 5);
  });

  test('App baut den Artikel-Eintrag der Beispieldatei', () async {
    final expected = entries.singleWhere((e) => e['kind'] == 'item_change');
    final c = expected['change'] as Map<String, dynamic>;
    final built = await payloads.build(
      OutboxEntry(
        id: expected['seq'] as int,
        kind: 'item_change',
        ref: c['itemId'] as String,
        field: c['field'] as String,
        value: jsonEncode(c['value']),
        changedAt: DateTime.parse(c['changedAt'] as String),
        rev: 0,
      ),
    );
    expect(jsonDecode(jsonEncode(built)), expected);
  });

  test(
    'Artikel-Eintrag: Wahrheitswert und Liste gehen als JSON-Werte hinaus',
    () async {
      Future<Object?> valueOf(String field, String value) async {
        final built = await payloads.build(
          OutboxEntry(
            id: 1,
            kind: 'item_change',
            ref: 'cola',
            field: field,
            value: value,
            changedAt: DateTime.utc(2026, 11, 19, 8, 10, 0, 5),
            rev: 0,
          ),
        );
        final change = jsonDecode(jsonEncode(built))['change'] as Map;
        expect(change['changedAt'], '2026-11-19T08:10:00.005Z');
        return change['value'];
      }

      expect(await valueOf('favorite', 'true'), true);
      expect(await valueOf('tags', '["spicy","vegan"]'), ['spicy', 'vegan']);
      expect(await valueOf('depositCents', '25'), 25);
    },
  );

  test('Zeiten gehen als ISO 8601 in UTC mit Millisekunden', () async {
    final built = await payloads.build(entry(3, 'day', refOfDay()));
    expect(
      (built!['day'] as Map)['openedAt'],
      matches(RegExp(r'^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{3}Z$')),
    );
  });

  test('Sonderbeleg hat payments leer und businessDayId null', () async {
    final base = entries[4]['receipt'] as Map<String, dynamic>;
    await insertReceiptOf(db, {
      ...base,
      'id': '5a000000-0000-4000-8000-000000000001',
      'number': 2,
      'kind': 'zero',
      'businessDayId': null,
      'goodsCents': 0,
      'totalCents': 0,
      'tipCents': 0,
      'discountCents': 0,
      'discount': null,
      'lines': <Object?>[],
      'payments': <Object?>[],
      'rksv': null,
    });
    final built = await payloads.build(
      entry(9, 'receipt', '5a000000-0000-4000-8000-000000000001'),
    );
    final r = built!['receipt'] as Map<String, dynamic>;
    expect(r['kind'], 'zero');
    expect(r['payments'], isEmpty);
    expect(r['businessDayId'], isNull);
    expect(r['lines'], isEmpty);
    expect(r['discount'], isNull);
    expect(r.containsKey('payments'), isTrue);
    expect(r.containsKey('payment'), isFalse);
    expect(r.containsKey('discount'), isTrue);
    expect(r.containsKey('businessDayId'), isTrue);
  });

  test('Bon ohne Protokoll hat rksv null', () async {
    final base = entries[4]['receipt'] as Map<String, dynamic>;
    await insertReceiptOf(db, {
      ...base,
      'id': '5a000000-0000-4000-8000-000000000002',
      'number': 3,
    }, withProtocol: false);
    final built = await payloads.build(
      entry(9, 'receipt', '5a000000-0000-4000-8000-000000000002'),
    );
    final r = built!['receipt'] as Map<String, dynamic>;
    expect(r.containsKey('rksv'), isTrue);
    expect(r['rksv'], isNull);
  });

  test(
    'Bon in einer echten Kette hat test false, in einer Probe true',
    () async {
      final cert = entries[0]['certificate'] as Map<String, dynamic>;
      await db
          .into(db.rksvChainRows)
          .insert(
            RksvChainRowsCompanion.insert(
              chain: const Value(2),
              mode: 'live',
              cashBoxId: 'ECHT1',
              zdaId: 'AT100',
              certSerial: cert['serialHex'] as String,
              startedAt: DateTime.parse('2026-11-20T08:00:00.000Z'),
            ),
          );
      final base = entries[4]['receipt'] as Map<String, dynamic>;
      await insertReceiptOf(db, {
        ...base,
        'id': '5a000000-0000-4000-8000-000000000003',
        'number': 4,
        'rksv': {
          'chain': 2,
          'position': 1,
          'jws': 'a.b.c',
          'damaged': false,
          'certSerial': cert['serialHex'],
        },
      });
      final live = await payloads.build(
        entry(9, 'receipt', '5a000000-0000-4000-8000-000000000003'),
      );
      final probe = await payloads.build(
        entry(5, 'receipt', 'e5b7c3a9-1f48-4d62-a0b6-3c8d9e2f1470'),
      );
      expect((live!['receipt'] as Map)['test'], isFalse);
      expect((probe!['receipt'] as Map)['test'], isTrue);
    },
  );

  test('fehlende Sachen ergeben null', () async {
    expect(await payloads.build(entry(1, 'receipt', 'gibt-es-nicht')), isNull);
    expect(await payloads.build(entry(1, 'day', 'gibt-es-nicht')), isNull);
    expect(
      await payloads.build(entry(1, 'cash_movement', 'gibt-es-nicht')),
      isNull,
    );
    expect(await payloads.build(entry(1, 'rksv_certificate', 'ffff')), isNull);
    expect(await payloads.build(entry(1, 'rksv_chain', '99')), isNull);
  });

  test(
    'Tag ohne Wechselgeld geht mit 0 hinaus, der Server verlangt eine Zahl',
    () async {
      await db
          .into(db.businessDayRows)
          .insert(
            BusinessDayRowsCompanion.insert(
              id: '5a000000-0000-4000-8000-000000000009',
              openedAt: DateTime.parse('2026-11-20T08:00:00.000Z'),
              closedAt: Value(DateTime.parse('2026-11-20T18:00:00.000Z')),
            ),
          );
      final built = await payloads.build(
        entry(1, 'day', '5a000000-0000-4000-8000-000000000009'),
      );
      expect((built!['day'] as Map)['openingFloatCents'], 0);
    },
  );

  test('App baut den Bericht der Beispieldatei (seq 7)', () async {
    final expected = entries.singleWhere((e) => e['kind'] == 'report');
    final r = expected['report'] as Map<String, dynamic>;
    final e = r['error'] as Map<String, dynamic>;
    await db
        .into(db.reportRows)
        .insert(
          ReportRowsCompanion.insert(
            id: r['id'] as String,
            kind: r['kind'] as String,
            at: DateTime.parse(r['at'] as String),
            appVersion: r['appVersion'] as String,
            androidVersion: Value(r['androidVersion'] as String),
            deviceModel: Value(r['deviceModel'] as String),
            count: Value(r['count'] as int),
            signature: 'sig',
            content: jsonEncode(e),
          ),
        );
    final built = await payloads.build(
      OutboxEntry(
        id: expected['seq'] as int,
        kind: 'report',
        ref: r['id'] as String,
        rev: 0,
      ),
    );
    expect(jsonDecode(jsonEncode(built)), expected);
  });

  test('Bon aus cart mit Bar-Teil 1000 und Trinkgeld 80 geht als v: 3 mit '
      'zwei Zahlungen hinaus', () async {
    final shop = await TestShop.open();
    addTearDown(shop.close);
    await shop.receipts.finalizeCardSale(
      saleId: 'gemischt',
      cart: cart,
      staff: shop.anna,
      provider: 'sumup',
      txCode: 'TX-1',
      cardScheme: 'VISA',
      cardLast4: '4242',
      cashPartCents: 1000,
      tipCents: 80,
    );
    final built = await PushPayloads(shop.db)
        .build(entry(1, 'receipt', 'gemischt'));
    final r = jsonDecode(jsonEncode(built))['receipt'] as Map<String, dynamic>;
    expect(r['v'], 3);
    expect(r.containsKey('payment'), isFalse);
    expect(r['totalCents'], 1820);
    expect(r['tipCents'], 80);
    expect(r['discountCents'], 0);
    expect(r['discount'], isNull);
    expect(r['payments'], [
      {
        'position': 0,
        'kind': 'cash',
        'amountCents': 1000,
        'givenCents': 1000,
        'changeCents': 0,
        'tipCents': 0,
        'tipStaffId': null,
        'tipStaffName': null,
        'provider': null,
        'providerTxCode': null,
        'cardScheme': null,
        'cardLast4': null,
        'voucherId': null,
        'voucherCode': null,
        'voucherBalanceAfterCents': null,
      },
      {
        'position': 1,
        'kind': 'card',
        'amountCents': 820,
        'givenCents': 0,
        'changeCents': 0,
        'tipCents': 80,
        'tipStaffId': shop.anna.id,
        'tipStaffName': 'Anna',
        'provider': 'sumup',
        'providerTxCode': 'TX-1',
        'cardScheme': 'VISA',
        'cardLast4': '4242',
        'voucherId': null,
        'voucherCode': null,
        'voucherBalanceAfterCents': null,
      },
    ]);
    for (final l in (r['lines'] as List).cast<Map<String, dynamic>>()) {
      expect(l['discountCents'], 0);
      expect(l['discount'], isNull);
    }
  });

  test('Bon mit Rabatt geht mit discountCents, discount und den Feldern der '
      'Zeilen hinaus', () async {
    final shop = await TestShop.open();
    addTearDown(shop.close);
    await shop.receipts.finalizeCashSale(
      saleId: 'r1',
      cart: discounted,
      givenCents: 2000,
      staff: shop.anna,
    );
    final built = await PushPayloads(shop.db).build(entry(1, 'receipt', 'r1'));
    final r = jsonDecode(jsonEncode(built))['receipt'] as Map<String, dynamic>;
    expect((r['goodsCents'], r['totalCents']), (1486, 1536));
    expect(r['discountCents'], 284);
    expect(r['discount'], {
      'percent': 10,
      'amountCents': 165,
      'reason': 'promotion',
    });
    final lines = (r['lines'] as List).cast<Map<String, dynamic>>();
    expect([for (final l in lines) l['discountCents']], [58, 226]);
    expect(
      [for (final l in lines) l['discount']],
      [
        null,
        {'percent': 10, 'amountCents': 119, 'reason': 'regular'},
      ],
    );
    expect(
      [for (final l in lines) (l['gross']['20'], l['gross']['10'])],
      [(522, 0), (0, 964)],
    );
  });

  test(
    'Bon v: 3: Gutschein-Verkauf geht mit vouchers hinaus, '
    'Gutschein-Zahlung mit Code und Restguthaben, publicToken ist dabei',
    () async {
      final shop = await TestShop.open();
      addTearDown(shop.close);
      final voucher = await sellVoucher(shop, 1000, saleId: 'gv');
      await shop.receipts.finalizeCashSale(
        saleId: 'einloesen',
        cart: cart.applyVoucher(applied(voucher)),
        givenCents: 1000,
        staff: shop.anna,
      );
      await sellVoucher(shop, 2000, saleId: 'gv2');
      final voided = await shop.receipts.voidReceipt('gv2', staff: shop.anna);
      final second = (await shop.receipts.byId('gv2')).soldVouchers.single;

      Future<Map<String, dynamic>> wire(String id) async =>
          jsonDecode(
                jsonEncode(
                  await PushPayloads(shop.db).build(entry(1, 'receipt', id)),
                ),
              )['receipt']
              as Map<String, dynamic>;
      final sale = await wire('gv');
      final redeem = await wire('einloesen');
      final voidSale = await wire(voided.id);

      for (final (id, r) in [
        ('gv', sale),
        ('einloesen', redeem),
        (voided.id, voidSale),
      ]) {
        expect(r['v'], 3, reason: id);
        expect(
          r['publicToken'],
          matches(RegExp(r'^[A-Za-z0-9_-]{22}$')),
          reason: id,
        );
        expect(
          r['publicToken'],
          (await shop.receipts.byId(id)).publicToken,
          reason: id,
        );
      }
      expect({
        sale['publicToken'],
        redeem['publicToken'],
        voidSale['publicToken'],
      }, hasLength(3));

      expect(sale['vouchers'], [
        {
          'id': voucher.id,
          'code': voucher.code,
          'valueCents': 1000,
          'linePosition': 0,
        },
      ]);
      expect((sale['lines'] as List).single['itemId'], 'voucher-sale');
      expect(
        (sale['payments'] as List).single,
        containsPair('voucherId', null),
      );
      expect(
        (sale['payments'] as List).single,
        containsPair('voucherCode', null),
      );
      expect(
        (sale['payments'] as List).single,
        containsPair('voucherBalanceAfterCents', null),
      );

      expect(redeem['vouchers'], isEmpty);
      expect(redeem['totalCents'], 1820);
      expect(redeem['payments'], [
        {
          'position': 0,
          'kind': 'voucher',
          'amountCents': 1000,
          'givenCents': 1000,
          'changeCents': 0,
          'tipCents': 0,
          'tipStaffId': null,
          'tipStaffName': null,
          'provider': null,
          'providerTxCode': null,
          'cardScheme': null,
          'cardLast4': null,
          'voucherId': voucher.id,
          'voucherCode': voucher.code,
          'voucherBalanceAfterCents': 0,
        },
        {
          'position': 1,
          'kind': 'cash',
          'amountCents': 820,
          'givenCents': 1000,
          'changeCents': 180,
          'tipCents': 0,
          'tipStaffId': null,
          'tipStaffName': null,
          'provider': null,
          'providerTxCode': null,
          'cardScheme': null,
          'cardLast4': null,
          'voucherId': null,
          'voucherCode': null,
          'voucherBalanceAfterCents': null,
        },
      ]);

      // Das Storno eines Gutschein-Verkaufs zeigt den Gutschein mit negativem Wert.
      expect(voidSale['voidsReceiptId'], 'gv2');
      expect(voidSale['vouchers'], [
        {
          'id': second.voucherId,
          'code': second.code,
          'valueCents': -2000,
          'linePosition': 0,
        },
      ]);
    },
  );

  test('push_request_v3.json: was das Tablet für die Beispiel-Bons baut, ist '
      'genau die Datei', () async {
    final v3 = jsonDecode(
      File('../shared/fixtures/sync/push_request_v3.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final expected = (v3['entries'] as List).cast<Map<String, dynamic>>();
    for (final e in expected) {
      await insertReceiptOf(db, e['receipt'] as Map<String, dynamic>);
    }
    for (final e in expected) {
      final r = e['receipt'] as Map<String, dynamic>;
      final built = await payloads.build(
        entry(e['seq'] as int, 'receipt', r['id'] as String),
      );
      // Über JSON, wie es hinausgeht: so zählen auch die Arten der Zahlen.
      expect(jsonDecode(jsonEncode(built)), e, reason: r['id'] as String);
    }
    expect(expected, hasLength(5));
  });

  test('Bericht, den es nicht mehr gibt, ergibt null', () async {
    expect(await payloads.build(entry(1, 'report', 'gibt-es-nicht')), isNull);
  });
}

String refOfDay() => '7c1e0d34-2a5b-4c86-8d19-0f3e6b9a7d21';
