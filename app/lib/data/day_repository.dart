// Geschäftstag, Bargeld-Bewegungen und Tagesabschluss.

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../core/clock.dart';
import '../domain/catalog.dart';
import '../domain/day.dart';
import '../domain/pricing.dart';
import '../domain/receipt.dart';
import '../domain/staff.dart';
import 'database.dart';

class NoOpenDayException implements Exception {
  const NoOpenDayException();

  @override
  String toString() => 'NoOpenDayException: Es gibt keinen offenen Tag.';
}

class LeftInDrawerTooHighException implements Exception {
  const LeftInDrawerTooHighException();

  @override
  String toString() =>
      'LeftInDrawerTooHighException: In der Lade bleibt mehr, als gezählt wurde.';
}

class InvalidAmountException implements Exception {
  const InvalidAmountException();

  @override
  String toString() => 'InvalidAmountException: Der Betrag ist ungültig.';
}

class DayRepository {
  DayRepository(this._db, this._clock);

  final KassaDatabase _db;
  final Clock _clock;

  Future<BusinessDay?> openDay() async {
    final row = await (_db.select(
      _db.businessDayRows,
    )..where((t) => t.closedAt.isNull())).getSingleOrNull();
    return row == null ? null : _toDay(row);
  }

  /// Der offene Tag als Strom: er meldet auch, wenn ein Tag neu beginnt
  /// (zum Beispiel mit dem ersten Verkauf) oder abgeschlossen wird.
  Stream<BusinessDay?> watchOpenDay() =>
      (_db.select(_db.businessDayRows)..where((t) => t.closedAt.isNull()))
          .watchSingleOrNull()
          .map((r) => r == null ? null : _toDay(r));

  Future<BusinessDay?> lastClosedDay() async {
    final row =
        await (_db.select(_db.businessDayRows)
              ..where((t) => t.closedAt.isNotNull())
              ..orderBy([(t) => OrderingTerm.desc(t.closedAt)])
              ..limit(1))
            .getSingleOrNull();
    return row == null ? null : _toDay(row);
  }

  /// Der offene Tag, sonst ein neuer. Sein Wechselgeld ist, was der letzte
  /// abgeschlossene Tag in der Lade gelassen hat, oder `null` am ersten Tag.
  /// Die einzige Stelle, die einen Tag öffnet.
  Future<BusinessDay> openOrCreateDay() {
    return _db.transaction(() async {
      final open = await openDay();
      if (open != null) return open;
      final last = await lastClosedDay();
      final row = BusinessDayRowsCompanion.insert(
        id: const Uuid().v4(),
        openedAt: _clock.now(),
        openingFloatCents: Value(last?.leftInDrawerCents),
      );
      await _db.into(_db.businessDayRows).insert(row);
      return (await openDay())!;
    });
  }

  /// Wahr, wenn der offene Tag noch kein Wechselgeld hat, und beim allerersten
  /// Start, wenn es noch gar keinen Tag gibt.
  Future<bool> needsOpeningFloat() async {
    final open = await openDay();
    if (open != null) return open.openingFloatCents == null;
    return await lastClosedDay() == null;
  }

  /// Nur am ersten Tag, solange es keinen abgeschlossenen Tag gibt (sonst
  /// [StateError]). Öffnet bei Bedarf den Tag.
  Future<void> setOpeningFloat(int cents) {
    if (cents < 0) throw const InvalidAmountException();
    return _db.transaction(() async {
      if (await lastClosedDay() != null) {
        throw StateError(
          'Das Wechselgeld ergibt sich aus dem letzten Abschluss.',
        );
      }
      final day = await openOrCreateDay();
      await (_db.update(_db.businessDayRows)..where((t) => t.id.equals(day.id)))
          .write(BusinessDayRowsCompanion(openingFloatCents: Value(cents)));
    });
  }

  Future<void> addMovement({
    required CashMovementKind kind,
    required int amountCents,
    required CashReason reason,
    required Staff staff,
  }) {
    if (amountCents <= 0) throw const InvalidAmountException();
    return _db.transaction(() async {
      final day = await openOrCreateDay();
      await _db
          .into(_db.cashMovementRows)
          .insert(
            CashMovementRowsCompanion.insert(
              id: const Uuid().v4(),
              businessDayId: day.id,
              kind: kind.name,
              amountCents: amountCents,
              reason: reason.name,
              createdAt: _clock.now(),
              staffId: staff.id,
              staffName: staff.name,
            ),
          );
    });
  }

  /// Zusammenfassung des offenen Tages, `null` ohne offenen Tag.
  Future<DaySummary?> summary() async {
    final day = await openDay();
    if (day == null) return null;
    return _summarize(day);
  }

  /// Zusammenfassung des zuletzt abgeschlossenen Tages, `null` ohne einen.
  Future<DaySummary?> lastClosedSummary() async {
    final day = await lastClosedDay();
    if (day == null) return null;
    return _summarize(day);
  }

