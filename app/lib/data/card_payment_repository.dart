// Offene Kartenzahlungen: stehen in der Datenbank, bevor das Terminal etwas
// erfährt, und bleiben über einen Neustart erhalten.

import 'dart:convert';

import 'package:drift/drift.dart';

import '../core/clock.dart';
import '../domain/cart.dart';
import '../domain/staff.dart';
import 'database.dart';

class PendingCardPayment {
  const PendingCardPayment({
    required this.id,
    required this.cartJson,
    required this.amountCents,
    required this.staffId,
    required this.staffName,
    required this.startedAt,
    required this.unknown,
  });

  final String id;

  /// Der Bon als JSON (`Cart.toJson`), damit er wieder aufgebaut werden kann.
  final String cartJson;
  final int amountCents;
  final String staffId;
  final String staffName;
  final DateTime startedAt;

  /// Ob der Ausgang unklar ist (nicht mehr "läuft").
  final bool unknown;
}

class CardPaymentRepository {
  CardPaymentRepository(this._db, this._clock);

  final KassaDatabase _db;
  final Clock _clock;

  Future<void> begin({
    required String paymentId,
    required Cart cart,
    required Staff staff,
  }) => _db
      .into(_db.pendingCardPaymentRows)
      .insertOnConflictUpdate(
        PendingCardPaymentRowsCompanion.insert(
          id: paymentId,
          cartJson: jsonEncode(cart.toJson()),
          amountCents: cart.totalCents,
          staffId: staff.id,
          staffName: staff.name,
          startedAt: _clock.now(),
          state: _started,
        ),
      );

  Future<void> markUnknown(String paymentId) =>
      (_db.update(_db.pendingCardPaymentRows)
            ..where((t) => t.id.equals(paymentId)))
          .write(const PendingCardPaymentRowsCompanion(state: Value(_unknown)));

  Future<void> discard(String paymentId) => (_db.delete(
    _db.pendingCardPaymentRows,
  )..where((t) => t.id.equals(paymentId))).go();

  Future<List<PendingCardPayment>> pending() async => _query().get().then(_map);

  Stream<List<PendingCardPayment>> watchPending() => _query().watch().map(_map);

  SimpleSelectStatement<$PendingCardPaymentRowsTable, PendingCardPaymentRow>
  _query() =>
      _db.select(_db.pendingCardPaymentRows)
        ..orderBy([(t) => OrderingTerm.asc(t.startedAt)]);

  List<PendingCardPayment> _map(List<PendingCardPaymentRow> rows) => [
    for (final r in rows)
      PendingCardPayment(
        id: r.id,
        cartJson: r.cartJson,
        amountCents: r.amountCents,
        staffId: r.staffId,
        staffName: r.staffName,
        startedAt: r.startedAt,
        unknown: r.state == _unknown,
      ),
  ];

  static const _started = 'started';
  static const _unknown = 'unknown';
}
