// "Verbindung prüfen" (Entwurf 6.6): vier Zeilen gegen A-Trust, ohne
// Oberfläche. Läuft außerhalb jeder Transaktion (P3).

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/clock.dart';
import '../card/card_check.dart' show RowResult, RowState;
import '../card/certificate.dart';
import '../signature_unit.dart';
import 'atrust_client.dart';
import 'atrust_session_keeper.dart';
import 'online_signature_unit.dart';

enum ConnectionRow { reach, certificate, login, signature }

/// Was "Verbindung prüfen" herausgefunden hat. Entsteht nur, wenn alle vier
/// Zeilen ok sind; nur damit lässt sich die Online-Probe einschalten.
final class ConnectionFacts {
  const ConnectionFacts._({
    required this.system,
    required this.zdaId,
    required this.certificate,
  });

  /// Das System, gegen das geprüft wurde.
  final AtrustSystem system;
  final String zdaId;
  final AtrustCertificate certificate;
}

final class ConnectionCheckState {
  const ConnectionCheckState({
    required this.rows,
    required this.running,
    this.facts,
  });

  final Map<ConnectionRow, RowResult> rows;
  final bool running;

  /// Nur bei vier Haken.
  final ConnectionFacts? facts;
}

/// Eine Zeile ist gescheitert: Satz, Rat und, wenn es sie gibt, der
/// Statuscode von A-Trust und die Art des Fehlers (nur für den Bericht).
final class _RowFailure implements Exception {
  const _RowFailure(this.message, this.hint, [this.status, this.detail]);

  final String message;
  final String? hint;
  final int? status;
  final String? detail;
}

class ConnectionCheck {
  ConnectionCheck({
    required this._client,
    required this._keeper,
    required this._user,
    required this._clock,
  });

  /// Je Zeile, auch für das Laden oder Aufheben von "abgelehnt" vorher.
  static const timeLimit = Duration(seconds: 20);

  /// Zeile 4 signiert den SHA-256 dieses Textes. Nur ASCII, wie jede
  /// Eingabe einer [SignatureUnit].
  static const signingInput = 'Kassa Verbindung pruefen';

  final AtrustClient _client;
  final AtrustSessionKeeper _keeper;

  /// Der Benutzer bei A-Trust, bei jedem Lauf neu gelesen; null, wenn keiner
  /// gespeichert ist. Er ist ein Geheimnis und steht nie im Bericht.
  final Future<String?> Function() _user;
  final Clock _clock;

  late final ValueNotifier<ConnectionCheckState> _state = ValueNotifier(
    const ConnectionCheckState(rows: _initialRows, running: false),
  );
  Map<ConnectionRow, RowResult> _rows = _initialRows;
  Future<ConnectionCheckState>? _running;

  // Für den Bericht, vom letzten Lauf.
  DateTime? _startedAt;
  final Map<ConnectionRow, Duration> _durations = {};
  final Map<ConnectionRow, int> _statuses = {};
  final Map<ConnectionRow, String> _details = {};
  String? _zdaId;
  AtrustCertificate? _certificate;

  ValueListenable<ConnectionCheckState> get state => _state;

  /// Das System, gegen das geprüft wird.
  AtrustSystem get system => _client.system;

  /// [chefTapped]: Der Aufruf kommt von einem Antippen des Chefs und darf
  /// eine abgelehnte Anmeldung ein Mal neu versuchen (keeper.allowOneLogin).
  /// Sonst geht bei "abgelehnt" keine einzige Anfrage hinaus. Ein zweiter
  /// Aufruf während eines Laufs liefert dessen Ergebnis.
  Future<ConnectionCheckState> run({required bool chefTapped}) =>
      _running ??= _run(chefTapped).whenComplete(() => _running = null);

