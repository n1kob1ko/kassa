import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/devices/mono_image.dart';

/// RGBA-Bild aus einer Zeile Grauwerte je Punkt.
Uint8List _rgba(List<List<int>> gray) {
  final out = BytesBuilder();
  for (final row in gray) {
    for (final g in row) {
      out.add([g, g, g, 255]);
    }
  }
  return out.toBytes();
}

void main() {
  test('Zeilen auf ganze Bytes: 10 Punkte geben 2 Bytes je Zeile', () {
    final image = MonoImage.fromRgba(
      _rgba(List.filled(3, List.filled(10, 255))),
      10,
      3,
    );
    expect(image.width, 10);
    expect(image.height, 3);
    expect(image.rowBytes, 2);
    expect(image.bits.length, 6);
    expect(image.bits.every((b) => b == 0), isTrue);
  });

  test('Bit-Reihenfolge: der erste Punkt ist das höchste Bit', () {
    final row = List.filled(10, 255);
    row[0] = 0;
    row[7] = 0;
    row[8] = 0;
    final image = MonoImage.fromRgba(_rgba([row]), 10, 1);
    expect(image.bits, [0x81, 0x80]);
    expect(image.at(0, 0), isTrue);
    expect(image.at(1, 0), isFalse);
    expect(image.at(7, 0), isTrue);
    expect(image.at(8, 0), isTrue);
    expect(image.at(9, 0), isFalse);
  });

  test('Schwelle 160: dunkler ist schwarz, ab 160 weiß', () {
    final image = MonoImage.fromRgba(
      _rgba([
        [0, 120, 159, 160, 200, 255],
      ]),
      6,
      1,
    );
    expect(
      [for (var x = 0; x < 6; x++) image.at(x, 0)],
      [true, true, true, false, false, false],
    );
  });

  test('eigene Schwelle', () {
    final image = MonoImage.fromRgba(
      _rgba([
        [100, 200],
      ]),
      2,
      1,
      threshold: 90,
    );
    expect(image.at(0, 0), isFalse);
    expect(image.at(1, 0), isFalse);
  });

  test('Farbe zählt nach Helligkeit: reines Rot ist dunkel, Gelb hell', () {
    final rgba = Uint8List.fromList([255, 0, 0, 255, 255, 255, 0, 255]);
    final image = MonoImage.fromRgba(rgba, 2, 1);
    expect(image.at(0, 0), isTrue);
    expect(image.at(1, 0), isFalse);
  });

  test('zweite Zeile beginnt an einem neuen Byte', () {
    final image = MonoImage.fromRgba(
      _rgba([
        [255, 255, 255],
        [0, 255, 255],
      ]),
      3,
      2,
    );
    expect(image.bits, [0x00, 0x80]);
    expect(image.at(0, 1), isTrue);
  });
}
