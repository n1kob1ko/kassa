// Ein Bon, den ein Tablet mit 1.10.0 schon gesendet hat, geht nach dem Update
// noch einmal hinaus, jetzt als v: 2. Die Datenbank
// `kassa_v7_receipts_1_10_0.sqlite` und die Sendung von 1.10.0
// (`shared/fixtures/sync/receipt_1_10_0_v1.json`) hat der Code von 1.10.0
// geschrieben (Befehle in `tool/fixtures/receipt_1_10_0.md`). Dieser Test baut
// aus derselben Datenbank nach der Migration 7 zu 8 die Sendung von heute und
// vergleicht sie mit `receipt_1_10_0_as_v2.json`. Der Server prüft beide
// Dateien zusammen (server/test/push.test.ts). Mit KASSA_WRITE_FIXTURES=1
// schreibt dieser Test die Datei neu, sonst vergleicht er.

import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/data/database.dart';
import 'package:kassa/data/outbox_repository.dart';
import 'package:kassa/sync/push_wire.dart';

import '../data/migration_test.dart' show copyFixture;

final _write = Platform.environment['KASSA_WRITE_FIXTURES'] == '1';

void main() {
  test('Bons von 1.10.0 gehen nach dem Update als v: 2 hinaus', () async {
    final old =
        jsonDecode(
              File(
                '../shared/fixtures/sync/receipt_1_10_0_v1.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final oldEntries = (old['entries'] as List).cast<Map<String, dynamic>>();
    final ids = [
      for (final e in oldEntries) (e['receipt'] as Map<String, dynamic>)['id'],
    ];

    final db = KassaDatabase(
      NativeDatabase(await copyFixture('kassa_v7_receipts_1_10_0.sqlite')),
    );
    addTearDown(db.close);
    final payloads = PushPayloads(db);
    final entries = <Map<String, Object?>>[];
    for (final e in await OutboxRepository(db).nextBatch()) {
      if (e.kind == 'receipt' && ids.contains(e.ref)) {
        entries.add((await payloads.build(e))!);
      }
    }
    expect([for (final e in entries) e['seq']], [
      for (final e in oldEntries) e['seq'],
    ]);
    expect([
      for (final e in entries) (e['receipt']! as Map<String, Object?>)['v'],
    ], everyElement(2));

    final file = File('../shared/fixtures/sync/receipt_1_10_0_as_v2.json');
    final content = {'entries': entries};
    if (_write) {
      file.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(content)}\n',
      );
      return;
    }
    expect(
      file.existsSync(),
      isTrue,
      reason:
          '${file.path} fehlt. Mit KASSA_WRITE_FIXTURES=1 schreibt der Test sie.',
    );
    expect(
      jsonDecode(file.readAsStringSync()),
      jsonDecode(jsonEncode(content)),
      reason:
          '${file.path} stimmt nicht mit der Sendung der App überein. Gewollt? '
          'Dann mit KASSA_WRITE_FIXTURES=1 neu schreiben.',
    );
  });
}
