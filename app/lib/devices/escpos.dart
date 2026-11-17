// Übersetzt Druckanweisungen in ESC/POS-Bytes für Bondrucker. Reines Dart,
// ohne Flutter. Die Befehle sind fest und nicht einstellbar.

import 'dart:typed_data';

import '../domain/print_document.dart';
import '../domain/receipt_layout.dart' show printable;

/// Statusabfrage: Zustand des Druckers (DLE EOT 1).
const escposStatusPrinter = [0x10, 0x04, 0x01];

/// Statusabfrage: Zustand des Papiersensors (DLE EOT 4).
const escposStatusPaper = [0x10, 0x04, 0x04];

const _init = [0x1B, 0x40];
const _selectPc858 = [0x1B, 0x74, 0x13];
const _cut = [0x1D, 0x56, 0x42, 0x00];
const _drawerKick = [0x1B, 0x70, 0x00, 0x19, 0xFA];
const _lineEnd = 0x0A;
const _unknown = 0x3F; // ?

/// Zeichen 0x80 bis 0xFF der Zeichentabelle PC858 (Codepage 850, Euro statt
/// punktlosem i). '\u0000' steht für Rahmen- und Blockzeichen und andere
/// Stellen, die der Bon nicht braucht.
const _pc858High =
    'ÇüéâäàåçêëèïîìÄÅ'
    'ÉæÆôöòûùÿÖÜø£Ø×ƒ'
    'áíóúñÑªº¿®¬½¼¡«»'
    '\u0000\u0000\u0000\u0000\u0000ÁÂÀ©\u0000\u0000\u0000\u0000¢¥\u0000'
    '\u0000\u0000\u0000\u0000\u0000\u0000ãÃ\u0000\u0000\u0000\u0000\u0000\u0000\u0000¤'
    'ðÐÊËÈ€ÍÎÏ\u0000\u0000\u0000\u0000¦Ì\u0000'
    'ÓßÔÒõÕµþÞÚÛÙýÝ¯´'
    '\u0000±\u0000¾¶§÷¸°¨·¹³²\u0000\u0000';

final Map<int, int> _pc858Bytes = () {
  final table = _pc858High.runes.toList();
  assert(table.length == 128);
  return {
    for (var i = 0; i < table.length; i++)
      if (table[i] != 0) table[i]: 0x80 + i,
  };
}();

/// Das Byte für [rune] in PC858, oder `null`, wenn der Drucker es nicht kann.
int? pc858(int rune) {
  if (rune >= 0x20 && rune <= 0x7E) return rune;
  return _pc858Bytes[rune];
}

/// Befehl, der die Geldlade öffnet.
Uint8List encodeDrawerKick() => Uint8List.fromList(_drawerKick);

/// Setzt [document] zu den Bytes um, die der Drucker versteht.
Uint8List encodeEscPos(List<PrintOp> document) {
  final out = BytesBuilder()
    ..add(_init)
    ..add(_selectPc858);

  // Zustand des Druckers nach der Initialisierung.
  var align = PrintAlign.left;
  var bold = false;
  var size = PrintSize.normal;

  for (final op in document) {
    switch (op) {
      case PrintText():
        if (op.align != align) {
          out.add([0x1B, 0x61, op.align.index]);
          align = op.align;
        }
        if (op.bold != bold) {
          out.add([0x1B, 0x45, op.bold ? 1 : 0]);
          bold = op.bold;
        }
        if (op.size != size) {
          out.add([0x1D, 0x21, _sizeByte(op.size)]);
          size = op.size;
        }
        for (final rune in printable(op.text).runes) {
          out.addByte(pc858(rune) ?? _unknown);
        }
        out.addByte(_lineEnd);
      case PrintFeed():
        out.add([0x1B, 0x64, op.lines.clamp(0, 255)]);
      case PrintCut():
        out.add(_cut);
      case PrintDrawerKick():
        out.add(_drawerKick);
    }
  }
  return out.toBytes();
}

int _sizeByte(PrintSize size) => switch (size) {
  PrintSize.normal => 0x00,
  PrintSize.doubleHeight => 0x01,
  PrintSize.doubleBoth => 0x11,
};
