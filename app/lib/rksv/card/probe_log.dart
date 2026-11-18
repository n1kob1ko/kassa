// Sammelt die Zeilen für den Bericht "Karte prüfen".

import 'dart:typed_data';

class ProbeLog {
  final List<String> _lines = [];

  void line(String text) => _lines.add(text);

  /// `<label> AA BB CC` (ohne Bytes nur `<label>`); bei [secret] nur `<label> [geheim, N Bytes]`.
  void bytes(String label, Uint8List data, {bool secret = false}) => line(
    secret
        ? '$label [geheim, ${data.length} Bytes]'
        : data.isEmpty
        ? label
        : '$label ${hex(data)}',
  );

  List<String> get lines => List.unmodifiable(_lines);
}

/// `AA BB CC`: Großbuchstaben, ein Leerzeichen zwischen den Bytes.
String hex(Uint8List data) => data
    .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
    .join(' ');
