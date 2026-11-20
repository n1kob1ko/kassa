// Der PIN-Wächter (K6): merkt sich je Karte, wie viele Versuche die Karte
// nach einem Fehlversuch noch hat. Kennt er nur noch einen, schickt die Kassa
// keine PIN mehr, bis der Chef ihn zurücksetzt. Er speichert nie die PIN,
// nur die Zahl.

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/secure_storage.dart';

abstract interface class PinGuard {
  /// Versuche, die die Karte mit [cardNumber] laut letzter Antwort noch hat;
  /// `null`, wenn kein Fehlversuch bekannt ist.
  Future<int?> retriesLeft(String cardNumber);

  Future<void> recordFailure(String cardNumber, int retriesLeft);

  Future<void> clear(String cardNumber);
}

/// Geschützter Speicher des Geräts; übersteht einen Neustart der App.
class SecurePinGuard implements PinGuard {
  SecurePinGuard([FlutterSecureStorage? storage])
    : _storage = storage ?? kassaSecureStorage;

  static String keyOf(String cardNumber) => 'rksv_pin_guard_$cardNumber';

  final FlutterSecureStorage _storage;

  /// Der Speicher dahinter, für Tests.
  @visibleForTesting
  FlutterSecureStorage get storage => _storage;

  /// Ein unlesbarer Eintrag zählt wie 0: lieber keine PIN schicken. Liest
  /// der Speicher gerade nicht, wirft dies; dann schickt die Kassa auch keine
  /// PIN (`CardCheck.sign`).
  @override
  Future<int?> retriesLeft(String cardNumber) async {
    final value = await _storage.read(key: keyOf(cardNumber));
    if (value == null) return null;
    return int.tryParse(value) ?? 0;
  }

  @override
  Future<void> recordFailure(String cardNumber, int retriesLeft) =>
      _storage.write(key: keyOf(cardNumber), value: '$retriesLeft');

  @override
  Future<void> clear(String cardNumber) =>
      _storage.delete(key: keyOf(cardNumber));
}

/// Für Tests: hält die Zahlen im Arbeitsspeicher. Mit einem gemeinsamen
/// [store] sehen zwei Instanzen dasselbe, wie nach einem Neustart.
class MemoryPinGuard implements PinGuard {
  MemoryPinGuard([Map<String, int>? store]) : _store = store ?? {};

  final Map<String, int> _store;

  @override
  Future<int?> retriesLeft(String cardNumber) async => _store[cardNumber];

  @override
  Future<void> recordFailure(String cardNumber, int retriesLeft) async =>
      _store[cardNumber] = retriesLeft;

  @override
  Future<void> clear(String cardNumber) async => _store.remove(cardNumber);
}
