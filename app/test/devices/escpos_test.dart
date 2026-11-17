import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/devices/escpos.dart';
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
}
