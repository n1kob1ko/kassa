import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/core/app_language.dart';
import 'package:kassa/domain/menu_dictionary.dart';

void main() {
  const dictionary = MenuDictionary({
    'Huhn Bowl': {'en': 'Chicken bowl', 'tr': '', 'zh': '  '},
  });

  test('Treffer in der Sprache', () {
    expect(dictionary.text('Huhn Bowl', AppLanguage.en), 'Chicken bowl');
  });

  test('Deutsch bleibt der Name aus der Speisekarte', () {
    expect(dictionary.text('Huhn Bowl', AppLanguage.de), 'Huhn Bowl');
  });

  test('kein Treffer: Name aus der Speisekarte', () {
    expect(dictionary.text('Cola', AppLanguage.en), 'Cola');
    expect(dictionary.text('Huhn Bowl', AppLanguage.ar), 'Huhn Bowl');
  });

  test('leerer Text: Name aus der Speisekarte', () {
    expect(dictionary.text('Huhn Bowl', AppLanguage.tr), 'Huhn Bowl');
    expect(dictionary.text('Huhn Bowl', AppLanguage.zh), 'Huhn Bowl');
  });

  test('Leerzeichen am Rand der Quelle zählen nicht', () {
    expect(dictionary.text('  Huhn Bowl ', AppLanguage.en), 'Chicken bowl');
    expect(dictionary.text('  Cola ', AppLanguage.en), '  Cola ');
  });

  test('leeres Wörterbuch', () {
    expect(MenuDictionary.empty.text('Cola', AppLanguage.zh), 'Cola');
  });

  test('textOrNull: null bleibt null', () {
    expect(dictionary.textOrNull(null, AppLanguage.en), isNull);
    expect(dictionary.textOrNull('Huhn Bowl', AppLanguage.en), 'Chicken bowl');
    expect(dictionary.textOrNull('Cola', AppLanguage.en), 'Cola');
  });

  test('die Sprachen mit Übersetzung', () {
    expect(translationLanguages, ['en', 'zh', 'tr', 'ar']);
  });
}
