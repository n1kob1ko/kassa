// Spielt eine Seite eines FakeServer über den echten Weg des Abgleichs ein
// (`ServerChanges.applyPage` aus `serverChangesProvider`), auch an einer
// Kassa, die nie gekoppelt wurde: die Kassa gilt danach als gekoppelt und
// fertig geladen. Ohne Erwartungen.

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kassa/data/database.dart';
import 'package:kassa/data/providers.dart';
import 'package:kassa/data/sync_state_repository.dart';

import 'fake_server.dart';

/// Alle Seiten von [server] ab dem Cursor der Kassa. `false`, wenn eine
/// Seite nicht passte.
Future<bool> pullFrom(ProviderContainer c, FakeServer server) async {
  final db = c.read(databaseProvider);
  final sync = SyncStateRepository(db);
  final state = await sync.current();
  if (!state.paired) {
    await sync.saveRegister(
      registerId: FakeServer.registerId,
      registerName: 'Kassa 1',
      businessId: FakeServer.businessId,
    );
    await (db.update(db.syncStateRows)..where((t) => t.id.equals(1))).write(
      const SyncStateRowsCompanion(initialPullDone: Value(true)),
    );
  }
  while (true) {
    final cursor = (await sync.current()).pullCursor;
    final page = server.page(cursor);
    final ok = await c
        .read(serverChangesProvider)
        .applyPage(
          page,
          at: DateTime(2026, 11, 17, 12),
          since: cursor,
          registerId: FakeServer.registerId,
        );
    if (!ok) return false;
    if (!page.more) return true;
  }
}
