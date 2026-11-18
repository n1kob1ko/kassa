import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/rksv/card/probe_log.dart';
import 'package:kassa/rksv/card/t1.dart';

import '../../support/scripted_reader.dart';

/// Ein erwarteter Austausch: dieser Block hinaus, jener zurück.
class Step {
  const Step(this.out, this.answer, {this.bwi = 0});

  final String out;
  final String answer;
  final int bwi;
}

/// Ein Austausch, der genau die Blöcke aus [steps] erwartet. Am Ende des
/// Tests scheitert er, wenn ein erwarteter Block fehlt.
class ScriptedExchange {
  ScriptedExchange(List<Step> steps) : _steps = List.of(steps) {
    addTearDown(() {
      if (_steps.isNotEmpty) {
        fail(
          '${_steps.length} erwartete Blöcke fehlen, der nächste: '
          '${_steps.first.out}',
        );
      }
    });
  }

  final List<Step> _steps;

  /// Was hinausging, mit `bwi` und `secret`.
  final List<({Uint8List block, int bwi, bool secret})> calls = [];

  Future<Uint8List> call(
    Uint8List block, {
    int bwi = 0,
    bool secret = false,
  }) async {
    calls.add((block: Uint8List.fromList(block), bwi: bwi, secret: secret));
    if (_steps.isEmpty) {
      throw TestFailure('Block ${calls.length} unerwartet');
    }
    final step = _steps.removeAt(0);
    expect(block, bytesOf(step.out), reason: 'Block ${calls.length}');
    expect(bwi, step.bwi, reason: 'bwi bei Block ${calls.length}');
    return bytesOf(step.answer);
  }
}

/// Ein Block mit Prüfbyte: `00`, [pcb], Länge, [data], XOR.
String block(int pcb, List<int> data) {
  final bytes = [0x00, pcb, data.length, ...data];
  final lrc = bytes.fold(0, (a, b) => a ^ b);
  return hex(Uint8List.fromList([...bytes, lrc]));
}

const select3F00 = '00A4000C023F00';
const selectDF01 = '00A4000C02DF01';

Future<T1Exception> t1Failure(Future<Object?> Function() call) async {
  try {
    await call();
  } on T1Exception catch (e) {
    return e;
  }
  fail('erwartet T1Exception');
}

