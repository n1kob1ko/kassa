import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/devices/escpos.dart';
import 'package:kassa/devices/mono_image.dart';
import 'package:kassa/domain/business_info.dart';
import 'package:kassa/domain/print_document.dart';
import 'package:kassa/domain/receipt.dart';
import 'package:kassa/domain/receipt_layout.dart';

import '../support/sales.dart';

void main() {
  test(
    'beginnt mit Start und Zeichensatz',
    () =>
        expect(encodeEscPos([]).sublist(0, 5), [0x1B, 0x40, 0x1B, 0x74, 0x13]),
  );

  test('Umlaute und Euro in PC858', () {
    int? b(String s) => pc858(s.runes.first);
    expect(b('ä'), 0x84);
    expect(b('ö'), 0x94);
    expect(b('ü'), 0x81);
    expect(b('Ä'), 0x8E);
    expect(b('Ö'), 0x99);
    expect(b('Ü'), 0x9A);
    expect(b('ß'), 0xE1);
    expect(b('€'), 0xD5);
    expect(b('A'), 0x41);
    expect(b('麻'), isNull);
  });

  test('jedes druckbare Zeichen hat ein eigenes Byte', () {
    final bytes = <int>{};
    for (final rune in pc858Characters.runes) {
      final byte = pc858(rune);
      expect(byte, isNotNull, reason: String.fromCharCode(rune));
      expect(bytes.add(byte!), isTrue, reason: String.fromCharCode(rune));
    }
    expect(bytes.length, pc858Characters.runes.length);
  });

  test(
    'eine fette zentrierte Zeile in doppelter Größe und danach eine normale',
    () {
      final b = encodeEscPos([
        const PrintText(
          'AB',
          align: PrintAlign.center,
          bold: true,
          size: PrintSize.doubleBoth,
        ),
        const PrintText('c'),
      ]).sublist(5);
      expect(b, [
        0x1B, 0x61, 1, 0x1B, 0x45, 1, 0x1D, 0x21, 0x11, 0x41, 0x42, 0x0A, //
        0x1B, 0x61, 0, 0x1B, 0x45, 0, 0x1D, 0x21, 0x00, 0x63, 0x0A,
      ]);
    },
  );

  test('gleiche Einstellungen werden nicht wiederholt', () {
    final b = encodeEscPos([const PrintText('a'), const PrintText('b')])
        .sublist(5);
    expect(b, [0x61, 0x0A, 0x62, 0x0A]);
  });

  test(
    'Text läuft durch printable, unbekannte Zeichen werden Fragezeichen',
    () {
      final b = encodeEscPos([const PrintText('ä麻')]).sublist(5);
      expect(b, [0x84, 0x3F, 0x0A]);
    },
  );

  test('Vorschub, Schnitt, Geldlade', () {
    expect(encodeEscPos([const PrintFeed(3), const PrintCut()]).sublist(5), [
      0x1B, 0x64, 3, 0x1D, 0x56, 0x42, 0x00, //
    ]);
    expect(encodeDrawerKick(), [0x1B, 0x70, 0x00, 0x19, 0xFA]);
    expect(encodeEscPos([const PrintDrawerKick()]).sublist(5), [
      0x1B,
      0x70,
      0x00,
      0x19,
      0xFA,
    ]);
  });

  test('Statusabfragen', () {
    expect(escposStatusPrinter, [0x10, 0x04, 0x01]);
    expect(escposStatusPaper, [0x10, 0x04, 0x04]);
  });

  test('ein ganzer Bon enthält nur Bytes, die der Drucker versteht', () async {
    final shop = await TestShop.open();
    addTearDown(shop.close);
    final Receipt r = await shop.sell('sale-escpos');
    final doc = layoutReceipt(
      r,
      const BusinessInfo(
        name: 'Beispiel-Imbiss',
        addressLines: ['Musterstraße 1', '1010 Wien'],
        vatId: 'ATU12345678',
        receiptFooter: 'Danke und bis bald!',
      ),
    );
    final bytes = encodeEscPos(doc);
    expect(bytes.length, greaterThan(200));
    expect(bytes.sublist(bytes.length - 4), [0x1D, 0x56, 0x42, 0x00]);
    // 0x00 kommt nur als Parameter eines Befehls vor (Ausrichtung, fett,
    // Größe, Schnitt), nie im Text.
    for (var i = 0; i < bytes.length; i++) {
      if (bytes[i] != 0x00) continue;
      final cmd = [bytes[i - 2], bytes[i - 1]];
      final isParam =
          (cmd[0] == 0x1B && (cmd[1] == 0x61 || cmd[1] == 0x45)) ||
          (cmd[0] == 0x1D && cmd[1] == 0x21) ||
          (i == bytes.length - 1 && cmd[1] == 0x42);
      expect(isParam, isTrue, reason: 'Byte 0x00 an Stelle $i');
    }
  });

  group('PrintQr', () {
    List<int> body(List<int> b) => b.sublist(5);

    List<int> command(int size) => [
      0x1B, 0x61, 1, //
      0x1D, 0x28, 0x6B, 0x04, 0x00, 0x31, 0x41, 0x32, 0x00,
      0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x43, size,
      0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x45, 0x31,
      0x1D, 0x28, 0x6B, 0x06, 0x00, 0x31, 0x50, 0x30, 0x41, 0x42, 0x43,
      0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x51, 0x30,
      0x1B, 0x61, 0,
    ];

    test('Befehl bei 48 Spalten: Punktgröße 5', () {
      expect(body(encodeEscPos([const PrintQr('ABC')])), command(5));
    });

    test('Befehl bei 42 Spalten: Punktgröße 5, bei 32 Spalten 4', () {
      expect(
        body(encodeEscPos([const PrintQr('ABC')], columns: 42)),
        command(5),
      );
      expect(
        body(encodeEscPos([const PrintQr('ABC')], columns: 32)),
        command(4),
      );
    });

    test('Ausrichtung davor bleibt nicht stehen: danach wieder links', () {
      final b = body(
        encodeEscPos([
          const PrintText('a', align: PrintAlign.right),
          const PrintQr('ABC'),
          const PrintText('b'),
        ]),
      );
      expect(b.sublist(b.length - 5), [0x1B, 0x61, 0, 0x62, 0x0A]);
    });

    test('Text mit 300 Zeichen: Länge in pL und pH', () {
      final b = body(encodeEscPos([PrintQr('A' * 300)]));
      // 300 + 3 = 303 = 0x012F
      final store = [0x1D, 0x28, 0x6B, 0x2F, 0x01, 0x31, 0x50, 0x30];
      var found = false;
      for (var i = 0; i + store.length <= b.length; i++) {
        if (List.generate(store.length, (k) => b[i + k]).join(',') ==
            store.join(',')) {
          found = true;
        }
      }
      expect(found, isTrue);
    });

    test('als Bild: Kopf, 72 Bytes Breite, Rand oben und unten leer', () {
      final b = body(encodeEscPos([PrintQr('A' * 300)], qrAsImage: true));
      expect(b.sublist(0, 3), [0x1B, 0x61, 1]);
      expect(b.sublist(3, 7), [0x1D, 0x76, 0x30, 0x00]);
      final xl = b[7], xh = b[8], yl = b[9], yh = b[10];
      final width = xl + 256 * xh;
      final height = yl + 256 * yh;
      expect(width, 72);
      final image = b.sublist(11, 11 + width * height);
      expect(image.length, width * height);
      expect(image.sublist(0, width).every((x) => x == 0), isTrue);
      expect(image.sublist((height - 1) * width).every((x) => x == 0), isTrue);
      // Es gibt dunkle Punkte, und die Ränder links und rechts sind leer.
      expect(image.any((x) => x != 0), isTrue);
      // Nach dem Bild wieder links.
      expect(b.sublist(11 + width * height), [0x1B, 0x61, 0]);
    });

    test('als Bild bei 32 Spalten: 48 Bytes Breite', () {
      final b = body(
        encodeEscPos([const PrintQr('ABC')], qrAsImage: true, columns: 32),
      );
      expect(b[7] + 256 * b[8], 48);
    });
  });

  group('Küchenbon als Rasterbild', () {
    /// Bild mit [height] Zeilen zu 576 Punkten; Zeile y hat das Byte y & 0xFF
    /// an jeder Stelle, damit die Streifen sich unterscheiden lassen.
    MonoImage image(int height, {int width = 576}) {
      final rowBytes = (width + 7) ~/ 8;
      final bits = Uint8List(rowBytes * height);
      for (var y = 0; y < height; y++) {
        bits.fillRange(y * rowBytes, (y + 1) * rowBytes, y & 0xFF);
      }
      return MonoImage(width, height, bits);
    }

    /// Die Streifen (Breite in Bytes, Höhe, Daten) ab [start], und wo sie enden.
    (List<(int, int, List<int>)>, int) strips(List<int> b, int start) {
      final out = <(int, int, List<int>)>[];
      var i = start;
      while (i + 8 <= b.length &&
          b[i] == 0x1D &&
          b[i + 1] == 0x76 &&
          b[i + 2] == 0x30 &&
          b[i + 3] == 0x00) {
        final w = b[i + 4] + 256 * b[i + 5];
        final h = b[i + 6] + 256 * b[i + 7];
        out.add((w, h, b.sublist(i + 8, i + 8 + w * h)));
        i += 8 + w * h;
      }
      return (out, i);
    }

    test('Start, ein Streifen, 3 Zeilen Vorschub, Schnitt', () {
      final b = encodeRasterTicket(image(100));
      expect(b.sublist(0, 2), [0x1B, 0x40]);
      final (s, end) = strips(b, 2);
      expect(s.length, 1);
      expect(s[0].$1, 72);
      expect(s[0].$2, 100);
      expect(b.sublist(end), [0x1B, 0x64, 0x03, 0x1D, 0x56, 0x42, 0x00]);
    });

    test('500 Zeilen geben 3 Streifen zu 240, 240 und 20 Zeilen', () {
      final img = image(500);
      final b = encodeRasterTicket(img);
      final (s, end) = strips(b, 2);
      expect([for (final x in s) x.$2], [240, 240, 20]);
      expect(s.every((x) => x.$1 == 72), isTrue);
      // Die Streifen ergeben zusammen genau das Bild.
      expect([for (final x in s) ...x.$3], img.bits);
      expect(end, b.length - 7);
    });

    test('Breite in Bytes aufgerundet: 384 gibt 48, 504 gibt 63', () {
      expect(strips(encodeRasterTicket(image(10, width: 384)), 2).$1[0].$1, 48);
      expect(strips(encodeRasterTicket(image(10, width: 504)), 2).$1[0].$1, 63);
    });

    test('Kopf des Streifens: Breite und Höhe in je zwei Bytes', () {
      final b = encodeRasterTicket(image(240));
      expect(b.sublist(2, 10), [0x1D, 0x76, 0x30, 0x00, 72, 0, 240, 0]);
    });
  });
}
