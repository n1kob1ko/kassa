import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/rksv/card/ccid.dart';
import 'package:kassa/rksv/card/probe_log.dart';
import 'package:kassa/rksv/card/reader_transport.dart';

import '../../support/scripted_reader.dart';

// Die Einträge eines echten Lesers.
const device = '12 01 10 01 00 00 00 08 E6 04 11 55 00 02 01 02 03 01';
const configuration = '09 02 5D 00 01 01 00 80 32';
const readerInterface = '09 04 00 00 02 0B 00 00 00';
const ccidEntry =
    '36 21 10 01 00 07 03 00 00 00 C0 12 00 00 C0 12 00 00 00 80 25 00 00 00 '
    'B0 04 00 00 FE 00 00 00 00 00 00 00 00 00 00 00 30 00 01 00 0F 01 00 00 '
    '00 00 00 00 00 01';
const endpoints = '07 05 81 02 40 00 00 07 05 02 02 40 00 00';

// Ein Drucker an derselben Stelle: Schnittstelle der Klasse 07 und ein
// Eintrag vom Typ 21 mit anderen Werten.
const printerInterface = '09 04 00 00 02 07 01 02 00';
const printerEntry =
    '36 21 10 01 00 01 02 00 00 00 C0 12 00 00 C0 12 00 00 00 80 25 00 00 00 '
    'B0 04 00 00 20 00 00 00 00 00 00 00 00 00 00 00 FE 00 04 00 00 01 00 00 '
    '00 00 00 00 00 01';

const atr =
    '3B DF 97 00 81 31 FE 46 80 31 90 52 41 04 64 05 04 01 AC 73 D6 22 '
    'C0 F9';

/// Ein Leser, der die Spannung selbst wählt.
const autoReader = CcidDescriptor(
  voltageSupport: 0x07,
  protocols: 0x03,
  maxIfsd: 254,
  features: 0x000100BA,
  maxMessageLength: 271,
);

/// Der Leser aus dem Beispiel: Spannung wählt die Kassa.
final manualReader = CcidDescriptor.parse(
  bytesOf('$device $configuration $readerInterface $ccidEntry $endpoints'),
);

Future<Object?> errorOf(Future<Object?> Function() call) async {
  try {
    await call();
    return null;
  } catch (e) {
    return e;
  }
}

Future<CcidProblem?> problemOf(Future<Object?> Function() call) async {
  final error = await errorOf(call);
  if (error is CcidException) return error.problem;
  fail('erwartet CcidException, kam $error');
}

/// Eine leere Antwort auf ein `6F` mit Nummer [seq].
String emptyBlockAnswer(int seq) =>
    '80 00000000 00 ${seq.toRadixString(16).padLeft(2, '0')} 00 00 00';

String transferOut(int seq, String block) {
  final length = bytesOf(block).length.toRadixString(16).padLeft(2, '0');
  final number = seq.toRadixString(16).padLeft(2, '0');
  return '6F $length 000000 00 $number 00 0000 $block';
}

