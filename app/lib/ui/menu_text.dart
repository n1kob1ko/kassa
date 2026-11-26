// Namen der Speisekarte am Bildschirm in der Bediensprache.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app.dart' show appLanguageProvider;
import '../core/app_language.dart';
import '../data/providers.dart';
import '../domain/menu_dictionary.dart';

/// Schlägt Namen der Speisekarte in der Bediensprache nach. Ohne Treffer, auf
/// Deutsch und solange das Wörterbuch noch nicht gelesen ist: der Name aus der
/// Speisekarte. Nur für die Anzeige; gespeichert und gedruckt wird immer der
/// Name aus der Speisekarte.
final menuTextProvider = Provider<String Function(String source)>((ref) {
  final language = ref.watch(appLanguageProvider);
  // Deutsch ist die Sprache der Speisekarte: kein Blick ins Wörterbuch.
  if (language == AppLanguage.de) return (source) => source;
  final dictionary =
      ref.watch(menuDictionaryProvider).value ?? MenuDictionary.empty;
  return (source) => dictionary.text(source, language);
});
