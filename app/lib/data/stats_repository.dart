// Rechnet die Zahlen der Übersicht aus den gespeicherten Bons. Gerechnet wird
// nach Kalendertagen der Gerätezeit, nicht nach Tagesabschluss.

import 'package:drift/drift.dart';

import '../core/clock.dart';
import '../domain/receipt.dart';
import '../domain/stats.dart';
import 'database.dart';

const _otherCategory = 'Sonstiges';
const _depositName = 'Pfand';

/// Die Arten von Bons, die in Umsatz und Anzahl zählen.
final _counted = [ReceiptKind.sale.name, ReceiptKind.voided.name];

class StatsRepository {
  StatsRepository(this._db, this._clock);

  final KassaDatabase _db;
  final Clock _clock;

  Future<Overview> overview(StatsRange range) async {
    final now = _clock.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = switch (range) {
      StatsRange.today => 1,
      StatsRange.days7 => 7,
      StatsRange.days30 => 30,
    };
    final DateTime from;
    final DateTime previousFrom;
    final DateTime previousTo; // einschließlich
    if (range == StatsRange.today) {
      from = today;
      previousFrom = DateTime(now.year, now.month, now.day - 7);
      previousTo = DateTime(
        now.year,
        now.month,
        now.day - 7,
        now.hour,
        now.minute,
        now.second,
        now.millisecond,
        now.microsecond,
      );
    } else {
      from = DateTime(now.year, now.month, now.day - (days - 1));
      previousFrom = DateTime(now.year, now.month, now.day - (2 * days - 1));
      previousTo = from.subtract(const Duration(microseconds: 1));
    }

    final receipts =
        await (_db.select(_db.receiptRows)
              ..where((t) => t.createdAt.isBiggerOrEqualValue(previousFrom))
              ..where((t) => t.createdAt.isSmallerOrEqualValue(now))
              // Sonderbelege zählen nicht.
              ..where((t) => t.kind.isIn(_counted))
              ..orderBy([
                (t) => OrderingTerm.asc(t.createdAt),
                (t) => OrderingTerm.asc(t.number),
              ]))
            .get();
    bool inRange(ReceiptRow r) =>
        !r.createdAt.isBefore(from) && !r.createdAt.isAfter(now);
    final current = [
      for (final r in receipts)
        if (inRange(r)) r,
    ];
    final previousRevenue = receipts
        .where(
          (r) =>
              !r.createdAt.isBefore(previousFrom) &&
              !r.createdAt.isAfter(previousTo),
        )
        .fold(0, (s, r) => s + r.totalCents);

    final ids = {for (final r in current) r.id};
    // Die Zahlungen der Bons im Zeitraum. Bar und Karte kommen aus ihnen,
    // ohne Trinkgeld; ein gemischter Bon trägt zu beiden bei.
    final payments = [
      for (final p in await _db.select(_db.paymentRows).get())
        if (ids.contains(p.receiptId)) p,
    ];
    final lineRows = [
      for (final l in await _db.select(_db.receiptLineRows).get())
        if (ids.contains(l.receiptId)) l,
    ];

    var revenue = 0;
    var count = 0;
    var voids = 0;
    var cash = 0;
    var card = 0;
    var deposit = 0;
    for (final r in current) {
      revenue += r.totalCents;
      deposit += r.depositCents;
      final isVoid = r.kind == ReceiptKind.voided.name;
      count += isVoid ? -1 : 1;
      if (isVoid) voids++;
    }
    for (final p in payments) {
      if (p.kind == PaymentKind.cash.name) {
        cash += p.amountCents;
      } else if (p.kind == PaymentKind.card.name) {
        card += p.amountCents;
      }
    }

    return Overview(
      revenueCents: revenue,
      previousRevenueCents: previousRevenue,
      receiptCount: count,
      voidCount: voids,
      buckets: _buckets(range, today, now, current),
      cashCents: cash,
      cardCents: card,
      topItems: _topItems(current, lineRows),
      byCategory: await _byCategory(lineRows, deposit),
    );
  }

  List<Bucket> _buckets(
    StatsRange range,
    DateTime today,
    DateTime now,
    List<ReceiptRow> rows,
  ) {
    if (range == StatsRange.today) {
      if (rows.isEmpty) return const [];
      final firstHour = rows.first.createdAt.hour; // aufsteigend sortiert
      return [
        for (var h = firstHour; h <= now.hour; h++)
          Bucket(
            label: '$h',
            start: DateTime(now.year, now.month, now.day, h),
            cents: rows
                .where((r) => r.createdAt.hour == h)
                .fold(0, (s, r) => s + r.totalCents),
          ),
      ];
    }
    final days = range == StatsRange.days7 ? 7 : 30;
    return [
      for (var i = days - 1; i >= 0; i--)
        () {
          final d = DateTime(today.year, today.month, today.day - i);
          return Bucket(
            label: '${d.day}.${d.month}.',
            start: d,
            cents: rows
                .where(
                  (r) =>
                      r.createdAt.year == d.year &&
                      r.createdAt.month == d.month &&
                      r.createdAt.day == d.day,
                )
                .fold(0, (s, r) => s + r.totalCents),
          );
        }(),
    ];
  }

  List<ItemStat> _topItems(
    List<ReceiptRow> receipts,
    List<ReceiptLineRow> lines,
  ) {
    // Die Bons sind nach Zeit sortiert: der Name der letzten Zeile gewinnt.
    final order = {for (var i = 0; i < receipts.length; i++) receipts[i].id: i};
    final sorted = [...lines]
      ..sort((a, b) => order[a.receiptId]!.compareTo(order[b.receiptId]!));
    final names = <String, String>{};
    final quantity = <String, int>{};
    final cents = <String, int>{};
    for (final l in sorted) {
      names[l.itemId] = l.name;
      quantity[l.itemId] = (quantity[l.itemId] ?? 0) + l.quantity;
      cents[l.itemId] = (cents[l.itemId] ?? 0) + l.unitPriceCents * l.quantity;
    }
    final stats = [
      for (final id in names.keys)
        if (quantity[id]! > 0)
          ItemStat(
            name: names[id]!,
            quantity: quantity[id]!,
            cents: cents[id]!,
          ),
    ];
    stats.sort((a, b) {
      final q = b.quantity.compareTo(a.quantity);
      if (q != 0) return q;
      final c = b.cents.compareTo(a.cents);
      return c != 0 ? c : a.name.compareTo(b.name);
    });
    return stats.take(5).toList();
  }

  Future<List<CategoryStat>> _byCategory(
    List<ReceiptLineRow> lines,
    int deposit,
  ) async {
    final categoryNames = {
      for (final c in await _db.select(_db.categoryRows).get()) c.id: c.name,
    };
    final itemCategory = {
      for (final i in await _db.select(_db.itemRows).get()) i.id: i.categoryId,
    };
    final sums = <String, int>{};
    for (final l in lines) {
      final name = categoryNames[itemCategory[l.itemId]] ?? _otherCategory;
      sums[name] = (sums[name] ?? 0) + l.unitPriceCents * l.quantity;
    }
    final stats = [
      for (final e in sums.entries)
        if (e.value != 0) CategoryStat(name: e.key, cents: e.value),
    ];
    stats.sort((a, b) {
      final c = b.cents.compareTo(a.cents);
      return c != 0 ? c : a.name.compareTo(b.name);
    });
    if (deposit != 0) {
      stats.add(
        CategoryStat(name: _depositName, cents: deposit, deposit: true),
      );
    }
    return stats;
  }
}
