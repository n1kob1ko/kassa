// Eine Bilddatei am Server, wie ein Artikel oder der Betrieb sie nennt.
// Reines Dart, ohne Flutter und ohne Datenbank.

class WireFile {
  const WireFile({required this.id, required this.color});

  /// Kennung der Datei am Server. Sie wird Teil eines Dateinamens am Tablet
  /// und darum von `FileSync` geprüft, bevor sie benutzt wird.
  final String id;

  /// Mittlere Farbe des Bildes, `#rrggbb`: der Hintergrund, bis es da ist.
  final String color;
}
