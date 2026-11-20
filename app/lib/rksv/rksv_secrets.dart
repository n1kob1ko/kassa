import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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

  /// Die Zugangsdaten des echten Kontos; null, wenn keine (vollständig)
  /// gespeichert sind.
  Future<AtrustCredentials?> atrustCredentials();

  /// null löscht sie.
  Future<void> writeAtrustCredentials(AtrustCredentials? credentials);

  Future<PendingSetup?> pendingSetup();

  /// null löscht es.
  Future<void> writePendingSetup(PendingSetup? setup);
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

  static String _rejected(bool live) =>
      live ? 'rksv_atrust_rejected_live' : 'rksv_atrust_rejected';
  static const _user = 'rksv_atrust_user';
  static const _password = 'rksv_atrust_password';
  static const _cashBoxId = 'rksv_setup_cash_box_id';
  static const _setupAes = 'rksv_setup_aes';

  @override
  Future<bool> atrustRejected({bool live = false}) async =>
      await _storage.read(key: _rejected(live)) == 'true';

  @override
  Future<void> writeAtrustRejected(bool rejected, {bool live = false}) =>
      rejected
      ? _storage.write(key: _rejected(live), value: 'true')
      : _storage.delete(key: _rejected(live));

  @override
  Future<AtrustCredentials?> atrustCredentials() async {
    final user = await _storage.read(key: _user);
    final password = await _storage.read(key: _password);
    if (user == null || password == null) return null;
    return AtrustCredentials(user, password);
  }

  @override
  Future<void> writeAtrustCredentials(AtrustCredentials? credentials) async {
    if (credentials == null) {
      await _storage.delete(key: _user);
      await _storage.delete(key: _password);
    } else {
      await _storage.write(key: _user, value: credentials.user);
      await _storage.write(key: _password, value: credentials.password);
    }
  }

  @override
  Future<PendingSetup?> pendingSetup() async {
    final id = await _storage.read(key: _cashBoxId);
    final aes = await _read(_setupAes);
    if (id == null || aes == null) return null;
    return PendingSetup(cashBoxId: id, aesKey: aes);
  }

  @override
  Future<void> writePendingSetup(PendingSetup? setup) async {
    if (setup == null) {
      await _storage.delete(key: _cashBoxId);
      await _storage.delete(key: _setupAes);
    } else {
      await _storage.write(key: _cashBoxId, value: setup.cashBoxId);
      await _write(_setupAes, setup.aesKey);
    }
  }
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
