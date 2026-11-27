// Monatsabrechnung am Tablet: rechnet aus den gespeicherten Bons einen
// Monat oder Zeitraum. Schreibt nichts.

import 'package:drift/drift.dart';

import '../core/clock.dart';
import '../domain/catalog.dart';
import '../domain/period_report.dart';
import '../domain/pricing.dart';
import '../domain/receipt.dart';
import 'database.dart';
import 'receipt_tally.dart';

class PeriodReportRepository {
  PeriodReportRepository(this._db, this._clock);

  final KassaDatabase _db;
  final Clock _clock;

  static final _kinds = [ReceiptKind.sale.name, ReceiptKind.voided.name];

  /// Von dem Monat des ältesten gezählten Bons bis zum Monat vor dem
  /// laufenden. Liegt der älteste Bon später, ist noch nichts abrechenbar.
  Future<MonthChoice> choice() async {
    final now = _clock.now();
    final current = YearMonth.of(now);
    final next = DateTime(now.year, now.month + 1);
    final oldest = _db.receiptRows.createdAt.min();
    final row =
        await (_db.selectOnly(_db.receiptRows)
              ..addColumns([oldest])
              ..where(_counted(_db.receiptRows, await _hasLive())))
            .getSingle();
    final first = row.read(oldest);
    final last = current.previous;
    if (first == null || YearMonth.of(first).compareTo(last) > 0) {
      return MonthChoice(nextAvailable: next);
    }
    return MonthChoice(
      first: YearMonth.of(first),
      last: last,
      nextAvailable: next,
    );
  }

  /// Wirft [ArgumentError], wenn ein Monat nicht in [choice] liegt oder der
  /// Beginn nach dem Ende liegt.
  Future<PeriodReport> report(MonthRange range) async {
    final choice = await this.choice();
    if (range.from.compareTo(range.to) > 0 ||
        !choice.allows(range.from) ||
        !choice.allows(range.to)) {
      throw ArgumentError.value(
        range.key,
        'range',
        'Zeitraum nicht abrechenbar',
      );
    }
    final live = await _hasLive();

    final tally = ReceiptTally();
    final taxByRate = <TaxRate, (int, int, int)>{};
    final monthRows = <PeriodRow>[];
    final dayRows = <PeriodRow>[];

    for (final month in range.months) {
      final rows = await _receiptsOf(month, live);
      final perDay = <DateTime, (int, int)>{};
      var monthCount = 0;
      var monthRevenue = 0;
      for (final r in rows) {
        tally.add(r.receipt, r.payments);
        final step = r.receipt.kind == ReceiptKind.voided.name ? -1 : 1;
        final total = r.receipt.totalCents;
        monthCount += step;
        monthRevenue += total;
        final t = r.receipt.createdAt;
        final day = DateTime(t.year, t.month, t.day);
        final old = perDay[day] ?? (0, 0);
        perDay[day] = (old.$1 + step, old.$2 + total);
      }
      monthRows.add(
        PeriodRow(
          start: month.start,
          receiptCount: monthCount,
          revenueCents: monthRevenue,
        ),
      );
      for (final e
          in perDay.entries.toList()..sort((a, b) => a.key.compareTo(b.key))) {
        dayRows.add(
          PeriodRow(
            start: e.key,
            receiptCount: e.value.$1,
            revenueCents: e.value.$2,
          ),
        );
      }
      // Steuer je Monat gerechnet, dann über die Monate addiert.
      for (final line in taxBreakdown(await _grossOf(month, live))) {
        final old = taxByRate[line.rate] ?? (0, 0, 0);
        taxByRate[line.rate] = (
          old.$1 + line.grossCents,
          old.$2 + line.netCents,
          old.$3 + line.taxCents,
        );
      }
    }
    final rates = [
      for (final e in taxByRate.entries)
        if (e.value.$1 != 0) e.key,
    ]..sort((a, b) => b.percent.compareTo(a.percent));

    return PeriodReport(
      range: range,
      testMode: !live,
      receiptCount: tally.count,
      cashReceiptCount: tally.cashCount,
      cardReceiptCount: tally.cardCount,
      voidCount: tally.voidCount,
      voidedCents: tally.voidedCents,
      revenueCents: tally.revenueCents,
      cashRevenueCents: tally.cashCents,
      cardRevenueCents: tally.cardCents,
      depositCents: tally.depositCents,
      taxLines: [
        for (final r in rates)
          TaxLine(
            rate: r,
            grossCents: taxByRate[r]!.$1,
            netCents: taxByRate[r]!.$2,
            taxCents: taxByRate[r]!.$3,
          ),
      ],
      firstNumber: tally.firstNumber,
      lastNumber: tally.lastNumber,
      rows: range.single ? dayRows : monthRows,
      discountCount: tally.discountCount,
      discountCents: tally.discountCents,
      cardTipCents: tally.cardTipCents,
      tipsByStaff: tally.tipsByStaff,
    );
  }

