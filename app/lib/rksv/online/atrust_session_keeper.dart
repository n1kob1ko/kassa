import 'package:flutter/foundation.dart';

import '../../core/clock.dart';
import '../rksv_secrets.dart';
import 'atrust_client.dart';

/// Hält die Sitzung bei A-Trust: meldet sich im Voraus an, nie zwei Mal
/// zugleich (eine nach [loginLimit] aufgegebene Anmeldung zählt nicht mehr
/// mit), und nach einer Ablehnung (401 oder 403 beim Anmelden) nie mehr von
/// selbst, bis der Chef [allowOneLogin] antippt (Plan, Schutz des Kontos).
///
/// Eine Sitzung gilt als abgelaufen 55 Minuten nach der letzten Benutzung oder
/// an einem neuen Kalendertag nach der Ortszeit von [Clock] (P7).
class AtrustSessionKeeper {
  AtrustSessionKeeper({
    required this._client,
    required this._user,
    required this._password,
    required this._secrets,
    required this._clock,
  });

  static const _maxIdle = Duration(minutes: 55);

  /// So lange wartet eine Anmeldung auf A-Trust, so lange wie eine Zeile von
  /// "Verbindung prüfen".
  static const loginLimit = Duration(seconds: 20);

  final AtrustClient _client;
  final String _user;
  final String _password;
  final RksvSecrets _secrets;
  final Clock _clock;

  final ValueNotifier<bool> _rejected = ValueNotifier(false);
  Future<void>? _restored;
  bool _isRestored = false;
  Future<AtrustSession>? _login;
  AtrustSession? _session;
  DateTime? _lastUse;

  /// Der Kalendertag zählt ab der Anmeldung, nicht ab der letzten Benutzung.
  DateTime? _loginAt;

  /// Lädt das gespeicherte Kennzeichen. Vor dem ersten Gebrauch aufrufen.
  /// Ein zweiter Aufruf tut nichts (R2). Scheitert das Lesen, wirft es, und
  /// der nächste Aufruf liest neu; bis dahin geht keine Anfrage hinaus.
  Future<void> restore() => _restored ??= _read();

  Future<void> _read() async {
    try {
      if (await _secrets.atrustRejected()) _rejected.value = true;
      _isRestored = true;
    } catch (_) {
      _restored = null;
      rethrow;
    }
  }

  /// Wahr nach 401 oder 403 auf eine Anmeldung, bis [allowOneLogin].
  ValueListenable<bool> get rejected => _rejected;

  /// Gültige Sitzung, sonst anmelden. Läuft schon eine Anmeldung, wartet der
  /// Aufruf auf dieselbe; nie zwei zugleich, solange eine auf Antwort wartet.
  /// Wirft AtrustException: bei [rejected] sofort, ohne Netz; antwortet
  /// A-Trust nicht binnen [loginLimit], `noInternet`, und der nächste Aufruf
  /// meldet neu an.
  Future<AtrustSession> session() async {
    // Nach dem Laden ohne await: kein Umweg über eine fertige Future aus einer
    // anderen Zone (fake_async).
    if (!_isRestored) await restore();
    if (_rejected.value) throw const AtrustException(AtrustProblem.rejected);
    final current = _session;
    if (current != null && _valid()) return current;
    _session = null;
    return _login ??= _startLogin();
  }

  bool _valid() {
    final now = _clock.now().toLocal();
    final login = _loginAt!.toLocal();
    return now.difference(_lastUse!.toLocal()) < _maxIdle &&
        now.year == login.year &&
        now.month == login.month &&
        now.day == login.day;
  }

  /// Die geteilte Anmeldung. Antwortet A-Trust nicht binnen [loginLimit],
  /// bekommen alle Wartenden `noInternet`, und der nächste Aufruf von
  /// [session] meldet neu an. Die späte Antwort zählt trotzdem: 401 oder 403
  /// setzt [rejected], eine Sitzung gilt nur, wenn der Halter keine hat, ein
  /// anderer Fehler fällt weg.
  Future<AtrustSession> _startLogin() {
    late final Future<AtrustSession> shared;
    shared = _answer()
        .timeout(
          loginLimit,
          onTimeout: () =>
              throw const AtrustException(AtrustProblem.noInternet),
        )
        .whenComplete(() {
          if (identical(_login, shared)) _login = null;
        });
    return shared;
  }

  Future<AtrustSession> _answer() async {
    try {
      final s = await _client.login(_user, _password);
      if (_session == null) {
        _session = s;
        _loginAt = _lastUse = _clock.now();
      }
      return s;
    } on AtrustException catch (e) {
      if (e.problem == AtrustProblem.rejected) _reject();
      rethrow;
    }
  }

  void _reject() {
    _session = null;
    _rejected.value = true;
    // Nicht abwarten: session() kehrt sofort zurück. Scheitert das Speichern,
    // gilt das Kennzeichen bis zum Neustart nur im Arbeitsspeicher.
    _secrets.writeAtrustRejected(true).then<void>((_) {}, onError: (_) {});
  }

  /// Anmelden im Hintergrund, wenn keine gültige Sitzung da ist. Wirft nie.
  /// Höchstens eine Anmeldung je Aufruf, keine bei [rejected] und keine,
  /// solange schon eine läuft.
  void warmUp() {
    if (_rejected.value) return;
    session().then<void>((_) {}, onError: (_) {});
  }

  /// Nach erfolgreichem Signieren: Die Sitzung gilt wieder 55 Minuten.
  void used(AtrustSession session) {
    if (identical(session, _session) && _valid()) _lastUse = _clock.now();
  }

  /// Die Sitzung gilt nicht mehr (401 beim Signieren).
  void drop(AtrustSession session) {
    if (identical(session, _session)) _session = null;
  }

  /// Nur nach ausdrücklichem Antippen des Chefs: hebt [rejected] auf. Die
  /// nächste Anmeldung ist dann genau ein Versuch; lehnt A-Trust wieder ab,
  /// gilt [rejected] wieder.
  Future<void> allowOneLogin() async {
    await restore();
    _rejected.value = false;
    await _secrets.writeAtrustRejected(false);
  }

  @override
  String toString() => 'AtrustSessionKeeper';
}
