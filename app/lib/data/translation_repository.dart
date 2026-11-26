// Speichert das Wörterbuch der Speisekarte (Tabelle `translations`).

import 'dart:convert';

import 'package:drift/drift.dart';

import '../domain/menu_dictionary.dart';
import 'database.dart';

class TranslationRepository {
  TranslationRepository(this._db);

  final KassaDatabase _db;

  Stream<MenuDictionary> watch() async* {
    yield await current();
    await for (final _ in _db.tableUpdates(
      TableUpdateQuery.onTable(_db.translationRows),
    )) {
      yield await current();
    }
  }

  Future<MenuDictionary> current() async {
    final rows = await _db.select(_db.translationRows).get();
    return MenuDictionary({
      for (final r in rows)
        r.source: {
          for (final e
              in (jsonDecode(r.valuesJson) as Map<String, dynamic>).entries)
            e.key: e.value as String,
        },
    });
  }

  /// Schreibt Einträge; ein Eintrag ohne Sprachen löscht die Zeile.
  Future<void> upsert(Map<String, Map<String, String>> entries) =>
      _db.transaction(() => upsertIn(_db, entries));

  Future<void> clear() => _db.delete(_db.translationRows).go();
}

/// Wie [TranslationRepository.upsert], aber in einer laufenden Transaktion.
Future<void> upsertIn(
  KassaDatabase db,
  Map<String, Map<String, String>> entries,
) async {
  for (final e in entries.entries) {
    if (e.value.isEmpty) {
      await (db.delete(
        db.translationRows,
      )..where((t) => t.source.equals(e.key))).go();
    } else {
      await db
          .into(db.translationRows)
          .insertOnConflictUpdate(
            TranslationRowsCompanion.insert(
              source: e.key,
              valuesJson: jsonEncode(e.value),
            ),
          );
    }
  }
}
