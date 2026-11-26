// Die gemeinsamen Beispiele für Umsätze und Protokoll-Datei. Die App rechnet
// sie aus einer echten Datenbank, der Server prüft dieselben Dateien gegen
// seine eigene Rechnung. Mit KASSA_WRITE_FIXTURES=1 schreibt dieser Test die
// Dateien neu, sonst vergleicht er.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/data/database.dart';
import 'package:kassa/data/outbox_repository.dart';
import 'package:kassa/domain/cart.dart';
import 'package:kassa/domain/catalog.dart';
import 'package:kassa/domain/period_report.dart';
import 'package:kassa/domain/receipt.dart';
import 'package:kassa/domain/staff.dart';
import 'package:kassa/domain/stats.dart';
import 'package:kassa/rksv/dep_export.dart';
import 'package:kassa/sync/push_wire.dart';

import '../support/demo_fixtures.dart';
import '../support/sales.dart';

const _anna = Staff(id: 'anna', name: 'Anna', role: StaffRole.staff);
const _chefin = Staff(id: 'chefin', name: 'Chefin', role: StaffRole.chef);

final _write = Platform.environment['KASSA_WRITE_FIXTURES'] == '1';

/// Eine feste Kennung in der Form einer UUID.
String _id(String group, int n) =>
    '$group-0000-4000-8000-${n.toString().padLeft(12, '0')}';

String _iso(DateTime t) => t.toUtc().toIso8601String();

Object? _roundTrip(Object? v) => jsonDecode(jsonEncode(v));

/// Schreibt [content] in die Beispieldatei, oder vergleicht damit.
void _checkFile(String path, Map<String, Object?> content) {
  final file = File('../shared/fixtures/$path');
  final text = '${const JsonEncoder.withIndent('  ').convert(content)}\n';
  if (_write) {
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(text);
    return;
  }
  expect(
    file.existsSync(),
    isTrue,
    reason:
        '${file.path} fehlt. Mit KASSA_WRITE_FIXTURES=1 schreibt der Test sie.',
  );
  expect(
    jsonDecode(file.readAsStringSync()),
    _roundTrip(content),
    reason:
        '${file.path} stimmt nicht mit der Rechnung der App überein. Gewollt? '
        'Dann mit KASSA_WRITE_FIXTURES=1 neu schreiben.',
  );
}

Map<String, Object?> _overviewJson(Overview o) => {
  'revenueCents': o.revenueCents,
  'previousRevenueCents': o.previousRevenueCents,
  'receiptCount': o.receiptCount,
  'voidCount': o.voidCount,
  'buckets': [
    for (final b in o.buckets)
      {'label': b.label, 'start': _iso(b.start), 'cents': b.cents},
  ],
  'cashCents': o.cashCents,
  'cardCents': o.cardCents,
  'topItems': [
    for (final i in o.topItems)
      {'name': i.name, 'quantity': i.quantity, 'cents': i.cents},
  ],
  'byCategory': [
    for (final c in o.byCategory) {'name': c.name, 'cents': c.cents},
  ],
};

