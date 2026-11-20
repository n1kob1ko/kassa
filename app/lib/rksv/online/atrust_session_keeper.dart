import 'package:flutter/foundation.dart';

import '../../core/clock.dart';
import '../rksv_secrets.dart';
import 'atrust_client.dart';

/// Hält die Sitzung bei A-Trust für ein System: meldet sich im Voraus an, nie
/// zwei Mal zugleich, und nach einer Ablehnung (401 oder 403 beim Anmelden)
/// nie mehr von selbst, bis der Chef [allowOneLogin] antippt (Plan, Schutz des
/// Kontos). Eine nach [loginLimit] aufgegebene Anmeldung ohne Antwort sperrt
/// neue Anmeldungen höchstens [abandonedLimit] lang (Plan Q13).
///
/// Die Zugangsdaten liest der Halter bei jeder Anmeldung neu aus
/// `credentials` (Plan Q5). [live] wählt das Kennzeichen "abgelehnt" des
/// echten Systems statt dessen des Testsystems (Plan Q4).
///
/// Eine Sitzung gilt als abgelaufen 55 Minuten nach der letzten Benutzung oder
/// an einem neuen Kalendertag nach der Ortszeit von [Clock] (P7).
class AtrustSessionKeeper {
  AtrustSessionKeeper({
    required this._client,
    required this._credentials,
    required this._secrets,
    required this._clock,
    this._live = false,
  });

  static const _maxIdle = Duration(minutes: 55);

  /// So lange wartet eine Anmeldung auf A-Trust, so lange wie eine Zeile von
  /// "Verbindung prüfen".
  static const loginLimit = Duration(seconds: 20);

  /// So lange nach dem Aufgeben einer Anmeldung, die noch keine Antwort hat,
  /// geht keine neue hinaus (Plan Q13).
  static const abandonedLimit = Duration(seconds: 120);

  final AtrustClient _client;
  final Future<AtrustCredentials?> Function() _credentials;
  final RksvSecrets _secrets;
  final Clock _clock;
  final bool _live;

  final ValueNotifier<bool> _rejected = ValueNotifier(false);
  Future<void>? _restored;
  bool _isRestored = false;
  Future<AtrustSession>? _login;
  AtrustSession? _session;
  DateTime? _lastUse;

  /// Der Kalendertag zählt ab der Anmeldung, nicht ab der letzten Benutzung.
  DateTime? _loginAt;

  /// Die zuletzt aufgegebene Anmeldung, solange sie keine Antwort hat, und
  /// wann sie aufgegeben wurde (Q13).
  _Attempt? _abandoned;
  DateTime? _abandonedAt;

  /// Zählt [forget]: Eine Anmeldung aus einer früheren Runde wird weder
  /// gehalten noch setzt sie [rejected].
  int _round = 0;

  /// "Abgelehnt" gilt, steht aber noch nicht im Speicher (Q14), und das
  /// Schreiben, das gerade läuft.
  bool _rejectUnsaved = false;
  Future<void>? _savingReject;

  /// Lädt das gespeicherte Kennzeichen. Vor dem ersten Gebrauch aufrufen.
  /// Ein zweiter Aufruf liest nicht noch einmal (R2). Scheitert das Lesen,
  /// wirft es, und der nächste Aufruf liest neu; bis dahin geht keine Anfrage
  /// hinaus. Steht ein "abgelehnt" noch nicht im Speicher, schreibt jeder
  /// Aufruf es erneut.
  Future<void> restore() {
    _saveReject();
    return _restored ??= _read();
  }

