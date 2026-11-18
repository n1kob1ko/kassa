// Sammelt die Zeilen für den Bericht "Karte prüfen".

import 'dart:typed_data';

class ProbeLog {
  /// [clock] liefert die Uhrzeit; der Bericht nennt bei jeder Zeile die
  /// Millisekunden seit dem Anlegen dieses Protokolls.
  ProbeLog({DateTime Function()? clock}) : _clock = clock ?? DateTime.now {
    _start = _clock();
  }

  final DateTime Function() _clock;
  late final DateTime _start;
  final List<String> _lines = [];
  final List<int> _ms = [];

  void line(String text) {
    _lines.add(text);
    _ms.add(_clock().difference(_start).inMilliseconds);
  }

  /// `<label> AA BB CC` (ohne Bytes nur `<label>`); bei [secret] nur `<label> [geheim, N Bytes]`.
  void bytes(String label, Uint8List data, {bool secret = false}) => line(
    secret
        ? '$label [geheim, ${data.length} Bytes]'
        : data.isEmpty
        ? label
        : '$label ${hex(data)}',
  );

  /// Die Zeilen ohne Zeit.
  List<String> get lines => List.unmodifiable(_lines);

  /// Die Zeilen für den Bericht: vorne die Millisekunden seit dem Anlegen,
  /// rechtsbündig, etwa `   1234 ms  an Leser …`.
  List<String> get timedLines => List.unmodifiable([
    for (var i = 0; i < _lines.length; i++)
      '${'${_ms[i]}'.padLeft(_msWidth)} ms  ${_lines[i]}',
  ]);

  static const _msWidth = 7;
}

/// `AA BB CC`: Großbuchstaben, ein Leerzeichen zwischen den Bytes.
String hex(Uint8List data) => data
    .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
    .join(' ');
