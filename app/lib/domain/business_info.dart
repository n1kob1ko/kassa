// Betriebsdaten, die auf dem Bon stehen. Kommen aus der Speisekarten-Datei.
// Reines Dart, ohne Flutter und ohne Datenbank.

import 'wire_file.dart';

class BusinessInfo {
  const BusinessInfo({
    required this.name,
    this.addressLines = const [],
    this.vatId,
    this.receiptFooter,
    this.logo,
    this.logoPath,
  });

  final String name;

  /// Höchstens vier Zeilen, ohne leere Zeilen.
  final List<String> addressLines;

  /// UID-Nummer, falls angegeben.
  final String? vatId;

  /// Schlusstext unter dem Bon, falls angegeben.
  final String? receiptFooter;

  /// Das Logo, wie der Server es nennt (Kennung und Farbe). Beim Lesen aus der
  /// Datenbank gesetzt, sobald der Server ein Logo nennt.
  final WireFile? logo;

  /// Wo die Datei des Logos auf dem Tablet liegt, erst wenn sie ganz geladen
  /// ist.
  final String? logoPath;
}
