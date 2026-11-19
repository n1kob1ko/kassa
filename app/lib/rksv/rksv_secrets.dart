import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Geheimnisse der Registrierkasse. Sie liegen nur im sicheren Speicher, nie in
/// der Datenbank, in einem Log oder in einem Text.
abstract interface class RksvSecrets {
  Future<Uint8List?> aesKey(int chain);

  /// [key] sind 32 Bytes.
  Future<void> writeAesKey(int chain, Uint8List key);

  /// Privater Schlüssel der Probe-Signatur, 32 Bytes.
  Future<Uint8List?> probeKey(int chain);
  Future<void> writeProbeKey(int chain, Uint8List key);

  /// Hat A-Trust die Zugangsdaten abgelehnt (401 oder 403 beim Anmelden)?
  /// Ohne Eintrag false. Kein Geheimnis, liegt aber hier und nicht in der
  /// Datenbank (Plan P1).
  Future<bool> atrustRejected();
  Future<void> writeAtrustRejected(bool rejected);
}

class SecureRksvSecrets implements RksvSecrets {
  SecureRksvSecrets([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  Future<Uint8List?> _read(String name) async {
    final value = await _storage.read(key: name);
    return value == null ? null : base64.decode(value);
  }

  Future<void> _write(String name, Uint8List key) =>
      _storage.write(key: name, value: base64.encode(key));

  @override
  Future<Uint8List?> aesKey(int chain) => _read('rksv_aes_$chain');

  @override
  Future<void> writeAesKey(int chain, Uint8List key) =>
      _write('rksv_aes_$chain', key);

  @override
  Future<Uint8List?> probeKey(int chain) => _read('rksv_probe_key_$chain');

  @override
  Future<void> writeProbeKey(int chain, Uint8List key) =>
      _write('rksv_probe_key_$chain', key);

  static const _rejected = 'rksv_atrust_rejected';

  @override
  Future<bool> atrustRejected() async =>
      await _storage.read(key: _rejected) == 'true';

  @override
  Future<void> writeAtrustRejected(bool rejected) => rejected
      ? _storage.write(key: _rejected, value: 'true')
      : _storage.delete(key: _rejected);
}

/// Für Tests. Mit [failReads] schlagen alle Lesezugriffe fehl, mit
/// [hangReads] kehren sie nie zurück, mit [hangWrites] die Schreibzugriffe
/// auch nicht.
class MemoryRksvSecrets implements RksvSecrets {
  final Map<String, Uint8List> _values = {};
  bool failReads = false;
  bool hangReads = false;
  bool hangWrites = false;

  Future<Uint8List?> _read(String name) async {
    if (hangReads) await Completer<void>().future;
    if (failReads) throw StateError('Der sichere Speicher ist nicht lesbar.');
    final v = _values[name];
    return v == null ? null : Uint8List.fromList(v);
  }

  @override
  Future<Uint8List?> aesKey(int chain) => _read('rksv_aes_$chain');

  Future<void> _write(String name, Uint8List value) async {
    if (hangWrites) await Completer<void>().future;
    _values[name] = Uint8List.fromList(value);
  }

  @override
  Future<void> writeAesKey(int chain, Uint8List key) =>
      _write('rksv_aes_$chain', key);

  @override
  Future<Uint8List?> probeKey(int chain) => _read('rksv_probe_key_$chain');

  @override
  Future<void> writeProbeKey(int chain, Uint8List key) =>
      _write('rksv_probe_key_$chain', key);

  bool _atrustRejected = false;

  @override
  Future<bool> atrustRejected() async {
    if (hangReads) await Completer<void>().future;
    if (failReads) throw StateError('Der sichere Speicher ist nicht lesbar.');
    return _atrustRejected;
  }

  @override
  Future<void> writeAtrustRejected(bool rejected) async {
    if (hangWrites) await Completer<void>().future;
    _atrustRejected = rejected;
  }
}
