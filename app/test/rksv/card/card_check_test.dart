// Der Prüflauf "Karte prüfen" gegen den nachgebauten Leser mit Karte. Kein
// Test schickt eine PIN über ScriptedReader; PINs stehen nur in den Körpern.

import 'dart:async';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/rksv/card/atrust_card.dart';
import 'package:kassa/rksv/card/card_check.dart';
import 'package:kassa/rksv/card/card_providers.dart';
import 'package:kassa/rksv/card/pin_guard.dart';
import 'package:kassa/rksv/card/probe_log.dart';
import 'package:kassa/rksv/card/reader_transport.dart';

import '../../support/fake_card_reader.dart';
import '../../support/scripted_reader.dart' show bytesOf;
import '../fixtures/test_card.dart';

const tpdu = 0x00010030;
const shortApdu = 0x00020030;

const acosId41Atr = '3BDF97008131FE4680319052410464050401AC73D622C0F9';
const acosId2Atr = '3BDF96FF910131FE4680319052410264050200AC73D622C017';
const cardOs53Atr = '3BDF18008131FE588031B05202046405C903AC73B7B1D422';

/// [hexText] mit dem Prüfbyte der ATR dahinter.
String withTck(String hexText) {
  final bytes = bytesOf(hexText);
  var check = 0;
  for (var i = 1; i < bytes.length; i++) {
    check ^= bytes[i];
  }
  return hexText + check.toRadixString(16).padLeft(2, '0').toUpperCase();
}

final acosAtr = withTck('3BBF11008131FE45455041${'00' * 12}');

/// Alle acht ATRs aus der Tabelle von Task 4, ganz.
final allAtrs = [
  acosAtr,
  withTck('3BBF11008131FE454D4341${'00' * 12}'),
  cardOs53Atr,
  '3BDF18008131FE588031905241016405C903AC73B7B1D444',
  acosId2Atr,
  '3BDF18FF910131FE4680319052410264050200AC73D622C099',
  '3BDF97008131FE4680319052410364050201AC73D622C0F8',
  acosId41Atr,
];

/// Eine ATR mit T=1, die in keiner Tabelle steht.
final foreignAtr = withTck('3BDF97008131FE4680319052410464050401AC73D622C1');

FakeCard cardOf(
  String atrHex, {
  String pin = '123456',
  int retriesLeft = 3,
  Uint8List? certificate,
  CardProfile? profile,
  Uint8List Function(Uint8List hash)? signer,
}) {
  final atr = bytesOf(atrHex);
  return FakeCard(
    atr: atr,
    profile: profile ?? profileForAtr(atr)!,
    pin: pin,
    retriesLeft: retriesLeft,
    certificate: certificate ?? testCertificate,
    signer: signer ?? testSigner,
  );
}

const cardNumber = '0102030405060708';

class Rig {
  Rig({
    FakeCard? card,
    int features = tpdu,
    List<UsbDeviceInfo>? devices,
    bool permission = true,
    PinGuard? guard,
    DateTime? now,
    ReaderTransport Function(FakeCardReader reader)? wrap,
  }) : reader = FakeCardReader(
         card: card ?? cardOf(acosId41Atr),
         features: features,
         devices: devices,
         permission: permission,
       ),
       guard = guard ?? MemoryPinGuard(),
       time = now ?? DateTime.utc(2026, 11, 18, 12) {
    check = CardCheck(
      transport: wrap == null ? reader : wrap(reader),
      guard: this.guard,
      now: () => time,
      appVersion: '9.9.9',
    );
    check.changes.listen(seen.add);
  }

  final FakeCardReader reader;
  final PinGuard guard;
  DateTime time;
  late final CardCheck check;
  final List<CardCheckState> seen = [];

  FakeCard get card => reader.card!;
  CardCheckState get state => check.state;
  RowResult row(CheckRow row) => state.rows[row]!;

  /// Die Uhr geht bei jedem Austausch mit dem Leser 100 ms weiter.
  void tickPerExchange() =>
      reader.onExchange = (_) =>
          time = time.add(const Duration(milliseconds: 100));
}

/// So viele VERIFY gingen hinaus; der nachgebaute Leser zählt einen neu
/// gesendeten Block nicht als zweites VERIFY, darum zählt der Test die
/// maskierten Einträge selbst.
int verifiesSent(FakeCardReader reader) =>
    reader.transfers.where((t) => t.contains('**')).length;

/// Was nach dem letzten VERIFY beim Leser geschah.
List<String> eventsAfterLastVerify(FakeCardReader reader) {
  final at = reader.events.lastIndexWhere(
    (e) => e.startsWith('command 002000'),
  );
  expect(at, greaterThanOrEqualTo(0));
  return reader.events.sublist(at + 1);
}

Matcher isRow(RowState state, String message, [Object? hint = anything]) =>
    isA<RowResult>()
        .having((r) => r.state, 'state', state)
        .having((r) => r.message, 'message', message)
        .having((r) => r.hint, 'hint', hint);

const prerequisite = 'Erst wenn die Zeile darüber grün ist.';
const ready =
    'Mit der PIN der Signaturkarte erstellt die Kassa eine Unterschrift zur Probe.';
const lostMessage = 'Die Verbindung zur Karte ist abgebrochen.';
const lostHint = 'Prüf nochmal. Bleibt es dabei, teil bitte den Bericht.';
const reportHint = 'Teil bitte den Bericht.';

void expectLockedFrom(Rig rig, CheckRow first) {
  for (final row in CheckRow.values.where((r) => r.index >= first.index)) {
    expect(rig.row(row).state, RowState.locked, reason: row.name);
  }
}

const printer = UsbDeviceInfo(
  address: '1046:20497',
  name: 'Beispiel-Drucker',
  vendorId: 1046,
  productId: 20497,
  deviceClass: 0,
  granted: true,
  interfaces: [UsbInterfaceInfo(0x07, 0x01, 0x02)],
);

/// Reicht alles an den nachgebauten Leser weiter; [hangAt]: ab diesem
/// Austausch kommt keine Antwort mehr. [openDelay]: so lange wartet `open`
/// (Android fragt nach der Erlaubnis).
class SlowReader implements ReaderTransport {
  SlowReader(this.inner, {this.hangAt, this.openDelay});

  final FakeCardReader inner;
  int? hangAt;
  Duration? openDelay;
  int count = 0;

