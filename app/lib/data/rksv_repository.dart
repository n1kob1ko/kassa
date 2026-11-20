// Liest den Stand der Signatur und beobachtet ihn. Erledigt Aufgaben und
// löscht den Hinweis. Einträge, Ketten und Zähler schreibt das Journal.

import 'package:drift/drift.dart';

import '../core/enums.dart';
import '../rksv/rksv_state.dart';
import 'database.dart';

class RksvRepository {
  RksvRepository(this._db);

  final KassaDatabase _db;

  Future<RksvState> current() async =>
      _toState(await _query().getSingleOrNull());

  /// Gibt zuerst den aktuellen Stand und danach nach jeder Änderung des
  /// Stands oder der Ketten den neuen.
  Stream<RksvState> watch() => _query().watchSingleOrNull().map(_toState);

  /// true, sobald es eine beendete Kette gibt (`ended_at` gesetzt): Dann
  /// bleibt "Protokoll ausgeben" auch ohne laufende Signatur. Meldet nur
  /// Änderungen des Werts.
  Stream<bool> watchHasEndedChain() =>
      (_db.select(_db.rksvChainRows)
            ..where((t) => t.endedAt.isNotNull())
            ..limit(1))
          .watch()
          .map((rows) => rows.isNotEmpty)
          .distinct();

  /// Entfernt die Aufgabe mit [id]. Eine unbekannte Id ändert nichts.
  Future<void> completeTask(String id) => _db.transaction(() async {
    final row = await (_db.select(
      _db.rksvStateRows,
    )..where((t) => t.id.equals(1))).getSingleOrNull();
    if (row == null) return;
    final tasks = decodeRksvTasks(row.tasks);
    final rest = [
      for (final t in tasks)
        if (t.id != id) t,
    ];
    if (rest.length == tasks.length) return;
    await _writeState(
      RksvStateRowsCompanion(tasks: Value(encodeRksvTasks(rest))),
    );
  });

  Future<void> clearNotice() =>
      _writeState(const RksvStateRowsCompanion(notice: Value(null)));

  Future<void> _writeState(RksvStateRowsCompanion c) =>
      (_db.update(_db.rksvStateRows)..where((t) => t.id.equals(1))).write(c);

  /// Die Kette mit der höchsten Nummer, für "Außer Betrieb" (Q8).
  late final _latest = _db.alias(_db.rksvChainRows, 'latest');

  /// Stand, laufende Kette und jüngste Kette.
  JoinedSelectStatement<HasResultSet, dynamic> _query() {
    final highest = _db.rksvChainRows.chain.max();
    return _db.select(_db.rksvStateRows).join([
      leftOuterJoin(
        _db.rksvChainRows,
        _db.rksvChainRows.chain.equalsExp(_db.rksvStateRows.chain),
      ),
      leftOuterJoin(
        _latest,
        _latest.chain.equalsExp(
          subqueryExpression<int>(
            _db.selectOnly(_db.rksvChainRows)..addColumns([highest]),
          ),
        ),
      ),
    ])..where(_db.rksvStateRows.id.equals(1));
  }

  RksvState _toState(TypedResult? result) {
    if (result == null) return const RksvState();
    final r = result.readTable(_db.rksvStateRows);
    final chain = result.readTableOrNull(_db.rksvChainRows);
    final latest = result.readTableOrNull(_latest);
    final mode = enumByNameOr(RksvMode.values, r.mode, RksvMode.off);
    return RksvState(
      mode: mode,
      chain: r.chain,
      cashBoxId: chain?.cashBoxId,
      chainStartedAt: chain?.startedAt,
      // Ein unbekannter Wert darf das Beobachten nicht abbrechen; signieren
      // lässt sich damit nicht (signatureUnitOf wirft).
      unit: chain == null ? null : RksvUnit.values.asNameMap()[chain.unit],
      counterCents: r.counterCents,
      outageSince: r.outageSince,
      outageReason: r.outageReason,
      tasks: decodeRksvTasks(r.tasks),
      notice: r.notice,
      decommissioned:
          mode == RksvMode.off &&
          latest != null &&
          latest.mode == RksvMode.live.name &&
          latest.endedAt != null,
    );
  }
}
