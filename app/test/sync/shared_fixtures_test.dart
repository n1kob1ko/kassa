// Die gemeinsamen Beispiele für Umsätze und Protokoll-Datei. Die App rechnet
// sie aus einer echten Datenbank, der Server prüft dieselben Dateien gegen
// seine eigene Rechnung. Mit KASSA_WRITE_FIXTURES=1 schreibt dieser Test die
// Dateien neu, sonst vergleicht er.

import 'dart:convert';
import 'dart:io';
import 'dart:math' show Random;
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/data/database.dart';
import 'package:kassa/data/outbox_repository.dart';
import 'package:kassa/domain/cart.dart';
import 'package:kassa/domain/catalog.dart';
import 'package:kassa/domain/period_report.dart';
import 'package:kassa/domain/pricing.dart' show TaxLine;
import 'package:kassa/domain/receipt.dart';
import 'package:kassa/domain/staff.dart';
import 'package:kassa/domain/stats.dart';
import 'package:kassa/rksv/dep_export.dart';
import 'package:kassa/sync/push_wire.dart';

import '../support/demo_fixtures.dart';
import '../support/sales.dart';
import '../support/voucher_deposit_day.dart';

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

  test(
    'Gemischt: die Beispieldatei mixed.json (bar, Karte, bar + Karte mit '
    'Trinkgeld, bar mit Rabatt) stimmt mit der Rechnung der App',
    () async {
      final now = DateTime(2026, 7, 1, 12);

      final ids = <String>[
        await sellCash(_id('ffffffff', 1), DateTime(2026, 6, 29, 10), cartCard),
        await sellCard(_id('ffffffff', 2), DateTime(2026, 6, 29, 12), cartCard),
      ];
      // 18,20 €: 10,00 € bar, 8,20 € mit Karte, dazu 0,80 € Trinkgeld für Anna.
      await ensureDay(DateTime(2026, 6, 30, 18));
      await shop.receipts.finalizeCardSale(
        saleId: _id('ffffffff', 3),
        cart: cart,
        staff: _anna,
        provider: 'sumup',
        txCode: 'TX-${_id('ffffffff', 3)}',
        cardScheme: 'VISA',
        cardLast4: '4242',
        cashPartCents: 1000,
        tipCents: 80,
      );
      ids.add(_id('ffffffff', 3));
      // 15,36 € bar: 10 % Stammgast auf der Huhn Bowl (1,19 €) und 10 % Aktion
      // auf dem Bon (1,65 €), zusammen 2,84 € Rabatt.
      ids.add(
        await sellCash(
          _id('ffffffff', 4),
          DateTime(2026, 6, 30, 19),
          discounted,
        ),
      );
      expect(await shop.count('receipts'), 4);

      shop.clock.value = now;
      final month = YearMonth(2026, 6);
      final choice = await shop.periods.choice();
      expect(choice.first, month);
      expect(choice.last, month);
      final r = await shop.periods.report(MonthRange(month, month));
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
        'expected': {
          'overview': {
            'today': _overviewJson(await shop.stats.overview(StatsRange.today)),
            'days7': _overviewJson(await shop.stats.overview(StatsRange.days7)),
            'days30': _overviewJson(
              await shop.stats.overview(StatsRange.days30),
            ),
          },
          'months': [
            {
              'month': month.key,
              'receiptCount': r.receiptCount,
              'revenueCents': r.revenueCents,
            },
          ],
          'summary': {
            'from': month.key,
            'to': month.key,
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
            'discountCount': r.discountCount,
            'discountCents': r.discountCents,
            'cardTipCents': r.cardTipCents,
            'cardAccountCents': r.cardAccountCents,
            'tipsByStaff': [
              for (final x in r.tipsByStaff)
                {'staffName': x.staffName, 'cents': x.cents},
            ],
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
                  'key':
                      '${row.start.year}-'
                      '${row.start.month.toString().padLeft(2, '0')}-'
                      '${row.start.day.toString().padLeft(2, '0')}',
                  'receiptCount': row.receiptCount,
                  'revenueCents': row.revenueCents,
                },
            ],
          },
        },
      };
      _checkFile('stats/mixed.json', content);
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
  test(
    'Stufe 1b: die Beispieldatei stufe_1b.json (Barbon, Gutschein-Verkauf, '
    'Gutschein-Zahlung, Pfand zurück) stimmt mit der Rechnung der App',
    () async {
      // Fester Zufall: derselbe Schlüssel der Seite und derselbe Code bei
      // jedem Lauf. Eigener Samen, denn der Schlüssel gilt am Server über
      // alle Betriebe.
      await shop.close();
      shop = await TestShop.open(random: Random(71215));
      final at = DateTime(2026, 10, 14, 10);
      final now = DateTime(2026, 11, 2, 12);
      final dayId = _id('dddddddd', 1);
      final ids = [for (var i = 1; i <= 4; i++) _id('b1b1b1b1', i)];
      await shop.insertDay(dayId, DateTime(2026, 10, 14, 8));
      shop.clock.value = at;
      await sellVoucherDepositDay(shop, ids: ids);
      expect(await shop.count('receipts'), 4);

      // Die Kennungen des Gutscheins und der Mitarbeiterin würfelt die App:
      // in der Datei stehen feste.
      final voucherId = (await shop.vouchers.soldOn(ids[1])).single.id;
      final fixed = {voucherId: _id('cccccccc', 1), shop.anna.id: 'anna'};
      Object? normalize(Object? v) => switch (v) {
        final String s => fixed[s] ?? s,
        final List<Object?> l => [for (final x in l) normalize(x)],
        final Map<String, Object?> m => {
          for (final e in m.entries) e.key: normalize(e.value),
        },
        _ => v,
      };

      final day = (await shop.days.summary())!;
      List<Map<String, Object?>> taxJson(List<TaxLine> lines) => [
        for (final t in lines)
          {
            'percent': t.rate.percent,
            'grossCents': t.grossCents,
            'netCents': t.netCents,
            'taxCents': t.taxCents,
          },
      ];
      final dayJson = <String, Object?>{
        'receiptCount': day.receiptCount,
        'revenueCents': day.revenueCents,
        'cashCents': day.cashRevenueCents,
        'cardCents': day.cardRevenueCents,
        'cashReceiptCount': day.cashReceiptCount,
        'cardReceiptCount': day.cardReceiptCount,
        'voidCount': day.voidCount,
        'voidedCents': day.voidedCents,
        'depositCents': day.depositCents,
        'discountCount': day.discountCount,
        'discountCents': day.discountCents,
        'cardTipCents': day.cardTipCents,
        'cardAccountCents': day.cardAccountCents,
        'tipsByStaff': [
          for (final x in day.tipsByStaff)
            {'staffName': x.staffName, 'cents': x.cents},
        ],
        'taxLines': taxJson(day.taxLines),
        'voucherPaidCents': day.voucherPaidCents,
        'voucherSoldCount': day.voucherSoldCount,
        'voucherSoldCents': day.voucherSoldCents,
        'depositReturnCount': day.depositReturnCount,
        'depositReturnCents': day.depositReturnCents,
      };

      shop.clock.value = now;
      final month = YearMonth(2026, 10);
      final choice = await shop.periods.choice();
      expect(choice.first, month);
      expect(choice.last, month);
      final r = await shop.periods.report(MonthRange(month, month));
      final usedItems = {
        for (final id in ids)
          for (final l in (await shop.receipts.byId(id)).lines) l.itemId,
      };
      Future<Map<String, Object?>> overviewJson(StatsRange range) async {
        final o = await shop.stats.overview(range);
        return {..._overviewJson(o), 'voucherCents': o.voucherCents};
      }

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
        'day': normalize(
          (await PushPayloads(
            shop.db,
          ).build(OutboxEntry(id: 1, kind: 'day', ref: dayId, rev: 0)))!['day'],
        ),
        'receipts': [for (final id in ids) normalize(await payloadOf(id))]
          ..sort(
            (a, b) => ((a! as Map)['number'] as int).compareTo(
              (b! as Map)['number'] as int,
            ),
          ),
        'expected': {
          'day': dayJson,
          'overview': {
            'today': await overviewJson(StatsRange.today),
            'days7': await overviewJson(StatsRange.days7),
            'days30': await overviewJson(StatsRange.days30),
          },
          'months': [
            {
              'month': month.key,
              'receiptCount': r.receiptCount,
              'revenueCents': r.revenueCents,
            },
          ],
          'summary': {
            'from': month.key,
            'to': month.key,
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
            'discountCount': r.discountCount,
            'discountCents': r.discountCents,
            'cardTipCents': r.cardTipCents,
            'cardAccountCents': r.cardAccountCents,
            'tipsByStaff': [
              for (final x in r.tipsByStaff)
                {'staffName': x.staffName, 'cents': x.cents},
            ],
            'taxLines': taxJson(r.taxLines),
            'voucherPaidCents': r.voucherPaidCents,
            'voucherSoldCount': r.voucherSoldCount,
            'voucherSoldCents': r.voucherSoldCents,
            'depositReturnCount': r.depositReturnCount,
            'depositReturnCents': r.depositReturnCents,
            'rows': [
              for (final row in r.rows)
                {
                  'key':
                      '${row.start.year}-'
                      '${row.start.month.toString().padLeft(2, '0')}-'
                      '${row.start.day.toString().padLeft(2, '0')}',
                  'receiptCount': row.receiptCount,
                  'revenueCents': row.revenueCents,
                },
            ],
          },
        },
      };
      // Die Bons sind in der Form v: 3, mit Gutschein und Pfand zurück.
      final receipts = content['receipts']! as List;
      expect([for (final x in receipts) (x! as Map)['v']], [3, 3, 3, 3]);
      _checkFile('stats/stufe_1b.json', content);
    },
    skip: DateTime.now().timeZoneOffset == Duration.zero
        ? false
        : 'Dieser Test braucht ein Gerät in UTC (die Beispieldatei sagt '
              '"timeZone": "UTC"). GitHub und die Entwicklungsumgebung laufen '
              'in UTC.',
  );
}
