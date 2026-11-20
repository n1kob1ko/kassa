import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/secure_storage.dart';

/// Zugangsdaten des echten Kontos bei A-Trust. Der Benutzername gilt wie das
/// Passwort als Geheimnis (Plan Q12); toString nennt keins von beiden.
final class AtrustCredentials {
  const AtrustCredentials(this.user, this.password);

  final String user, password;

  @override
  String toString() => 'AtrustCredentials';
}

/// Kassen-Kennung und AES-Schlüssel, die für FinanzOnline abgeschrieben
/// wurden und bis zur Inbetriebnahme warten (Plan Q2). toString ohne Inhalt.
final class PendingSetup {
  const PendingSetup({required this.cashBoxId, required this.aesKey});

  final String cashBoxId;

  /// 32 Bytes.
  final Uint8List aesKey;

  @override
  String toString() => 'PendingSetup';
}

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
  /// Je System ein eigenes Kennzeichen: [live] für das echte, sonst das
  /// Testsystem (Plan Q4). Ohne Eintrag false. Kein Geheimnis, liegt aber
  /// hier und nicht in der Datenbank (Plan P1).
  Future<bool> atrustRejected({bool live = false});
  Future<void> writeAtrustRejected(bool rejected, {bool live = false});

  /// Die Zugangsdaten des echten Kontos; null, wenn keine gespeichert sind.
  /// Benutzername und Passwort sind ein Wert: Es gibt nie das eine ohne das
  /// andere.
  Future<AtrustCredentials?> atrustCredentials();

  /// null löscht sie.
  Future<void> writeAtrustCredentials(AtrustCredentials? credentials);

  /// Kassen-Kennung und AES-Schlüssel sind ein Wert, wie die Zugangsdaten.
  Future<PendingSetup?> pendingSetup();

  /// null löscht es.
  Future<void> writePendingSetup(PendingSetup? setup);
}

class SecureRksvSecrets implements RksvSecrets {
  SecureRksvSecrets([FlutterSecureStorage? storage])
    : _storage = storage ?? kassaSecureStorage;

  final FlutterSecureStorage _storage;

  /// Der Speicher dahinter, für Tests.
  @visibleForTesting
  FlutterSecureStorage get storage => _storage;

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

  static String _rejected(bool live) =>
      live ? 'rksv_atrust_rejected_live' : 'rksv_atrust_rejected';
  // Zugangsdaten und PendingSetup sind je EIN Wert: Ein Fehler zwischen zwei
  // Schreibvorgängen hinterließe sonst ein gemischtes Paar (Schlussprüfung
  // S2b, Minor 1).
  static const _credentials = 'rksv_atrust_credentials';
  static const _setup = 'rksv_setup';

  @override
  Future<bool> atrustRejected({bool live = false}) async =>
      await _storage.read(key: _rejected(live)) == 'true';

  @override
  Future<void> writeAtrustRejected(bool rejected, {bool live = false}) =>
      rejected
      ? _storage.write(key: _rejected(live), value: 'true')
      : _storage.delete(key: _rejected(live));

  /// Liest [name] als JSON-Objekt; null ohne Eintrag. Ein beschädigter Wert
  /// wirft.
  Future<Map<String, Object?>?> _readJson(String name) async {
    final value = await _storage.read(key: name);
    if (value == null) return null;
    return (jsonDecode(value) as Map).cast<String, Object?>();
  }

  @override
  Future<AtrustCredentials?> atrustCredentials() async {
    final json = await _readJson(_credentials);
    if (json == null) return null;
    return AtrustCredentials(
      json['user']! as String,
      json['password']! as String,
    );
  }

  @override
  Future<void> writeAtrustCredentials(AtrustCredentials? credentials) =>
      credentials == null
      ? _storage.delete(key: _credentials)
      : _storage.write(
          key: _credentials,
          value: jsonEncode({
            'user': credentials.user,
            'password': credentials.password,
          }),
        );

  @override
  Future<PendingSetup?> pendingSetup() async {
    final json = await _readJson(_setup);
    if (json == null) return null;
    return PendingSetup(
      cashBoxId: json['cashBoxId']! as String,
      aesKey: base64.decode(json['aesKey']! as String),
    );
  }

  @override
  Future<void> writePendingSetup(PendingSetup? setup) => setup == null
      ? _storage.delete(key: _setup)
      : _storage.write(
          key: _setup,
          value: jsonEncode({
            'cashBoxId': setup.cashBoxId,
            'aesKey': base64.encode(setup.aesKey),
          }),
        );
}

/// Für Tests. Mit [failReads] schlagen alle Lesezugriffe fehl, mit
/// [hangReads] kehren sie nie zurück, mit [hangWrites] die Schreibzugriffe
/// auch nicht, mit [failWrites] schlagen sie fehl.
class MemoryRksvSecrets implements RksvSecrets {
  final Map<String, Uint8List> _values = {};
  bool failReads = false;
  bool hangReads = false;
  bool hangWrites = false;
  bool failWrites = false;

  Future<void> _reading() async {
    if (hangReads) await Completer<void>().future;
    if (failReads) throw StateError('Der sichere Speicher ist nicht lesbar.');
  }

  Future<void> _writing() async {
    if (hangWrites) await Completer<void>().future;
    if (failWrites) {
      throw StateError('Der sichere Speicher ist nicht beschreibbar.');
    }
  }

  Future<Uint8List?> _read(String name) async {
    await _reading();
    final v = _values[name];
    return v == null ? null : Uint8List.fromList(v);
  }

  @override
  Future<Uint8List?> aesKey(int chain) => _read('rksv_aes_$chain');

  Future<void> _write(String name, Uint8List value) async {
    await _writing();
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

  bool _rejectedTest = false;
  bool _rejectedLive = false;
  AtrustCredentials? _credentials;
  PendingSetup? _setup;

  @override
  Future<bool> atrustRejected({bool live = false}) async {
    await _reading();
    return live ? _rejectedLive : _rejectedTest;
  }

  @override
  Future<void> writeAtrustRejected(bool rejected, {bool live = false}) async {
    await _writing();
    if (live) {
      _rejectedLive = rejected;
    } else {
      _rejectedTest = rejected;
    }
  }

  @override
  Future<AtrustCredentials?> atrustCredentials() async {
    await _reading();
    return _credentials;
  }

  @override
  Future<void> writeAtrustCredentials(AtrustCredentials? credentials) async {
    await _writing();
    _credentials = credentials;
  }

  @override
  Future<PendingSetup?> pendingSetup() async {
    await _reading();
    final s = _setup;
    return s == null
        ? null
        : PendingSetup(
            cashBoxId: s.cashBoxId,
            aesKey: Uint8List.fromList(s.aesKey),
          );
  }

  @override
  Future<void> writePendingSetup(PendingSetup? setup) async {
    await _writing();
    _setup = setup == null
        ? null
        : PendingSetup(
            cashBoxId: setup.cashBoxId,
            aesKey: Uint8List.fromList(setup.aesKey),
          );
  }
}