void main() {
  test('Deskriptor: Felder aus einem echten Beispiel', () {
    final d = manualReader;
    expect(d.voltageSupport, 7);
    expect(d.protocols, 3);
    expect(d.maxIfsd, 254);
    expect(d.features, 0x00010030);
    expect(d.level, ExchangeLevel.tpdu);
    expect(d.maxMessageLength, 271);
    expect(d.has(CcidFeature.autoVoltage), isFalse);
    expect(d.has(CcidFeature.autoActivation), isFalse);
  });

  test('Deskriptor: Stufe aus den Bits 16 bis 18 von dwFeatures', () {
    CcidDescriptor withFeatures(int f) => CcidDescriptor(
      voltageSupport: 1,
      protocols: 2,
      maxIfsd: 254,
      features: f,
      maxMessageLength: 271,
    );
    expect(withFeatures(0x000000BA).level, ExchangeLevel.character);
    expect(withFeatures(0x000100BA).level, ExchangeLevel.tpdu);
    expect(withFeatures(0x000200BA).level, ExchangeLevel.shortApdu);
    expect(withFeatures(0x000400BA).level, ExchangeLevel.extendedApdu);
    expect(withFeatures(0x000400BA).has(CcidFeature.autoPps), isTrue);
    expect(withFeatures(0x000400BA).has(CcidFeature.autoIfsd), isFalse);
  });

  test('Deskriptor: Schnittstelle der Klasse 07 davor wird übersprungen; '
      'ohne Eintrag FormatException', () {
    final d = CcidDescriptor.parse(
      bytesOf(
        '$device $configuration $printerInterface $printerEntry $endpoints '
        '$readerInterface $ccidEntry $endpoints',
      ),
    );
    expect(d.voltageSupport, 7);
    expect(d.maxIfsd, 254);
    expect(d.features, 0x00010030);

    expect(
      () => CcidDescriptor.parse(
        bytesOf(
          '$device $configuration $printerInterface $printerEntry $endpoints',
        ),
      ),
      throwsFormatException,
    );
    // Der Eintrag gehört zur nächsten Schnittstelle, nicht zum Leser.
    expect(
      () => CcidDescriptor.parse(
        bytesOf(
          '$device $configuration $readerInterface $endpoints '
          '$printerInterface $printerEntry',
        ),
      ),
      throwsFormatException,
    );
    expect(() => CcidDescriptor.parse(Uint8List(0)), throwsFormatException);
    // Abgeschnittener Eintrag.
    expect(
      () => CcidDescriptor.parse(
        bytesOf('$readerInterface ${ccidEntry.substring(0, 60)}'),
      ),
      throwsFormatException,
    );
  });

  test(
    'powerOn schickt 62 00000000 00 00 00 0000 und gibt die ATR zurück',
    () async {
      final reader = ScriptedReader([
        send('62 00000000 00 00 00 0000', '80 18000000 00 00 00 00 00 $atr'),
      ]);
      final ccid = CcidReader(reader, autoReader);
      expect(await ccid.powerOn(), bytesOf(atr));
    },
  );

  test(
    'powerOn ohne autoVoltage versucht 5 V, dann 3 V, schaltet dazwischen aus',
    () async {
      final reader = ScriptedReader([
        send('62 00000000 00 00 01 0000', '80 00000000 00 00 41 FE 00'),
        send('63 00000000 00 01 00 0000', '81 00000000 00 01 01 00 00'),
        send('62 00000000 00 02 02 0000', '80 18000000 00 02 00 00 00 $atr'),
      ]);
      final ccid = CcidReader(reader, manualReader);
      expect(await ccid.powerOn(), bytesOf(atr));
    },
  );

  test('powerOn nimmt nur Spannungen, die der Leser kann', () async {
    final reader = ScriptedReader([
      send('62 00000000 00 00 02 0000', '80 00000000 00 00 41 FE 00'),
      send('63 00000000 00 01 00 0000', '81 00000000 00 01 01 00 00'),
      send('62 00000000 00 02 03 0000', '80 00000000 00 02 41 FE 00'),
    ]);
    const onlyLow = CcidDescriptor(
      voltageSupport: 0x06,
      protocols: 0x02,
      maxIfsd: 254,
      features: 0x00010030,
      maxMessageLength: 271,
    );
    final ccid = CcidReader(reader, onlyLow);
    expect(await problemOf(ccid.powerOn), CcidProblem.cardMute);
  });

  test('powerOn: Status 42 mit Fehler FE und keine Karte ergibt cardAbsent; '
      'Status 41 mit FE ergibt cardMute', () async {
    // Keine Karte: die Reihe bricht nach 5 V ab.
    final absent = ScriptedReader([
      send('62 00000000 00 00 01 0000', '80 00000000 00 00 42 FE 00'),
    ]);
    expect(
      await problemOf(CcidReader(absent, manualReader).powerOn),
      CcidProblem.cardAbsent,
    );

    final mute = ScriptedReader([
      send('62 00000000 00 00 00 0000', '80 00000000 00 00 41 FE 00'),
    ]);
    expect(
      await problemOf(CcidReader(mute, autoReader).powerOn),
      CcidProblem.cardMute,
    );

    final noData = ScriptedReader([
      send('62 00000000 00 00 00 0000', '80 00000000 00 00 00 00 00'),
    ]);
    expect(
      await problemOf(CcidReader(noData, autoReader).powerOn),
      CcidProblem.cardMute,
    );

    final other = ScriptedReader([
      send('62 00000000 00 00 00 0000', '80 00000000 00 00 41 07 00'),
    ]);
    final error = await errorOf(CcidReader(other, autoReader).powerOn);
    expect(error, isA<CcidException>());
    expect((error as CcidException).problem, CcidProblem.commandFailed);
    expect(error.error, 0x07);
  });

  test(
    'setParameters schickt 61 07000000 00 nn 01 0000 und die 7 Bytes',
    () async {
      final reader = ScriptedReader([
        send('62 00000000 00 00 00 0000', '80 18000000 00 00 00 00 00 $atr'),
        send(
          '61 07000000 00 01 01 0000 11 10 00 45 00 FE 00',
          '82 07000000 00 01 00 00 01 11 10 00 45 00 FE 00',
        ),
      ]);
      final ccid = CcidReader(reader, autoReader);
      await ccid.powerOn();
      await ccid.setParameters(1, bytesOf('11 10 00 45 00 FE 00'));
    },
  );

  test('setParameters: Antwort vom Typ 80 ist badAnswer', () async {
    final reader = ScriptedReader([
      send(
        '61 07000000 00 00 01 0000 11 10 00 45 00 FE 00',
        '80 00000000 00 00 00 00 00',
      ),
    ]);
    final ccid = CcidReader(reader, autoReader);
    expect(
      await problemOf(
        () => ccid.setParameters(1, bytesOf('11 10 00 45 00 FE 00')),
      ),
      CcidProblem.badAnswer,
    );
  });

  test('transfer zählt die Nummer hoch und prüft sie in der Antwort', () async {
    final reader = ScriptedReader([
      send(
        '6F 04000000 00 00 00 0000 00 00 00 00',
        '80 04000000 00 00 00 00 00 00 00 00 00',
      ),
      send(
        '6F 04000000 00 01 05 0000 00 40 00 40',
        '80 06000000 00 01 00 00 00 00 40 02 90 00 D2',
      ),
      for (var seq = 2; seq < 256; seq++)
        send(transferOut(seq, 'AB'), emptyBlockAnswer(seq)),
      // Nach 255 wieder 0.
      send(transferOut(0, 'CD'), emptyBlockAnswer(0)),
      // Falsche Nummer, auch nach Weiterlesen.
      send(transferOut(1, 'EF'), emptyBlockAnswer(0)),
      read(emptyBlockAnswer(0)),
      read(emptyBlockAnswer(0)),
      read(emptyBlockAnswer(0)),
    ]);
    final ccid = CcidReader(reader, autoReader);
    expect(await ccid.transfer(bytesOf('00 00 00 00')), bytesOf('00 00 00 00'));
    expect(
      await ccid.transfer(bytesOf('00 40 00 40'), bwi: 5),
      bytesOf('00 40 02 90 00 D2'),
    );
    for (var seq = 2; seq < 256; seq++) {
      expect(await ccid.transfer(bytesOf('AB')), isEmpty);
    }
    expect(await ccid.transfer(bytesOf('CD')), isEmpty);
    expect(
      await problemOf(() => ccid.transfer(bytesOf('EF'))),
      CcidProblem.badAnswer,
    );
    expect(reader.limits.first, const Duration(seconds: 3));
  });

  test('transfer gibt das Limit an jeden Lesevorgang weiter', () async {
    final reader = ScriptedReader([
      send(transferOut(0, 'AB'), '80 00000000 00 00 80 01 00'),
      read(emptyBlockAnswer(0)),
    ]);
    final ccid = CcidReader(reader, autoReader);
    await ccid.transfer(bytesOf('AB'), limit: const Duration(seconds: 7));
    expect(reader.limits, [
      const Duration(seconds: 7),
      const Duration(seconds: 7),
    ]);
  });

  test(
    'transfer: Status 80 heißt weiterlesen; nach 30 Runden timeout',
    () async {
      const moreTime = '80 00000000 00 00 80 01 00';
      final patient = ScriptedReader([
        send(transferOut(0, 'AB'), moreTime),
        for (var i = 0; i < 29; i++) read(moreTime),
        read('80 02000000 00 00 00 00 00 90 00'),
      ]);
      expect(
        await CcidReader(patient, autoReader).transfer(bytesOf('AB')),
        bytesOf('90 00'),
      );

      final endless = ScriptedReader([
        send(transferOut(0, 'AB'), moreTime),
        for (var i = 0; i < 30; i++) read(moreTime),
      ]);
      final error = await errorOf(
        () => CcidReader(endless, autoReader).transfer(bytesOf('AB')),
      );
      expect(error, isA<ReaderException>());
      expect((error as ReaderException).problem, ReaderProblem.timeout);
    },
  );

  test('transfer: mehr Zeit endet nach 20 Sekunden mit timeout', () async {
    const moreTime = '80 00000000 00 00 80 01 00';
    var now = DateTime(2026, 11, 18, 9);
    final reader = ScriptedReader([
      send(transferOut(0, 'AB'), moreTime),
      for (var i = 0; i < 3; i++) read(moreTime),
    ], onExchange: () => now = now.add(const Duration(seconds: 6)));
    final ccid = CcidReader(reader, autoReader, clock: () => now);
    final error = await errorOf(() => ccid.transfer(bytesOf('AB')));
    expect(error, isA<ReaderException>());
    expect((error as ReaderException).problem, ReaderProblem.timeout);
  });

  test('transfer: eine Antwort mit alter Nummer wird übersprungen', () async {
    final reader = ScriptedReader([
      send(transferOut(0, 'AB'), emptyBlockAnswer(0)),
      send(transferOut(1, 'CD'), '80 01000000 00 00 00 00 00 99'),
      read('80 02000000 00 01 00 00 00 90 00'),
    ]);
    final ccid = CcidReader(reader, autoReader);
    await ccid.transfer(bytesOf('AB'));
    expect(await ccid.transfer(bytesOf('CD')), bytesOf('90 00'));
  });

  test(
    'transfer: Typ 81 statt 80 ist badAnswer; 9 Bytes sind badAnswer',
    () async {
      final wrongType = ScriptedReader([
        send(transferOut(0, 'AB'), '81 00000000 00 00 00 00 00'),
      ]);
      expect(
        await problemOf(
          () => CcidReader(wrongType, autoReader).transfer(bytesOf('AB')),
        ),
        CcidProblem.badAnswer,
      );

      final short = ScriptedReader([
        send(transferOut(0, 'AB'), '80 00000000 00 00 00 00'),
      ]);
      expect(
        await problemOf(
          () => CcidReader(short, autoReader).transfer(bytesOf('AB')),
        ),
        CcidProblem.badAnswer,
      );

      // Die Länge im Kopf verspricht mehr Daten, als kamen.
      final truncated = ScriptedReader([
        send(transferOut(0, 'AB'), '80 05000000 00 00 00 00 00 90 00'),
      ]);
      expect(
        await problemOf(
          () => CcidReader(truncated, autoReader).transfer(bytesOf('AB')),
        ),
        CcidProblem.badAnswer,
      );
    },
  );

  test('transfer: Karte gezogen ergibt cardAbsent', () async {
    final reader = ScriptedReader([
      send(transferOut(0, 'AB'), '80 00000000 00 00 42 FE 00'),
    ]);
    expect(
      await problemOf(
        () => CcidReader(reader, autoReader).transfer(bytesOf('AB')),
      ),
      CcidProblem.cardAbsent,
    );
  });

  test('ReaderException(io) aus dem Transport wird durchgereicht', () async {
    final unplugged = ScriptedReader([
      sendFails(transferOut(0, 'AB'), const ReaderException(ReaderProblem.io)),
    ]);
    final error = await errorOf(
      () => CcidReader(unplugged, autoReader).transfer(bytesOf('AB')),
    );
    expect(error, isA<ReaderException>());
    expect((error as ReaderException).problem, ReaderProblem.io);

    final duringPowerOn = ScriptedReader([
      sendFails(
        '62 00000000 00 00 01 0000',
        const ReaderException(ReaderProblem.io),
      ),
    ]);
    final powerOnError = await errorOf(
      CcidReader(duringPowerOn, manualReader).powerOn,
    );
    expect(powerOnError, isA<ReaderException>());
    expect((powerOnError as ReaderException).problem, ReaderProblem.io);

    final whileWaiting = ScriptedReader([
      send(transferOut(0, 'AB'), '80 00000000 00 00 80 01 00'),
      readFails(const ReaderException(ReaderProblem.io)),
    ]);
    final waitError = await errorOf(
      () => CcidReader(whileWaiting, autoReader).transfer(bytesOf('AB')),
    );
    expect((waitError as ReaderException).problem, ReaderProblem.io);
  });

  test('Protokoll: jede Nachricht hin und zurück als Hex', () async {
    final log = ProbeLog();
    final reader = ScriptedReader([
      send(transferOut(0, 'AB'), '80 00000000 00 00 80 01 00'),
      read('80 02000000 00 00 00 00 00 90 00'),
    ]);
    await CcidReader(reader, autoReader, log: log).transfer(bytesOf('AB'));
    expect(log.lines, [
      'an Leser 6F 01 00 00 00 00 00 00 00 00 AB',
      'vom Leser 80 00 00 00 00 00 00 80 01 00',
      'vom Leser 80 02 00 00 00 00 00 00 00 00 90 00',
    ]);
  });

  test('secret: das Protokoll zeigt [geheim, N Bytes] statt der Bytes, '
      'in beiden Richtungen', () async {
    final log = ProbeLog();
    final reader = ScriptedReader([
      send(
        transferOut(0, '00 00 0D 00 20 00 8A 08 26 11 22 33 FF FF FF FF 6F'),
        '80 04000000 00 00 00 00 00 00 00 02 90',
      ),
    ]);
    await CcidReader(reader, autoReader, log: log).transfer(
      bytesOf('00 00 0D 00 20 00 8A 08 26 11 22 33 FF FF FF FF 6F'),
      secret: true,
    );
    expect(log.lines, [
      'an Leser [geheim, 27 Bytes]',
      'vom Leser [geheim, 14 Bytes]',
    ]);
    expect(log.lines.join('\n'), isNot(contains('26')));
  });

  test('powerOff schluckt Fehler', () async {
    final reader = ScriptedReader([
      sendFails(
        '63 00000000 00 00 00 0000',
        const ReaderException(ReaderProblem.io),
      ),
      send('63 00000000 00 01 00 0000', '81 00000000 00 01 02 FE 00'),
      send('63 00000000 00 02 00 0000', '80 00000000 00 02 00 00 00'),
      send('63 00000000 00 03 00 0000', '81 00000000 00 03 01 00 00'),
    ]);
    final ccid = CcidReader(reader, autoReader);
    await ccid.powerOff();
    await ccid.powerOff();
    await ccid.powerOff();
    await ccid.powerOff();
  });

  test('ProbeLog und hex', () {
    expect(hex(Uint8List(0)), '');
    expect(hex(bytesOf('aa bb 0c')), 'AA BB 0C');
    final log = ProbeLog()
      ..line('Leser gefunden')
      ..bytes('ATR', bytesOf('3B 8F'))
      ..bytes('PIN', bytesOf('26 11 22'), secret: true);
    expect(log.lines, ['Leser gefunden', 'ATR 3B 8F', 'PIN [geheim, 3 Bytes]']);
    expect(() => log.lines.add('x'), throwsUnsupportedError);
  });
}
