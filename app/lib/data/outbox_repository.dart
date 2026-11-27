// Die Liste "noch zu senden": was am Tablet entstanden ist und der Server noch
// nicht hat. Bons, Tage, Bewegungen, Berichte und die Signatur trägt die
// Datenbank selbst ein (siehe `KassaDatabase._createOutboxTriggers`); hier
// liegen das Lesen, das Abhaken und die Artikel-Änderungen.

import 'dart:convert';

import 'package:drift/drift.dart';

import 'database.dart';

/// Ein Eintrag der Liste. Der Inhalt eines Bons, Tages usw. steht nicht hier,
/// er wird beim Senden aus den Tabellen gelesen. Nur eine Artikel-Änderung
/// trägt [field], [value] (JSON) und [changedAt].
class OutboxEntry {
  const OutboxEntry({
    required this.id,
    required this.kind,
    required this.ref,
    this.field,
    this.value,
    this.changedAt,
    required this.rev,
  });

  final int id;
  final String kind;
  final String ref;
  final String? field;
  final String? value;
  final DateTime? changedAt;

  /// Hebt sich, wenn sich die Sache ändert, während der Eintrag wartet.
  final int rev;
}

/// Wie viele Einträge warten und wie viele abgelehnt wurden.
class OutboxCounts {
  const OutboxCounts({required this.pending, required this.rejected});

  final int pending;
  final int rejected;
}

/// Arten von Einträgen, die zu einem Bon gehören, und wie ihr `ref` den Bon
/// nennt. Der Server kennt sie nur, wenn er den Bon schon hat (sonst
/// `invalid`, für immer); darum wartet so ein Eintrag, solange der Bon selbst
/// noch in der Liste steht. Weitere Arten kommen hierher.
const _receiptOf = <String, String Function(String ref)>{
  // ref = `<Bon>/<Fassung>`
  'recipient': _beforeSlash,
  // ref = `<Bon>/<Art>` (Belegerteilung, Task 15)
  'delivery': _beforeSlash,
};

String _beforeSlash(String ref) {
  final i = ref.indexOf('/');
  return i < 0 ? ref : ref.substring(0, i);
}

/// Der Bon, auf den [e] wartet, oder `null`, wenn es nicht zu einem Bon
/// gehört.
String? receiptOfEntry(OutboxEntry e) => _receiptOf[e.kind]?.call(e.ref);

class OutboxRepository {
  OutboxRepository(this._db);

  final KassaDatabase _db;

  static const _pending = 'pending';
  static const _rejected = 'rejected';
  static const _itemChange = 'item_change';

  /// Die nächsten wartenden Einträge, älteste zuerst. Abgelehnte kommen nicht
  /// mehr vor.
  Future<List<OutboxEntry>> nextBatch({int limit = 100}) async {
    final rows =
        await (_db.select(_db.outboxRows)
              ..where((t) => t.state.equals(_pending))
              ..orderBy([(t) => OrderingTerm.asc(t.id)])
              ..limit(limit))
            .get();
    return [
      for (final r in rows)
        OutboxEntry(
          id: r.id,
          kind: r.kind,
          ref: r.ref,
          field: r.field,
          value: r.value,
          changedAt: r.changedAt,
          rev: r.rev,
        ),
    ];
  }

  /// Die Bons aus [ids], deren eigener Eintrag `receipt` noch wartet.
  Future<Set<String>> pendingReceipts(Iterable<String> ids) async {
    final wanted = ids.toSet();
    if (wanted.isEmpty) return const {};
    final rows =
        await (_db.select(_db.outboxRows)..where(
              (t) =>
                  t.kind.equals('receipt') &
                  t.state.equals(_pending) &
                  t.ref.isIn(wanted),
            ))
            .get();
    return {for (final r in rows) r.ref};
  }

  /// Nimmt einen gesendeten Eintrag aus der Liste, aber nur, wenn er sich seit
  /// dem Lesen nicht geändert hat ([rev] gleich). Sonst bleibt er und geht
  /// beim nächsten Lauf mit dem neuen Stand noch einmal.
  Future<void> remove(int id, {required int rev}) => (_db.delete(
    _db.outboxRows,
  )..where((t) => t.id.equals(id) & t.rev.equals(rev))).go();

  /// Der Server hat den Eintrag abgelehnt: er bleibt mit [reason] stehen und
  /// wird nicht mehr gesendet.
  Future<void> markRejected(int id, String reason) =>
      (_db.update(_db.outboxRows)..where((t) => t.id.equals(id))).write(
        OutboxRowsCompanion(
          state: const Value(_rejected),
          reason: Value(reason),
        ),
      );

  Stream<OutboxCounts> watchCounts() => _db
      .customSelect(
        'SELECT '
        "COALESCE(SUM(state = '$_pending'), 0) AS pending, "
        "COALESCE(SUM(state = '$_rejected'), 0) AS rejected "
        'FROM outbox',
        // Die Trigger schreiben in `outbox`, ohne dass drift es merkt. Darum
        // wird auch neu gelesen, wenn eine der Tabellen sich ändert, die
        // Einträge nach sich ziehen.
        readsFrom: {
          _db.outboxRows,
          _db.receiptRows,
          _db.businessDayRows,
          _db.cashMovementRows,
          _db.rksvEntryRows,
          _db.rksvCertificateRows,
          _db.rksvChainRows,
          _db.reportRows,
        },
      )
      .watchSingle()
      .map(
        (r) => OutboxCounts(
          pending: r.read<int>('pending'),
          rejected: r.read<int>('rejected'),
        ),
      );

  /// Merkt eine Änderung an einem Artikel. Eine noch wartende ältere
  /// Änderung desselben Feldes fällt weg: je Artikel und Feld bleibt eine mit
  /// dem neuesten Wert und Zeitpunkt. [value] wird als JSON gespeichert
  /// (`1290`, `true`, `["spicy","vegan"]`).
  Future<void> addItemChange({
    required String itemId,
    required String field,
    required Object value,
    required DateTime changedAt,
  }) => _db.transaction(() async {
    await (_db.delete(_db.outboxRows)..where(
          (t) =>
              t.kind.equals(_itemChange) &
              t.ref.equals(itemId) &
              t.field.equals(field) &
              t.state.equals(_pending),
        ))
        .go();
    await _db
        .into(_db.outboxRows)
        .insert(
          OutboxRowsCompanion.insert(
            kind: _itemChange,
            ref: itemId,
            field: Value(field),
            value: Value(jsonEncode(value)),
            changedAt: Value(changedAt),
          ),
        );
  });

  /// Artikel mit noch wartenden Änderungen und deren Felder. Was hier steht,
  /// überschreibt der Abgleich vom Server nicht.
  Future<Map<String, Set<String>>> pendingItemFields() async {
    final rows =
        await (_db.select(_db.outboxRows)..where(
              (t) => t.kind.equals(_itemChange) & t.state.equals(_pending),
            ))
            .get();
    final result = <String, Set<String>>{};
    for (final r in rows) {
      final field = r.field;
      if (field != null) (result[r.ref] ??= {}).add(field);
    }
    return result;
  }

  /// Wirft alle Artikel-Änderungen weg (zum Beispiel beim Koppeln an einen
  /// anderen Betrieb). Andere Arten bleiben.
  Future<void> clearItemChanges() => (_db.delete(
    _db.outboxRows,
  )..where((t) => t.kind.equals(_itemChange))).go();
}
