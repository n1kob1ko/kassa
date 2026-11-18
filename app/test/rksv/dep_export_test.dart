import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/data/database.dart';
import 'package:kassa/rksv/dep_export.dart';
import 'package:kassa/rksv/rksv_service.dart';

import 'fixtures/test_card.dart';
import '../support/fake_signature_unit.dart';
import '../support/rksv_rig.dart';
import '../support/sales.dart' show cart;

void main() {
  late RksvRig rig;

  setUp(() async => rig = await RksvRig.open());
  tearDown(() => rig.close());

  Future<List<String>> jwsOf(int chain) async => [
    for (final e in await rig.entries(chain)) e.jws,
  ];

  /// Die Belege-kompakt aller Gruppen der zuletzt gespeicherten Datei.
  List<String> savedJws() => [
    for (final g
        in (jsonDecode(rig.saver.lastText)
                as Map<String, dynamic>)['Belege-Gruppe']
            as List)
      ...((g as Map<String, dynamic>)['Belege-kompakt'] as List).cast<String>(),
  ];

  group('depFileName', () {
    test('Probe: kassa-protokoll-PROBE-<Kennung>-<JJJJMMTT>.json', () {
      expect(
        depFileName(
          cashBoxId: 'ABCDEFGH23',
          probe: true,
          now: DateTime(2026, 11, 18, 23, 59),
        ),
        'kassa-protokoll-PROBE-ABCDEFGH23-20261118.json',
      );
    });

    test('ohne Probe ohne "PROBE-"', () {
      expect(
        depFileName(
          cashBoxId: 'ABCDEFGH23',
          probe: false,
          now: DateTime(2027, 1, 5),
        ),
        'kassa-protokoll-ABCDEFGH23-20270105.json',
      );
    });
  });

  group('buildDepExport', () {
    test('eine Gruppe je zusammenhängender Folge mit derselben Seriennummer, '
        'mit Zertifikat und Zertifizierungsstellen', () async {
      // Bons ohne Signatur (mode off), die Einträge setzt der Test selbst.
      final receipts = [
        for (var i = 1; i <= 4; i++) await rig.sell('s$i', cart),
      ];
      final fakeSerial = (await rig.fake.info()).serialHex;
      await rig.db
          .into(rig.db.rksvCertificateRows)
          .insert(
            RksvCertificateRowsCompanion.insert(
              serialHex: 'b0b0',
              certificate: Uint8List.fromList([1, 2, 3]),
              issuers: const Value('["AAEC","BAUG"]'),
            ),
          );
      await rig.db
          .into(rig.db.rksvChainRows)
          .insert(
            RksvChainRowsCompanion.insert(
              chain: const Value(1),
              mode: 'probe',
              cashBoxId: 'ABCDEFGH23',
              zdaId: 'AT100',
              certSerial: fakeSerial,
              startedAt: rig.clock.now(),
            ),
          );
      final serials = [fakeSerial, fakeSerial, 'b0b0', fakeSerial];
      for (var i = 0; i < 4; i++) {
        await rig.db
            .into(rig.db.rksvEntryRows)
            .insert(
              RksvEntryRowsCompanion.insert(
                chain: 1,
                position: i + 1,
                receiptId: receipts[i].id,
                jws: 'j${i + 1}',
                damaged: i == 1,
                certSerial: serials[i],
              ),
            );
      }

      final text = await buildDepExport(rig.db, chain: 1);

      expect(jsonDecode(text), {
        'Belege-Gruppe': [
          {
            'Signaturzertifikat': base64.encode(testCertificate),
            'Zertifizierungsstellen': <String>[],
            'Belege-kompakt': ['j1', 'j2'],
          },
          {
            'Signaturzertifikat': 'AQID',
            'Zertifizierungsstellen': ['AAEC', 'BAUG'],
            'Belege-kompakt': ['j3'],
          },
          {
            'Signaturzertifikat': base64.encode(testCertificate),
            'Zertifizierungsstellen': <String>[],
            'Belege-kompakt': ['j4'],
          },
        ],
      });
      expect(await buildDepExport(rig.db, chain: 2), '{"Belege-Gruppe":[]}');
    });
  });

  group('exportProtocol', () {
    test('ohne Kette: RksvProblem, nichts gespeichert', () async {
      await expectLater(
        rig.service.exportProtocol(ExportRange.all, now: rig.clock.now()),
        throwsA(
          isA<RksvProblem>().having(
            (p) => p.message,
            'message',
            'Es gibt noch kein Protokoll.',
          ),
        ),
      );
      expect(rig.saver.saved, isEmpty);
    });

    test('Start, zwei Verkäufe, Ausfall-Eintrag: eine Gruppe mit dem '
        'Zertifikat der Attrappe, Einträge in Reihenfolge, Dateiname mit '
        'PROBE und Kennung', () async {
      await rig.service.enableProbe(staff: rig.chef);
      await rig.sell('s1', cart);
      await rig.sell('s2', cart);
      rig.fake.mode = FakeMode.error;
      await rig.sell('s3', cart);
      final entries = await rig.entries(1);
      expect([for (final e in entries) e.damaged], [false, false, false, true]);

      final outcome = await rig.service.exportProtocol(
        ExportRange.all,
        now: DateTime(2026, 11, 19, 9),
      );

      expect(outcome, ExportOutcome.saved);
      final cashBoxId = (await rig.chainRow(1)).cashBoxId;
      expect(rig.saver.saved, hasLength(1));
      expect(
        rig.saver.saved.single.$1,
        'kassa-protokoll-PROBE-$cashBoxId-20261119.json',
      );
      expect(jsonDecode(rig.saver.lastText), {
        'Belege-Gruppe': [
          {
            'Signaturzertifikat': base64.encode(testCertificate),
            'Zertifizierungsstellen': <String>[],
            'Belege-kompakt': await jwsOf(1),
          },
        ],
      });
      expect(rig.saver.lastText, await buildDepExport(rig.db, chain: 1));
    });

    test('die laufende Kette, sonst die zuletzt beendete', () async {
      await rig.service.enableProbe(staff: rig.chef);
      await rig.sell('s1', cart);
      await rig.service.disableProbe(staff: rig.chef);

      expect(
        await rig.service.exportProtocol(ExportRange.all, now: rig.clock.now()),
        ExportOutcome.saved,
      );
      expect(savedJws(), await jwsOf(1));
      expect(savedJws(), hasLength(3));
      final first = (await rig.chainRow(1)).cashBoxId;
      expect(rig.saver.saved.last.$1, contains(first));

      await rig.service.enableProbe(staff: rig.chef);
      await rig.service.exportProtocol(ExportRange.all, now: rig.clock.now());
      expect(savedJws(), await jwsOf(2));
      expect(savedJws(), hasLength(1));
      expect(
        rig.saver.saved.last.$1,
        contains((await rig.chainRow(2)).cashBoxId),
      );
    });

    group('Vierteljahre', () {
      // Start 20.9., Verkäufe am 25.9. und 30.9. 23:59:59, dann am 1.10. um
      // 0:00 Monatsbeleg und Verkauf, am 2.10. noch ein Verkauf.
      late List<String> all;

      setUp(() async {
        rig.clock.value = DateTime(2026, 9, 20, 10);
        await rig.service.enableProbe(staff: rig.chef);
        rig.clock.value = DateTime(2026, 9, 25, 12);
        await rig.sell('s1', cart);
        rig.clock.value = DateTime(2026, 9, 30, 23, 59, 59);
        await rig.sell('s2', cart);
        rig.clock.value = DateTime(2026, 10, 1);
        await rig.sell('s3', cart);
        rig.clock.value = DateTime(2026, 10, 2, 9);
        await rig.sell('s4', cart);
        expect(await rig.entryKinds(), [
          'start',
          'sale',
          'sale',
          'month',
          'sale',
          'sale',
        ]);
        all = await jwsOf(1);
      });

      test('lastQuarter: nur die Einträge von Juli bis September', () async {
        final outcome = await rig.service.exportProtocol(
          ExportRange.lastQuarter,
          now: DateTime(2026, 11, 18, 13),
        );
        expect(outcome, ExportOutcome.saved);
        expect(savedJws(), all.sublist(0, 3));
      });

      test('thisQuarter: ab dem 1. Oktober 0:00', () async {
        await rig.service.exportProtocol(
          ExportRange.thisQuarter,
          now: DateTime(2026, 12, 31, 23, 59),
        );
        expect(savedJws(), all.sublist(3));
      });

      test(
        'lastQuarter im Jänner: Oktober bis Dezember des Vorjahres',
        () async {
          await rig.service.exportProtocol(
            ExportRange.lastQuarter,
            now: DateTime(2027, 1, 15),
          );
          expect(savedJws(), all.sublist(3));
        },
      );

      test('all: alle Einträge', () async {
        await rig.service.exportProtocol(
          ExportRange.all,
          now: DateTime(2027, 1, 15),
        );
        expect(savedJws(), all);
      });

      test(
        'empty, wenn im Zeitraum kein Eintrag steht; nichts gespeichert',
        () async {
          expect(
            await rig.service.exportProtocol(
              ExportRange.thisQuarter,
              now: DateTime(2027, 1, 15),
            ),
            ExportOutcome.empty,
          );
          expect(
            await rig.service.exportProtocol(
              ExportRange.lastQuarter,
              now: DateTime(2026, 9, 30),
            ),
            ExportOutcome.empty,
          );
          expect(rig.saver.saved, isEmpty);
        },
      );
    });

    test('cancelled, wenn der Speichern-Dialog abgebrochen wird', () async {
      await rig.service.enableProbe(staff: rig.chef);
      rig.saver.accept = false;
      expect(
        await rig.service.exportProtocol(ExportRange.all, now: rig.clock.now()),
        ExportOutcome.cancelled,
      );
      expect(rig.saver.saved, isEmpty);
    });

    test(
      'die Datei enthält weder den AES-Schlüssel noch den Probe-Schlüssel',
      () async {
        await rig.service.enableProbe(staff: rig.chef);
        await rig.sell('s1', cart);
        await rig.service.exportProtocol(ExportRange.all, now: rig.clock.now());
        final text = rig.saver.lastText;
        for (final key in [
          (await rig.secrets.aesKey(1))!,
          (await rig.secrets.probeKey(1))!,
        ]) {
          final forms = {
            base64.encode(key),
            base64Url.encode(key),
            base64.encode(key).replaceAll('=', ''),
            base64Url.encode(key).replaceAll('=', ''),
            [for (final b in key) b.toRadixString(16).padLeft(2, '0')].join(),
          };
          for (final form in forms) {
            expect(text, isNot(contains(form)));
          }
        }
      },
    );
  });
}