  /// Der früheste Monats- oder Jahresbeleg, der nach Ende von [month] entstand.
  Future<String?> signatureReceiptId(YearMonth month) async {
    final row =
        await (_db.select(_db.receiptRows)
              ..where(
                (t) =>
                    t.kind.isIn([
                      ReceiptKind.month.name,
                      ReceiptKind.year.name,
                    ]) &
                    t.createdAt.isBiggerOrEqualValue(month.end),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])
              ..limit(1))
            .getSingleOrNull();
    return row?.id;
  }

  Future<bool> hasSignature() async =>
      (await (_db.select(_db.rksvChainRows)..limit(1)).get()).isNotEmpty;

  /// Gibt es einen Eintrag in einer Kette der Art `live`?
  Future<bool> _hasLive() async {
    final rows =
        await (_db.select(_db.rksvEntryRows).join([
                innerJoin(
                  _db.rksvChainRows,
                  _db.rksvChainRows.chain.equalsExp(_db.rksvEntryRows.chain),
                ),
              ])
              ..where(_db.rksvChainRows.mode.equals('live'))
              ..limit(1))
            .get();
    return rows.isNotEmpty;
  }

  /// Bedingung für gezählte Bons: Verkauf oder Storno, und bei [live] nur
  /// solche mit Eintrag in einer `live`-Kette.
  Expression<bool> _counted($ReceiptRowsTable t, bool live) {
    final kind = t.kind.isIn(_kinds);
    return live ? kind & t.id.isInQuery(_liveIds()) : kind;
  }

  JoinedSelectStatement _liveIds() => _db.selectOnly(_db.rksvEntryRows)
    ..addColumns([_db.rksvEntryRows.receiptId])
    ..join([
      innerJoin(
        _db.rksvChainRows,
        _db.rksvChainRows.chain.equalsExp(_db.rksvEntryRows.chain),
      ),
    ])
    ..where(_db.rksvChainRows.mode.equals('live'));

  Expression<bool> _inMonth(YearMonth m, bool live) =>
      _counted(_db.receiptRows, live) &
      _db.receiptRows.createdAt.isBiggerOrEqualValue(m.start) &
      _db.receiptRows.createdAt.isSmallerThanValue(m.end);

  /// Die gezählten Bons des Monats mit ihren Zahlungen, nach Nummer. Ein
  /// gemischter Bon hat zwei Zahlungen und steht trotzdem einmal da.
  Future<List<({ReceiptRow receipt, List<PaymentRow> payments})>> _receiptsOf(
    YearMonth m,
    bool live,
  ) async {
    final receipts =
        await (_db.select(_db.receiptRows)
              ..where((_) => _inMonth(m, live))
              ..orderBy([(t) => OrderingTerm.asc(t.number)]))
            .get();
    final payments = <String, List<PaymentRow>>{};
    for (final j in await (_db.select(_db.paymentRows).join([
      innerJoin(
        _db.receiptRows,
        _db.receiptRows.id.equalsExp(_db.paymentRows.receiptId),
      ),
    ])..where(_inMonth(m, live))).get()) {
      final p = j.readTable(_db.paymentRows);
      (payments[p.receiptId] ??= []).add(p);
    }
    return [
      for (final r in receipts)
        (receipt: r, payments: payments[r.id] ?? const <PaymentRow>[]),
    ];
  }

  /// Brutto je Steuersatz aus den Zeilen der gezählten Bons des Monats.
  Future<Map<TaxRate, int>> _grossOf(YearMonth m, bool live) async {
    final l = _db.receiptLineRows;
    final sums = {
      TaxRate.normal: l.gross20Cents.sum(),
      TaxRate.reduced1: l.gross10Cents.sum(),
      TaxRate.reduced2: l.gross13Cents.sum(),
      TaxRate.zero: l.gross0Cents.sum(),
      TaxRate.special: l.gross19Cents.sum(),
    };
    final row =
        await (_db.selectOnly(l).join([
                innerJoin(
                  _db.receiptRows,
                  _db.receiptRows.id.equalsExp(l.receiptId),
                ),
              ])
              ..addColumns(sums.values)
              ..where(_inMonth(m, live)))
            .getSingle();
    return sumByRate([
      {for (final e in sums.entries) e.key: row.read(e.value) ?? 0},
    ]);
  }
}
