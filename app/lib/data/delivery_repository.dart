// Die Belegerteilung (Spec 5.4): wie der Beleg zu einem Bon erteilt wurde,
// "gedruckt" oder "digital angeboten". Je Bon und Art ein Eintrag mit Zeit,
// nur anfügen; der Bon selbst bleibt unverändert. Jeder neue Eintrag geht als
// `delivery` zum Server.

import 'package:drift/drift.dart';

import 'database.dart';

/// `printed`: der Kundenbon ist das erste Mal ohne Fehler gedruckt.
/// `digital`: der QR-Code seiner Seite wurde das erste Mal gezeigt.
enum DeliveryKind { printed, digital }

class ReceiptDelivery {
  const ReceiptDelivery({
    required this.receiptId,
    required this.kind,
    required this.at,
  });

  final String receiptId;
  final DeliveryKind kind;
  final DateTime at;
}

class DeliveryRepository {
  DeliveryRepository(this._db);

  final KassaDatabase _db;

  /// Hält fest, dass der Beleg zu [receiptId] als [kind] erteilt wurde, und
  /// stellt den Eintrag `delivery` (ref `<Bon>/<Art>`) in "noch zu senden",
  /// beides in einer Transaktion. Gibt es diese Art zum Bon schon, ändert
  /// sich nichts: die erste Zeit bleibt, kein neuer Eintrag.
  Future<void> record(
    String receiptId,
    DeliveryKind kind, {
    required DateTime at,
  }) => _db.transaction(() async {
    final known =
        await (_db.select(_db.receiptDeliveryRows)..where(
              (t) => t.receiptId.equals(receiptId) & t.kind.equals(kind.name),
            ))
            .getSingleOrNull();
    if (known != null) return;
    await _db
        .into(_db.receiptDeliveryRows)
        .insert(
          ReceiptDeliveryRowsCompanion.insert(
            receiptId: receiptId,
            kind: kind.name,
            at: at,
          ),
        );
    await _db
        .into(_db.outboxRows)
        .insert(
          OutboxRowsCompanion.insert(
            kind: 'delivery',
            ref: '$receiptId/${kind.name}',
          ),
          mode: InsertMode.insertOrIgnore,
        );
  });

  /// Die Einträge zu [receiptId], gedruckt vor digital.
  Future<List<ReceiptDelivery>> of(String receiptId) =>
      _of(receiptId).get().then(_sorted);

  /// Wie [of], als Strom: liefert neu, sobald ein Eintrag dazukommt.
  Stream<List<ReceiptDelivery>> watch(String receiptId) =>
      _of(receiptId).watch().map(_sorted);

  static List<ReceiptDelivery> _sorted(List<ReceiptDelivery> list) =>
      [...list]..sort((a, b) => a.kind.index.compareTo(b.kind.index));

  Selectable<ReceiptDelivery> _of(String receiptId) =>
      (_db.select(_db.receiptDeliveryRows)
            ..where((t) => t.receiptId.equals(receiptId)))
          .map(
            (r) => ReceiptDelivery(
              receiptId: r.receiptId,
              kind: DeliveryKind.values.byName(r.kind),
              at: r.at,
            ),
          );
}