  Future<ConnectionCheckState> _run(bool chefTapped) async {
    _startedAt = _clock.now();
    _durations.clear();
    _statuses.clear();
    _details.clear();
    _zdaId = null;
    _certificate = null;
    _rows = _initialRows;
    _publish(running: true);

    // Erst wissen, ob die Zugangsdaten abgelehnt sind, dann fragen. Scheitert
    // das, oder gilt "abgelehnt" und der Chef hat nicht getippt, endet der
    // Lauf gleich in der ersten Zeile, ohne Anfrage.
    try {
      await (chefTapped ? _keeper.allowOneLogin() : _keeper.restore()).timeout(
        timeLimit,
      );
    } on Object catch (e) {
      return _fail(
        ConnectionRow.reach,
        e is TimeoutException
            ? const _RowFailure(_T.noAnswer, _T.later)
            : const _RowFailure(_T.cannotReadLogin, _T.later),
      );
    }
    if (_keeper.rejected.value) {
      return _fail(
        ConnectionRow.reach,
        const _RowFailure(_T.rejected, _T.rejectedHint),
      );
    }

    final String? stored;
    try {
      stored = await _user().timeout(timeLimit);
    } on Object catch (e) {
      return _fail(
        ConnectionRow.reach,
        e is TimeoutException
            ? const _RowFailure(_T.noAnswer, _T.later)
            : const _RowFailure(_T.cannotReadLogin, _T.later),
      );
    }
    if (stored == null) {
      return _fail(
        ConnectionRow.reach,
        _RowFailure(
          AtrustException(AtrustProblem.noCredentials).sentence,
          null,
        ),
      );
    }

    final user = stored;
    var row = ConnectionRow.reach;
    try {
      final zdaId = await _step(row, () => _client.zdaId(user));
      _zdaId = zdaId;
      _ok(row, 'A-Trust erreicht (${_seconds(_durations[row]!)}).');

      row = ConnectionRow.certificate;
      final certificate = await _step(row, () => _client.certificate(user));
      _certificate = certificate;
      final (message, hint) = _judge(certificate);
      _ok(row, message, hint);

      row = ConnectionRow.login;
      await _step(row, _keeper.session);
      _ok(row, _T.loggedIn);

      row = ConnectionRow.signature;
      final unit = OnlineSignatureUnit(
        client: _client,
        keeper: _keeper,
        zdaId: zdaId,
        certificateDer: certificate.certificateDer,
        issuerCertificatesDer: certificate.issuersDer,
      );
      await _step(row, () => unit.sign(signingInput));
      _ok(
        row,
        'Probe-Unterschrift erstellt und geprüft '
        '(${_seconds(_durations[row]!)}).',
      );

      return _finish(
        ConnectionFacts._(
          system: _client.system,
          zdaId: zdaId,
          certificate: certificate,
        ),
      );
    } on Object catch (e) {
      return _fail(row, _failureOf(e));
    }
  }

  /// Zeile [row] läuft [work], höchstens [timeLimit] lang; die Dauer zählt
  /// auf der Uhr der Kassa.
  Future<T> _step<T>(ConnectionRow row, Future<T> Function() work) async {
    _set(row, RowResult(RowState.running, _runningText[row]!));
    final start = _clock.now();
    try {
      return await work().timeout(timeLimit);
    } finally {
      final d = _clock.now().difference(start);
      _durations[row] = d.isNegative ? Duration.zero : d;
    }
  }

  /// Satz und kleine Zeile zum Zertifikat, oder [_RowFailure].
  (String, String) _judge(AtrustCertificate c) {
    if (c.alg != 'ES256') {
      throw _RowFailure(_mismatch('Verfahren ${c.alg} statt ES256'), _T.report);
    }
    final CardCertificate parsed;
    try {
      parsed = CardCertificate.parse(c.certificateDer);
    } on FormatException {
      throw _RowFailure(_mismatch('Schlüssel nicht P-256'), _T.report);
    }
    final now = _clock.now();
    final until = _date(parsed.notAfter);
    final expired = now.isAfter(parsed.notAfter);
    if (_client.system == AtrustSystem.live) {
      if (now.isBefore(parsed.notBefore)) {
        throw _RowFailure(
          _T.notValid,
          _T.report,
          null,
          'gültig erst ab ${_date(parsed.notBefore)}',
        );
      }
      if (expired) {
        throw _RowFailure(_T.notValid, _T.report, null, 'abgelaufen am $until');
      }
      return (
        'Zertifikat geladen: Nummer ${c.serialHex}, gültig bis $until.',
        'Ausgestellt von ${parsed.issuer}.',
      );
    }
    // Am Testsystem ist das Zertifikat des Test-Benutzers seit 2020
    // abgelaufen (Befunde aus Task 1); für Testbons ist das egal.
    return (
      'Zertifikat geladen: Nummer ${c.serialHex}.',
      expired
          ? 'Test-Zertifikat von A-Trust (${parsed.issuer}), abgelaufen am '
                '$until. Für die Online-Probe ist das in Ordnung.'
          : 'Test-Zertifikat von A-Trust (${parsed.issuer}), gültig bis '
                '$until.',
    );
  }

