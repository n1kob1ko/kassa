// Lauf mit dem Prüfwerkzeug des Finanzministeriums über ein Protokoll der
// Kassa. Läuft nur, wenn KASSA_RKSV_TOOL auf den Ordner des Werkzeugs zeigt
// (tool/rksv/pruefen.sh); auf GitHub ist es nicht da.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/domain/cart.dart';
import 'package:kassa/domain/catalog.dart';
import 'package:kassa/rksv/dep_export.dart';

import '../support/demo_fixtures.dart';
import '../support/fake_signature_unit.dart';
import '../support/rksv_rig.dart';

const _jar = 'regkassen-verification-depformat-1.1.1.jar';

String? _toolDir() {
  final dir = Platform.environment['KASSA_RKSV_TOOL'];
  if (dir == null || dir.isEmpty || !Directory(dir).existsSync()) return null;
  return dir;
}

Item _item(String id, int priceCents, TaxRate rate, {int deposit = 0}) => Item(
  id: id,
  name: id,
  priceCents: priceCents,
  categoryId: 'snacks',
  taxRate: rate,
  depositCents: deposit,
  position: 0,
);

/// Alle Ergebnisse (Objekte mit `verificationState`) in [json], auch
/// verschachtelte.
Iterable<Map<String, dynamic>> _results(Object? json) sync* {
  if (json is Map<String, dynamic>) {
    if (json.containsKey('verificationState')) yield json;
    for (final v in json.values) {
      yield* _results(v);
    }
  } else if (json is List) {
    for (final v in json) {
      yield* _results(v);
    }
  }
}

