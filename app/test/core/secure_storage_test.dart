// Der geschützte Speicher löscht bei einem Lesefehler nichts (Schlussprüfung
// S2b, C1): Das gilt für alle drei Klassen, die ihn benutzen. Sonst bleibt
// jede Einstellung so wie in Version 1.6.0, damit gespeicherte Werte lesbar
// bleiben.

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/rksv/card/pin_guard.dart';
import 'package:kassa/rksv/rksv_secrets.dart';
import 'package:kassa/sync/token_store.dart';

void main() {
  final storages = <String, FlutterSecureStorage>{
    'SecureRksvSecrets': SecureRksvSecrets().storage,
    'SecureTokenStore': SecureTokenStore().storage,
    'SecurePinGuard': SecurePinGuard().storage,
  };

  for (final MapEntry(key: name, value: storage) in storages.entries) {
    test('$name: der Speicher löscht bei einem Lesefehler nichts', () {
      expect(storage.aOptions.toMap()['resetOnError'], 'false');
    });

    test('$name: sonst die Voreinstellungen von 1.6.0', () {
      final defaults = AndroidOptions.defaultOptions.toMap()
        ..remove('resetOnError');
      final options = storage.aOptions.toMap()..remove('resetOnError');
      expect(options, defaults);
      expect(storage.iOptions.toMap(), IOSOptions.defaultOptions.toMap());
    });
  }
}