void main() {
  late TestShop shop;

  var dayCount = 0;

  setUp(() async {
    dayCount = 0;
    shop = await TestShop.open();
  });
  tearDown(() => shop.close());

  /// Sorgt dafür, dass zur Zeit [at] der Tag dieses Kalendertags offen ist: ein
  /// offener Tag eines früheren Kalendertags wird abgeschlossen.
  Future<void> ensureDay(DateTime at) async {
    final open = await shop.days.openDay();
    if (open != null) {
      final o = open.openedAt;
      if (DateTime(o.year, o.month, o.day) ==
          DateTime(at.year, at.month, at.day)) {
        shop.clock.value = at;
        return;
      }
      shop.clock.value = DateTime(o.year, o.month, o.day, 22);
      await shop.days.close(
        countedCents: 0,
        leftInDrawerCents: 0,
        staff: _chefin,
      );
    }
    await shop.insertDay(_id('dddddddd', ++dayCount), at);
    shop.clock.value = at;
  }

  Future<String> sellCash(String id, DateTime at, Cart cart) async {
    await ensureDay(at);
    await shop.receipts.finalizeCashSale(
      saleId: id,
      cart: cart,
      givenCents: 5000,
      staff: _anna,
    );
    return id;
  }

  Future<String> sellCard(String id, DateTime at, Cart cart) async {
    await ensureDay(at);
    await shop.receipts.finalizeCardSale(
      saleId: id,
      cart: cart,
      staff: _anna,
      provider: 'sumup',
      txCode: 'TX-$id',
      cardScheme: 'VISA',
      cardLast4: '4242',
    );
    return id;
  }

  Future<int> nextNumber() async =>
      (await shop.db
              .customSelect(
                'SELECT COALESCE(MAX(number), 0) + 1 AS n FROM receipts',
              )
              .getSingle())
          .read<int>('n');

  /// Der Storno-Bon zu [originalId], so geschrieben wie `voidReceipt`, aber mit
  /// fester Kennung (das Repository würfelt sie).
  Future<String> voidReceipt(String id, String originalId, DateTime at) async {
    await ensureDay(at);
    final original = await shop.receipts.byId(originalId);
    final day = await shop.dayId();
    final db = shop.db;
    await db
        .into(db.receiptRows)
        .insert(
          ReceiptRowsCompanion.insert(
            id: id,
            number: await nextNumber(),
            createdAt: at,
            staffId: _chefin.id,
            staffName: _chefin.name,
            businessDayId: Value(day),
            kind: ReceiptKind.voided.name,
            voidsReceiptId: Value(originalId),
            goodsCents: -original.goodsCents,
            depositCents: -original.depositCents,
            totalCents: -original.totalCents,
          ),
        );
    for (final l in original.lines) {
      int gross(TaxRate r) => -(l.grossByRate[r] ?? 0);
      await db
          .into(db.receiptLineRows)
          .insert(
            ReceiptLineRowsCompanion.insert(
              receiptId: id,
              position: l.position,
              itemId: l.itemId,
              name: l.name,
              info: Value(l.info),
              unitPriceCents: l.unitPriceCents,
              quantity: -l.quantity,
              unitDepositCents: l.unitDepositCents,
              gross20Cents: Value(gross(TaxRate.normal)),
              gross10Cents: Value(gross(TaxRate.reduced1)),
              gross13Cents: Value(gross(TaxRate.reduced2)),
              gross0Cents: Value(gross(TaxRate.zero)),
              gross19Cents: Value(gross(TaxRate.special)),
            ),
          );
      for (var i = 0; i < l.options.length; i++) {
        await db
            .into(db.receiptLineOptionRows)
            .insert(
              ReceiptLineOptionRowsCompanion.insert(
                receiptId: id,
                linePosition: l.position,
                position: i,
                groupName: l.options[i].groupName,
                optionName: l.options[i].optionName,
                surchargeCents: l.options[i].surchargeCents,
              ),
            );
      }
    }
    final p = original.payments.single;
    await db
        .into(db.paymentRows)
        .insert(
          PaymentRowsCompanion.insert(
            receiptId: id,
            kind: p.kind.name,
            amountCents: -p.amountCents,
            givenCents: 0,
            changeCents: 0,
            provider: Value(p.provider),
            providerTxCode: Value(p.providerTxCode),
            cardScheme: Value(p.cardScheme),
            cardLast4: Value(p.cardLast4),
          ),
        );
    return id;
  }

  /// Ein Sonderbeleg von Anna: Betrag 0, keine Zeilen, keine Zahlung, kein Tag.
  Future<void> insertSpecial(
    String id,
    int number,
    ReceiptKind kind, {
    required DateTime at,
  }) => shop.db
      .into(shop.db.receiptRows)
      .insert(
        ReceiptRowsCompanion.insert(
          id: id,
          number: number,
          createdAt: at,
          staffId: _anna.id,
          staffName: _anna.name,
          kind: kind.name,
          goodsCents: 0,
          depositCents: 0,
          totalCents: 0,
        ),
      );

  Future<Map<String, Object?>> payloadOf(String id) async {
    final built = await PushPayloads(shop.db)
        .build(OutboxEntry(id: 1, kind: 'receipt', ref: id, rev: 0));
    return built!['receipt'] as Map<String, Object?>;
  }

  test(
    'Umsätze: die Beispieldatei overview.json stimmt mit der Rechnung der App',
    () async {
      final now = DateTime(2026, 11, 19, 15);
      final bowl = const Cart.empty().add(huhnBowl, options: [normal, reis]);
      final colas = const Cart.empty().add(cola).add(cola);
      const daily = Item(
        id: 'tagesgericht',
        name: 'Tagesgericht',
        priceCents: 850,
        categoryId: 'gibt-es-am-tablet-nicht',
        taxRate: TaxRate.reduced1,
        position: 99,
      );
      final dailyCart = const Cart.empty().add(daily);

      final ids = <String>[
        await sellCash(_id('eeeeeeee', 1), DateTime(2026, 10, 11, 10), cart),
        await sellCard(
          _id('eeeeeeee', 2),
          DateTime(2026, 10, 25, 12),
          cartCard,
        ),
        await sellCash(
          _id('eeeeeeee', 3),
          DateTime(2026, 10, 30, 18, 30),
          dailyCart,
        ),
        await sellCash(_id('eeeeeeee', 4), DateTime(2026, 11, 8, 11), colas),
        await sellCard(
          _id('eeeeeeee', 5),
          DateTime(2026, 11, 12, 12, 30),
          cartCard,
        ),
        await sellCash(_id('eeeeeeee', 6), DateTime(2026, 11, 13, 9), bowl),
        await sellCash(
          _id('eeeeeeee', 7),
          DateTime(2026, 11, 13, 9, 30),
          colas,
        ),
        await voidReceipt(
          _id('eeeeeeee', 8),
          _id('eeeeeeee', 7),
          DateTime(2026, 11, 15, 10),
        ),
        await sellCash(_id('eeeeeeee', 9), DateTime(2026, 11, 17, 13), cart),
        // Kurz vor und kurz nach Mitternacht.
        await sellCash(
          _id('eeeeeeee', 10),
          DateTime(2026, 11, 18, 23, 59),
          bowl,
        ),
        await sellCard(
          _id('eeeeeeee', 11),
          DateTime(2026, 11, 19, 0, 1),
          cartCard,
        ),
      ];
      // Ein Sonderbeleg: kein Tag, keine Zahlung, zählt nicht.
      await ensureDay(DateTime(2026, 11, 19, 8));
      await insertSpecial(
        _id('eeeeeeee', 13),
        await nextNumber(),
        ReceiptKind.zero,
        at: DateTime(2026, 11, 19, 8),
      );
      ids.add(_id('eeeeeeee', 13));
      ids.add(
        await sellCash(
          _id('eeeeeeee', 12),
          DateTime(2026, 11, 19, 9, 15),
          colas,
        ),
      );
      ids.add(
        await sellCash(_id('eeeeeeee', 14), DateTime(2026, 11, 19, 11), cart),
      );
      expect(ids, hasLength(14));
      expect(await shop.count('receipts'), 14);

      shop.clock.value = now;
      final expected = {
        'today': _overviewJson(await shop.stats.overview(StatsRange.today)),
        'days7': _overviewJson(await shop.stats.overview(StatsRange.days7)),
        'days30': _overviewJson(await shop.stats.overview(StatsRange.days30)),
      };
      final usedItems = {
        for (final id in ids)
          for (final l in (await shop.receipts.byId(id)).lines) l.itemId,
      };
      final content = <String, Object?>{
        'now': _iso(now),
        'timeZone': 'UTC',
        'categories': [
          for (final c in catalog.categories)
            {'id': c.id, 'name': c.name, 'position': c.position},
        ],
        'items': [
          for (final i in catalog.items)
            if (usedItems.contains(i.id))
              {
                'id': i.id,
                'name': i.name,
                'priceCents': i.priceCents,
                'categoryId': i.categoryId,
                'taxPercent': i.taxRate.percent,
                'depositCents': i.depositCents,
              },
        ],
        'receipts': [for (final id in ids) await payloadOf(id)]
          ..sort((a, b) => (a['number'] as int).compareTo(b['number'] as int)),
        'expected': expected,
      };
      _checkFile('stats/overview.json', content);
    },
    skip: DateTime.now().timeZoneOffset == Duration.zero
        ? false
        : 'Dieser Test braucht ein Gerät in UTC (die Beispieldatei sagt '
              '"timeZone": "UTC"). GitHub und die Entwicklungsumgebung laufen '
              'in UTC.',
  );

  test(
    'Monate: die Beispieldatei months.json stimmt mit der Rechnung der App',
    () async {
      final now = DateTime(2026, 3, 12, 15);
      final bowl = const Cart.empty().add(huhnBowl, options: [normal, reis]);
      final colas = const Cart.empty().add(cola).add(cola);

      final ids = <String>[
        await sellCash(_id('eeeeeeee', 1), DateTime(2025, 11, 3, 10), cart),
        await sellCard(
          _id('eeeeeeee', 2),
          DateTime(2025, 11, 29, 12),
          cartCard,
        ),
        await sellCash(
          _id('eeeeeeee', 3),
          DateTime(2025, 11, 30, 23, 30),
          colas,
        ),
        await sellCash(_id('eeeeeeee', 4), DateTime(2025, 12, 5, 9), bowl),
        // Der Storno kommt im Monat nach dem Bon.
        await voidReceipt(
          _id('eeeeeeee', 5),
          _id('eeeeeeee', 3),
          DateTime(2025, 12, 6, 10),
        ),
        await sellCard(
          _id('eeeeeeee', 6),
          DateTime(2025, 12, 31, 23, 59),
          cartCard,
        ),
        // Jänner bleibt leer.
        await sellCash(_id('eeeeeeee', 7), DateTime(2026, 2, 1, 0, 1), cart),
        await sellCard(_id('eeeeeeee', 8), DateTime(2026, 2, 14, 18), cartCard),
        await sellCash(_id('eeeeeeee', 9), DateTime(2026, 2, 14, 19), bowl),
        await sellCash(_id('eeeeeeee', 10), DateTime(2026, 2, 28, 22), colas),
      ];
      // Ein Sonderbeleg im Dezember: kein Tag, keine Zahlung, zählt nicht.
      await ensureDay(DateTime(2026, 3, 2, 8));
      await insertSpecial(
        _id('eeeeeeee', 11),
        await nextNumber(),
        ReceiptKind.zero,
        at: DateTime(2025, 12, 15, 8),
      );
      ids.add(_id('eeeeeeee', 11));
      // Im laufenden Monat: zählt nirgends mit.
      ids.add(
        await sellCash(_id('eeeeeeee', 12), DateTime(2026, 3, 2, 9), cart),
      );
      ids.add(
        await sellCard(
          _id('eeeeeeee', 13),
          DateTime(2026, 3, 10, 12),
          cartCard,
        ),
      );
      expect(await shop.count('receipts'), 13);

      shop.clock.value = now;
      final choice = await shop.periods.choice();
      final first = choice.first!;
      final last = choice.last!;
      expect(first.key, '2025-11');
      expect(last.key, '2026-02');

      String dayKey(DateTime t) =>
          '${t.year}-${t.month.toString().padLeft(2, '0')}-'
          '${t.day.toString().padLeft(2, '0')}';
      Future<Map<String, Object?>> summary(YearMonth from, YearMonth to) async {
        final r = await shop.periods.report(MonthRange(from, to));
        return {
          'from': from.key,
          'to': to.key,
          'testMode': r.testMode,
          'receiptCount': r.receiptCount,
          'cashReceiptCount': r.cashReceiptCount,
          'cardReceiptCount': r.cardReceiptCount,
          'voidCount': r.voidCount,
          'voidedCents': r.voidedCents,
          'revenueCents': r.revenueCents,
          'cashRevenueCents': r.cashRevenueCents,
          'cardRevenueCents': r.cardRevenueCents,
          'depositCents': r.depositCents,
          'taxLines': [
            for (final t in r.taxLines)
              {
                'percent': t.rate.percent,
                'grossCents': t.grossCents,
                'netCents': t.netCents,
                'taxCents': t.taxCents,
              },
          ],
          'rows': [
            for (final row in r.rows)
              {
                'key': from == to
                    ? dayKey(row.start)
                    : YearMonth.of(row.start).key,
                'receiptCount': row.receiptCount,
                'revenueCents': row.revenueCents,
              },
          ],
        };
      }

      final all = await shop.periods.report(MonthRange(first, last));
      final summaries = <String, Object?>{};
      for (final m in MonthRange(first, last).months) {
        summaries['${m.key}..${m.key}'] = await summary(m, m);
      }
      summaries['${first.key}..${last.key}'] = await summary(first, last);

      final content = <String, Object?>{
        'now': _iso(now),
        'timeZone': 'UTC',
        'receipts': [for (final id in ids) await payloadOf(id)]
          ..sort((a, b) => (a['number'] as int).compareTo(b['number'] as int)),
        'expected': {
          'months': [
            for (final row in all.rows.reversed)
              {
                'month': YearMonth.of(row.start).key,
                'receiptCount': row.receiptCount,
                'revenueCents': row.revenueCents,
              },
          ],
          'summaries': summaries,
        },
      };
      _checkFile('stats/months.json', content);
    },
    skip: DateTime.now().timeZoneOffset == Duration.zero
        ? false
        : 'Dieser Test braucht ein Gerät in UTC (die Beispieldatei sagt '
              '"timeZone": "UTC"). GitHub und die Entwicklungsumgebung laufen '
              'in UTC.',
  );

  test('Protokoll-Datei: dep.json stimmt mit buildDepExport', () async {
    DateTime at(int h, int m) => DateTime.utc(2026, 11, 18, h, m);
    final db = shop.db;
    await shop.insertDay(_id('dddddddd', 1), at(8, 0));

    // Zwei Zertifikate in Folge: das erste signiert Startbeleg bis Bon 2, dann
    // wechselt die Kette zum zweiten.
    const certificates = [
      ('1a2b3c', [1, 2, 3, 4, 5, 6], ['BwgJCgsM', 'DQ4PEBES']),
      ('4d5e6f', [9, 8, 7, 6, 5, 4, 3], ['BwgJCgsM']),
    ];
    for (final (serial, der, issuers) in certificates) {
      await db
          .into(db.rksvCertificateRows)
          .insert(
            RksvCertificateRowsCompanion.insert(
              serialHex: serial,
              certificate: Uint8List.fromList(der),
              issuers: Value(jsonEncode(issuers)),
            ),
          );
    }
    await db
        .into(db.rksvChainRows)
        .insert(
          RksvChainRowsCompanion.insert(
            chain: const Value(1),
            mode: 'probe',
            cashBoxId: 'DEMOKASSA1',
            zdaId: 'AT100',
            certSerial: '4d5e6f',
            startedAt: at(8, 0),
          ),
        );

    String b64(String s) =>
        base64Url.encode(utf8.encode(s)).replaceAll('=', '');
    String jws(int number, DateTime t, String serial, {bool damaged = false}) =>
        'eyJhbGciOiJFUzI1NiJ9.${b64('_R1-AT100_DEMOKASSA1_${number}_${t.toIso8601String().substring(0, 19)}_0,00_0,00_0,00_0,00_0,00_Q29uc3Q_${serial}_AAAAAAAAAAA=')}'
        '.${damaged ? b64('Sicherheitseinrichtung ausgefallen') : b64('signatur-$number')}';

    // Position 1: Startbeleg, danach vier Verkäufe. Der dritte Eintrag ist
    // ausgefallen.
    final times = [at(8, 1), at(9, 5), at(10, 20), at(11, 30), at(12, 45)];
    final serials = ['1a2b3c', '1a2b3c', '1a2b3c', '4d5e6f', '4d5e6f'];
    final ids = <String>[];
    shop.clock.value = times[0];
    await insertSpecial(_id('eeeeeeee', 1), 1, ReceiptKind.start, at: times[0]);
    ids.add(_id('eeeeeeee', 1));
    final carts = [cart, cartCard, cart, cartCard];
    for (var i = 0; i < 4; i++) {
      shop.clock.value = times[i + 1];
      await shop.receipts.finalizeCashSale(
        saleId: _id('eeeeeeee', i + 2),
        cart: carts[i],
        givenCents: 5000,
        staff: _anna,
      );
      ids.add(_id('eeeeeeee', i + 2));
    }
    for (var i = 0; i < ids.length; i++) {
      await db
          .into(db.rksvEntryRows)
          .insert(
            RksvEntryRowsCompanion.insert(
              chain: 1,
              position: i + 1,
              receiptId: ids[i],
              jws: jws(i + 1, times[i], serials[i], damaged: i == 2),
              damaged: i == 2,
              certSerial: serials[i],
            ),
          );
    }

    final push = PushPayloads(db);
    Future<Map<String, Object?>> body(String kind, String ref) async =>
        (await push.build(OutboxEntry(id: 1, kind: kind, ref: ref, rev: 0)))!;
    final content = <String, Object?>{
      'certificates': [
        for (final c in certificates)
          (await body('rksv_certificate', c.$1))['certificate'],
      ],
      'chain': (await body('rksv_chain', '1'))['chain'],
      'entries': [for (final id in ids) await payloadOf(id)],
      'expected': jsonDecode(await buildDepExport(db, chain: 1)),
    };
    // Die Einträge tragen ihre Zeile im Protokoll, in der Reihenfolge der Kette.
    final entries = content['entries']! as List;
    expect(
      [for (final e in entries) (e as Map)['rksv']['position']],
      [1, 2, 3, 4, 5],
    );
    _checkFile('rksv/dep.json', content);
  });
}
