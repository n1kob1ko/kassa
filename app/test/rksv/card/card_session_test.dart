import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/rksv/card/atrust_card.dart';
import 'package:kassa/rksv/card/card_session.dart';
import 'package:kassa/rksv/card/ccid.dart';
import 'package:kassa/rksv/card/probe_log.dart';
import 'package:kassa/rksv/card/reader_transport.dart';

import '../../support/fake_card_reader.dart';
import '../../support/scripted_reader.dart';

const acosId41Atr = '3BDF97008131FE4680319052410464050401AC73D622C0F9';
const acosId2Cold = '3BDF96FF910131FE4680319052410264050200AC73D622C017';

/// Leser auf Stufe TPDU, ohne autoIfsd und ohne autoNegotiation.
const tpdu = 0x00010030;
const shortApdu = 0x00020030;
const extendedApdu = 0x00040030;

FakeCard cardWith(String atrHex, {String pin = '123456'}) {
  final atr = bytesOf(atrHex);
  return FakeCard(atr: atr, profile: profileForAtr(atr)!, pin: pin);
}

class Started {
  Started(this.reader, this.session, this.log);

  final FakeCardReader reader;
  final CardSession session;
  final ProbeLog log;

  FakeCard get card => reader.card!;
}

Future<CardSession> startOn(FakeCardReader reader, ProbeLog log) async {
  final descriptor = CcidDescriptor.parse(
    await reader.open(FakeCardReader.readerAddress),
  );
  return CardSession.start(
    CcidReader(reader, descriptor, log: log),
    descriptor,
    log: log,
  );
}

Future<Started> start({
  String atr = acosId41Atr,
  int features = tpdu,
  String pin = '123456',
}) async {
  final reader = FakeCardReader(
    card: cardWith(atr, pin: pin),
    features: features,
  );
  final log = ProbeLog();
  return Started(reader, await startOn(reader, log), log);
}

/// [hexText] ohne Leerzeichen und mit dem Prüfbyte der ATR dahinter.
String withTck(String hexText) {
  final bytes = bytesOf(hexText);
  var check = 0;
  for (var i = 1; i < bytes.length; i++) {
    check ^= bytes[i];
  }
  return hexText.replaceAll(' ', '') +
      check.toRadixString(16).padLeft(2, '0').toUpperCase();
}

Future<SessionException> sessionErrorOf(Future<Object?> Function() call) async {
  try {
    await call();
  } on SessionException catch (e) {
    return e;
  }
  fail('erwartet SessionException');
}

