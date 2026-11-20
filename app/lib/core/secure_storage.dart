// Der geschützte Speicher der Kassa (Android Keystore). Ihn teilen sich die
// Signatur (`SecureRksvSecrets`), die Kopplung mit dem Server
// (`SecureTokenStore`) und der PIN-Wächter (`SecurePinGuard`).

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Bei einem Lesefehler löscht der Speicher nichts (`resetOnError: false`):
/// Die Voreinstellung des Bausteins löschte sonst beim ersten Fehler den
/// Schlüssel einer echten Kette für immer. Ein Lesefehler bleibt ein Fehler,
/// bis der Speicher wieder liest. Alle anderen Einstellungen bleiben die
/// Voreinstellungen, mit denen Version 1.6.0 geschrieben hat: Sonst wären
/// die gespeicherten Werte nicht mehr lesbar.
const kassaSecureStorage = FlutterSecureStorage(
  aOptions: AndroidOptions(resetOnError: false),
);
