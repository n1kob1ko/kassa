// Hilfe zum Lesen gespeicherter Enum-Namen.

/// Liest den Eintrag mit dem Namen [name]; bei `null` oder einem unbekannten
/// Namen (zum Beispiel aus einer neueren Version) gilt [fallback].
T enumByNameOr<T extends Enum>(List<T> values, String? name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}