void main() {
  test('Leser auf Stufe TPDU ohne autoIfsd: Parameter 1110004600FE00, dann Blockgröße 254, dann Befehle', () async {
    final s = await start();
    expect(s.session.atr.bytes, bytesOf(acosId41Atr));
    final answer = await s.session.send(CardCommand.selectFile([0x3F, 0x00]));
    expect(answer.ok, isTrue);
    expect(s.reader.events, [
      'powerOn',
      'parameters 1110004600FE00',
      'ifsd FE',
      'command 00A4000C023F00',
    ]);
    // Der Befehl ging als T=1-Block hinaus: 00, PCB 00, Länge 07, Prüfbyte.
    expect(s.reader.transfers, ['00C101FE3E', '00000700A4000C023F0092']);
  });

  test(
    'ACOS-ID 2.1 (feste Geschwindigkeit): Parameter beginnen mit 96',
    () async {
      final s = await start(atr: acosId2Cold);
      expect(s.reader.events[1], 'parameters 9610FF4600FE00');
    },
  );

  test('Leser mit autoNegotiation (0x40): keine Parameter', () async {
    final s = await start(features: tpdu | CcidFeature.autoNegotiation);
    expect(s.reader.events.where((e) => e.startsWith('parameters')), isEmpty);
    expect(s.reader.events, contains('ifsd FE'));

    // Mit autoIfsd auch keine Blockgröße.
    final quiet = await start(
      features: tpdu | CcidFeature.autoNegotiation | CcidFeature.autoIfsd,
    );
    expect(quiet.reader.events, ['powerOn']);
    expect(
      (await quiet.session.send(CardCommand.selectFile([0x3F, 0x00]))).ok,
      isTrue,
    );
  });

  test('Leser auf Stufe kurze APDU: Befehl geht unverändert hinaus, keine Blockgröße', () async {
    for (final features in [shortApdu, extendedApdu]) {
      final s = await start(features: features);
      final command = CardCommand.selectApplication(bytesOf('D0400000220001'));
      final answer = await s.session.send(command);
      expect(answer.status, 0x9000);
      expect(answer.data, isEmpty);
      expect(s.reader.events, [
        'powerOn',
        'parameters 1110004600FE00',
        'command 00A4040C07D0400000220001',
      ]);
      expect(s.reader.transfers, ['00A4040C07D0400000220001']);
    }
  });

  test('Leser auf Stufe Zeichen: readerNotSupported', () async {
    final reader = FakeCardReader(
      card: cardWith(acosId41Atr),
      features: 0x00000030,
    );
    final e = await sessionErrorOf(() => startOn(reader, ProbeLog()));
    expect(e.problem, SessionProblem.readerNotSupported);
    expect(reader.events, ['powerOn', 'powerOff']);
    expect(reader.transfers, isEmpty);
  });

  test('Karte mit T=0 zuerst: cardNotSupported', () async {
    for (final atr in [
      '3B80800101', // T=0, dann T=1
      '3B021450', // nur T=0
      '3BDF97008131FE47', // kaputt: abgeschnitten
      withTck('3B90119111 31FE45'), // TA2 mit Bit 0x10
      withTck('3B901181 71FE4501'), // CRC statt LRC
      withTck('3B808111 00'), // Blockgröße 0
      withTck('3B808111 FF'), // Blockgröße 255
    ]) {
      final reader = FakeCardReader(
        card: FakeCard(
          atr: bytesOf(atr),
          profile: profileForAtr(bytesOf(acosId41Atr))!,
        ),
      );
      final e = await sessionErrorOf(() => startOn(reader, ProbeLog()));
      expect(e.problem, SessionProblem.cardNotSupported, reason: atr);
      expect(e.detail.replaceAll(' ', ''), contains(atr), reason: atr);
      expect(reader.events.last, 'powerOff', reason: atr);
      expect(reader.transfers, isEmpty, reason: atr);
    }
  });

  test(
    'Parameter scheitern: Zeile im Protokoll, die Sitzung startet trotzdem',
    () async {
      final reader = FakeCardReader(card: cardWith(acosId41Atr))
        ..acceptParameters = false;
      final log = ProbeLog();
      final session = await startOn(reader, log);
      expect(
        log.lines,
        contains(
          'Parameter nicht gesetzt (CcidException(commandFailed, 0A)), '
          'es geht weiter',
        ),
      );
      expect(
        (await session.send(CardCommand.selectFile([0x3F, 0x00]))).ok,
        isTrue,
      );
    },
  );

  test('send(selectFile(3F00)) ergibt 9000; unbekannte Datei 6A82', () async {
    for (final features in [tpdu, shortApdu]) {
      final s = await start(features: features);
      final ok = await s.session.send(CardCommand.selectFile([0x3F, 0x00]));
      expect(ok.status, 0x9000);
      expect(ok.ok, isTrue);
      final missing = await s.session.send(
        CardCommand.selectFile([0x12, 0x34]),
      );
      expect(missing.status, 0x6A82);
      expect(missing.ok, isFalse);
      expect(s.reader.limits.last, const Duration(seconds: 3));

      // Eine Antwort mit Daten: die Kartennummer.
      await s.session.send(CardCommand.selectFile([0xD0, 0x01]));
      final number = await s.session.send(CardCommand.readCardNumber());
      expect(number.data, bytesOf('0102030405060708'));
      expect(number.status, 0x9000);

      // Das Zertifikat in zwei Teilen; die erste Antwort braucht bei T=1
      // zwei Blöcke.
      await s.session.send(CardCommand.selectFile([0xDF, 0x01]));
      await s.session.send(CardCommand.selectFile([0xC0, 0x00]));
      final first = await s.session.send(CardCommand.readBinary(0));
      final second = await s.session.send(CardCommand.readBinary(256));
      final behind = await s.session.send(CardCommand.readBinary(512));
      expect(first.data.length, 256);
      expect(second.data.length, 379 - 256);
      expect([...first.data, ...second.data], s.card.certificate);
      expect(behind.status, 0x6B00);
    }
  });

  test(
    'Karte gezogen während send: SessionException(connectionLost)',
    () async {
      // Mitten in einer Antwort aus zwei T=1-Blöcken.
      final s = await start();
      await s.session.send(CardCommand.selectFile([0xDF, 0x01]));
      await s.session.send(CardCommand.selectFile([0xC0, 0x00]));
      final before = s.reader.exchanges;
      s.reader.onExchange = (n) {
        if (n == before + 2) s.card.removed = true;
      };
      final pulled = await sessionErrorOf(
        () => s.session.send(CardCommand.readBinary(0)),
      );
      expect(pulled.problem, SessionProblem.connectionLost);
      expect(s.reader.exchanges, before + 2);

      // Leser abgezogen, auf beiden Stufen.
      for (final features in [tpdu, shortApdu]) {
        final r = await start(features: features);
        r.reader.failAfterExchanges = r.reader.exchanges;
        final e = await sessionErrorOf(
          () => r.session.send(CardCommand.selectFile([0x3F, 0x00])),
        );
        expect(e.problem, SessionProblem.connectionLost);
        expect(e.detail, contains('io'));
      }

      // Ein verfälschtes Prüfbyte in der Antwort auf VERIFY: kein zweites
      // VERIFY, die Sitzung meldet den Abbruch.
      final v = await start();
      v.reader.corruptBlockNumber = v.reader.cardBlocks + 1;
      final e = await sessionErrorOf(
        () => v.session.send(CardCommand.verifyPin(v.card.profile, '123456')),
      );
      expect(e.problem, SessionProblem.connectionLost);
      expect(v.card.verifyCount, 1);
    },
  );

  test('Protokoll: verifyPin zeigt 00 20 00 8A 08 ** ** ** ** ** ** ** **, die Schichten darunter [geheim, …]', () async {
    const secrets = [
      '493817',
      '26493817',
      '26 49 38 17',
      '34 39 33 38 31 37',
      '343933383137',
    ];
    void expectNoPin(String text) {
      final upper = text.toUpperCase();
      for (final secret in secrets) {
        expect(upper, isNot(contains(secret)), reason: text);
        expect(
          upper.replaceAll(' ', ''),
          isNot(contains(secret.replaceAll(' ', ''))),
          reason: text,
        );
      }
    }

    for (final features in [tpdu, shortApdu]) {
      final s = await start(features: features, pin: '493817');
      final command = CardCommand.verifyPin(s.card.profile, '493817');
      final answer = await s.session.send(command);
      expect(answer.ok, isTrue);
      expect(s.reader.limits.last, const Duration(seconds: 5));
      expect(
        s.log.lines,
        contains(
          'VERIFY: 00 20 00 8A 08 ** ** ** ** ** ** ** **; Antwort 90 00',
        ),
      );
      final secretLines = s.log.lines.where((l) => l.contains('[geheim, '));
      expect(
        secretLines.where((l) => l.startsWith('an Leser [geheim, ')),
        hasLength(1),
      );
      expect(
        secretLines.where((l) => l.startsWith('vom Leser [geheim, ')),
        hasLength(1),
      );

      final wrong = await s.session.send(
        CardCommand.verifyPin(s.card.profile, '000000'),
      );
      expect(wrong.status, 0x63C2);
      expect(
        s.log.lines.last,
        'VERIFY: 00 20 00 8A 08 ** ** ** ** ** ** ** **; Antwort 63 C2',
      );

      s.card.removed = true;
      final lost = await sessionErrorOf(() => s.session.send(command));
      expect(lost.problem, SessionProblem.connectionLost);
      expect(s.card.received, contains('0020008A08****************'));

      for (final text in [
        ...s.log.lines,
        lost.toString(),
        lost.detail,
        command.toString(),
        ...s.card.received,
        ...s.reader.transfers,
        ...s.reader.events,
      ]) {
        expectNoPin(text);
      }
    }
  });

  test('end schaltet aus und wirft nie', () async {
    final s = await start();
    await s.session.end();
    expect(s.reader.events.last, 'powerOff');

    final gone = await start();
    gone.reader.failAfterExchanges = gone.reader.exchanges;
    await gone.session.end();
    await gone.session.end();

    final pulled = await start(features: shortApdu);
    pulled.card.removed = true;
    await pulled.session.end();
    expect(pulled.reader.events.last, 'powerOff');
  });

  test('Einschalten ohne Karte oder mit stummer Karte: Fehler des Lesers kommen unverändert', () async {
    final empty = FakeCardReader();
    Object? error;
    try {
      await startOn(empty, ProbeLog());
    } catch (e) {
      error = e;
    }
    expect(error, isA<CcidException>());
    expect((error as CcidException).problem, CcidProblem.cardAbsent);

    final mute = FakeCardReader(card: cardWith(acosId41Atr)..mute = true);
    try {
      await startOn(mute, ProbeLog());
    } catch (e) {
      error = e;
    }
    expect((error as CcidException).problem, CcidProblem.cardMute);

    final unplugged = FakeCardReader(
      card: cardWith(acosId41Atr),
      failAfterExchanges: 0,
    );
    try {
      await startOn(unplugged, ProbeLog());
    } catch (e) {
      error = e;
    }
    expect((error as ReaderException).problem, ReaderProblem.io);
  });

  test(
    'send gibt putHash und sign 5 Sekunden, den anderen Befehlen 3',
    () async {
      final s = await start(atr: acosId41Atr);
      final hash = Uint8List(32);
      await s.session.send(CardCommand.selectFile([0x3F, 0x00]));
      expect(s.reader.limits.last, const Duration(seconds: 3));
      await s.session.send(CardCommand.verifyPin(s.card.profile, '123456'));
      expect(s.reader.limits.last, const Duration(seconds: 5));
      final signature = await s.session.send(
        CardCommand.sign(s.card.profile, hash),
      );
      expect(signature.ok, isTrue);
      expect(signature.data, hasLength(64));
      expect(s.reader.limits.last, const Duration(seconds: 5));
      await s.session.send(CardCommand.putHash(hash));
      expect(s.reader.limits.last, const Duration(seconds: 5));
      await s.session.send(CardCommand.readCardNumber());
      expect(s.reader.limits.last, const Duration(seconds: 3));
    },
  );

  test('nachgebaute Karte: falsche PIN zählt herunter, bei 0 gesperrt, auch für die richtige', () async {
    final s = await start();
    final profile = s.card.profile;
    final hash = Uint8List(32);
    final unsigned = await s.session.send(CardCommand.sign(profile, hash));
    expect(unsigned.status, 0x6982);
    final statuses = <int>[];
    for (final pin in ['111111', '222222', '333333', '123456']) {
      statuses.add(
        (await s.session.send(CardCommand.verifyPin(profile, pin))).status,
      );
    }
    expect(statuses, [0x63C2, 0x63C1, 0x63C0, 0x6983]);
    expect(s.card.verifyCount, 4);
    expect(s.card.retriesLeft, 0);
    expect(
      (await s.session.send(CardCommand.sign(profile, hash))).status,
      0x6982,
    );
    expect(s.card.signCount, 0);

    // Richtige PIN füllt den Zähler wieder auf; jede Unterschrift braucht
    // ein neues VERIFY.
    final r = await start();
    await r.session.send(CardCommand.verifyPin(profile, '000000'));
    expect(r.card.retriesLeft, 2);
    await r.session.send(CardCommand.verifyPin(profile, '123456'));
    expect(r.card.retriesLeft, 3);
    expect((await r.session.send(CardCommand.sign(profile, hash))).ok, isTrue);
    expect(
      (await r.session.send(CardCommand.sign(profile, hash))).status,
      0x6982,
    );
  });

  test('nachgebaute Karte acos: Unterschrift nur nach prepareSignature und putHash', () async {
    final atr = withTck('3BBF11008131FE45455041000000000000000000000000');
    final s = await start(atr: atr);
    final profile = s.card.profile;
    expect(profile.kind, CardKind.acos);
    final hash = Uint8List.fromList(List.generate(32, (i) => i));
    final setup = [
      for (final aid in profile.applications)
        await s.session.send(CardCommand.selectApplication(aid)),
      await s.session.send(CardCommand.selectFile([0x3F, 0x00])),
      await s.session.send(CardCommand.selectFile(profile.signatureFolder)),
    ];
    expect(setup.every((r) => r.ok), isTrue);
    await s.session.send(CardCommand.verifyPin(profile, '123456'));
    expect((await s.session.send(CardCommand.putHash(hash))).status, 0x6F05);
    expect((await s.session.send(CardCommand.sign(profile, hash))).ok, isFalse);
    expect((await s.session.send(CardCommand.prepareSignature())).ok, isTrue);
    await s.session.send(CardCommand.verifyPin(profile, '123456'));
    expect((await s.session.send(CardCommand.putHash(hash))).ok, isTrue);
    final signature = await s.session.send(CardCommand.sign(profile, hash));
    expect(signature.ok, isTrue);
    expect(signature.data.sublist(0, 32), hash);
    expect(s.card.signCount, 1);

    // Kartennummer im eigenen Ordner.
    await s.session.send(CardCommand.selectFile(profile.numberFolder));
    await s.session.send(CardCommand.selectFile(profile.numberFile));
    expect(
      (await s.session.send(CardCommand.readCardNumber())).data,
      fakeCardNumber,
    );
    // Andere Arten kennen die Befehle nur für acos nicht.
    final other = await start();
    expect(
      (await other.session.send(CardCommand.prepareSignature())).status,
      0x6D00,
    );
    expect(
      (await other.session.send(CardCommand.selectApplication([1, 2, 3])))
          .status,
      0x6A82,
    );
  });

  test('nachgebauter Leser: WTX vor der Unterschrift und ein verfälschtes Prüfbyte werden verkraftet', () async {
    for (final features in [tpdu, shortApdu]) {
      final s = await start(features: features);
      s.reader.wtxBeforeSign = 2;
      final profile = s.card.profile;
      await s.session.send(CardCommand.verifyPin(profile, '123456'));
      final signature = await s.session.send(
        CardCommand.sign(profile, Uint8List(32)),
      );
      expect(signature.ok, isTrue, reason: '$features');
      if (features == tpdu) {
        expect(
          s.log.lines.where((l) => l.startsWith('T=1: Karte bittet')),
          hasLength(2),
        );
        expect(s.reader.bwis.where((b) => b == 1), hasLength(2));
      }
    }

    final c = await start();
    await c.session.send(CardCommand.selectFile([0xDF, 0x01]));
    await c.session.send(CardCommand.selectFile([0xC0, 0x00]));
    c.reader.corruptBlockNumber = c.reader.cardBlocks + 2;
    final first = await c.session.send(CardCommand.readBinary(0));
    expect(first.data, c.card.certificate.sublist(0, 256));
    expect(
      c.log.lines,
      contains('T=1: Block der Karte fehlerhaft, neu angefordert'),
    );
    expect(c.reader.corruptBlockNumber, isNull);
  });

  test('nachgebauter Leser: kleinere Blöcke der Karte (cardIfsc 32)', () async {
    final reader = FakeCardReader(card: cardWith(acosId41Atr))..cardIfsc = 32;
    final session = await startOn(reader, ProbeLog());
    await session.send(CardCommand.selectFile([0xDF, 0x01]));
    await session.send(CardCommand.selectFile([0xC0, 0x00]));
    final before = reader.cardBlocks;
    final first = await session.send(CardCommand.readBinary(0));
    expect(first.data, reader.card!.certificate.sublist(0, 256));
    expect(reader.cardBlocks - before, 9); // 258 Bytes in Stücken zu 32
  });
}
