// Übersetzt Druckanweisungen in ESC/POS-Bytes für Bondrucker. Reines Dart,
// ohne Flutter. Die Befehle sind fest und nicht einstellbar.

import 'dart:typed_data';

import 'package:qr/qr.dart';

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
///
/// Mit [qrAsImage] geht ein QR-Code als Rasterbild hinaus statt mit dem
/// QR-Befehl des Druckers. [columns] ist die Breite des Papiers in Zeichen.
Uint8List encodeEscPos(
  List<PrintOp> document, {
  bool qrAsImage = false,
  int columns = 48,
}) {
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
      case PrintQr():
        if (align != PrintAlign.center) out.add([0x1B, 0x61, 1]);
        out.add(
          qrAsImage ? _qrImage(op.data, columns) : _qrCommand(op.data, columns),
        );
        out.add([0x1B, 0x61, 0]);
        align = PrintAlign.left;
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

/// Größe der Punkte (Module) eines QR-Codes: 5 ab 42 Spalten, sonst 4.
int _qrDot(int columns) => columns >= 42 ? 5 : 4;

/// Der Text des QR-Codes als Bytes: ASCII bleibt, alles andere wird `?`.
List<int> _qrBytes(String data) => [
  for (final unit in data.codeUnits) unit <= 0x7E ? unit : _unknown,
];

/// QR-Code mit den Befehlen des Druckers (GS ( k): Modell 2, Punktgröße,
/// Fehlerkorrektur M, Daten speichern, drucken. Das Papier ist schon mittig
/// ausgerichtet.
List<int> _qrCommand(String data, int columns) {
  final bytes = _qrBytes(data);
  final length = bytes.length + 3;
  return [
    0x1D, 0x28, 0x6B, 0x04, 0x00, 0x31, 0x41, 0x32, 0x00, //
    0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x43, _qrDot(columns),
    0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x45, 0x31,
    0x1D, 0x28, 0x6B, length & 0xFF, length >> 8, 0x31, 0x50, 0x30,
    ...bytes,
    0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x51, 0x30,
  ];
}

/// QR-Code als Rasterbild (GS v 0). Das Bild ist so breit wie das Papier
/// (12 Punkte je Spalte), der Code steht mittig, ringsum 4 Module Rand. Wird
/// der Code zu breit für die gewünschte Punktgröße, werden die Punkte kleiner.
List<int> _qrImage(String data, int columns) {
  final qr = QrImage(
    QrCode(
      payload: QrPayload.fromString(String.fromCharCodes(_qrBytes(data))),
      errorCorrectLevel: QrErrorCorrectLevel.medium,
    ),
  );
  const quiet = 4;
  final modules = qr.moduleCount + 2 * quiet;
  final widthBytes = (columns * 12 + 7) ~/ 8;
  final widthDots = widthBytes * 8;
  var dot = _qrDot(columns);
  while (dot > 1 && modules * dot > widthDots) {
    dot--;
  }
  final height = modules * dot;
  final left = (widthDots - modules * dot) ~/ 2;
  final image = Uint8List(widthBytes * height);
  for (var row = 0; row < qr.moduleCount; row++) {
    for (var col = 0; col < qr.moduleCount; col++) {
      if (!qr.isDark(row, col)) continue;
      for (var dy = 0; dy < dot; dy++) {
        final y = (row + quiet) * dot + dy;
        for (var dx = 0; dx < dot; dx++) {
          final x = left + (col + quiet) * dot + dx;
          image[y * widthBytes + (x >> 3)] |= 0x80 >> (x & 7);
        }
      }
    }
  }
  return [
    0x1D, 0x76, 0x30, 0x00, //
    widthBytes & 0xFF, widthBytes >> 8, height & 0xFF, height >> 8,
    ...image,
  ];
}