void main() {
  final tool = _toolDir();

  test(
    'Protokoll der Kassa besteht das Prüfwerkzeug des Finanzministeriums',
    () async {
      final rig = await RksvRig.open();
      addTearDown(rig.close);
      final temp = await Directory.systemTemp.createTemp('kassa-rksv-');
      addTearDown(() => temp.delete(recursive: true));

      // Feste Zeiten in der Vergangenheit: Das Prüfwerkzeug vergleicht jeden
      // Bon mit der echten Uhr, ein Bon nach "jetzt" scheitert immer (R11).
      // Bons vor dem 1.1.2026 liegen vor der Gültigkeit des Test-Zertifikats;
      // das nimmt das Prüfwerkzeug an.
      // Startbeleg am 18.11.2025 13:05:09.
      rig.clock.value = DateTime(2025, 11, 18, 13, 5, 9);
      await rig.service.enableProbe(staff: rig.chef);
      var minute = 0;
      void tick() =>
          rig.clock.value = DateTime(2025, 11, 18, 13, 6 + minute++, 9);

      // Ein Verkauf mit allen fünf Sätzen und Pfand.
      tick();
      await rig.sell(
        'alle-saetze',
        const Cart.empty()
            .add(cola)
            .add(huhnBowl, options: [xxl, nudeln])
            .add(_item('satz-13', 1350, TaxRate.reduced2))
            .add(_item('satz-0', 500, TaxRate.zero))
            .add(_item('satz-19', 1190, TaxRate.special)),
      );
      // Je ein Satz für sich, einer davon mit Karte.
      for (final (id, item) in [
        ('nur-20', cola),
        ('nur-10', teigtaschen),
        ('nur-13', _item('satz-13', 1350, TaxRate.reduced2)),
        ('nur-0', _item('satz-0', 500, TaxRate.zero)),
        ('nur-19', _item('satz-19', 1190, TaxRate.special)),
      ]) {
        tick();
        await rig.sell(id, const Cart.empty().add(item));
      }
      tick();
      await rig.sellCard(
        'karte',
        const Cart.empty().add(teigtaschen).add(cola),
      );
      // 1.234,56 Euro.
      tick();
      await rig.sell(
        'gross',
        const Cart.empty().add(_item('gross', 123456, TaxRate.normal)),
      );
      // Storno.
      tick();
      await rig.receipts.voidReceipt('nur-10', staff: rig.chef);
      // Zwei Bons im Ausfall, dann Sammelbeleg.
      rig.fake.mode = FakeMode.error;
      tick();
      await rig.sell('ausfall-1', const Cart.empty().add(cola));
      tick();
      await rig.sell('ausfall-2', const Cart.empty().add(teigtaschen));
      rig.fake.mode = FakeMode.ok;
      tick();
      expect(await rig.service.retrySignature(staff: rig.chef), isTrue);
      // Monatswechsel.
      rig.clock.value = DateTime(2025, 12, 1, 10);
      await rig.sell('dezember', const Cart.empty().add(cola));
      // Jahreswechsel.
      rig.clock.value = DateTime(2026, 1, 2, 10);
      await rig.sell('jaenner', const Cart.empty().add(teigtaschen));
      // Nullbeleg, Schlussbeleg.
      rig.clock.value = DateTime(2026, 1, 2, 10, 5);
      await rig.service.zeroReceipt(staff: rig.chef);
      rig.clock.value = DateTime(2026, 1, 2, 10, 10);
      await rig.service.disableProbe(staff: rig.chef);

      final kinds = await rig.entryKinds();
      expect(kinds, [
        'start',
        ...List.filled(8, 'sale'),
        'voided',
        'sale',
        'sale',
        'collective',
        'month',
        'sale',
        'year',
        'sale',
        'zero',
        'closing',
      ]);
      await rig.verifyChain(1);
      final entries = await rig.entries(1);
      expect(
        [for (final e in entries) e.damaged].where((d) => d),
        hasLength(2),
      );

      expect(
        await rig.service.exportProtocol(ExportRange.all, now: rig.clock.now()),
        ExportOutcome.saved,
      );
      final problems = await _check(tool!, rig, temp);
      expect(problems, isEmpty, reason: problems.join('\n\n'));
    },
    skip: tool == null
        ? 'Prüfwerkzeug nicht da: KASSA_RKSV_TOOL zeigt auf keinen Ordner.'
        : null,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

/// Schreibt das Protokoll der Kette 1 als `dep-export.json` und den
/// Schlüssel samt Zertifikaten als `cryptographicMaterialContainer.json` nach
/// [temp], lässt das Prüfwerkzeug darüber laufen und gibt jede Beanstandung
/// zurück (Datei, verificationId, Meldung). Druckt immer den Ausgang und die
/// letzten 20 Zeilen der Ausgabe.
Future<List<String>> _check(String tool, RksvRig rig, Directory temp) async {
  final entries = await rig.entries(1);
  final dep = File('${temp.path}/dep-export.json')
    ..writeAsStringSync(rig.saver.lastText);
  final container = {
    'base64AESKey': base64.encode((await rig.secrets.aesKey(1))!),
    'certificateOrPublicKeyMap': {
      for (final c in await rig.db.select(rig.db.rksvCertificateRows).get())
        if (entries.any((e) => e.certSerial == c.serialHex))
          c.serialHex: {
            'id': c.serialHex,
            'signatureDeviceType': 'CERTIFICATE',
            'signatureCertificateOrPublicKey': base64.encode(c.certificate),
          },
    },
  };
  final crypto = File('${temp.path}/cryptographicMaterialContainer.json')
    ..writeAsStringSync(jsonEncode(container));
  final out = '${temp.path}/aus';

  final run = await Process.run(
    'java',
    [
      '-jar',
      '$tool/$_jar',
      '-v',
      '-f',
      '-i',
      dep.path,
      '-c',
      crypto.path,
      '-o',
      out,
    ],
    workingDirectory: temp.path,
    environment: {'JAVA_TOOL_OPTIONS': ''},
  );
  final lines = '${run.stdout}${run.stderr}'.trimRight().split('\n');
  // ignore: avoid_print
  print(
    'Prüfwerkzeug: Ausgang ${run.exitCode}, letzte Zeilen:\n'
    '${lines.skip(lines.length > 20 ? lines.length - 20 : 0).join('\n')}',
  );
  expect(run.exitCode, 0, reason: 'Ausgang des Prüfwerkzeugs');

  final names = [
    for (var i = 0; i < entries.length; i++)
      for (final part in ['app', 'cashbox', 'cashbox_full', 'dep'])
        '${i.toString().padLeft(4, '0')}_$part.json',
    'DEP-global.json',
    'DEP-full.json',
  ];
  final problems = <String>[];
  for (final name in names) {
    final file = File('$out/$name');
    if (!file.existsSync()) {
      problems.add('$name: fehlt');
      continue;
    }
    final text = utf8.decode(file.readAsBytesSync(), allowMalformed: true);
    final json = jsonDecode(text) as Map<String, dynamic>;
    // Jedes Ergebnis muss PASS sein, das oberste der Datei eingeschlossen.
    // Ausnahme: Ein Bon hat nur eine Art, die übrigen TYPE_OF_RECEIPT_*-
    // Prüfungen scheitern auch beim Beispiel des Finanzministeriums (R9).
    for (final r in _results(json)) {
      final id = '${r['verificationId']}';
      if (r['verificationState'] != 'PASS' &&
          !id.startsWith('TYPE_OF_RECEIPT_')) {
        problems.add(
          '$name: $id ist ${r['verificationState']}: '
          '${r['verificationResultDetailedMessage']}',
        );
      }
    }
    if (name.endsWith('_cashbox_full.json') &&
        !_results(json).any(
          (r) =>
              '${r['verificationId']}'.startsWith('TYPE_OF_RECEIPT_') &&
              r['verificationState'] == 'PASS',
        )) {
      problems.add('$name: keine TYPE_OF_RECEIPT_*-Prüfung mit PASS');
    }
  }
  return problems;
}