void main() {
  test('ein kurzer Befehl: 00000700A4000C023F0092 hin, 000002900092 zurück, Ergebnis 9000', () async {
    final exchange = ScriptedExchange([
      const Step('00000700A4000C023F0092', '000002900092'),
    ]);
    final t1 = T1(exchange.call, ifsc: 254);
    expect(await t1.transmit(bytesOf(select3F00)), bytesOf('9000'));
    expect(exchange.calls.single.secret, isFalse);
  });

  test('der zweite Befehl trägt die Nummer 1: 00400700A4000C02DF0133, Antwort 0040029000D2', () async {
    final exchange = ScriptedExchange([
      const Step('00000700A4000C023F0092', '000002900092'),
      const Step('00400700A4000C02DF0133', '0040029000D2'),
      // Beide Nummern sind wieder bei 0.
      const Step('00000700A4000C023F0092', '000002900092'),
    ]);
    final t1 = T1(exchange.call, ifsc: 254);
    expect(await t1.transmit(bytesOf(select3F00)), bytesOf('9000'));
    expect(await t1.transmit(bytesOf(selectDF01)), bytesOf('9000'));
    expect(await t1.transmit(bytesOf(select3F00)), bytesOf('9000'));
  });

  test('Antwort in zwei Teilen: 002004AAAAAAAA24, Kassa schickt 00900090, dann 004003BB900068', () async {
    final exchange = ScriptedExchange([
      const Step('00000700A4000C023F0092', '002004AAAAAAAA24'),
      const Step('00900090', '004003BB900068'),
      // Eigene Nummer 1, die Karte hat zwei Blöcke geschickt: wieder 0.
      const Step('00400700A4000C02DF0133', '000002900092'),
    ]);
    final t1 = T1(exchange.call, ifsc: 254);
    expect(await t1.transmit(bytesOf(select3F00)), bytesOf('AAAAAAAABB9000'));
    expect(await t1.transmit(bytesOf(selectDF01)), bytesOf('9000'));
  });

  test(
    'ein Befehl länger als ifsc wird geteilt; die Karte bestätigt mit 00900090',
    () async {
      final exchange = ScriptedExchange([
        const Step('00200400A4000C8C', '00900090'),
        const Step('004003023F007E', '000002900092'),
      ]);
      final t1 = T1(exchange.call, ifsc: 4);
      expect(await t1.transmit(bytesOf(select3F00)), bytesOf('9000'));
    },
  );

  test('WTX: Karte schickt 00C30102C0, Kassa 00E30102E0 und bwi 2 beim nächsten Austausch', () async {
    final exchange = ScriptedExchange([
      const Step('00000700A4000C023F0092', '00C30102C0'),
      const Step('00E30102E0', '000002900092', bwi: 2),
      const Step('00400700A4000C02DF0133', '0040029000D2'),
    ]);
    final t1 = T1(exchange.call, ifsc: 254);
    expect(await t1.transmit(bytesOf(select3F00)), bytesOf('9000'));
    expect(await t1.transmit(bytesOf(selectDF01)), bytesOf('9000'));
    expect([for (final c in exchange.calls) c.bwi], [0, 2, 0]);
  });

  test('WTX 21-mal hintereinander endet mit T1Exception', () async {
    final exchange = ScriptedExchange([
      const Step('00000700A4000C023F0092', '00C30102C0'),
      for (var i = 0; i < 20; i++)
        const Step('00E30102E0', '00C30102C0', bwi: 2),
    ]);
    final t1 = T1(exchange.call, ifsc: 254);
    await t1Failure(() => t1.transmit(bytesOf(select3F00)));
    expect(exchange.calls, hasLength(21));
  });

  test('falsches Prüfbyte in der Antwort: Kassa schickt 00810081 und bekommt die Antwort neu', () async {
    final exchange = ScriptedExchange([
      const Step('00000700A4000C023F0092', '000002900093'),
      const Step('00810081', '000002900092'),
      const Step('00400700A4000C02DF0133', '0040029000D2'),
    ]);
    final t1 = T1(exchange.call, ifsc: 254);
    expect(await t1.transmit(bytesOf(select3F00)), bytesOf('9000'));
    expect(await t1.transmit(bytesOf(selectDF01)), bytesOf('9000'));
  });

  test(
    'dreimal falsches Prüfbyte: Neuabgleich 00C000C0 und T1Exception',
    () async {
      final exchange = ScriptedExchange([
        const Step('00000700A4000C023F0092', '000002900092'),
        const Step('00400700A4000C02DF0133', '0040029000D3'),
        const Step('00910091', '0040029000D3'),
        const Step('00910091', '0040029000D3'),
        const Step('00C000C0', '00E000E0'),
        // Nach dem Neuabgleich beginnen beide Nummern bei 0.
        const Step('00000700A4000C023F0092', '000002900092'),
      ]);
      final t1 = T1(exchange.call, ifsc: 254);
      expect(await t1.transmit(bytesOf(select3F00)), bytesOf('9000'));
      await t1Failure(() => t1.transmit(bytesOf(selectDF01)));
      expect(await t1.transmit(bytesOf(select3F00)), bytesOf('9000'));
    },
  );

  test('die Karte bestätigt den eigenen Block nicht (00800080): neu senden, höchstens dreimal', () async {
    final exchange = ScriptedExchange([
      const Step('00000700A4000C023F0092', '00800080'),
      for (var i = 0; i < 3; i++)
        const Step('00000700A4000C023F0092', '00800080'),
      const Step('00C000C0', '00E000E0'),
    ]);
    final t1 = T1(exchange.call, ifsc: 254);
    await t1Failure(() => t1.transmit(bytesOf(select3F00)));
  });

  test(
    'die Karte bestätigt nach einem neuen Senden: Antwort wie gewohnt',
    () async {
      final exchange = ScriptedExchange([
        const Step('00000700A4000C023F0092', '00800080'),
        const Step('00000700A4000C023F0092', '000002900092'),
      ]);
      final t1 = T1(exchange.call, ifsc: 254);
      expect(await t1.transmit(bytesOf(select3F00)), bytesOf('9000'));
    },
  );

  test('Blockgröße von der Karte: 00C10120E0 wird mit 00E10120C0 bestätigt, ifsc ist danach 32', () async {
    final data = [for (var i = 0; i < 35; i++) 0x11];
    final apdu = [0x00, 0xD6, 0x00, 0x00, 0x23, ...data];
    final exchange = ScriptedExchange([
      const Step('00000700A4000C023F0092', '00C10120E0'),
      const Step('00E10120C0', '000002900092'),
      // 40 Bytes: ein Stück mit 32, eines mit 8.
      Step(block(0x60, apdu.sublist(0, 32)), '00800080'),
      Step(block(0x00, apdu.sublist(32)), '0040029000D2'),
    ]);
    final t1 = T1(exchange.call, ifsc: 254);
    expect(await t1.transmit(bytesOf(select3F00)), bytesOf('9000'));
    expect(await t1.transmit(Uint8List.fromList(apdu)), bytesOf('9000'));
  });

  test('negotiateIfsd(254): 00C101FE3E hin, 00E101FE1E zurück', () async {
    final exchange = ScriptedExchange([
      const Step('00C101FE3E', '00E101FE1E'),
      // Die Nummern bleiben, wo sie waren.
      const Step('00000700A4000C023F0092', '000002900092'),
    ]);
    final t1 = T1(exchange.call, ifsc: 254);
    await t1.negotiateIfsd(254);
    expect(await t1.transmit(bytesOf(select3F00)), bytesOf('9000'));
  });

  test('negotiateIfsd: falsche Antwort dreimal ergibt T1Exception', () async {
    final exchange = ScriptedExchange([
      const Step('00C101FE3E', '00E10120C0'),
      const Step('00C101FE3E', '00E101FE1F'),
      const Step('00C101FE3E', '000002900092'),
    ]);
    final t1 = T1(exchange.call, ifsc: 254);
    await t1Failure(() => t1.negotiateIfsd(254));
  });

  test('negotiateIfsd: beim zweiten Versuch bestätigt', () async {
    final exchange = ScriptedExchange([
      const Step('00C101FE3E', '00E101FE1F'),
      const Step('00C101FE3E', '00E101FE1E'),
    ]);
    final t1 = T1(exchange.call, ifsc: 254);
    await t1.negotiateIfsd(254);
  });

  test('secret: falsches Prüfbyte in der Antwort ergibt sofort T1Exception, es geht kein weiterer Block hinaus', () async {
    final log = ProbeLog();
    final exchange = ScriptedExchange([
      const Step('00000700A4000C023F0092', '000002900093'),
    ]);
    final t1 = T1(exchange.call, ifsc: 254, log: log);
    final error = await t1Failure(
      () => t1.transmit(bytesOf(select3F00), secret: true),
    );
    expect(exchange.calls, hasLength(1));
    for (final text in [error.reason, error.toString(), ...log.lines]) {
      expect(text.toUpperCase(), isNot(contains('A4')));
      expect(text.toUpperCase(), isNot(contains('3F')));
    }
  });

  test(
    'secret: die Karte bestätigt nicht, der Block geht kein zweites Mal hinaus',
    () async {
      final exchange = ScriptedExchange([
        const Step('00000700A4000C023F0092', '00800080'),
      ]);
      final t1 = T1(exchange.call, ifsc: 254);
      await t1Failure(() => t1.transmit(bytesOf(select3F00), secret: true));
      expect(exchange.calls, hasLength(1));
    },
  );

  test('secret: ein Befehl länger als ifsc ergibt T1Exception, ohne etwas zu senden', () async {
    final exchange = ScriptedExchange([]);
    final t1 = T1(exchange.call, ifsc: 4);
    await t1Failure(() => t1.transmit(bytesOf(select3F00), secret: true));
    expect(exchange.calls, isEmpty);
  });

  test('secret wird an den Austausch durchgereicht', () async {
    final exchange = ScriptedExchange([
      const Step('00000700A4000C023F0092', '00C30102C0'),
      const Step('00E30102E0', '000002900092', bwi: 2),
      const Step('00400700A4000C02DF0133', '0040029000D2'),
    ]);
    final t1 = T1(exchange.call, ifsc: 254);
    expect(
      await t1.transmit(bytesOf(select3F00), secret: true),
      bytesOf('9000'),
    );
    expect(await t1.transmit(bytesOf(selectDF01)), bytesOf('9000'));
    // Nur der Block mit dem Befehl ist geheim, nicht die Antwort auf WTX.
    expect([for (final c in exchange.calls) c.secret], [true, false, false]);
  });

  test(
    'Müll von der Karte: nach drei Fehlern Neuabgleich und T1Exception',
    () async {
      final exchange = ScriptedExchange([
        const Step('00000700A4000C023F0092', '0000'),
        const Step('00820082', '00000590009F'),
        const Step('00820082', '00A0009F'),
        const Step('00C000C0', '00E000E0'),
      ]);
      final t1 = T1(exchange.call, ifsc: 254);
      await t1Failure(() => t1.transmit(bytesOf(select3F00)));
    },
  );

  test('T1Exception nennt keine Bytes', () {
    const error = T1Exception('Die Karte antwortet nicht passend.');
    expect(error.toString(), 'T1Exception: Die Karte antwortet nicht passend.');
  });
}