  static String _mismatch(String reason) =>
      'Das Zertifikat von A-Trust passt nicht: $reason.';

  static _RowFailure _failureOf(Object e) => switch (e) {
    _RowFailure() => e,
    TimeoutException() => const _RowFailure(_T.noAnswer, _T.later),
    AtrustException(problem: AtrustProblem.rejected) => _RowFailure(
      e.sentence,
      _T.rejectedHint,
      e.status,
      e.detail,
    ),
    AtrustException() => _RowFailure(
      e.sentence,
      _hintOf(e.problem),
      e.status,
      e.detail,
    ),
    SignatureFailure() => _RowFailure(e.reason, _hintOfSentence(e.reason)),
    // Nur der Typ: der Text eines fremden Fehlers kann Geheimnisse enthalten.
    _ => _RowFailure(_T.failed, _T.report, null, '${e.runtimeType}'),
  };

  static String _hintOf(AtrustProblem problem) => switch (problem) {
    AtrustProblem.noInternet => _T.wifi,
    AtrustProblem.untrusted => _T.report,
    AtrustProblem.rejected => _T.rejectedHint,
    _ => _T.later,
  };

  /// Der Rat zu einem Satz der Online-Einheit: zu einem Satz von A-Trust
  /// wie bei Zeile 1, sonst (die Signatur passt nicht oder ist gescheitert)
  /// "Bericht schicken".
  static String _hintOfSentence(String sentence) {
    for (final p in AtrustProblem.values) {
      if (AtrustException(p).sentence == sentence) return _hintOf(p);
    }
    return _T.report;
  }

  void _ok(ConnectionRow row, String message, [String? hint]) =>
      _set(row, RowResult(RowState.ok, message, hint));

  void _set(ConnectionRow row, RowResult result) {
    _rows = Map.unmodifiable({..._rows, row: result});
    _publish(running: true);
  }

  /// Zeile [row] ist ein Problem, die folgenden warten.
  ConnectionCheckState _fail(ConnectionRow row, _RowFailure f) {
    final status = f.status;
    if (status != null) _statuses[row] = status;
    final detail = f.detail;
    if (detail != null) _details[row] = detail;
    _rows = Map.unmodifiable({
      ..._rows,
      row: RowResult(RowState.problem, f.message, f.hint),
      for (final later in ConnectionRow.values.skip(row.index + 1))
        later: const RowResult(RowState.waiting, _T.prerequisite),
    });
    return _finish(null);
  }

  ConnectionCheckState _finish(ConnectionFacts? facts) {
    final s = ConnectionCheckState(rows: _rows, running: false, facts: facts);
    _state.value = s;
    return s;
  }

  void _publish({required bool running}) =>
      _state.value = ConnectionCheckState(rows: _rows, running: running);

  /// Zeilen, Dauern, Statuscodes, Art des Fehlers, Zertifikat (Base64), nie
  /// Passwort oder Sitzungsschlüssel.
  String report() {
    final started = _startedAt;
    final certificate = _certificate;
    final out = StringBuffer()
      ..writeln(
        'Verbindung prüfen am ${started == null ? '-' : _dateTime(started)}',
      )
      ..writeln('Adresse: ${_client.system.base}');
    // Der Benutzer am echten System ist ein Geheimnis (Q12).
    if (_client.system == AtrustSystem.live) out.writeln('Konto: echtes Konto');
    out.writeln();
    for (final row in ConnectionRow.values) {
      final r = _rows[row]!;
      final hint = r.hint;
      final duration = _durations[row];
      final status = _statuses[row];
      final detail = _details[row];
      // Zeilen 1 und 4 nennen die Dauer schon im Satz.
      final ownDuration =
          duration != null && !r.message.contains(_seconds(duration));
      out.writeln(
        '${_titles[row]}: ${_word(r.state)}. ${r.message}'
        '${hint == null ? '' : ' $hint'}'
        '${ownDuration ? ' Dauer ${_seconds(duration)}.' : ''}'
        '${status == null ? '' : ' Status $status.'}'
        '${detail == null ? '' : ' Fehlerart: $detail.'}',
      );
    }
    out
      ..writeln()
      ..writeln('ZDA: ${_zdaId ?? '-'}')
      ..writeln(
        'Zertifikat (Base64): '
        '${certificate == null ? '-' : base64.encode(certificate.certificateDer)}',
      );
    for (final i in certificate?.issuersDer ?? const <Uint8List>[]) {
      out.writeln('Aussteller (Base64): ${base64.encode(i)}');
    }
    return out.toString();
  }

