// Die Übertragung T=1 (ISO 7816-3), wenn der Leser sie der Kassa überlässt:
// Befehle in Blöcke teilen, Antworten einsammeln, Fehler der Leitung
// begrenzt verkraften. Nur LRC als Prüfbyte. Ein Block mit PIN geht nie ein
// zweites Mal hinaus.

import 'dart:math';
import 'dart:typed_data';

import 'probe_log.dart';

/// Schickt einen Block zur Karte und gibt ihren Antwort-Block zurück. [bwi]
/// verlängert die Wartezeit; bei [secret] zeigt kein Protokoll die Bytes.
typedef BlockExchange = Future<Uint8List> Function(
  Uint8List block, {
  int bwi,
  bool secret,
});

class T1Exception implements Exception {
  const T1Exception(this.reason);

  /// Nennt nie die Bytes eines Blocks.
  final String reason;

  @override
  String toString() => 'T1Exception: $reason';
}

class T1 {
  /// [ifsc]: wie viele Bytes ein Block der Kassa höchstens trägt (1 bis 254).
  T1(this._exchange, {required int ifsc, this.log}) : _ifsc = ifsc {
    if (ifsc < 1 || ifsc > _maxInformation) {
      throw ArgumentError.value(ifsc, 'ifsc', 'nicht zwischen 1 und 254');
    }
  }

  final BlockExchange _exchange;
  final ProbeLog? log;
  int _ifsc;

  /// Die eigene Nummer des nächsten Daten-Blocks.
  int _ns = 0;

  /// Die erwartete Nummer des nächsten Daten-Blocks der Karte.
  int _nr = 0;

  static const _maxInformation = 254;
  static const _more = 0x20;
  static const _ack = 0x80;
  static const _checksumError = 0x01;
  static const _otherError = 0x02;
  static const _resyncRequest = 0xC0;
  static const _resyncResponse = 0xE0;
  static const _sizeRequest = 0xC1;
  static const _sizeResponse = 0xE1;
  static const _waitRequest = 0xC3;
  static const _waitResponse = 0xE3;

  static const _maxErrors = 3;
  static const _maxResends = 3;
  static const _maxWaits = 20;
  static const _maxSizeRequests = 3;
  static const _ifsdAttempts = 3;

  /// Mehr nimmt die Kassa als Antwort auf einen Befehl nicht an.
  static const _maxResponse = 65538;

  /// Schickt `C1` mit [ifsd]; [T1Exception], wenn die Karte es nach drei
  /// Versuchen nicht mit `E1` und demselben Byte bestätigt.
  Future<void> negotiateIfsd(int ifsd) async {
    if (ifsd < 1 || ifsd > _maxInformation) {
      throw ArgumentError.value(ifsd, 'ifsd', 'nicht zwischen 1 und 254');
    }
    final request = _block(_sizeRequest, [ifsd]);
    for (var attempt = 0; attempt < _ifsdAttempts; attempt++) {
      final answer = await _exchange(request);
      if (_frameError(answer) == 0 &&
          answer[1] == _sizeResponse &&
          answer[2] == 1 &&
          answer[3] == ifsd) {
        return;
      }
      log?.line('T=1: Karte bestätigt die Blockgröße nicht');
    }
    throw const T1Exception('Die Karte bestätigt die Blockgröße nicht.');
  }

