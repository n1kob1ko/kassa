// Stand des Abgleichs mit dem Server: wer die Kassa ist, bis wohin eingespielt
// ist und wie der letzte Versuch ausging. Der Geräte-Schlüssel gehört nicht
// hierher, er liegt im `TokenStore`.

import 'package:drift/drift.dart';

import 'database.dart';

class SyncState {
  const SyncState({
    this.registerId,
    this.registerName,
    this.businessId,
    this.pullCursor = 0,
    this.initialPullDone = false,
    this.lastPullAt,
    this.lastError,
    this.blocked = false,
  });

  final String? registerId;
  final String? registerName;
  final String? businessId;
  final int pullCursor;
  final bool initialPullDone;

  /// Wann der letzte erfolgreiche Abgleich war.
  final DateTime? lastPullAt;
  final String? lastError;
  final bool blocked;

  /// Die Kassa hat einen Platz beim Server.
  bool get hasRegister => registerId != null;

  /// Gekoppelt und die Daten des Betriebs sind da.
  bool get paired => hasRegister && initialPullDone;
}

class SyncStateRepository {
  SyncStateRepository(this._db);

  final KassaDatabase _db;

  Future<SyncState> current() async => _toState(await _row());

  /// Gibt zuerst den aktuellen Stand und danach nach jeder Änderung den neuen.
  Stream<SyncState> watch() => (_db.select(
    _db.syncStateRows,
  )..where((t) => t.id.equals(1))).watchSingleOrNull().map(_toState);

  /// Merkt sich die Kassa nach dem Koppeln. Der Abgleich beginnt von vorn:
  /// Cursor und `initialPullDone` schreibt danach nur der Abgleich selbst,
  /// zusammen mit den Daten.
  Future<void> saveRegister({
    required String registerId,
    required String registerName,
    required String businessId,
  }) => _db
      .into(_db.syncStateRows)
      .insertOnConflictUpdate(
        SyncStateRowsCompanion(
          id: const Value(1),
          registerId: Value(registerId),
          registerName: Value(registerName),
          businessId: Value(businessId),
          pullCursor: const Value(0),
          initialPullDone: const Value(false),
          blocked: const Value(false),
        ),
      );

  /// Hält das Ergebnis eines Versuchs fest. `lastError` wird immer
  /// geschrieben (`null` löscht ihn), `blocked` nur, wenn es angegeben ist,
  /// und `lastPullAt` rückt nur bei Erfolg (`error == null`) auf [at]: die
  /// Anzeige "Zuletzt abgeglichen" darf bei einem Fehler nicht weiterrücken.
  Future<void> setResult({
    required DateTime at,
    String? error,
    bool? blocked,
  }) => _db
      .into(_db.syncStateRows)
      .insertOnConflictUpdate(
        SyncStateRowsCompanion(
          id: const Value(1),
          lastError: Value(error),
          blocked: blocked == null ? const Value.absent() : Value(blocked),
          lastPullAt: error == null ? Value(at) : const Value.absent(),
        ),
      );

  Future<SyncStateRow?> _row() => (_db.select(
    _db.syncStateRows,
  )..where((t) => t.id.equals(1))).getSingleOrNull();

  SyncState _toState(SyncStateRow? r) => r == null
      ? const SyncState()
      : SyncState(
          registerId: r.registerId,
          registerName: r.registerName,
          businessId: r.businessId,
          pullCursor: r.pullCursor,
          initialPullDone: r.initialPullDone,
          lastPullAt: r.lastPullAt,
          lastError: r.lastError,
          blocked: r.blocked,
        );
}
