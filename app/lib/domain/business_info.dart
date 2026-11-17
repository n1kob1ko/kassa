// Betriebsdaten, die auf dem Bon stehen. Kommen aus der Speisekarten-Datei.
// Reines Dart, ohne Flutter und ohne Datenbank.

class BusinessInfo {
  const BusinessInfo({
    required this.name,
    this.addressLines = const [],
    this.vatId,
    this.receiptFooter,
  });

  final String name;

  /// Höchstens vier Zeilen, ohne leere Zeilen.
  final List<String> addressLines;

  /// UID-Nummer, falls angegeben.
  final String? vatId;

  /// Schlusstext unter dem Bon, falls angegeben.
  final String? receiptFooter;
}
