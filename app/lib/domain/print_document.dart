// Ein Druckauftrag als Liste von Anweisungen, unabhängig vom Drucker. Reines
// Dart, ohne Flutter und ohne Datenbank. Die Umsetzung in Druckerbytes folgt
// an anderer Stelle.

enum PrintAlign { left, center, right }

enum PrintSize { normal, doubleHeight, doubleBoth }

sealed class PrintOp {
  const PrintOp();
}

/// Eine Zeile Text. Der Text ist schon auf die Zeichen des Druckers
/// beschränkt und passt in die Papierbreite.
class PrintText extends PrintOp {
  const PrintText(
    this.text, {
    this.align = PrintAlign.left,
    this.bold = false,
    this.size = PrintSize.normal,
  });

  final String text;
  final PrintAlign align;
  final bool bold;
  final PrintSize size;
}

/// Papiervorschub um [lines] Zeilen.
class PrintFeed extends PrintOp {
  const PrintFeed(this.lines);

  final int lines;
}

/// Ein QR-Code, mittig. [data] ist reines ASCII.
class PrintQr extends PrintOp {
  const PrintQr(this.data);

  final String data;
}

class PrintCut extends PrintOp {
  const PrintCut();
}

class PrintDrawerKick extends PrintOp {
  const PrintDrawerKick();
}

/// Zeichen oberhalb von ASCII in der Zeichentabelle PC858, in der Reihenfolge
/// der Tabelle (ohne die Rahmenzeichen). Der Drucker kann diese Zeichen.
const String pc858Extra =
    'ÇüéâäàåçêëèïîìÄÅ'
    'ÉæÆôöòûùÿÖÜø£Ø×ƒ'
    'áíóúñÑªº¿®¬½¼¡«»'
    'ÁÂÀ©¢¥'
    'ãÃ¤ðÐÊËÈ€ÍÎÏ'
    '¦ÌÓßÔÒõÕµþÞÚÛÙýÝ¯´'
    '±¾¶§÷¸°¨·¹³²';

/// Alle druckbaren Zeichen: ASCII 0x20 bis 0x7E und [pc858Extra].
final String pc858Characters = [
  for (var c = 0x20; c <= 0x7E; c++) String.fromCharCode(c),
  pc858Extra,
].join();