  void dispose() => _state.dispose();

  @override
  String toString() => 'ConnectionCheck';

  static const _titles = {
    ConnectionRow.reach: 'A-Trust',
    ConnectionRow.certificate: 'Zertifikat',
    ConnectionRow.login: 'Anmeldung',
    ConnectionRow.signature: 'Probe-Unterschrift',
  };

  static String _word(RowState state) => switch (state) {
    RowState.ok => 'gut',
    RowState.problem => 'Fehler',
    RowState.running => 'läuft',
    _ => 'offen',
  };
}

/// `0,2 Sekunden`: eine Nachkommastelle, mit Komma.
String _seconds(Duration d) =>
    '${(d.inMilliseconds / 1000).toStringAsFixed(1).replaceAll('.', ',')} '
    'Sekunden';

String _two(int n) => n.toString().padLeft(2, '0');

/// `TT.MM.JJJJ` in der Ortszeit des Tablets.
String _date(DateTime t) {
  final l = t.toLocal();
  return '${_two(l.day)}.${_two(l.month)}.${l.year}';
}

/// `TT.MM.JJJJ HH:MM:SS` in der Ortszeit des Tablets.
String _dateTime(DateTime t) {
  final l = t.toLocal();
  return '${_date(l)} ${_two(l.hour)}:${_two(l.minute)}:${_two(l.second)}';
}

/// Die Texte am Bildschirm.
abstract final class _T {
  static const reachWaiting = 'Die Kassa fragt bei A-Trust an.';
  static const certificateWaiting =
      'Seriennummer und Gültigkeit des Zertifikats.';
  static const certificateRunning = 'Wird geladen.';
  static const loginWaiting = 'Die Kassa meldet sich bei A-Trust an.';
  static const signatureWaiting =
      'A-Trust erstellt eine Unterschrift zur Probe, das Tablet prüft sie.';
  static const prerequisite = 'Erst wenn die Zeile darüber grün ist.';

  static const loggedIn = 'Angemeldet.';
  static const rejected = 'A-Trust hat die Zugangsdaten abgelehnt.';
  static const rejectedHint =
      'Die Kassa versucht es nicht von selbst noch einmal. "Nochmal prüfen" '
      'ist genau ein Versuch.';
  static const noAnswer = 'A-Trust hat nicht geantwortet.';
  static const cannotReadLogin =
      'Die Kassa konnte den Stand der Anmeldung nicht lesen.';
  static const notValid = 'Das Zertifikat von A-Trust ist nicht gültig.';
  static const failed = 'Die Prüfung ist gescheitert.';

  static const wifi = 'WLAN prüfen.';
  static const report = 'Bitte den Bericht schicken.';
  static const later = 'Später noch einmal versuchen.';
}

const _initialRows = {
  ConnectionRow.reach: RowResult(RowState.waiting, _T.reachWaiting),
  ConnectionRow.certificate: RowResult(RowState.waiting, _T.certificateWaiting),
  ConnectionRow.login: RowResult(RowState.waiting, _T.loginWaiting),
  ConnectionRow.signature: RowResult(RowState.waiting, _T.signatureWaiting),
};

const _runningText = {
  ConnectionRow.reach: _T.reachWaiting,
  ConnectionRow.certificate: _T.certificateRunning,
  ConnectionRow.login: _T.loginWaiting,
  ConnectionRow.signature: _T.signatureWaiting,
};
