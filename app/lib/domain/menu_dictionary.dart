// Wörterbuch der Speisekarte: Übersetzungen der Namen, geschlüsselt nach dem
// deutschen Namen aus der Speisekarte. Reines Dart.

import '../core/app_language.dart';

/// Sprachen, für die es Übersetzungen gibt (Deutsch ist der Name selbst).
const translationLanguages = ['en', 'zh', 'tr', 'ar'];

class MenuDictionary {
  const MenuDictionary(this.entries);

  static const empty = MenuDictionary({});

  /// Name aus der Speisekarte -> Sprachkürzel -> Text.
  final Map<String, Map<String, String>> entries;

  /// Name in [language]; für Deutsch, ohne Treffer oder bei leerem Text: [source].
  String text(String source, AppLanguage language) {
    if (language == AppLanguage.de) return source;
    final translated = entries[source.trim()]?[language.name];
    if (translated == null || translated.trim().isEmpty) return source;
    return translated;
  }

  /// Wie [text]; ein fehlender Name bleibt fehlend.
  String? textOrNull(String? source, AppLanguage language) =>
      source == null ? null : text(source, language);
}
