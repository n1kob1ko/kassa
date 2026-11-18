// Aufbewahrung des Geräte-Schlüssels. Er liegt im geschützten Speicher des
// Geräts, nie in der Datenbank, in Protokollen oder in Fehlermeldungen.

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class TokenStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> clear();
}

/// Geschützter Speicher des Geräts (Android Keystore).
class SecureTokenStore implements TokenStore {
  SecureTokenStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const key = 'kassa_device_token';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: key);

  @override
  Future<void> write(String token) => _storage.write(key: key, value: token);

  @override
  Future<void> clear() => _storage.delete(key: key);
}

/// Für Tests: hält den Schlüssel nur im Arbeitsspeicher.
class MemoryTokenStore implements TokenStore {
  String? _token;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String token) async => _token = token;

  @override
  Future<void> clear() async => _token = null;
}
