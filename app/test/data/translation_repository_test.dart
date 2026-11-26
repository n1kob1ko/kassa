import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/core/app_language.dart';
import 'package:kassa/data/database.dart';
import 'package:kassa/data/translation_repository.dart';

void main() {
  late KassaDatabase db;
  late TranslationRepository repo;

  setUp(() {
    db = KassaDatabase(NativeDatabase.memory());
    repo = TranslationRepository(db);
  });
  tearDown(() => db.close());

  test('leer am Anfang', () async {
    expect((await repo.current()).entries, isEmpty);
  });

  test('upsert schreibt und current liest', () async {
    await repo.upsert({
      'Cola': {'en': 'Cola', 'tr': 'Kola'},
      'Huhn Bowl': {'en': 'Chicken bowl'},
    });
    final d = await repo.current();
    expect(d.text('Cola', AppLanguage.tr), 'Kola');
    expect(d.text('Huhn Bowl', AppLanguage.en), 'Chicken bowl');
  });

  test('upsert ersetzt den Eintrag je Name', () async {
    await repo.upsert({
      'Cola': {'en': 'Cola', 'tr': 'Kola'},
    });
    await repo.upsert({
      'Cola': {'en': 'Soda'},
    });
    expect((await repo.current()).entries, {
      'Cola': {'en': 'Soda'},
    });
  });

  test('ein Eintrag ohne Sprachen löscht die Zeile', () async {
    await repo.upsert({
      'Cola': {'en': 'Cola'},
      'Wasser': {'en': 'Water'},
    });
    await repo.upsert({'Cola': {}});
    expect((await repo.current()).entries.keys, ['Wasser']);
    expect(await db.select(db.translationRows).get(), hasLength(1));
  });

  test('clear löscht alles', () async {
    await repo.upsert({
      'Cola': {'en': 'Cola'},
    });
    await repo.clear();
    expect((await repo.current()).entries, isEmpty);
  });

  test('watch meldet nach upsert', () async {
    final emitted = expectLater(
      repo.watch().map((d) => d.entries),
      emitsInOrder([
        isEmpty,
        {
          'Cola': {'en': 'Cola'},
        },
      ]),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await repo.upsert({
      'Cola': {'en': 'Cola'},
    });
    await emitted;
  });

  test('watch verpasst keinen Schreibvorgang vor dem ersten Lesen', () async {
    final values = <Map<String, Map<String, String>>>[];
    final sub = repo.watch().listen((d) => values.add(d.entries));
    // Kein Warten: das Schreiben läuft, bevor der erste Wert angekommen ist.
    await repo.upsert({
      'Cola': {'en': 'Cola'},
    });
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await sub.cancel();
    expect(values.last, {
      'Cola': {'en': 'Cola'},
    });
  });

  test('current liest tolerant: kaputte Zeilen und Werte fallen weg', () async {
    Future<void> raw(String source, String json) => db
        .into(db.translationRows)
        .insert(
          TranslationRowsCompanion.insert(source: source, valuesJson: json),
        );
    await raw('Gut', '{"en":"Good"}');
    await raw('Zahl', '{"en":3,"tr":"Kola"}');
    await raw('Liste', '["en"]');
    await raw('Kaputt', 'kein json');
    await raw('Nur Zahl', '{"en":null}');
    final d = await repo.current();
    expect(d.entries, {
      'Gut': {'en': 'Good'},
      'Zahl': {'tr': 'Kola'},
    });
    expect(d.text('Zahl', AppLanguage.en), 'Zahl');
    expect(d.text('Kaputt', AppLanguage.en), 'Kaputt');
  });
}