  @override
  Future<List<UsbDeviceInfo>> list() => inner.list();

  @override
  Future<Uint8List> open(String address) async {
    final delay = openDelay;
    if (delay != null) await Future<void>.delayed(delay);
    return inner.open(address);
  }

  @override
  Future<Uint8List> exchange(Uint8List? out, {required Duration limit}) {
    count++;
    final hang = hangAt;
    if (hang != null && count >= hang) return Completer<Uint8List>().future;
    return inner.exchange(out, limit: limit);
  }

  @override
  Future<void> close() => inner.close();

  @override
  Future<TabletInfo> info() => inner.info();
}

/// Merkt sich, was der Bildschirm sah, als der Wächter schrieb.
class SpyGuard extends MemoryPinGuard {
  CardCheck? check;
  final List<RowState?> rowAtWrite = [];

  @override
  Future<void> recordFailure(String cardNumber, int retriesLeft) {
    rowAtWrite.add(check?.state.rows[CheckRow.signature]?.state);
    return super.recordFailure(cardNumber, retriesLeft);
  }
}

Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  group('run', () {
    test('alles gut mit ACOS-ID 4.1 an einem TPDU-Leser: Zeilen 1 bis 4 ok, 5 wartet, canSign', () async {
      final rig = Rig();
      // Vor dem ersten Lauf: fünf wartende Zeilen mit den Texten aus dem Plan.
      expect(
        rig.row(CheckRow.reader),
        isRow(
          RowState.waiting,
          'Wird geprüft, sobald du auf "Jetzt prüfen" tippst.',
        ),
      );
      expect(
        rig.row(CheckRow.access),
        isRow(
          RowState.waiting,
          'Android fragt einmal, ob die Kassa den Leser verwenden darf.',
        ),
      );
      expect(
        rig.row(CheckRow.card),
        isRow(RowState.waiting, 'Die Karte muss im Leser stecken.'),
      );
      expect(
        rig.row(CheckRow.certificate),
        isRow(RowState.waiting, 'Seriennummer und Gültigkeit der Karte.'),
      );
      expect(rig.row(CheckRow.signature), isRow(RowState.waiting, ready));
      expect(rig.state.canSign, isFalse);
      expect(rig.state.busy, isFalse);

      final running = rig.check.run();
      expect(rig.state.busy, isTrue);
      await running;
      await settle();

      expect(
        rig.row(CheckRow.reader),
        isRow(RowState.ok, 'Beispiel-Kartenleser gefunden.'),
      );
      expect(
        rig.row(CheckRow.access),
        isRow(RowState.ok, 'Die Kassa darf den Kartenleser verwenden.'),
      );
      expect(
        rig.row(CheckRow.card),
        isRow(RowState.ok, 'a.sign RK CHIP (ACOS-ID 4.1) erkannt.', isNull),
      );
      expect(
        rig.row(CheckRow.certificate),
        isRow(
          RowState.ok,
          'Seriennummer 889977665544, gültig bis 30.06.2031.',
          'Ausgestellt von Beispiel CA.',
        ),
      );
      expect(rig.row(CheckRow.signature), isRow(RowState.waiting, ready));
      expect(rig.state.canSign, isTrue);
      expect(rig.state.guardBlocks, isFalse);
      expect(rig.state.busy, isFalse);

      // Befehle in der Reihenfolge aus dem Plan.
      expect(rig.card.received, [
        '00A4040C07D0400000220001',
        '00A4000C023F00',
        '00A4000C02D001',
        '00B0000008',
        '00A4000C023F00',
        '00A4000C02DF01',
        '00A4000C02C000',
        '00B0000000',
        '00B0010000',
      ]);
      // Freigegeben: ausgeschaltet und geschlossen.
      expect(rig.reader.events.last, 'powerOff');
      expect(rig.reader.closed, 1);
      expect(rig.reader.opened, [FakeCardReader.readerAddress]);

      // Jede Zeile ging sichtbar von wartend über läuft zum Ergebnis.
      for (final row in CheckRow.values.take(4)) {
        final states = [for (final s in rig.seen) s.rows[row]!.state];
        final waiting = states.indexOf(RowState.waiting);
        final running = states.indexOf(RowState.running);
        final ok = states.indexOf(RowState.ok);
        expect(waiting, greaterThanOrEqualTo(0), reason: row.name);
        expect(running, greaterThan(waiting), reason: row.name);
        expect(ok, greaterThan(running), reason: row.name);
      }
      expect(rig.seen.last.busy, isFalse);
    });

    test('alles gut an einem APDU-Leser', () async {
      final rig = Rig(features: shortApdu);
      await rig.check.run();
      for (final row in CheckRow.values.take(4)) {
        expect(rig.row(row).state, RowState.ok, reason: row.name);
      }
      expect(rig.row(CheckRow.signature), isRow(RowState.waiting, ready));
      expect(rig.state.canSign, isTrue);
      // Auf Stufe APDU keine Blockgröße.
      expect(rig.reader.events.where((e) => e.startsWith('ifsd')), isEmpty);
      expect(rig.reader.closed, 1);
    });

    test('jede Art aus der Tabelle: run und sign gelingen (acos mit getrenntem Hash)', () async {
      for (final atr in allAtrs) {
        final rig = Rig(card: cardOf(atr));
        await rig.check.run();
        final profile = rig.card.profile;
        expect(
          rig.row(CheckRow.card),
          isRow(RowState.ok, '${profile.label} erkannt.', profile.notice),
          reason: atr,
        );
        expect(rig.row(CheckRow.certificate).state, RowState.ok, reason: atr);
        expect(rig.state.canSign, isTrue, reason: atr);

        await rig.check.sign('123456');
        expect(rig.row(CheckRow.signature).state, RowState.ok, reason: atr);
        expect(rig.card.verifyCount, 3, reason: atr);
        expect(rig.card.signCount, 3, reason: atr);
        final received = rig.card.received;
        if (profile.kind == CardKind.acos) {
          expect(received, contains('00A4000C02DF71'));
          expect(received, contains('00A4000C02DF70'));
          expect(received, contains('00A4000C02C002'));
          expect(
            received,
            contains(
              '002241B6068401888001'
              '44',
            ),
          );
          expect(received.where((c) => c.startsWith('002A908120')).length, 3);
          expect(received.where((c) => c == '002A9E9A00').length, 3);
          expect(
            received.where((c) => c == '0020008108****************').length,
            3,
          );
        } else {
          expect(received.where((c) => c.startsWith('002A9E9A20')).length, 3);
          expect(
            received
                .where(
                  (c) =>
                      c.endsWith('40') &&
                      c.startsWith('002A9E9A20') &&
                      c.length == 76,
                )
                .length,
            3,
          );
          final p2 = profile.kind == CardKind.cardOs53 ? '81' : '8A';
          expect(
            received.where((c) => c == '002000${p2}08****************').length,
            3,
          );
        }
        expect(rig.reader.closed, 2, reason: atr);
      }
    });

    test('run schickt nie VERIFY: verifyCount bleibt 0', () async {
      for (final atr in allAtrs) {
        for (final features in [tpdu, shortApdu]) {
          final rig = Rig(card: cardOf(atr), features: features);
          await rig.check.run();
          await rig.check.run();
          await rig.check.resetGuard();
          expect(rig.card.verifyCount, 0);
          expect(verifiesSent(rig.reader), 0);
          expect(rig.card.received.where((c) => c.startsWith('0020')), isEmpty);
          expect(rig.card.signCount, 0);
        }
      }
    });

    test('kein Gerät; nur ein Drucker (Klasse 07): "Kein Kartenleser gefunden.", open wird nie gerufen', () async {
      for (final devices in [
        <UsbDeviceInfo>[],
        [printer],
      ]) {
        final rig = Rig(devices: devices);
        await rig.check.run();
        expect(
          rig.row(CheckRow.reader),
          isRow(
            RowState.problem,
            'Kein Kartenleser gefunden.',
            'Steckt der Leser am Verteiler, und hat der Verteiler Strom?',
          ),
        );
        expectLockedFrom(rig, CheckRow.access);
        expect(rig.row(CheckRow.access).message, prerequisite);
        expect(rig.reader.opened, isEmpty);
        expect(rig.reader.exchanges, 0);
        expect(rig.state.busy, isFalse);
        expect(rig.state.canSign, isFalse);
      }
    });

    test('Drucker und Leser: der Leser wird geöffnet, der Bericht nennt beide Geräte', () async {
      final rig = Rig(devices: [printer, FakeCardReader.readerDevice()]);
      await rig.check.run();
      expect(rig.reader.opened, [FakeCardReader.readerAddress]);
      expect(rig.row(CheckRow.certificate).state, RowState.ok);
      final report = rig.state.report;
      expect(
        report,
        contains(
          '1046:20497 "Beispiel-Drucker" Klasse 00 Schnittstellen 07/01/02 erlaubt',
        ),
      );
      expect(
        report,
        contains(
          '1254:21777 "Beispiel-Kartenleser" Klasse 00 Schnittstellen 0B/00/00 erlaubt',
        ),
      );
    });

    test(
      'Erlaubnis abgelehnt: Zeile 2 Fehler, Zeilen 3 bis 5 gesperrt',
      () async {
        final rig = Rig(permission: false);
        await rig.check.run();
        expect(rig.row(CheckRow.reader).state, RowState.ok);
        expect(
          rig.row(CheckRow.access),
          isRow(
            RowState.problem,
            'Die Kassa darf den Kartenleser nicht verwenden.',
            'Tipp auf "Nochmal prüfen" und erlaube den Zugriff im Fenster von Android.',
          ),
        );
        expectLockedFrom(rig, CheckRow.card);
        for (final row in [
          CheckRow.card,
          CheckRow.certificate,
          CheckRow.signature,
        ]) {
          expect(rig.row(row).message, prerequisite);
        }
        expect(rig.reader.closed, 1);
        expect(rig.state.report, contains('nicht erlaubt'));
      },
    );

    test('belegter Leser, unbekannter Leser, Stufe Zeichen: Texte der Zeile Zugriff', () async {
      final busy = Rig(
        wrap: (reader) => _FailingOpen(reader, ReaderProblem.busy),
      );
      await busy.check.run();
      expect(
        busy.row(CheckRow.access),
        isRow(
          RowState.problem,
          'Der Kartenleser ist gerade belegt.',
          'Zieh den Leser ab, steck ihn wieder an und prüf nochmal.',
        ),
      );
      final unknownMessage = isRow(
        RowState.problem,
        'Diesen Kartenleser kennt die Kassa nicht.',
        reportHint,
      );
      final notCcid = Rig(
        wrap: (reader) => _FailingOpen(reader, ReaderProblem.notCcid),
      );
      await notCcid.check.run();
      expect(notCcid.row(CheckRow.access), unknownMessage);
      final character = Rig(features: 0x00000030);
      await character.check.run();
      expect(character.row(CheckRow.access), unknownMessage);
      expect(character.reader.events, isEmpty);
      expect(character.reader.closed, 1);
      final gone = Rig(
        wrap: (reader) => _FailingOpen(reader, ReaderProblem.io),
      );
      await gone.check.run();
      expect(
        gone.row(CheckRow.access),
        isRow(
          RowState.problem,
          'Der Kartenleser antwortet nicht mehr.',
          'Steck ihn wieder an und prüf nochmal.',
        ),
      );
      expectLockedFrom(gone, CheckRow.card);
    });

    test('keine Karte; stumme Karte; fremde ATR; Anwendung fehlt: je der Text aus der Tabelle', () async {
      final none = Rig()..reader.card = null;
      await none.check.run();
      expect(
        none.row(CheckRow.card),
        isRow(
          RowState.problem,
          'Keine Karte im Leser.',
          'Steck die Karte mit dem Chip voran bis zum Anschlag hinein.',
        ),
      );
      expectLockedFrom(none, CheckRow.certificate);
      expect(none.reader.closed, 1);

      final mute = Rig()..card.mute = true;
      await mute.check.run();
      expect(
        mute.row(CheckRow.card),
        isRow(
          RowState.problem,
          'Die Karte antwortet nicht.',
          'Dreh die Karte um und steck sie nochmal hinein.',
        ),
      );
      expectLockedFrom(mute, CheckRow.certificate);

      final foreign = Rig(
        card: cardOf(foreignAtr, profile: profileForAtr(bytesOf(acosId41Atr))),
      );
      await foreign.check.run();
      expect(
        foreign.row(CheckRow.card),
        isRow(
          RowState.problem,
          'Die Karte antwortet, aber die Kassa kennt diese Art nicht.',
          'Antwort der Karte: ${hex(bytesOf(foreignAtr))}. $reportHint',
        ),
      );
      expect(
        foreign.row(CheckRow.certificate),
        isRow(RowState.locked, prerequisite),
      );
      expect(
        foreign.row(CheckRow.signature),
        isRow(
          RowState.locked,
          'Für diese Karte ist die Probe-Unterschrift nicht freigegeben.',
        ),
      );
      // Eine fremde Karte bekommt keinen einzigen Befehl.
      expect(foreign.card.received, isEmpty);
      expect(foreign.reader.events.last, 'powerOff');
      expect(foreign.state.report, contains('Art: unbekannt'));

      // T=0 (cardNotSupported aus der Sitzung): derselbe Text.
      const t0 = '3B021450';
      final t0Card = Rig(
        card: cardOf(t0, profile: profileForAtr(bytesOf(acosId41Atr))),
      );
      await t0Card.check.run();
      expect(
        t0Card.row(CheckRow.card),
        isRow(
          RowState.problem,
          'Die Karte antwortet, aber die Kassa kennt diese Art nicht.',
          'Antwort der Karte: 3B 02 14 50. $reportHint',
        ),
      );
      expect(
        t0Card.row(CheckRow.signature).message,
        'Für diese Karte ist die Probe-Unterschrift nicht freigegeben.',
      );

      // ATR von ACOS-ID 4.1, aber die Anwendung fehlt.
      final missing = Rig(
        card: cardOf(acosId41Atr, profile: profileForAtr(bytesOf(acosAtr))),
      );
      await missing.check.run();
      expect(
        missing.row(CheckRow.card),
        isRow(
          RowState.problem,
          'Auf der Karte fehlt die Signatur für Registrierkassen.',
          reportHint,
        ),
      );
      expectLockedFrom(missing, CheckRow.certificate);
      expect(missing.card.received, ['00A4040C07D0400000220001']);
      expect(missing.state.canSign, isFalse);
    });

    test('Zertifikat in zwei Blöcken (379 Bytes) wird ganz gelesen und auf 379 gekürzt', () async {
      // Die Datei auf der Karte ist länger als das Zertifikat (Füllbytes).
      final file = Uint8List.fromList([
        ...testCertificate,
        ...List.filled(300, 0xFF),
      ]);
      final rig = Rig(card: cardOf(acosId41Atr, certificate: file));
      await rig.check.run();
      expect(rig.row(CheckRow.certificate).state, RowState.ok);
      expect(
        rig.card.received.where(
          (c) => c.startsWith('00B0') && c != '00B0000008',
        ),
        ['00B0000000', '00B0010000'],
      );
      expect(
        rig.state.report,
        contains('Zertifikat: ${hex(testCertificate)}\n'),
      );
      // Die Antworten auf das Lesen kamen in je zwei T=1-Blöcken: die Kassa
      // hat mit einem Bestätigungsblock das zweite Stück angefordert.
      expect(
        rig.reader.transfers.where((t) => RegExp(r'^00[89]000').hasMatch(t)),
        isNotEmpty,
      );
    });

    test('Zertifikat mit unklarer Länge wird bis zur kurzen Antwort gelesen; zu lang ist nicht lesbar', () async {
      final unreadable = isRow(
        RowState.problem,
        'Das Zertifikat ließ sich nicht lesen.',
        reportHint,
      );
      // Unbestimmte Länge (30 80): lesen, bis eine Antwort kürzer als 256 ist.
      final indefinite = Uint8List.fromList([
        0x30,
        0x80,
        ...List.filled(600, 0x01),
      ]);
      final open = Rig(card: cardOf(acosId41Atr, certificate: indefinite));
      await open.check.run();
      expect(open.row(CheckRow.certificate), unreadable);
      expect(
        open.card.received.where(
          (c) => c.startsWith('00B0') && c != '00B0000008',
        ),
        ['00B0000000', '00B0010000', '00B0020000'],
      );
      expect(
        open.row(CheckRow.signature),
        isRow(RowState.locked, prerequisite),
      );
      expect(open.state.canSign, isFalse);

      // Angegebene Länge über 16 * 256 Bytes: nach dem ersten Block Schluss.
      final huge = Uint8List.fromList([
        0x30,
        0x82,
        0x10,
        0x00,
        ...List.filled(5000, 0x01),
      ]);
      final big = Rig(card: cardOf(acosId41Atr, certificate: huge));
      await big.check.run();
      expect(big.row(CheckRow.certificate), unreadable);
      expect(
        big.card.received.where(
          (c) => c.startsWith('00B0') && c != '00B0000008',
        ),
        ['00B0000000'],
      );

      // Datei fehlt: nicht lesbar.
      final noFile = Rig(card: cardOf(acosId41Atr, certificate: Uint8List(0)));
      await noFile.check.run();
      expect(noFile.row(CheckRow.certificate), unreadable);
    });

    test('Zertifikat abgelaufen (Uhr nach dem 30.06.2031): Zeile 4 Fehler, canSign false', () async {
      final rig = Rig(now: DateTime.utc(2031, 7, 1));
      await rig.check.run();
      expect(
        rig.row(CheckRow.certificate),
        isRow(
          RowState.problem,
          'Das Zertifikat ist am 30.06.2031 abgelaufen.',
          'Die Karte muss getauscht werden.',
        ),
      );
      expect(rig.row(CheckRow.signature), isRow(RowState.locked, prerequisite));
      expect(rig.state.canSign, isFalse);
      await rig.check.sign('123456');
      expect(rig.reader.opened.length, 1);
      expect(rig.card.verifyCount, 0);
    });

    test('Leser nach dem 5. Austausch abgezogen: Zeile zeigt den Fehler, close wurde gerufen, ein zweiter run gelingt', () async {
      final rig = Rig()..reader.failAfterExchanges = 5;
      await rig.check.run();
      expect(rig.row(CheckRow.access).state, RowState.ok);
      expect(
        rig.row(CheckRow.card),
        isRow(
          RowState.problem,
          'Der Kartenleser antwortet nicht mehr.',
          'Steck ihn wieder an und prüf nochmal.',
        ),
      );
      expectLockedFrom(rig, CheckRow.certificate);
      expect(rig.reader.closed, 1);
      expect(rig.state.busy, isFalse);
      expect(rig.state.canSign, isFalse);

      rig.reader.failAfterExchanges = null;
      await rig.check.run();
      for (final row in CheckRow.values.take(4)) {
        expect(rig.row(row).state, RowState.ok, reason: row.name);
      }
      expect(rig.state.canSign, isTrue);
      expect(rig.reader.closed, 2);
    });

    test('Karte gezogen mitten im Zertifikat: Zeile 4 "Verbindung … abgebrochen", Leser frei', () async {
      final rig = Rig();
      rig.reader.onExchange = (_) {
        if (rig.card.received.isNotEmpty &&
            rig.card.received.last == '00A4000C02C000') {
          rig.card.removed = true;
        }
      };
      await rig.check.run();
      expect(rig.row(CheckRow.card).state, RowState.ok);
      expect(
        rig.row(CheckRow.certificate),
        isRow(RowState.problem, lostMessage, lostHint),
      );
      expect(rig.row(CheckRow.signature), isRow(RowState.locked, prerequisite));
      expect(rig.reader.closed, 1);
    });

    test('ACOS-ID 2.1: bricht der erste Befehl ab, nennt der Bericht die feste Geschwindigkeit', () async {
      for (final (atr, hinted) in [(acosId2Atr, true), (acosId41Atr, false)]) {
        final rig = Rig(card: cardOf(atr));
        rig.reader.onExchange = (n) {
          // 1 Einschalten, 2 Parameter, 3 Blockgröße, 4 erster Befehl.
          if (n == 4) rig.card.removed = true;
        };
        await rig.check.run();
        expect(
          rig.row(CheckRow.card),
          isRow(RowState.problem, lostMessage, lostHint),
        );
        const line =
            'Hinweis: Die Karte gibt ihre Geschwindigkeit fest vor (TA1 96). '
            'Kann der Leser das nicht, bricht die Verbindung ab.';
        expect(rig.state.report.contains(line), hinted, reason: atr);
      }
    });

    test('ein Lauf, der hängt, endet nach 20 Sekunden mit "Das hat zu lange gedauert." und gibt den Leser frei', () {
      fakeAsync((async) {
        late SlowReader slow;
        final rig = Rig(
          wrap: (reader) => slow = SlowReader(reader, hangAt: 11),
        );
        var done = false;
        rig.check.run().then((_) => done = true);
        async.elapse(const Duration(seconds: 19));
        expect(done, isFalse);
        expect(rig.state.busy, isTrue);
        expect(rig.row(CheckRow.certificate).state, RowState.running);
        expect(rig.reader.closed, 0);

        async.elapse(const Duration(seconds: 2));
        expect(done, isTrue);
        expect(rig.state.busy, isFalse);
        expect(
          rig.row(CheckRow.certificate),
          isRow(
            RowState.problem,
            'Das hat zu lange gedauert.',
            'Prüf nochmal. Bleibt es dabei, teil bitte den Bericht.',
          ),
        );
        expect(
          rig.row(CheckRow.signature),
          isRow(RowState.locked, prerequisite),
        );
        expect(rig.reader.closed, 1);
        expect(rig.state.canSign, isFalse);

        // Danach gelingt ein neuer Lauf.
        slow.hangAt = null;
        rig.check.run();
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 1));
        expect(rig.row(CheckRow.certificate).state, RowState.ok);
        expect(rig.reader.closed, 2);
      });
    });

    test('ein open, das 30 Sekunden auf die Erlaubnis wartet, zählt nicht zu den 20 Sekunden', () {
      fakeAsync((async) {
        final rig = Rig(
          wrap: (reader) =>
              SlowReader(reader, openDelay: const Duration(seconds: 30)),
        );
        rig.check.run();
        async.elapse(const Duration(seconds: 10));
        expect(rig.row(CheckRow.reader).state, RowState.ok);
        expect(rig.row(CheckRow.access).state, RowState.running);
        async.elapse(const Duration(seconds: 25));
        expect(rig.state.busy, isFalse);
        for (final row in CheckRow.values.take(4)) {
          expect(rig.row(row).state, RowState.ok, reason: row.name);
        }
        expect(rig.state.canSign, isTrue);
      });
    });
  });

  group('sign', () {
    test('sign mit richtiger PIN: Zeile 5 ok mit Dauer, verifyCount 3, Wächter leer', () async {
      final guard = MemoryPinGuard({cardNumber: 2});
      final rig = Rig(guard: guard);
      await rig.check.run();
      rig.tickPerExchange();
      final signing = rig.check.sign('123456');
      expect(rig.state.busy, isTrue);
      expect(rig.state.canSign, isFalse);
      await signing;
      await settle();
      expect(
        rig.seen.map((s) => s.rows[CheckRow.signature]!.state),
        contains(RowState.running),
      );
      expect(
        rig.row(CheckRow.signature),
        isRow(
          RowState.ok,
          'Unterschrift erstellt und geprüft. Dauer: 0,2 Sekunden.',
          isNull,
        ),
      );
      expect(rig.card.verifyCount, 3);
      expect(verifiesSent(rig.reader), 3);
      expect(rig.card.signCount, 3);
      expect(await guard.retriesLeft(cardNumber), isNull);
      expect(rig.state.canSign, isTrue);
      expect(rig.state.busy, isFalse);
      expect(rig.reader.closed, 2);
      expect(rig.reader.events.last, 'powerOff');
      // Zuerst dieselbe Karte erkannt, dann VERIFY.
      final afterRun = rig.card.received.sublist(9);
      expect(afterRun.take(6), [
        '00A4000C023F00',
        '00A4000C02D001',
        '00B0000008',
        '00A4000C023F00',
        '00A4000C02DF01',
        '0020008A08****************',
      ]);
      expect(afterRun[6], startsWith('002A9E9A20'));
    });

    test('sign mit falscher PIN: genau ein VERIFY, "Noch 2 Versuche.", kein Befehl danach außer Ausschalten', () async {
      final guard = SpyGuard();
      final rig = Rig(guard: guard);
      guard.check = rig.check;
      await rig.check.run();
      await rig.check.sign('654321');
      expect(
        rig.row(CheckRow.signature),
        isRow(
          RowState.problem,
          'Die PIN war falsch. Noch 2 Versuche.',
          'Frag im Betrieb nach der richtigen PIN, bevor du es nochmal versuchst.',
        ),
      );
      expect(rig.card.verifyCount, 1);
      expect(verifiesSent(rig.reader), 1);
      expect(rig.card.signCount, 0);
      expect(eventsAfterLastVerify(rig.reader), ['powerOff']);
      expect(rig.reader.transfers.last, contains('**'));
      expect(await guard.retriesLeft(cardNumber), 2);
      // Der Wächter schrieb, bevor der Bildschirm das Ergebnis sah.
      expect(guard.rowAtWrite, [RowState.running]);
      expect(rig.state.canSign, isTrue);
      expect(rig.state.guardBlocks, isFalse);
      expect(rig.reader.closed, 2);
    });

    test('zweite falsche PIN: "nur noch einen Versuch", guardBlocks, canSign false', () async {
      final rig = Rig();
      await rig.check.run();
      await rig.check.sign('654321');
      await rig.check.sign('654321');
      expect(
        rig.row(CheckRow.signature),
        isRow(
          RowState.problem,
          'Die PIN war falsch. Die Karte hat nur noch einen Versuch.',
          'Die Kassa schickt die PIN jetzt nicht mehr. Wird die Karte in der '
              'alten Kassa mit der richtigen PIN verwendet, ist der Zähler '
              'wieder voll.',
        ),
      );
      expect(rig.state.guardBlocks, isTrue);
      expect(rig.state.canSign, isFalse);
      expect(rig.card.verifyCount, 2);
      expect(verifiesSent(rig.reader), 2);
      expect(await rig.guard.retriesLeft(cardNumber), 1);
      expect(rig.card.retriesLeft, 1);
    });

    test('guardBlocks übersteht eine neue CardCheck-Instanz (SecurePinGuard-Ersatz mit gemeinsamem Speicher)', () async {
      final store = <String, int>{};
      final first = Rig(guard: MemoryPinGuard(store));
      await first.check.run();
      await first.check.sign('654321');
      await first.check.sign('654321');
      expect(first.state.guardBlocks, isTrue);

      // Neustart der App: neuer Prüflauf, neuer Wächter, derselbe Speicher.
      final card = first.card;
      final second = Rig(card: card, guard: MemoryPinGuard(store));
      await second.check.run();
      expect(second.state.guardBlocks, isTrue);
      expect(second.state.canSign, isFalse);
      expect(
        second.row(CheckRow.signature).message,
        'Die PIN war falsch. Die Karte hat nur noch einen Versuch.',
      );
      await second.check.sign('123456');
      expect(card.verifyCount, 2);
      expect(second.reader.opened.length, 1);
      expect(verifiesSent(second.reader), 0);
    });

    test(
      'sign bei guardBlocks schickt nichts; nach resetGuard geht es wieder',
      () async {
        final rig = Rig();
        await rig.check.run();
        await rig.check.sign('654321');
        await rig.check.sign('654321');
        expect(rig.state.guardBlocks, isTrue);
        final opened = rig.reader.opened.length;
        final exchanges = rig.reader.exchanges;
        await rig.check.sign('123456');
        expect(rig.reader.opened.length, opened);
        expect(rig.reader.exchanges, exchanges);
        expect(rig.card.verifyCount, 2);

        await rig.check.resetGuard();
        expect(rig.state.guardBlocks, isFalse);
        expect(rig.state.canSign, isTrue);
        expect(rig.row(CheckRow.signature), isRow(RowState.waiting, ready));
        expect(await rig.guard.retriesLeft(cardNumber), isNull);
        // resetGuard selbst schickt nichts.
        expect(rig.reader.exchanges, exchanges);

        await rig.check.sign('123456');
        expect(rig.row(CheckRow.signature).state, RowState.ok);
        expect(rig.card.verifyCount, 5);
      },
    );

    test('kennt der Wächter seit dem Lauf nur noch einen Versuch, wird der Leser nicht geöffnet', () async {
      final store = <String, int>{};
      final rig = Rig(guard: MemoryPinGuard(store));
      await rig.check.run();
      expect(rig.state.canSign, isTrue);
      // Eine andere Instanz (etwa nach Neustart) hat inzwischen geschrieben.
      store[cardNumber] = 1;
      await rig.check.sign('123456');
      expect(rig.reader.opened.length, 1);
      expect(rig.card.verifyCount, 0);
      expect(rig.state.guardBlocks, isTrue);
      expect(rig.state.canSign, isFalse);
    });

    test('sign mit 5 Ziffern, Buchstaben oder leer tut nichts', () async {
      final rig = Rig();
      await rig.check.run();
      final before = rig.state;
      for (final pin in ['12345', '1234567', '12a456', '', ' 123456']) {
        await rig.check.sign(pin);
        expect(rig.state, same(before), reason: 'Länge ${pin.length}');
      }
      expect(rig.reader.opened.length, 1);
      expect(rig.card.verifyCount, 0);
    });

    test(
      'gesperrte Karte (6983): Text aus der Tabelle, kein zweites VERIFY',
      () async {
        final locked = isRow(
          RowState.problem,
          'Die Karte ist gesperrt.',
          'Wende dich an A-Trust.',
        );
        final rig = Rig(card: cardOf(acosId41Atr, retriesLeft: 0));
        await rig.check.run();
        await rig.check.sign('123456');
        expect(rig.row(CheckRow.signature), locked);
        expect(rig.card.verifyCount, 1);
        expect(verifiesSent(rig.reader), 1);
        expect(eventsAfterLastVerify(rig.reader), ['powerOff']);
        expect(rig.state.canSign, isFalse);
        expect(await rig.guard.retriesLeft(cardNumber), 0);

        // 63C0 gilt ebenso als gesperrt.
        final last = Rig(card: cardOf(acosId41Atr, retriesLeft: 1));
        await last.check.run();
        await last.check.sign('654321');
        expect(last.row(CheckRow.signature), locked);
        expect(last.card.verifyCount, 1);
        expect(verifiesSent(last.reader), 1);
        expect(await last.guard.retriesLeft(cardNumber), 0);
        expect(last.state.canSign, isFalse);
      },
    );

    test('anderer Status auf VERIFY: "abgelehnt", nichts danach', () async {
      // Ein Profil der Art acos auf einer Karte, die 8A erwartet: 6A88.
      final rig = Rig(card: cardOf(acosId41Atr));
      await rig.check.run();
      // Die nachgebaute Karte antwortet auf eine fremde Referenz mit 6A88;
      // dafür bekommt sie ein Profil mit anderer Referenz untergeschoben.
      final other = cardOf(
        acosId41Atr,
        profile: profileForAtr(bytesOf(cardOs53Atr)),
      );
      rig.reader.card = other;
      // Für die Kassa ist es dieselbe Karte (ATR und Nummer gleich), sie
      // schickt VERIFY mit 8A; die Karte erwartet 81.
      await rig.check.sign('123456');
      expect(
        rig.row(CheckRow.signature),
        isRow(
          RowState.problem,
          'Die Karte hat die Unterschrift abgelehnt.',
          reportHint,
        ),
      );
      expect(other.verifyCount, 1);
      expect(verifiesSent(rig.reader), 1);
      expect(eventsAfterLastVerify(rig.reader), ['powerOff']);
      expect(await rig.guard.retriesLeft(cardNumber), isNull);
    });

    test(
      'Unterschrift passt nicht zum Zertifikat: Text aus der Tabelle',
      () async {
        final rig = Rig(
          card: cardOf(
            acosId41Atr,
            signer: (hash) => Uint8List.fromList(List.filled(64, 0x11)),
          ),
        );
        await rig.check.run();
        await rig.check.sign('123456');
        expect(
          rig.row(CheckRow.signature),
          isRow(
            RowState.problem,
            'Die Karte hat unterschrieben, aber die Unterschrift passt nicht zum Zertifikat.',
            reportHint,
          ),
        );
        // Keine weiteren Runden.
        expect(rig.card.verifyCount, 1);
        expect(rig.card.signCount, 1);
        expect(
          rig.state.report,
          contains('Unterschrift: 64 Bytes, ungültig, '),
        );
      },
    );

    test('WTX vor der Unterschrift wird verkraftet', () async {
      final rig = Rig()..reader.wtxBeforeSign = 2;
      await rig.check.run();
      await rig.check.sign('123456');
      expect(rig.row(CheckRow.signature).state, RowState.ok);
      expect(rig.card.signCount, 3);
      expect(rig.card.verifyCount, 3);
      expect(rig.state.report, contains('T=1: Karte bittet um mehr Zeit'));
    });

    test(
      'ein verfälschtes Prüfbyte beim Zertifikat-Lesen wird verkraftet',
      () async {
        final rig = Rig();
        rig.reader.onExchange = (_) {
          final received = rig.card.received;
          if (received.isNotEmpty && received.last == '00A4000C02C000') {
            rig.reader.corruptBlockNumber = rig.reader.cardBlocks + 1;
            rig.reader.onExchange = null;
          }
        };
        await rig.check.run();
        expect(rig.row(CheckRow.certificate).state, RowState.ok);
        expect(
          rig.state.report,
          contains('Zertifikat: ${hex(testCertificate)}\n'),
        );
        expect(
          rig.state.report,
          contains('T=1: Block der Karte fehlerhaft, neu angefordert'),
        );
        expect(rig.state.canSign, isTrue);
      },
    );

    test('ein verfälschtes Prüfbyte in der Antwort auf VERIFY: Zeile 5 "Verbindung … abgebrochen", kein zweites VERIFY', () async {
      final rig = Rig();
      await rig.check.run();
      rig.reader.onExchange = (_) {
        final received = rig.card.received;
        if (received.last == '00A4000C02DF01') {
          // Der nächste Block der Karte ist die Antwort auf VERIFY.
          rig.reader.corruptBlockNumber = rig.reader.cardBlocks + 1;
          rig.reader.onExchange = null;
        }
      };
      await rig.check.sign('123456');
      expect(
        rig.row(CheckRow.signature),
        isRow(RowState.problem, lostMessage, lostHint),
      );
      expect(rig.card.verifyCount, 1);
      expect(verifiesSent(rig.reader), 1);
      expect(rig.card.signCount, 0);
      expect(eventsAfterLastVerify(rig.reader), ['powerOff']);
      expect(rig.reader.transfers.last, contains('**'));
      // Der Zähler ist unbekannt: der Wächter merkt sich nichts.
      expect(await rig.guard.retriesLeft(cardNumber), isNull);
      expect(rig.reader.closed, 2);
    });

    test('andere Karte zwischen run und sign: kein VERIFY, Zeile 3 "Das ist eine andere Karte. Prüf nochmal."', () async {
      final rig = Rig();
      await rig.check.run();
      final first = rig.card;
      final other = cardOf(cardOs53Atr);
      rig.reader.card = other;
      await rig.check.sign('123456');
      expect(
        rig.row(CheckRow.card),
        isRow(
          RowState.problem,
          'Das ist eine andere Karte. Prüf nochmal.',
          isNull,
        ),
      );
      expectLockedFrom(rig, CheckRow.certificate);
      expect(first.verifyCount, 0);
      expect(other.verifyCount, 0);
      expect(verifiesSent(rig.reader), 0);
      expect(rig.state.canSign, isFalse);
      expect(rig.reader.closed, 2);
    });

    test(
      'sign ohne vorheriges run und sign bei fremder Karte tun nichts',
      () async {
        final fresh = Rig();
        final before = fresh.state;
        await fresh.check.sign('123456');
        expect(fresh.state, same(before));
        expect(fresh.reader.opened, isEmpty);

        final foreign = Rig(
          card: cardOf(
            foreignAtr,
            profile: profileForAtr(bytesOf(acosId41Atr)),
          ),
        );
        await foreign.check.run();
        final afterRun = foreign.state;
        await foreign.check.sign('123456');
        expect(foreign.state, same(afterRun));
        expect(foreign.reader.opened.length, 1);
        expect(foreign.card.verifyCount, 0);
      },
    );

    test(
      'Karte gezogen vor sign: Zeile 3 "Keine Karte im Leser.", kein VERIFY',
      () async {
        final rig = Rig();
        await rig.check.run();
        rig.card.removed = true;
        await rig.check.sign('123456');
        expect(rig.row(CheckRow.card).message, 'Keine Karte im Leser.');
        expect(rig.card.verifyCount, 0);
        expect(rig.state.canSign, isFalse);
        expect(rig.reader.closed, 2);
      },
    );
  });

  group('Bericht', () {
    test('Bericht nach sign mit PIN 493817: enthält weder 493817 noch 26493817 noch 343933383137 (Groß/Klein, mit und ohne Leerzeichen)', () async {
      for (final atr in [acosId41Atr, acosAtr]) {
        final rig = Rig(card: cardOf(atr, pin: '493817'));
        await rig.check.run();
        await rig.check.sign('493817');
        expect(rig.row(CheckRow.signature).state, RowState.ok);
        // Und ein falscher Versuch danach.
        await rig.check.sign('493818');
        final report = rig.state.report;
        final upper = report.toUpperCase();
        final compact = upper.replaceAll(RegExp(r'\s'), '');
        for (final secret in ['493817', '26493817', '343933383137', '493818']) {
          expect(upper.contains(secret), isFalse, reason: secret);
          expect(compact.contains(secret), isFalse, reason: secret);
        }
        final p2 = atr == acosId41Atr ? '8A' : '81';
        expect(report, contains('00 20 00 $p2 08 ** ** ** ** ** ** ** **'));
        expect(report, contains('[geheim, '));
      }
    });

    test('Bericht enthält ATR, Deskriptoren, Zertifikat, die fünf Zeilen und die Dauer', () async {
      final rig = Rig();
      await rig.check.run();
      rig.tickPerExchange();
      await rig.check.sign('123456');
      final report = rig.state.report;
      final lines = report.split('\n');
      expect(lines.take(3), [
        'Kassa: Bericht "Karte prüfen"',
        'Version 9.9.9, 18.11.2026 12:00:00 UTC, Beispiel Tablet, Android 14 (API 34)',
        '',
      ]);
      expect(
        report,
        contains(
          'Ergebnis\n'
          '1 Kartenleser: gut Beispiel-Kartenleser gefunden.\n'
          '2 Zugriff: gut Die Kassa darf den Kartenleser verwenden.\n'
          '3 Signaturkarte: gut a.sign RK CHIP (ACOS-ID 4.1) erkannt.\n'
          '4 Zertifikat: gut Seriennummer 889977665544, gültig bis 30.06.2031.\n'
          '5 Probe-Unterschrift: gut Unterschrift erstellt und geprüft. Dauer: 0,2 Sekunden.\n',
        ),
      );
      expect(
        report,
        contains(
          'USB-Geräte\n'
          '1254:21777 "Beispiel-Kartenleser" Klasse 00 Schnittstellen 0B/00/00 erlaubt\n',
        ),
      );
      expect(
        report,
        contains(
          'Kartenleser\n'
          'Deskriptoren: ${hex(rig.reader.descriptors)}\n'
          'Stufe tpdu, Merkmale 00010030, Blockgröße 254\n',
        ),
      );
      expect(
        report,
        contains(
          'Karte\n'
          'ATR: ${hex(bytesOf(acosId41Atr))}\n'
          'Art: a.sign RK CHIP (ACOS-ID 4.1)\n'
          'Kartennummer: 01 02 03 04 05 06 07 08\n'
          'Zertifikat: ${hex(testCertificate)}\n'
          'Unterschrift: 64 Bytes, gültig, 200 ms, 200 ms, 200 ms\n',
        ),
      );
      expect(report, contains('\nProtokoll\n'));
      expect(report, contains('an Leser '));
      expect(report, contains('vom Leser '));
      expect(report, isNot(contains('gekürzt')));
      expect(report.length, lessThanOrEqualTo(60000));
    });

    test('Bericht vor dem Lauf und bei einem Fehler: offene Zeilen heißen offen, Fehler Fehler', () async {
      final rig = Rig(devices: const []);
      expect(rig.state.report, contains('1 Kartenleser: offen '));
      await rig.check.run();
      final report = rig.state.report;
      expect(
        report,
        contains('1 Kartenleser: Fehler Kein Kartenleser gefunden.\n'),
      );
      expect(report, contains('2 Zugriff: offen $prerequisite\n'));
      expect(report, contains('USB-Geräte\nkeine\n'));
      expect(report, contains('Art: unbekannt'));
    });

    test('Bericht über 60 000 Zeichen wird in der Mitte gekürzt', () async {
      final rig = Rig();
      await rig.check.run();
      for (var i = 0; i < 20; i++) {
        await rig.check.sign('123456');
      }
      final report = rig.state.report;
      expect(report.length, lessThanOrEqualTo(60000));
      expect(report.length, greaterThan(55000));
      expect(report, contains('\n… gekürzt …\n'));
      // Kopf und Ergebnis bleiben ganz.
      expect(report, startsWith('Kassa: Bericht "Karte prüfen"\n'));
      expect(report, contains('Zertifikat: ${hex(testCertificate)}\n'));
      expect(report, contains('5 Probe-Unterschrift: gut '));
      // Anfang und Ende des Protokolls bleiben.
      final protocol = report.split('\nProtokoll\n').last.split('\n');
      expect(protocol.first, 'Prüflauf 18.11.2026 12:00:00 UTC');
      expect(protocol.last, 'Probe-Unterschrift: gut');
      expect(protocol.where((l) => l == '… gekürzt …').length, 1);
    });
  });
  group('Provider', () {
    test('cardCheckProvider startet beim Anlegen keinen Lauf', () async {
      final reader = FakeCardReader(card: cardOf(acosId41Atr));
      final container = ProviderContainer(
        overrides: [
          readerTransportProvider.overrideWithValue(reader),
          pinGuardProvider.overrideWithValue(MemoryPinGuard()),
        ],
      );
      addTearDown(container.dispose);
      final check = container.read(cardCheckProvider);
      await settle();
      expect(check.state.busy, isFalse);
      expect(
        check.state.rows.values.map((r) => r.state),
        everyElement(RowState.waiting),
      );
      expect(reader.opened, isEmpty);
      expect(reader.exchanges, 0);
      expect(identical(container.read(cardCheckProvider), check), isTrue);
      expect(container.read(shareSheetProvider), isNotNull);

      await check.run();
      expect(check.state.canSign, isTrue);
    });
  });
}

class _FailingOpen extends SlowReader {
  _FailingOpen(super.inner, this.problem);

  final ReaderProblem problem;

  @override
  Future<Uint8List> open(String address) async {
    inner.opened.add(address);
    throw ReaderException(problem);
  }
}
