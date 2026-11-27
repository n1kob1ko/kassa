// Ein Bon, den ein Tablet mit 1.11.0 schon gesendet hat, geht nach dem Update
// noch einmal hinaus, jetzt als v: 3. Die Datenbank
// `kassa_v8_receipts_1_11_0.sqlite` und die Sendung von 1.11.0
// (`shared/fixtures/sync/receipt_1_11_0_v2.json`) hat der Code von 1.11.0
// geschrieben (Befehle in `tool/fixtures/receipt_1_11_0.md`). Dieser Test baut
// aus derselben Datenbank nach der Migration 8 zu 9 die Sendung von heute und
// vergleicht sie mit `receipt_1_11_0_as_v3.json`. Der Server prüft beide
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
  test('der Bon aus 1.11.0 geht nach dem Update als v: 3 hinaus und ist genau '
      'receipt_1_11_0_as_v3.json', () async {
    final old = jsonDecode(
      File('../shared/fixtures/sync/receipt_1_11_0_v2.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final oldEntries = (old['entries'] as List).cast<Map<String, dynamic>>();
    final oldReceipts = [
      for (final e in oldEntries) e['receipt'] as Map<String, dynamic>,
    ];
    expect([for (final r in oldReceipts) r['v']], [2]);

    final db = KassaDatabase(
      NativeDatabase(await copyFixture('kassa_v8_receipts_1_11_0.sqlite')),
    );
    addTearDown(db.close);
    final payloads = PushPayloads(db);
    final entries = <Map<String, Object?>>[];
    final ids = [for (final r in oldReceipts) r['id']];
    for (final e in await OutboxRepository(db).nextBatch()) {
      if (e.kind == 'receipt' && ids.contains(e.ref)) {
        entries.add((await payloads.build(e))!);
      }
    }
    expect(
      [for (final e in entries) e['seq']],
      [for (final e in oldEntries) e['seq']],
    );

    // Nach dem Update: dieselben Felder wie in 1.11.0, dazu v: 3 und die
    // neuen Felder leer (ein Bon aus 1.11.0 hat keinen Schlüssel der Seite).
    final now = [
      for (final e in jsonDecode(jsonEncode(entries)) as List)
        (e as Map<String, dynamic>)['receipt'] as Map<String, dynamic>,
    ];
    for (var i = 0; i < now.length; i++) {
      final r = now[i];
      final before = oldReceipts[i];
      expect(r['v'], 3);
      expect(r['publicToken'], isNull);
      expect(r['vouchers'], isEmpty);
      final payments = (r['payments'] as List).cast<Map<String, dynamic>>();
      expect(
        {
          ...r,
          'v': 2,
          'payments': [
            for (final p in payments)
              {
                for (final k in p.keys)
                  if (!k.startsWith('voucher')) k: p[k],
              },
          ],
        }..removeWhere((k, _) => k == 'publicToken' || k == 'vouchers'),
        before,
      );
      for (final p in payments) {
        expect(
          (p['voucherId'], p['voucherCode'], p['voucherBalanceAfterCents']),
          (null, null, null),
        );
      }
    }

    final file = File('../shared/fixtures/sync/receipt_1_11_0_as_v3.json');
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
          '${file.path} fehlt. Mit KASSA_WRITE_FIXTURES=1 schreibt der Test '
          'sie.',
    );
    expect(
      jsonDecode(file.readAsStringSync()),
      jsonDecode(jsonEncode(content)),
      reason:
          '${file.path} stimmt nicht mit der Sendung der App überein. '
          'Gewollt? Dann mit KASSA_WRITE_FIXTURES=1 neu schreiben.',
    );
  });
}