  /// Schließt den offenen Tag. Das Soll ist das der Zusammenfassung.
  Future<BusinessDay> close({
    required int countedCents,
    required int leftInDrawerCents,
    required Staff staff,
  }) {
    return _db.transaction(() async {
      final day = await openDay();
      if (day == null) throw const NoOpenDayException();
      if (countedCents < 0 || leftInDrawerCents < 0) {
        throw const InvalidAmountException();
      }
      if (leftInDrawerCents > countedCents) {
        throw const LeftInDrawerTooHighException();
      }
      final expected = (await _summarize(day)).expectedCashCents;
      await (_db.update(
        _db.businessDayRows,
      )..where((t) => t.id.equals(day.id))).write(
        BusinessDayRowsCompanion(
          closedAt: Value(_clock.now()),
          countedCents: Value(countedCents),
          leftInDrawerCents: Value(leftInDrawerCents),
          expectedCents: Value(expected),
          differenceCents: Value(countedCents - expected),
          closedByName: Value(staff.name),
        ),
      );
      final row = await (_db.select(
        _db.businessDayRows,
      )..where((t) => t.id.equals(day.id))).getSingle();
      return _toDay(row);
    });
  }

  /// Wahr, wenn der offene Tag an einem früheren Kalendertag begann als heute.
  Future<bool> hasForgottenClose() async =>
      isForgottenClose(await openDay(), _clock.now());

  Future<DaySummary> _summarize(BusinessDay day) async {
    // Nur Verkäufe und Storno-Bons zählen, Sonderbelege nicht.
    final receipts =
        await (_db.select(_db.receiptRows)
              ..where((t) => t.businessDayId.equals(day.id))
              ..where(
                (t) => t.kind.isIn([
                  ReceiptKind.sale.name,
                  ReceiptKind.voided.name,
                ]),
              ))
            .get();
    final payments = {
      for (final p in await (_db.select(_db.paymentRows).join([
        innerJoin(
          _db.receiptRows,
          _db.receiptRows.id.equalsExp(_db.paymentRows.receiptId),
        ),
      ])..where(_db.receiptRows.businessDayId.equals(day.id))).get())
        p.readTable(_db.paymentRows).receiptId: p
            .readTable(_db.paymentRows)
            .kind,
    };
    final lines = await (_db.select(_db.receiptLineRows).join([
      innerJoin(
        _db.receiptRows,
        _db.receiptRows.id.equalsExp(_db.receiptLineRows.receiptId),
      ),
    ])..where(_db.receiptRows.businessDayId.equals(day.id))).get();

    var count = 0;
    var cashCount = 0;
    var cardCount = 0;
    var voidCount = 0;
    var voided = 0;
    var revenue = 0;
    var cash = 0;
    var card = 0;
    var deposit = 0;
    for (final r in receipts) {
      final isVoid = r.kind == ReceiptKind.voided.name;
      final step = isVoid ? -1 : 1;
      count += step;
      if (isVoid) {
        voidCount++;
        voided -= r.totalCents;
      }
      revenue += r.totalCents;
      deposit += r.depositCents;
      if (payments[r.id] == PaymentKind.cash.name) {
        cash += r.totalCents;
        cashCount += step;
      } else {
        card += r.totalCents;
        cardCount += step;
      }
    }
    final gross = sumByRate([
      for (final j in lines)
        () {
          final l = j.readTable(_db.receiptLineRows);
          return {
            TaxRate.normal: l.gross20Cents,
            TaxRate.reduced1: l.gross10Cents,
            TaxRate.reduced2: l.gross13Cents,
            TaxRate.zero: l.gross0Cents,
            TaxRate.special: l.gross19Cents,
          };
        }(),
    ]);

    final movementRows =
        await (_db.select(_db.cashMovementRows)
              ..where((t) => t.businessDayId.equals(day.id))
              ..orderBy([
                (t) => OrderingTerm.asc(t.createdAt),
                (t) => OrderingTerm.asc(const CustomExpression<int>('rowid')),
              ]))
            .get();
    final movements = [
      for (final m in movementRows)
        CashMovement(
          id: m.id,
          kind: CashMovementKind.values.byName(m.kind),
          amountCents: m.amountCents,
          reason: CashReason.values.byName(m.reason),
          createdAt: m.createdAt,
          staffName: m.staffName,
        ),
    ];
    int sumOf(CashMovementKind k) => movements
        .where((m) => m.kind == k)
        .fold(0, (s, m) => s + m.amountCents);
    final cashIn = sumOf(CashMovementKind.deposit);
    final cashOut = sumOf(CashMovementKind.withdrawal);
    final float = day.openingFloatCents ?? 0;
    return DaySummary(
      day: day,
      receiptCount: count,
      cashReceiptCount: cashCount,
      cardReceiptCount: cardCount,
      voidCount: voidCount,
      voidedCents: voided,
      revenueCents: revenue,
      cashRevenueCents: cash,
      cardRevenueCents: card,
      depositCents: deposit,
      taxLines: taxBreakdown(gross),
      openingFloatCents: float,
      cashInCents: cashIn,
      cashOutCents: cashOut,
      expectedCashCents: float + cash + cashIn - cashOut,
      movements: movements,
    );
  }

  BusinessDay _toDay(BusinessDayRow r) => BusinessDay(
    id: r.id,
    openedAt: r.openedAt,
    closedAt: r.closedAt,
    openingFloatCents: r.openingFloatCents,
    countedCents: r.countedCents,
    leftInDrawerCents: r.leftInDrawerCents,
    expectedCents: r.expectedCents,
    differenceCents: r.differenceCents,
    closedByName: r.closedByName,
  );
}
