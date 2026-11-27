// Liest Gutscheine und ihre Bewegungen (Spec 5.5). Geschrieben werden beide
// nur mit einem Bon, im selben Schritt (`ReceiptRepository`).

import 'package:drift/drift.dart';

import '../domain/voucher.dart';
import 'database.dart';

class VoucherRepository {
  VoucherRepository(this._db);

  final KassaDatabase _db;

  /// Die Gutscheine mit diesem Code: keiner, einer oder mehrere (zwei Kassen
  /// können ohne Abgleich denselben Code vergeben haben).
  Future<List<Voucher>> findByCode(String code) async => _hydrate(
    await (_db.select(_db.voucherRows)
          ..where((t) => t.code.equals(code))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get(),
  );

  /// Der Gutschein mit dieser Kennung, sonst `null`.
  Future<Voucher?> byId(String id) async {
    final rows = await (_db.select(
      _db.voucherRows,
    )..where((t) => t.id.equals(id))).get();
    final vouchers = await _hydrate(rows);
    return vouchers.isEmpty ? null : vouchers.single;
  }

  /// Das Guthaben: die Summe aller Bewegungen, 0 ohne Bewegung.
  Future<int> balanceOf(String voucherId) async {
    final sum = _db.voucherMovementRows.amountCents.sum();
    final total =
        await (_db.selectOnly(_db.voucherMovementRows)
              ..addColumns([sum])
              ..where(_db.voucherMovementRows.voucherId.equals(voucherId)))
            .map((r) => r.read(sum))
            .getSingle();
    return total ?? 0;
  }

  /// Die Gutscheine, die auf dem Bon [receiptId] verkauft wurden, nach ihrer
  /// Zeile.
  Future<List<Voucher>> soldOn(String receiptId) async => _hydrate(
    await (_db.select(_db.voucherRows)
          ..where((t) => t.soldReceiptId.equals(receiptId))
          ..orderBy([(t) => OrderingTerm.asc(t.soldLinePosition)]))
        .get(),
  );

  Future<List<Voucher>> _hydrate(List<VoucherRow> rows) async {
    if (rows.isEmpty) return const [];
    final movementsOf = <String, List<VoucherMovement>>{};
    // Nach der Zeit, bei gleicher Zeit in der Reihenfolge des Schreibens.
    for (final m
        in await (_db.select(_db.voucherMovementRows)
              ..where((t) => t.voucherId.isIn([for (final r in rows) r.id]))
              ..orderBy([
                (t) => OrderingTerm.asc(t.createdAt),
                (_) => OrderingTerm.asc(const CustomExpression<int>('rowid')),
              ]))
            .get()) {
      (movementsOf[m.voucherId] ??= []).add(
        VoucherMovement(
          voucherId: m.voucherId,
          receiptId: m.receiptId,
          kind: VoucherMovementKind.fromDb(m.kind),
          amountCents: m.amountCents,
          createdAt: m.createdAt,
        ),
      );
    }
    return [
      for (final r in rows)
        Voucher(
          id: r.id,
          code: r.code,
          valueCents: r.valueCents,
          createdAt: r.createdAt,
          isTest: r.isTest,
          soldReceiptId: r.soldReceiptId,
          movements: List.unmodifiable(movementsOf[r.id] ?? const []),
        ),
    ];
  }
}
