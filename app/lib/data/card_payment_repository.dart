// Offene Kartenzahlungen: stehen in der Datenbank, bevor das Terminal etwas
// erfährt, und bleiben über einen Neustart erhalten.

import 'dart:convert';

import 'package:drift/drift.dart';

import '../core/clock.dart';
import '../domain/cart.dart';
import '../domain/staff.dart';
import 'database.dart';

/// Was das Terminal bucht: was nach den Gutscheinen offen ist [totalCents]
/// (`cart.pricing.dueCents`; ohne Gutschein die Summe des Bons) ohne den
/// Bar-Teil [cashPartCents], dazu das Trinkgeld [tipCents]. Die eine Rechnung
/// für das Schreiben der offenen Zahlung, den Aufruf des Terminals und die
/// Prüfung beim Wiederaufbau.
int terminalAmountCents({
  required int totalCents,
  required int cashPartCents,
  required int tipCents,
}) => totalCents - cashPartCents + tipCents;

class PendingCardPayment {
  const PendingCardPayment({
    required this.id,
    required this.cartJson,
    required this.amountCents,
    required this.staffId,
    required this.staffName,
    required this.startedAt,
    required this.unknown,
    this.cashPartCents = 0,
    this.tipCents = 0,
  });

  final String id;

  /// Der Bon als JSON (`Cart.toJson`, mit den gewählten Gutscheinen), damit
  /// er wieder aufgebaut werden kann.
  final String cartJson;

  /// Was das Terminal bucht: die Summe des Bons ohne [cashPartCents], mit
  /// [tipCents].
  final int amountCents;
  final String staffId;
  final String staffName;
  final DateTime startedAt;

  /// Ob der Ausgang unklar ist (nicht mehr "läuft").
  final bool unknown;

  /// Der Teil des Bons, der bar bezahlt wird (0 ohne). Eine Zahlung aus
  /// 1.10.0 hat hier 0.
  final int cashPartCents;

  /// Das Trinkgeld auf der Karte (0 ohne); es gehört der Person [staffName].
  final int tipCents;
}

class CardPaymentRepository {
  CardPaymentRepository(this._db, this._clock);

  final KassaDatabase _db;
  final Clock _clock;

  /// Schreibt die offene Zahlung mit dem Bar-Teil [cashPartCents] und dem
  /// Trinkgeld [tipCents]; das Terminal bucht, was nach den Gutscheinen offen
  /// ist, ohne Bar-Teil, mit Trinkgeld. Eine Zeile mit dieser Id wird nie überschrieben: gibt es sie
  /// schon, wirft der Aufruf.
  Future<void> begin({
    required String paymentId,
    required Cart cart,
    required Staff staff,
    int cashPartCents = 0,
    int tipCents = 0,
  }) => _db
      .into(_db.pendingCardPaymentRows)
      .insert(
        PendingCardPaymentRowsCompanion.insert(
          id: paymentId,
          cartJson: jsonEncode(cart.toJson()),
          amountCents: terminalAmountCents(
            totalCents: cart.pricing.dueCents,
            cashPartCents: cashPartCents,
            tipCents: tipCents,
          ),
          staffId: staff.id,
          staffName: staff.name,
          startedAt: _clock.now(),
          state: _started,
          cashPartCents: Value(cashPartCents),
          tipCents: Value(tipCents),
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
        cashPartCents: r.cashPartCents,
        tipCents: r.tipCents,
      ),
  ];

  static const _started = 'started';
  static const _unknown = 'unknown';
}
