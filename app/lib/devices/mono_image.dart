// Ein Bild mit einem Bit je Punkt, wie es der Bondrucker als Raster nimmt.
// Reines Dart, ohne Flutter.

import 'dart:typed_data';

/// Schwarz oder weiß je Punkt. Jede Zeile beginnt an einem ganzen Byte, der
/// erste Punkt einer Zeile ist das höchste Bit; ein gesetztes Bit ist schwarz.
class MonoImage {
  MonoImage(this.width, this.height, this.bits)
    : assert(bits.length == ((width + 7) >> 3) * height);

  /// Wandelt RGBA-Punkte (4 Bytes je Punkt, Zeile für Zeile) um: schwarz ist
  /// ein Punkt, dessen Helligkeit unter [threshold] (0 bis 255) liegt.
  /// Durchsichtige Punkte zählen wie auf weißem Papier: ganz durchsichtig ist
  /// weiß, halb durchsichtig wird mit Weiß gemischt.
  factory MonoImage.fromRgba(
    Uint8List rgba,
    int width,
    int height, {
    int threshold = 160,
  }) {
    assert(rgba.length >= width * height * 4);
    final rowBytes = (width + 7) >> 3;
    final bits = Uint8List(rowBytes * height);
    // Helligkeit nach BT.601 in ganzen Zahlen (Gewichte zusammen 256), auf
    // Weiß gemischt nach Deckkraft (0 bis 255). Verglichen wird mit 256 * 255
    // multipliziert, damit die Schleife ohne Division auskommt.
    const white = 255 << 8;
    final limit = (threshold << 8) * 255;
    var p = 0;
    for (var y = 0; y < height; y++) {
      final row = y * rowBytes;
      for (var x = 0; x < width; x++, p += 4) {
        final alpha = rgba[p + 3];
        final lum = rgba[p] * 77 + rgba[p + 1] * 150 + rgba[p + 2] * 29;
        if (lum * alpha + white * (255 - alpha) < limit) {
          bits[row + (x >> 3)] |= 0x80 >> (x & 7);
        }
      }
    }
    return MonoImage(width, height, bits);
  }

  final int width;
  final int height;
  final Uint8List bits;

  /// Bytes je Zeile.
  int get rowBytes => (width + 7) >> 3;

  /// Ist der Punkt bei [x], [y] schwarz?
  bool at(int x, int y) =>
      bits[y * rowBytes + (x >> 3)] & (0x80 >> (x & 7)) != 0;
}
