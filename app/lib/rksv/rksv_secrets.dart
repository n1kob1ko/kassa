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

/// Die PIN der Signaturkarte mit Kartenart und Kartennummer der Karte, die
/// mit ihr eine gültige Probe-Unterschrift geliefert hat (Plan C3). Ein Wert:
/// Es gibt nie die PIN ohne die Karte. toString nennt nichts davon.
final class CardPin {
  const CardPin({
    required this.kind,
    required this.numberHex,
    required this.pin,
  });

  /// `CardKind.name`.
  final String kind;

  /// Die Kartennummer als Hex in Großbuchstaben, ohne Leerzeichen.
  final String numberHex;
  final String pin;

  @override
  String toString() => 'CardPin';
}

/// Was die Kassa über die gespeicherte PIN weiß (Plan C4): [rejected], wenn
/// die Karte sie abgelehnt hat; [unanswered], wie viele VERIFY seit der
/// letzten gelungenen Prüfung ohne Antwort blieben. Kein Geheimnis.
final class CardPinStatus {
  const CardPinStatus({this.rejected = false, this.unanswered = 0});

  final bool rejected;
  final int unanswered;

  @override
  String toString() =>
      'CardPinStatus(rejected: $rejected, unanswered: $unanswered)';
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

  /// Die PIN der einen gespeicherten Karte; null, wenn keine gespeichert ist.
  Future<CardPin?> cardPin();

  /// null löscht sie. Setzt den [cardPinStatus] zurück, auch beim Löschen.
  Future<void> writeCardPin(CardPin? pin);

  /// Ohne Eintrag `const CardPinStatus()`; ein unlesbarer Eintrag gilt als
  /// abgelehnt.
  Future<CardPinStatus> cardPinStatus();
  Future<void> writeCardPinStatus(CardPinStatus status);
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
  static const _cardPin = 'rksv_card_pin';
  static const _cardPinStatus = 'rksv_card_pin_status';

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

  @override
  Future<CardPin?> cardPin() async {
    final json = await _readJson(_cardPin);
    if (json == null) return null;
    return CardPin(
      kind: json['kind']! as String,
      numberHex: json['numberHex']! as String,
      pin: json['pin']! as String,
    );
  }

  @override
  Future<void> writeCardPin(CardPin? pin) async {
    if (pin == null) {
      await _storage.delete(key: _cardPin);
    } else {
      await _storage.write(
        key: _cardPin,
        value: jsonEncode({
          'kind': pin.kind,
          'numberHex': pin.numberHex,
          'pin': pin.pin,
        }),
      );
    }
    await _storage.delete(key: _cardPinStatus);
  }

  @override
  Future<CardPinStatus> cardPinStatus() async {
    final value = await _storage.read(key: _cardPinStatus);
    if (value == null) return const CardPinStatus();
    try {
      final json = jsonDecode(value) as Map;
      return CardPinStatus(
        rejected: json['rejected']! as bool,
        unanswered: json['unanswered']! as int,
      );
    } catch (_) {
      // Lieber keine PIN mehr schicken.
      return const CardPinStatus(rejected: true);
    }
  }

  @override
  Future<void> writeCardPinStatus(CardPinStatus status) =>
      !status.rejected && status.unanswered == 0
      ? _storage.delete(key: _cardPinStatus)
      : _storage.write(
          key: _cardPinStatus,
          value: jsonEncode({
            'rejected': status.rejected,
            'unanswered': status.unanswered,
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

  CardPin? _cardPin;
  CardPinStatus _cardPinStatus = const CardPinStatus();

  @override
  Future<CardPin?> cardPin() async {
    await _reading();
    return _cardPin;
  }

  @override
  Future<void> writeCardPin(CardPin? pin) async {
    await _writing();
    _cardPin = pin;
    _cardPinStatus = const CardPinStatus();
  }

  @override
  Future<CardPinStatus> cardPinStatus() async {
    await _reading();
    return _cardPinStatus;
  }

  @override
  Future<void> writeCardPinStatus(CardPinStatus status) async {
    await _writing();
    _cardPinStatus = status;
  }
}
