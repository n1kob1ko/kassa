// Liest Gutscheine und ihre Bewegungen (Spec 5.5). Geschrieben werden beide
// mit einem Bon, im selben Schritt (`ReceiptRepository`), oder vom Server
// ([VoucherRepository.mergeFromServer]).

import 'package:drift/drift.dart';

import '../domain/voucher.dart';
import '../sync/wire.dart';
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

  /// Übernimmt Gutscheine und Bewegungen vom Server, ohne Eintrag in "noch
  /// zu senden": fügt an, was die Kassa noch nicht kennt (Gutschein nach
  /// Kennung, Bewegung nach Gutschein und Bon), und ändert nichts
  /// Vorhandenes. Dieselbe Seite noch einmal ändert nichts. Eine Bewegung,
  /// deren Gutschein die Kassa noch nicht kennt, bleibt trotzdem: das
  /// Guthaben stimmt, sobald der Gutschein kommt. `true`, wenn etwas Neues
  /// dabei war. Läuft in der Transaktion des Aufrufers.
  Future<bool> mergeFromServer(
    List<WireVoucher> vouchers,
    List<WireVoucherMovement> movements,
  ) async {
    var added = false;
    final knownVouchers = vouchers.isEmpty
        ? const <String>{}
        : {
            for (final r
                in await (_db.selectOnly(_db.voucherRows)
                      ..addColumns([_db.voucherRows.id])
                      ..where(
                        _db.voucherRows.id.isIn([
                          for (final v in vouchers) v.id,
                        ]),
                      ))
                    .get())
              r.read(_db.voucherRows.id)!,
          };
    for (final v in vouchers) {
      if (!knownVouchers.add(v.id)) continue;
      await _db
          .into(_db.voucherRows)
          .insert(
            VoucherRowsCompanion.insert(
              id: v.id,
              code: v.code,
              valueCents: v.valueCents,
              createdAt: v.createdAt,
              soldReceiptId: Value(v.soldReceiptId),
              isTest: v.isTest,
            ),
          );
      added = true;
    }
    final t = _db.voucherMovementRows;
    final knownMovements = movements.isEmpty
        ? const <(String, String)>{}
        : {
            for (final r
                in await (_db.selectOnly(t)
                      ..addColumns([t.voucherId, t.receiptId])
                      ..where(
                        t.voucherId.isIn({
                          for (final m in movements) m.voucherId,
                        }),
                      ))
                    .get())
              (r.read(t.voucherId)!, r.read(t.receiptId)!),
          };
    for (final m in movements) {
      if (!knownMovements.add((m.voucherId, m.receiptId))) continue;
      await _db
          .into(t)
          .insert(
            VoucherMovementRowsCompanion.insert(
              voucherId: m.voucherId,
              receiptId: m.receiptId,
              kind: m.kind,
              amountCents: m.amountCents,
              createdAt: m.createdAt,
            ),
          );
      added = true;
    }
    return added;
  }

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
