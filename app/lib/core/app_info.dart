/// Versionsnummer der App, wie sie unten in den Einstellungen steht. Muss mit
/// dem Teil von `version:` in `pubspec.yaml` vor dem "+" übereinstimmen (ein
/// Test prüft das).
const appVersion = '1.3.0';

/// Adresse des Servers. Kommt beim Bauen mit
/// `--dart-define=KASSA_SERVER_URL=...`, steht also nicht im Quelltext.
const serverUrl = String.fromEnvironment('KASSA_SERVER_URL');

/// Ohne Adresse arbeitet die Kassa wie bisher allein, ohne Server.
bool get hasServer => serverUrl.isNotEmpty;
