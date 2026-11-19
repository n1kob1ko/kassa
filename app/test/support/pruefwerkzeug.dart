// Das Prüfwerkzeug des Finanzministeriums aus Tests: die Datei mit Schlüssel
// und Zertifikaten, der Aufruf und die Regel für seine Ergebnisse. Das
// Werkzeug selbst liegt nicht im Repo; KASSA_RKSV_TOOL zeigt auf seinen
// Ordner (tool/rksv/pruefen.sh).

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'rksv_rig.dart';

const _jar = 'regkassen-verification-depformat-1.1.1.jar';

/// Der Ordner des Prüfwerkzeugs aus KASSA_RKSV_TOOL, sonst null.
String? pruefwerkzeugDir() {
  final dir = Platform.environment['KASSA_RKSV_TOOL'];
  if (dir == null || dir.isEmpty || !Directory(dir).existsSync()) return null;
  return dir;
}

/// Der Inhalt von `cryptographicMaterialContainer.json` zur Kette [chain]:
/// ihr AES-Schlüssel und jedes Zertifikat, mit dem einer ihrer Einträge
/// signiert ist.
Future<String> cryptographicMaterialContainer(RksvRig rig, int chain) async {
  final entries = await rig.entries(chain);
  return jsonEncode({
    'base64AESKey': base64.encode((await rig.secrets.aesKey(chain))!),
    'certificateOrPublicKeyMap': {
      for (final c in await rig.db.select(rig.db.rksvCertificateRows).get())
        if (entries.any((e) => e.certSerial == c.serialHex))
          c.serialHex: {
            'id': c.serialHex,
            'signatureDeviceType': 'CERTIFICATE',
            'signatureCertificateOrPublicKey': base64.encode(c.certificate),
          },
    },
  });
}

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

/// Lässt das Prüfwerkzeug in [tool] über [dep] und [crypto] laufen (Ausgabe
/// nach `aus` in [workDir]) und gibt jede Beanstandung zurück (Datei,
/// verificationId, Meldung). [entryCount]: so viele Einträge hat die Kette.
/// Druckt immer den Ausgang und die letzten 20 Zeilen der Ausgabe.
Future<List<String>> checkWithPruefwerkzeug(
  String tool, {
  required File dep,
  required File crypto,
  required int entryCount,
  required Directory workDir,
}) async {
  final out = '${workDir.path}/aus';
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
    workingDirectory: workDir.path,
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
    for (var i = 0; i < entryCount; i++)
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
