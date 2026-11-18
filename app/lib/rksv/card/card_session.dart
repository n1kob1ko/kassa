// Eine Sitzung mit der Signaturkarte: einschalten, ATR prüfen, Parameter
// setzen, und dann nur Befehle aus atrust_card.dart schicken, über T=1
// (Stufe TPDU) oder unverändert (Stufe APDU).

import 'dart:math';
import 'dart:typed_data';

import 'atr.dart';
import 'atrust_card.dart';
import 'ccid.dart';
import 'probe_log.dart';
import 'reader_transport.dart';
import 't1.dart';

enum SessionProblem { readerNotSupported, cardNotSupported, connectionLost }

class SessionException implements Exception {
  const SessionException(this.problem, this.detail);

  final SessionProblem problem;

  /// Kurzer technischer Text für den Bericht (ATR als Hex, Name des Fehlers
  /// darunter, Status); nie Bytes eines Befehls mit PIN.
  final String detail;

  @override
  String toString() => 'SessionException(${problem.name}: $detail)';
}

class CardSession {
  CardSession._(this._reader, this.atr, this._t1, this._log);

  final CcidReader _reader;
  final Atr atr;

  /// `null` auf Stufe APDU.
  final T1? _t1;
  final ProbeLog? _log;

  /// Das Limit für jeden Lesevorgang des laufenden Befehls.
  Duration _limit = _shortLimit;

  static const _shortLimit = Duration(seconds: 3);
  static const _longLimit = Duration(seconds: 5);
  static const _maxIfsd = 254;

  /// Schaltet die Karte ein und bereitet die Übertragung vor.
  /// [CcidException] und [ReaderException] aus dem Einschalten kommen
  /// unverändert; danach endet jeder Fehler mit [SessionException], und die
  /// Karte ist wieder aus.
  static Future<CardSession> start(
    CcidReader reader,
    CcidDescriptor descriptor, {
    ProbeLog? log,
  }) async {
    final raw = await reader.powerOn();
    try {
      return await _prepare(reader, descriptor, raw, log);
    } on SessionException {
      await reader.powerOff();
      rethrow;
    }
  }

  static Future<CardSession> _prepare(
    CcidReader reader,
    CcidDescriptor descriptor,
    Uint8List raw,
    ProbeLog? log,
  ) async {
    final Atr atr;
    try {
      atr = Atr.parse(raw);
    } on FormatException {
      throw SessionException(
        SessionProblem.cardNotSupported,
        'ATR ${hex(raw)} nicht lesbar',
      );
    }
    final level = descriptor.level;
    if (level == ExchangeLevel.character) {
      throw const SessionException(
        SessionProblem.readerNotSupported,
        'Stufe character',
      );
    }
    final ta2 = atr.ta2;
    if (atr.firstProtocol != 1 ||
        atr.crc ||
        (ta2 != null && ta2 & 0x10 != 0) ||
        atr.ifsc < 1 ||
        atr.ifsc > _maxIfsd) {
      throw SessionException(
        SessionProblem.cardNotSupported,
        'ATR ${hex(atr.bytes)}',
      );
    }

    try {
      if (!descriptor.has(CcidFeature.autoNegotiation)) {
        // Ohne PPS (K1): die Geschwindigkeit der Karte nur, wenn sie sie
        // fest vorgibt.
        final fd = ta2 != null ? atr.ta1 ?? 0x11 : 0x11;
        final parameters = Uint8List.fromList([
          fd,
          0x10 | (atr.inverse ? 0x02 : 0x00),
          atr.tc1 ?? 0,
          atr.waiting,
          0x00,
          atr.ifsc,
          0x00,
        ]);
        try {
          await reader.setParameters(1, parameters);
        } on CcidException catch (e) {
          log?.line('Parameter nicht gesetzt ($e), es geht weiter');
        }
      }

      T1? t1;
      if (level == ExchangeLevel.tpdu) {
        late final CardSession session;
        t1 = T1(
          (block, {bwi = 0, secret = false}) => reader.transfer(
            block,
            bwi: bwi,
            secret: secret,
            limit: session._limit,
          ),
          ifsc: atr.ifsc,
          log: log,
        );
        session = CardSession._(reader, atr, t1, log);
        if (!descriptor.has(CcidFeature.autoIfsd)) {
          final ifsd = min(_maxIfsd, descriptor.maxIfsd);
          if (ifsd < 1) {
            log?.line('Leser nennt keine Blockgröße, es bleibt bei 32');
          } else {
            await t1.negotiateIfsd(ifsd);
          }
        }
        return session;
      }
      return CardSession._(reader, atr, null, log);
    } on T1Exception catch (e) {
      throw SessionException(SessionProblem.connectionLost, e.reason);
    } on CcidException catch (e) {
      throw SessionException(SessionProblem.connectionLost, '$e');
    } on ReaderException catch (e) {
      throw SessionException(SessionProblem.connectionLost, '$e');
    }
  }

  /// Schickt [command] und gibt die Antwort der Karte zurück. Jeder Fehler
  /// der Verbindung endet mit [SessionException] ([SessionProblem.connectionLost]).
  Future<CardResponse> send(CardCommand command) async {
    final out = Uint8List.fromList(command.bytes);
    final secret = command.secret;
    final shown = secret
        ? '${hex(out.sublist(0, 5))}${' **' * (out.length - 5)}'
        : hex(out);
    // VERIFY (20) und die Befehle zum Unterschreiben (2A) dürfen länger
    // dauern.
    _limit = out[1] == 0x20 || out[1] == 0x2A ? _longLimit : _shortLimit;

    final Uint8List answer;
    try {
      final t1 = _t1;
      answer = t1 != null
          ? await t1.transmit(out, secret: secret)
          : await _reader.transfer(out, secret: secret, limit: _limit);
    } on T1Exception catch (e) {
      throw _lost(command, shown, e.reason);
    } on CcidException catch (e) {
      throw _lost(command, shown, '$e');
    } on ReaderException catch (e) {
      throw _lost(command, shown, '$e');
    } finally {
      _limit = _shortLimit;
    }
    if (answer.length < 2) {
      throw _lost(command, shown, 'Antwort ohne Status');
    }
    final status = answer.sublist(answer.length - 2);
    _log?.line(
      '${command.label}: $shown; Antwort ${secret ? hex(status) : hex(answer)}',
    );
    return CardResponse(
      answer.sublist(0, answer.length - 2),
      status[0] << 8 | status[1],
    );
  }

  SessionException _lost(CardCommand command, String shown, String detail) {
    _log?.line('${command.label}: $shown; keine Antwort ($detail)');
    return SessionException(SessionProblem.connectionLost, detail);
  }

  /// Schaltet die Karte aus; wirft nie.
  Future<void> end() async {
    try {
      await _reader.powerOff();
    } catch (_) {
      // Ausschalten gelingt immer.
    }
  }
}
