// Die Antwort der Karte beim Einschalten (ATR, ISO 7816-3): Protokolle,
// Blockgröße und Wartezeit für T=1, die Bytes des Herstellers.

import 'dart:typed_data';

class Atr {
  Atr._({
    required this.bytes,
    required this.inverse,
    required this.protocols,
    required this.ta1,
    required this.tc1,
    required this.ta2,
    required this.ifsc,
    required this.waiting,
    required this.crc,
    required this.historical,
    required this.checksumOk,
  });

  /// [FormatException] bei zu kurzer oder kaputter ATR.
  static Atr parse(Uint8List bytes) {
    final raw = Uint8List.fromList(bytes);
    if (raw.length > _maxLength) {
      throw const FormatException('ATR zu lang');
    }
    var at = 0;
    int next() {
      if (at >= raw.length) throw const FormatException('ATR abgeschnitten');
      return raw[at++];
    }

    final ts = next();
    if (ts != _direct && ts != _inverse) {
      throw const FormatException('ATR beginnt weder mit 3B noch mit 3F');
    }
    final t0 = next();
    final historicalLength = t0 & 0x0F;
    final protocols = <int>[];
    int? ta1, tc1, ta2, ifsc, waiting, tc3;
    var indicator = t0 >> 4;
    for (var group = 1; ; group++) {
      final ta = indicator & 0x1 != 0 ? next() : null;
      final tb = indicator & 0x2 != 0 ? next() : null;
      final tc = indicator & 0x4 != 0 ? next() : null;
      final td = indicator & 0x8 != 0 ? next() : null;
      if (group == 1) {
        ta1 = ta;
        tc1 = tc;
      } else if (group == 2) {
        ta2 = ta;
      } else {
        ifsc ??= ta;
        waiting ??= tb;
        tc3 ??= tc;
      }
      if (td == null) break;
      protocols.add(td & 0x0F);
      indicator = td >> 4;
    }
    if (protocols.isEmpty) protocols.add(0);

    if (at + historicalLength > raw.length) {
      throw const FormatException('ATR abgeschnitten');
    }
    final historical = raw.sublist(at, at + historicalLength);
    at += historicalLength;

    // Ein Prüfbyte gibt es, sobald ein anderes Protokoll als T=0 dasteht.
    final hasCheck = protocols.any((p) => p != 0);
    if (hasCheck) next();
    if (at != raw.length) {
      throw const FormatException('ATR hat Bytes zu viel');
    }
    var check = 0;
    for (var i = 1; i < raw.length; i++) {
      check ^= raw[i];
    }

    return Atr._(
      bytes: raw,
      inverse: ts == _inverse,
      protocols: List.unmodifiable(protocols),
      ta1: ta1,
      tc1: tc1,
      ta2: ta2,
      ifsc: ifsc ?? _defaultIfsc,
      waiting: waiting ?? _defaultWaiting,
      crc: tc3 != null && tc3 & 0x01 != 0,
      historical: historical,
      checksumOk: !hasCheck || check == 0,
    );
  }

  static const _direct = 0x3B;
  static const _inverse = 0x3F;
  static const _maxLength = 33;
  static const _defaultIfsc = 32;
  static const _defaultWaiting = 0x4D;

  final Uint8List bytes;

  /// Das erste Byte ist `3F`.
  final bool inverse;

  /// Die Protokolle in der Reihenfolge der Karte; ohne Angabe `[0]`.
  final List<int> protocols;
  final int? ta1, tc1, ta2;

  /// Das erste TA ab der dritten Gruppe, sonst 32.
  final int ifsc;

  /// Das erste TB ab der dritten Gruppe, sonst `4D`.
  final int waiting;

  /// Bit 0 des ersten TC ab der dritten Gruppe: Prüfsumme CRC statt LRC.
  final bool crc;
  final Uint8List historical;

  /// XOR ab dem zweiten Byte ist 0; ohne Prüfbyte `true`.
  final bool checksumOk;

  /// Bei gesetztem [ta2] dessen untere 4 Bits, sonst das erste aus [protocols].
  int get firstProtocol => ta2 != null ? ta2! & 0x0F : protocols.first;
}
