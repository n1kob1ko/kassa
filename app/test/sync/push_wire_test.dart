import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/data/database.dart';
import 'package:kassa/data/outbox_repository.dart';
import 'package:kassa/sync/push_wire.dart';

Map<String, dynamic> pushRequest() => jsonDecode(
  File('../shared/fixtures/sync/push_request.json').readAsStringSync(),
) as Map<String, dynamic>;

/// Schreibt die Daten eines Bons aus der Beispieldatei in die Tabellen.
Future<void> insertReceiptOf(
  KassaDatabase db,
  Map<String, dynamic> r, {
  bool withProtocol = true,
}) async {
  DateTime time(String s) => DateTime.parse(s);
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
        ),
      );
  for (final l in (r['lines'] as List).cast<Map<String, dynamic>>()) {
    final gross = l['gross'] as Map<String, dynamic>;
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
  final p = r['payment'] as Map<String, dynamic>?;
  if (p != null) {
    await db
        .into(db.paymentRows)
        .insert(
          PaymentRowsCompanion.insert(
            receiptId: r['id'] as String,
            kind: p['kind'] as String,
            amountCents: p['amountCents'] as int,
            givenCents: p['givenCents'] as int,
            changeCents: p['changeCents'] as int,
            provider: Value(p['provider'] as String?),
            providerTxCode: Value(p['providerTxCode'] as String?),
            cardScheme: Value(p['cardScheme'] as String?),
            cardLast4: Value(p['cardLast4'] as String?),
          ),
        );
  }
  final e = r['rksv'] as Map<String, dynamic>?;
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
      expect(jsonDecode(jsonEncode(built)), expected, reason: kind);
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

  test('Sonderbeleg hat payment null und businessDayId null', () async {
    final base = entries[4]['receipt'] as Map<String, dynamic>;
    await insertReceiptOf(db, {
      ...base,
      'id': '5a000000-0000-4000-8000-000000000001',
      'number': 2,
      'kind': 'zero',
      'businessDayId': null,
      'goodsCents': 0,
      'totalCents': 0,
      'lines': <Object?>[],
      'payment': null,
      'rksv': null,
    });
    final built = await payloads.build(
      entry(9, 'receipt', '5a000000-0000-4000-8000-000000000001'),
    );
    final r = built!['receipt'] as Map<String, dynamic>;
    expect(r['kind'], 'zero');
    expect(r['payment'], isNull);
    expect(r['businessDayId'], isNull);
    expect(r['lines'], isEmpty);
    expect(r.containsKey('payment'), isTrue);
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

  test(
    'Bericht ist noch nicht gebaut, wird aber nie still verschluckt',
    () async {
      await expectLater(
        payloads.build(entry(1, 'report', 'x')),
        throwsA(isA<UnimplementedError>()),
      );
    },
  );
}

String refOfDay() => '7c1e0d34-2a5b-4c86-8d19-0f3e6b9a7d21';