  /// Schickt [apdu] und gibt die Antwort mit den zwei Status-Bytes zurück.
  /// Bei [secret] (Befehl mit PIN) endet jeder Fehler sofort mit
  /// [T1Exception], und der Befehl muss in einen Block passen.
  Future<Uint8List> transmit(Uint8List apdu, {bool secret = false}) async {
    if (apdu.isEmpty) throw ArgumentError.value(apdu.length, 'apdu', 'leer');
    if (secret && apdu.length > _ifsc) {
      throw const T1Exception('Der Befehl mit PIN passt nicht in einen Block.');
    }

    var start = 0;
    var end = min(apdu.length, _ifsc);
    Uint8List piece() => _block(
      _ns << 6 | (end < apdu.length ? _more : 0),
      apdu.sublist(start, end),
    );

    var out = piece();
    var outSecret = secret;
    var outIsAck = false;
    var bwi = 0;
    var sending = true;
    var errors = 0, resends = 0, waits = 0, sizeRequests = 0;
    final response = BytesBuilder(copy: false);

    while (true) {
      final answer = await _exchange(out, bwi: bwi, secret: outSecret);
      bwi = 0;
      outSecret = false;

      var error = _frameError(answer);
      if (error == 0) {
        final pcb = answer[1];
        final data = answer.sublist(3, answer.length - 1);
        if (pcb & 0x80 == 0) {
          // Daten-Block der Karte.
          if ((sending && end < apdu.length) || (pcb >> 6) & 1 != _nr) {
            error = _otherError;
          } else {
            if (sending) {
              // Er bestätigt den letzten eigenen Block.
              _ns ^= 1;
              sending = false;
            }
            _nr ^= 1;
            response.add(data);
            if (response.length > _maxResponse) {
              throw const T1Exception('Die Antwort der Karte ist zu lang.');
            }
            if (pcb & _more == 0) {
              if (response.length < 2) {
                throw const T1Exception(
                  'Die Antwort der Karte hat keinen Status.',
                );
              }
              return response.takeBytes();
            }
            out = _block(_ack | _nr << 4, const []);
            outIsAck = true;
            continue;
          }
        } else if (pcb & 0x40 == 0) {
          // Bestätigung der Karte.
          final expected = (pcb >> 4) & 1;
          if (data.isNotEmpty || pcb & _more != 0 || !sending) {
            error = _otherError;
          } else if (expected == _ns) {
            // Sie nennt wieder die alte Nummer: Block nicht angekommen.
            if (secret) {
              throw const T1Exception(
                'Die Karte hat den Befehl mit PIN nicht bestätigt.',
              );
            }
            if (resends == _maxResends) throw await _resync();
            resends++;
            log?.line('T=1: Karte hat den Block nicht bestätigt, neu gesendet');
            out = piece();
            outIsAck = false;
            continue;
          } else if (end < apdu.length) {
            // Das Stück ist angekommen, das nächste folgt.
            _ns ^= 1;
            start = end;
            end = min(apdu.length, start + _ifsc);
            out = piece();
            outIsAck = false;
            continue;
          } else {
            error = _otherError;
          }
        } else if (pcb == _waitRequest && data.length == 1) {
          if (waits == _maxWaits) {
            throw const T1Exception('Die Karte bittet zu oft um mehr Zeit.');
          }
          waits++;
          log?.line('T=1: Karte bittet um mehr Zeit (Faktor ${data[0]})');
          out = _block(_waitResponse, data);
          outIsAck = false;
          bwi = data[0];
          continue;
        } else if (pcb == _sizeRequest &&
            data.length == 1 &&
            data[0] >= 1 &&
            data[0] <= _maxInformation &&
            sizeRequests < _maxSizeRequests) {
          sizeRequests++;
          _ifsc = data[0];
          log?.line('T=1: Karte setzt die Blockgröße auf ${data[0]}');
          out = _block(_sizeResponse, data);
          outIsAck = false;
          continue;
        } else {
          error = _otherError;
        }
      }

      // Ein fehlerhafter oder unerwarteter Block.
      if (secret) {
        throw const T1Exception(
          'Die Antwort auf den Befehl mit PIN ist fehlerhaft.',
        );
      }
      errors++;
      if (errors == _maxErrors) throw await _resync();
      log?.line('T=1: Block der Karte fehlerhaft, neu angefordert');
      // War der letzte eigene Block eine Bestätigung, geht sie unverändert
      // noch einmal hinaus (ISO 7816-3, Regel 7.2).
      if (!outIsAck) {
        out = _block(_ack | _nr << 4 | error, const []);
        outIsAck = true;
      }
    }
  }

  /// Schickt einmal `C0`; bei `E0` beginnen beide Nummern wieder bei 0.
  /// Gibt die [T1Exception] zurück, mit der der Befehl endet.
  Future<T1Exception> _resync() async {
    log?.line('T=1: Neuabgleich');
    final answer = await _exchange(_block(_resyncRequest, const []));
    if (_frameError(answer) == 0 &&
        answer[1] == _resyncResponse &&
        answer[2] == 0) {
      _ns = 0;
      _nr = 0;
      return const T1Exception('Die Übertragung war gestört.');
    }
    return const T1Exception(
      'Die Übertragung war gestört, der Neuabgleich ist misslungen.',
    );
  }

  /// `0` für einen heilen Block, sonst das Fehlerbit für die Bestätigung.
  static int _frameError(Uint8List block) {
    if (block.length < 4 ||
        block[0] != 0x00 ||
        block[2] == 0xFF ||
        block.length != block[2] + 4) {
      return _otherError;
    }
    var check = 0;
    for (final b in block) {
      check ^= b;
    }
    return check == 0 ? 0 : _checksumError;
  }

  /// `00`, [pcb], Länge, [data], Prüfbyte.
  static Uint8List _block(int pcb, List<int> data) {
    final block = Uint8List(data.length + 4)
      ..[1] = pcb
      ..[2] = data.length
      ..setAll(3, data);
    var check = 0;
    for (var i = 0; i < block.length - 1; i++) {
      check ^= block[i];
    }
    block[block.length - 1] = check;
    return block;
  }
}
