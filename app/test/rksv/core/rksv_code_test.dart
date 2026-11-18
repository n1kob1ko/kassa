import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/rksv/core/rksv_code.dart';

void main() {
  final v = jsonDecode(
    File('test/rksv/fixtures/mustercode_vectors.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final key = base64Decode(v['aesKeyBase64'] as String);
  final box = v['cashBoxId'] as String;
  final counters = (v['counters'] as List).cast<Map<String, dynamic>>();
  final fake = base64Decode(v['fakeSignatureBase64'] as String);

  String enc(String id, int cents) => encryptCounter(
    aesKey: key,
    cashBoxId: box,
    receiptId: id,
    counterCents: cents,
  );

  CodeFields fields(
    String id,
    DateTime t,
    List<int> sums,
    String counter,
    String chain,
  ) => CodeFields(
    zdaId: 'AT1',
    cashBoxId: box,
    receiptId: id,
    time: t,
    sumsCents: sums,
    counterField: counter,
    certSerial: '1a2b3c',
    chain: chain,
  );

  group('Zähler', () {
    test('encryptCounter trifft alle Werte des Mustercodes', () {
      expect(counters, isNotEmpty);
      for (final c in counters) {
        expect(
          enc(c['receiptId'] as String, c['cents'] as int),
          c['encrypted'],
          reason: 'Beleg ${c['receiptId']}',
        );
      }
    });
    test('decryptCounter kehrt jeden Wert um', () {
      for (final c in counters) {
        expect(
          decryptCounter(
            aesKey: key,
            cashBoxId: box,
            receiptId: c['receiptId'] as String,
            field: c['encrypted'] as String,
          ),
          c['cents'],
        );
      }
    });
  });

  group('Kette', () {
    test('chainValue trifft die drei Kettenwerte', () {
      expect(chainValue(box), v['chainFromCashBoxId']);
      expect(chainValue(v['jws1'] as String), v['chainAfterJws1']);
      expect(chainValue(v['jws2Damaged'] as String), v['chainAfterJws2']);
    });
  });

  group('Code-Text', () {
    final chain1 = v['chainFromCashBoxId'] as String;
    final chain2 = v['chainAfterJws1'] as String;
    final chain3 = v['chainAfterJws2'] as String;
    final text1 = codeText(
      fields(
        '1',
        DateTime(2026, 11, 18, 13, 5, 9),
        [0, 0, 0, 0, 0],
        enc('1', 0),
        chain1,
      ),
    );
    final text2 = codeText(
      fields(
        '2',
        DateTime(2026, 11, 18, 13, 7, 41),
        [1290, 450, 0, 25, 0],
        enc('2', 1765),
        chain2,
      ),
    );

    test('text1 bis text4', () {
      expect(text1, v['text1']);
      expect(text2, v['text2']);
      expect(
        codeText(
          fields(
            '3',
            DateTime(2026, 12, 1),
            [-1290, -450, 0, -25, 0],
            v['stornoMarker'] as String,
            chain3,
          ),
        ),
        v['text3Storno'],
      );
      expect(
        codeText(
          fields(
            '4',
            DateTime(2027, 1, 2, 9),
            [99999, 0, 5, 0, -1],
            enc('4', 100003),
            chain3,
          ),
        ),
        v['text4'],
      );
    });
    test('wirft bei vier Summen und bei Unterstrich oder leerer Kennung', () {
      expect(
        () => codeText(fields('1', DateTime(2026), [0, 0, 0, 0], 'x', 'y')),
        throwsArgumentError,
      );
      expect(
        () => codeText(
          CodeFields(
            zdaId: 'AT1',
            cashBoxId: 'A_B',
            receiptId: '1',
            time: DateTime(2026),
            sumsCents: const [0, 0, 0, 0, 0],
            counterField: 'x',
            certSerial: 's',
            chain: 'c',
          ),
        ),
        throwsArgumentError,
      );
      expect(
        () => codeText(
          CodeFields(
            zdaId: 'AT1',
            cashBoxId: box,
            receiptId: '',
            time: DateTime(2026),
            sumsCents: const [0, 0, 0, 0, 0],
            counterField: 'x',
            certSerial: 's',
            chain: 'c',
          ),
        ),
        throwsArgumentError,
      );
    });

    test('JWS und QR', () {
      expect(jwsCompact(text1, fake), v['jws1']);
      expect(qrText(v['jws1'] as String), v['qr1']);
      expect(jwsDamaged(text2), v['jws2Damaged']);
      expect(qrText(v['jws2Damaged'] as String), v['qr2Damaged']);
      expect(isDamagedJws(v['jws2Damaged'] as String), isTrue);
      expect(isDamagedJws(v['jws1'] as String), isFalse);
      expect(v['damagedDetected'], isTrue);
      expect(
        jwsSigningInput(text1),
        (v['jws1'] as String).substring(
          0,
          (v['jws1'] as String).lastIndexOf('.'),
        ),
      );
    });
  });

  group('DER', () {
    Uint8List hex(String s) => Uint8List.fromList([
      for (var i = 0; i < s.length; i += 2)
        int.parse(s.substring(i, i + 2), radix: 16),
    ]);
    test('derSignatureToConcat trifft den Mustercode', () {
      expect(
        base64Encode(derSignatureToConcat(hex(v['derSignatureHex'] as String))),
        v['concatSignatureBase64'],
      );
    });
    test('kurzes R wird links mit 0 aufgefüllt', () {
      final r = List<int>.filled(31, 7);
      final s = List<int>.filled(32, 9);
      final der = Uint8List.fromList([
        0x30,
        2 + 31 + 2 + 32,
        0x02,
        31,
        ...r,
        0x02,
        32,
        ...s,
      ]);
      final out = derSignatureToConcat(der);
      expect(out.length, 64);
      expect(out[0], 0);
      expect(out.sublist(1, 32), r);
      expect(out.sublist(32), s);
    });
    test('Müll wirft FormatException', () {
      expect(
        () => derSignatureToConcat(Uint8List.fromList([1, 2, 3])),
        throwsFormatException,
      );
      expect(() => derSignatureToConcat(Uint8List(0)), throwsFormatException);
    });
  });

  test('formatCodeAmount', () {
    expect(formatCodeAmount(0), '0,00');
    expect(formatCodeAmount(5), '0,05');
    expect(formatCodeAmount(-1), '-0,01');
    expect(formatCodeAmount(123456), '1234,56');
    expect(formatCodeAmount(-129000), '-1290,00');
  });

  test('formatCodeTime', () {
    expect(
      formatCodeTime(DateTime(2026, 11, 18, 13, 5, 9)),
      '2026-11-18T13:05:09',
    );
  });
}