  Future<void> _read() async {
    try {
      if (await _secrets.atrustRejected(live: _live)) _rejected.value = true;
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
  /// Wirft AtrustException, jeweils ohne Anfrage: bei [rejected] `rejected`;
  /// solange eine aufgegebene Anmeldung keine Antwort hat, höchstens
  /// [abandonedLimit] lang, `noInternet`; ohne Zugangsdaten
  /// `noCredentials`. Antwortet A-Trust nicht binnen [loginLimit],
  /// `noInternet`.
  Future<AtrustSession> session() async {
    _saveReject();
    // Nach dem Laden ohne await: kein Umweg über eine fertige Future aus einer
    // anderen Zone (fake_async).
    if (!_isRestored) await restore();
    if (_rejected.value) throw const AtrustException(AtrustProblem.rejected);
    final current = _session;
    if (current != null && _valid()) return current;
    _session = null;
    final running = _login;
    if (running != null) return running;
    if (_blocked()) throw const AtrustException(AtrustProblem.noInternet);
    return _login = _startLogin();
  }

  bool _valid() {
    final now = _clock.now().toLocal();
    final login = _loginAt!.toLocal();
    return now.difference(_lastUse!.toLocal()) < _maxIdle &&
        now.year == login.year &&
        now.month == login.month &&
        now.day == login.day;
  }

  /// Hat eine aufgegebene Anmeldung noch keine Antwort und ist sie jünger als
  /// [abandonedLimit]? Geht die Uhr zurück, sperrt das nicht.
  bool _blocked() {
    final at = _abandonedAt;
    if (_abandoned == null || at == null) return false;
    final age = _clock.now().difference(at);
    return age >= Duration.zero && age < abandonedLimit;
  }

  /// Die geteilte Anmeldung. Antwortet A-Trust nicht binnen [loginLimit],
  /// bekommen alle Wartenden `noInternet`, und die Anmeldung gilt als
  /// aufgegeben (Q13). Die späte Antwort zählt trotzdem: 401 oder 403 setzt
  /// [rejected], eine Sitzung gilt nur, wenn der Halter keine hat und
  /// [rejected] nicht gilt, ein anderer Fehler fällt weg.
  Future<AtrustSession> _startLogin() {
    final attempt = _Attempt();
    final answer = _answer(attempt, _round);
    late final Future<AtrustSession> shared;
    shared = answer
        .timeout(
          loginLimit,
          onTimeout: () {
            attempt.abandoned = true;
            _abandoned = attempt;
            _abandonedAt = _clock.now();
            throw const AtrustException(AtrustProblem.noInternet);
          },
        )
        .whenComplete(() {
          if (identical(_login, shared)) _login = null;
        });
    return shared;
  }

  Future<AtrustSession> _answer(_Attempt attempt, int round) async {
    try {
      final credentials = await _credentials();
      if (credentials == null) {
        throw const AtrustException(AtrustProblem.noCredentials);
      }
      // Das Lesen kann dauern: Was in session() geprüft wurde, gilt dann
      // vielleicht nicht mehr. Nach einer Ablehnung, für alte Zugangsdaten
      // (forget) oder nach dem Aufgeben geht keine Anfrage hinaus.
      if (_rejected.value) throw const AtrustException(AtrustProblem.rejected);
      if (round != _round || attempt.abandoned) {
        throw const AtrustException(AtrustProblem.noInternet);
      }
      final AtrustSession s;
      try {
        s = await _client.login(credentials.user, credentials.password);
      } on AtrustException catch (e) {
        if (e.problem == AtrustProblem.rejected && round == _round) _reject();
        rethrow;
      }
      // F5: Gilt "abgelehnt" schon (etwa durch die späte Antwort einer
      // aufgegebenen Anmeldung), wird die Sitzung weder gehalten noch
      // ausgegeben.
      if (_rejected.value) throw const AtrustException(AtrustProblem.rejected);
      if (_session == null && round == _round) {
        _session = s;
        _loginAt = _lastUse = _clock.now();
      }
      return s;
    } finally {
      if (identical(_abandoned, attempt)) {
        _abandoned = null;
        _abandonedAt = null;
      }
    }
  }

  void _reject() {
    _session = null;
    _rejected.value = true;
    _rejectUnsaved = true;
    _saveReject();
  }

  /// Schreibt ein noch nicht gespeichertes "abgelehnt" (Q14). Nicht
  /// abwarten: session() kehrt sofort zurück. Scheitert das Schreiben, gilt
  /// das Kennzeichen im Arbeitsspeicher, und der nächste Aufruf versucht es
  /// wieder. Kein Fehler erreicht den Aufrufer.
  void _saveReject() {
    if (!_rejectUnsaved || _savingReject != null) return;
    _savingReject = _secrets
        .writeAtrustRejected(true, live: _live)
        .then<void>((_) => _rejectUnsaved = false, onError: (_) {})
        .whenComplete(() => _savingReject = null);
  }

  /// Anmelden im Hintergrund, wenn keine gültige Sitzung da ist. Wirft nie.
  /// Höchstens eine Anmeldung je Aufruf, keine bei [rejected], keine, solange
  /// schon eine läuft, und keine, solange eine aufgegebene Anmeldung sperrt.
  /// Das Ergebnis ist fertig, wenn die Anmeldung fertig ist (gelungen oder
  /// nicht); wer nicht warten will, lässt es liegen.
  Future<void> warmUp() {
    _saveReject();
    if (_rejected.value || (_login == null && _blocked())) {
      return Future<void>.value();
    }
    return session().then<void>((_) {}, onError: (_) {});
  }

  /// Nach erfolgreichem Signieren: Die Sitzung gilt wieder 55 Minuten.
  void used(AtrustSession session) {
    if (identical(session, _session) && _valid()) _lastUse = _clock.now();
  }

  /// Die Sitzung gilt nicht mehr (401 beim Signieren).
  void drop(AtrustSession session) {
    if (identical(session, _session)) _session = null;
  }

  /// Für neue Zugangsdaten: verwirft die gehaltene Sitzung, ohne Anfrage.
  /// Eine Anmeldung, die noch läuft, gehört zu den alten Zugangsdaten: Ihre
  /// Antwort wird nicht gehalten und setzt [rejected] nicht, und die nächste
  /// [session] meldet mit den neuen an. [rejected] bleibt, wie es ist.
  void forget() {
    _round++;
    _session = null;
    _login = null;
  }

  /// Nur nach ausdrücklichem Antippen des Chefs: hebt [rejected] auf. Die
  /// nächste Anmeldung ist dann genau ein Versuch; lehnt A-Trust wieder ab,
  /// gilt [rejected] wieder. Die Sperre nach einer aufgegebenen Anmeldung
  /// (Q13) bleibt.
  Future<void> allowOneLogin() async {
    // Wie in session(): nach dem Laden ohne await.
    if (!_isRestored) await restore();
    _rejectUnsaved = false;
    // Ein laufendes Schreiben von "abgelehnt" darf das Aufheben nicht
    // überholen.
    await _savingReject;
    _rejected.value = false;
    await _secrets.writeAtrustRejected(false, live: _live);
  }

  @override
  String toString() => 'AtrustSessionKeeper';
}

/// Eine Anmeldung; [abandoned], sobald sie nach
/// [AtrustSessionKeeper.loginLimit] aufgegeben wurde.
class _Attempt {
  bool abandoned = false;
}
