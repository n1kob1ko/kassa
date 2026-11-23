import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/data/database.dart';
import 'package:kassa/domain/catalog.dart';
import 'package:kassa/domain/period_report.dart';
import 'package:kassa/domain/receipt.dart';

import '../support/sales.dart';

const sep = YearMonth(2026, 9);
const okt = YearMonth(2026, 10);
const nov = YearMonth(2026, 11);

void main() {
  late TestShop shop;

  setUp(() async => shop = await TestShop.open());
  tearDown(() => shop.close());

  /// Bar-Bon über 18,20 € zur Zeit [at]; die Uhr steht danach auf "jetzt".
  Future<Receipt> sellAt(String id, DateTime at) async {
    final now = shop.clock.value;
    shop.clock.value = at;
    final r = await shop.sell(id);
    shop.clock.value = now;
    return r;
  }

  Map<TaxRate, TaxLineValues> taxOf(PeriodReport r) => {
    for (final l in r.taxLines)
      l.rate: (gross: l.grossCents, tax: l.taxCents, net: l.netCents),
  };

  /// Ein Eintrag des Bons [receiptId] in einer Kette der Art [mode].
  Future<void> stamp(String receiptId, {String mode = 'live'}) async {
    final db = shop.db;
    await db
        .into(db.rksvCertificateRows)
        .insertOnConflictUpdate(
          RksvCertificateRowsCompanion.insert(
            serialHex: '01',
            certificate: Uint8List.fromList([1]),
          ),
        );
    await db
        .into(db.rksvChainRows)
        .insertOnConflictUpdate(
          RksvChainRowsCompanion.insert(
            chain: const Value(1),
            mode: mode,
            cashBoxId: 'K1',
            zdaId: 'AT1',
            certSerial: '01',
            startedAt: DateTime(2026, 9),
          ),
        );
    await db
        .into(db.rksvEntryRows)
        .insert(
          RksvEntryRowsCompanion.insert(
            chain: 1,
            position: (await shop.count('rksv_entries')) + 1,
            receiptId: receiptId,
            jws: 'x',
            damaged: false,
            certSerial: '01',
          ),
        );
  }

  test('Monatsgrenzen', () async {
    await sellAt('a', DateTime(2026, 9, 30, 23, 59));
    await sellAt('b', DateTime(2026, 10, 1));
    await sellAt('c', DateTime(2026, 10, 31, 23, 59));
    await sellAt('d', DateTime(2026, 11, 1));
    final r = await shop.periods.report(const MonthRange(okt, okt));
    expect((r.revenueCents, r.receiptCount), (3640, 2));
    expect(r.rows.map((x) => (x.start, x.receiptCount, x.revenueCents)), [
      (DateTime(2026, 10, 1), 1, 1820),
      (DateTime(2026, 10, 31), 1, 1820),
    ]);
  });

  test('Storno in anderem Monat', () async {
    final s = await sellAt('a', DateTime(2026, 10, 30, 12));
    shop.clock.value = DateTime(2026, 11, 2, 9);
    await shop.receipts.voidReceipt(s.id, staff: shop.chef);
    shop.clock.value = DateTime(2026, 12, 5, 11);
    final o = await shop.periods.report(const MonthRange(okt, okt));
    expect((o.revenueCents, o.receiptCount, o.voidCount), (1820, 1, 0));
    final n = await shop.periods.report(const MonthRange(nov, nov));
    expect((n.revenueCents, n.receiptCount), (-1820, -1));
    expect((n.voidCount, n.voidedCents), (1, 1820));
    expect(n.taxLines, isNotEmpty);
    expect(n.taxLines.every((l) => l.grossCents < 0 && l.taxCents < 0), isTrue);
    expect(n.rows.single.receiptCount, -1);
  });

  test('Sonderbelege zählen nicht', () async {
    await sellAt('a', DateTime(2026, 10, 5, 10));
    await shop.insertSpecialReceipt(
      'm1',
      99,
      ReceiptKind.month,
      at: DateTime(2026, 10, 6, 10),
    );
    final r = await shop.periods.report(const MonthRange(okt, okt));
    expect(r.receiptCount, 1);
    expect(r.firstNumber, isNotNull);
    expect(r.firstNumber, r.lastNumber);
    expect(r.lastNumber, isNot(99));
  });

  test('Bar und Karte', () async {
    await sellAt('a', DateTime(2026, 10, 5, 10));
    await shop.insertCardReceipt('k', 50, 965, at: DateTime(2026, 10, 6, 10));
    final r = await shop.periods.report(const MonthRange(okt, okt));
    expect((r.cashRevenueCents, r.cashReceiptCount), (1820, 1));
    expect((r.cardRevenueCents, r.cardReceiptCount), (965, 1));
    expect((r.revenueCents, r.receiptCount), (2785, 2));
  });

  test('Steuer und Pfand', () async {
    await sellAt('a', DateTime(2026, 10, 5, 10));
    await sellAt('b', DateTime(2026, 10, 6, 10));
    final r = await shop.periods.report(const MonthRange(okt, okt));
    final t = taxOf(r);
    expect(t[TaxRate.normal], (gross: 1160, tax: 193, net: 967));
    expect(t[TaxRate.reduced1], (gross: 2380, tax: 216, net: 2164));
    expect(r.taxLines.map((l) => l.rate), [TaxRate.normal, TaxRate.reduced1]);
    expect(r.depositCents, 100);
  });

  test('Mehrere Monate: Steuer ist die Summe der Monate', () async {
    await sellAt('a', DateTime(2026, 9, 1, 10));
    await sellAt('b', DateTime(2026, 10, 1, 10));
    final both = await shop.periods.report(const MonthRange(sep, okt));
    expect(taxOf(both)[TaxRate.normal], (gross: 1160, tax: 194, net: 966));
    expect(both.rows.map((x) => (x.start, x.receiptCount, x.revenueCents)), [
      (DateTime(2026, 9, 1), 1, 1820),
      (DateTime(2026, 10, 1), 1, 1820),
    ]);
    final a = await shop.periods.report(const MonthRange(sep, sep));
    final b = await shop.periods.report(const MonthRange(okt, okt));
    expect(both.revenueCents, a.revenueCents + b.revenueCents);
    expect(both.depositCents, a.depositCents + b.depositCents);
    for (final rate in [TaxRate.normal, TaxRate.reduced1]) {
      expect(taxOf(both)[rate]!.tax, taxOf(a)[rate]!.tax + taxOf(b)[rate]!.tax);
    }
  });

  test('Über den Jahreswechsel', () async {
    await sellAt('a', DateTime(2025, 12, 10, 10));
    await sellAt('b', DateTime(2026, 2, 10, 10));
    shop.clock.value = DateTime(2026, 3, 5, 10);
    final r = await shop.periods.report(
      const MonthRange(YearMonth(2025, 12), YearMonth(2026, 2)),
    );
    expect(r.rows.map((x) => (x.start, x.receiptCount, x.revenueCents)), [
      (DateTime(2025, 12), 1, 1820),
      (DateTime(2026, 1), 0, 0),
      (DateTime(2026, 2), 1, 1820),
    ]);
  });

  test('Auswahl', () async {
    var c = await shop.periods.choice();
    expect((c.first, c.last), (null, null));
    expect(c.nextAvailable, DateTime(2026, 12, 1));
    await sellAt('a', DateTime(2026, 11, 3, 10));
    c = await shop.periods.choice();
    expect((c.first, c.last), (null, null));
    await sellAt('b', DateTime(2026, 9, 3, 10));
    await sellAt('c', DateTime(2026, 10, 3, 10));
    c = await shop.periods.choice();
    expect((c.first, c.last), (sep, okt));
    expect(c.allows(nov), isFalse);
  });

  test('Laufender Monat und falsche Reihenfolge', () async {
    await sellAt('a', DateTime(2026, 9, 3, 10));
    await sellAt('b', DateTime(2026, 10, 3, 10));
    expect(
      () => shop.periods.report(const MonthRange(nov, nov)),
      throwsArgumentError,
    );
    expect(
      () => shop.periods.report(const MonthRange(okt, sep)),
      throwsArgumentError,
    );
  });

  test('Nur Testbons: alle zählen', () async {
    await sellAt('a', DateTime(2026, 10, 3, 10));
    await sellAt('b', DateTime(2026, 10, 4, 10));
    final r = await shop.periods.report(const MonthRange(okt, okt));
    expect((r.testMode, r.receiptCount), (true, 2));
    await stamp('a', mode: 'probe');
    final p = await shop.periods.report(const MonthRange(okt, okt));
    expect((p.testMode, p.receiptCount), (true, 2));
  });

  test('Testbons und echte gemischt', () async {
    await sellAt('a', DateTime(2026, 9, 3, 10));
    await sellAt('b', DateTime(2026, 10, 3, 10));
    await sellAt('c', DateTime(2026, 10, 4, 10));
    await stamp('c');
    final r = await shop.periods.report(const MonthRange(okt, okt));
    expect((r.testMode, r.receiptCount), (false, 1));
    final c = await shop.periods.choice();
    expect((c.first, c.last), (okt, okt));
  });

  test('Leerer Monat', () async {
    await sellAt('a', DateTime(2026, 9, 3, 10));
    shop.clock.value = DateTime(2026, 11, 10, 10);
    final r = await shop.periods.report(const MonthRange(okt, okt));
    expect(r.isEmpty, isTrue);
    expect(r.rows, isEmpty);
    expect(r.taxLines, isEmpty);
    expect((await shop.periods.choice()).last, okt);
  });

  test('Bon in der Zukunft zählt nicht und wirft nicht', () async {
    await sellAt('a', DateTime(2026, 10, 3, 10));
    await sellAt('z', DateTime(2027, 2, 3, 10));
    expect((await shop.periods.choice()).last, okt);
    final r = await shop.periods.report(const MonthRange(okt, okt));
    expect(r.receiptCount, 1);
  });

  test('Langer Zeitraum', () async {
    await sellAt('a', DateTime(2023, 12, 5, 10));
    await sellAt('b', DateTime(2026, 10, 5, 10));
    final r = await shop.periods.report(
      const MonthRange(YearMonth(2023, 12), okt),
    );
    expect(r.rows, hasLength(35));
    expect(r.revenueCents, 3640);
  });

  test('Signaturbeleg', () async {
    expect(await shop.periods.signatureReceiptId(okt), isNull);
    await shop.insertSpecialReceipt(
      'm1',
      90,
      ReceiptKind.month,
      at: DateTime(2026, 11, 1, 10, 2),
    );
    await shop.insertSpecialReceipt(
      'm2',
      91,
      ReceiptKind.month,
      at: DateTime(2026, 12, 1, 10, 2),
    );
    expect(await shop.periods.signatureReceiptId(okt), 'm1');
    expect(await shop.periods.signatureReceiptId(nov), 'm2');
    expect(
      await shop.periods.signatureReceiptId(const YearMonth(2026, 12)),
      isNull,
    );
  });

  test('hasSignature', () async {
    expect(await shop.periods.hasSignature(), isFalse);
    await sellAt('a', DateTime(2026, 10, 3, 10));
    await stamp('a', mode: 'probe');
    expect(await shop.periods.hasSignature(), isTrue);
  });
}

typedef TaxLineValues = ({int gross, int tax, int net});
