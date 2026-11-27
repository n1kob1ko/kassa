/// Versionsnummer der App, wie sie unten in den Einstellungen steht. Muss mit
/// dem Teil von `version:` in `pubspec.yaml` vor dem "+" übereinstimmen (ein
/// Test prüft das).
const appVersion = '1.11.0';

/// Adresse des Servers. Kommt beim Bauen mit
/// `--dart-define=KASSA_SERVER_URL=...`, steht also nicht im Quelltext.
const serverUrl = String.fromEnvironment('KASSA_SERVER_URL');

/// Ohne Adresse arbeitet die Kassa wie bisher allein, ohne Server.
bool get hasServer => serverUrl.isNotEmpty;

/// Die Adresse der Seite eines Bons am Server (`/beleg/<Schlüssel>`), für den
/// QR-Code des digitalen Bons. `null` ohne Server ([base] leer) oder ohne
/// Schlüssel (Bon aus 1.11.0). [base] ist in der App [serverUrl]; Tests setzen
/// eine erfundene Adresse ein.
String? receiptPageUrl(String? publicToken, {String base = serverUrl}) {
  if (base.isEmpty || publicToken == null || publicToken.isEmpty) return null;
  final root = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
  return '$root/beleg/$publicToken';
}
