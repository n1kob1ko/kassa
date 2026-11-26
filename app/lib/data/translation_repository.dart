// Speichert das Wörterbuch der Speisekarte (Tabelle `translations`).

import 'dart:convert';

import '../domain/menu_dictionary.dart';
import 'database.dart';

class TranslationRepository {
  TranslationRepository(this._db);

  final KassaDatabase _db;

  /// Meldet das Wörterbuch bei jeder Änderung der Tabelle (drifts eigenes
  /// `watch`, damit zwischen Lesen und Abonnieren nichts verloren geht).
  Stream<MenuDictionary> watch() =>
      _db.select(_db.translationRows).watch().map(_toDictionary);

  Future<MenuDictionary> current() async =>
      _toDictionary(await _db.select(_db.translationRows).get());

  /// Liest tolerant: eine Zeile, die kein JSON-Objekt hält, und ein Wert, der
  /// kein Text ist, fallen weg. Der Name aus der Speisekarte gilt dann.
  static MenuDictionary _toDictionary(List<TranslationRow> rows) {
    final entries = <String, Map<String, String>>{};
    for (final r in rows) {
      final Object? decoded;
      try {
        decoded = jsonDecode(r.valuesJson);
      } on FormatException {
        continue;
      }
      if (decoded is! Map<String, dynamic>) continue;
      final values = {
        for (final e in decoded.entries)
          if (e.value case final String text) e.key: text,
      };
      if (values.isNotEmpty) entries[r.source] = values;
    }
    return MenuDictionary(entries);
  }

  /// Schreibt Einträge; ein Eintrag ohne Sprachen löscht die Zeile.
  Future<void> upsert(Map<String, Map<String, String>> entries) =>
      _db.transaction(() => upsertIn(_db, entries));

  Future<void> clear() => _db.delete(_db.translationRows).go();
}

/// Wie [TranslationRepository.upsert], aber in einer laufenden Transaktion.
/// Die Zeile einer Quelle wird ganz durch [entries] ersetzt (kein Mischen mit
/// dem, was dort stand); der Abgleich mit dem Server braucht genau das.
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
