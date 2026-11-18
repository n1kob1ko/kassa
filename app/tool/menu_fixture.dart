// Erzeugt die erwarteten Ergebnisse der gemeinsamen Beispiele zur
// Speisekarten-Datei. Aufruf aus `app/`: dart run tool/menu_fixture.dart
//
// Liest jede Datei aus shared/fixtures/menu/inputs/, liest sie mit dem Leser
// der App und schreibt nach shared/fixtures/menu/expected/ entweder
// {"problems": [...]} oder {"menu": {...}}. Der Server prüft denselben
// Satz Dateien mit seinem eigenen Leser.

import 'dart:convert';
import 'dart:io';

import 'package:kassa/domain/menu_import.dart';
import 'package:kassa/sync/wire.dart';

final fixtureRoot = Directory('../shared/fixtures/menu');

/// Dateiname (mit `.json`) und erwarteter Inhalt für jede Eingabe.
Map<String, String> buildMenuFixtures(Directory root) {
  final inputs = Directory('${root.path}/inputs')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  final result = <String, String>{};
  for (final file in inputs) {
    final name = file.uri.pathSegments.last;
    final text = utf8.decode(file.readAsBytesSync());
    Object body;
    try {
      body = {'menu': catalogToWire(parseMenuFile(text))};
    } on MenuImportException catch (e) {
      body = {'problems': e.problems};
    }
    result[name] =
        '${const JsonEncoder.withIndent('  ').convert(_sorted(body))}\n';
  }
  return result;
}

Object? _sorted(Object? v) {
  if (v is Map) {
    final keys = v.keys.cast<String>().toList()..sort();
    return {for (final k in keys) k: _sorted(v[k])};
  }
  if (v is List) return [for (final e in v) _sorted(e)];
  return v;
}

void main() {
  final out = Directory('${fixtureRoot.path}/expected')
    ..createSync(recursive: true);
  final fixtures = buildMenuFixtures(fixtureRoot);
  for (final f in out.listSync().whereType<File>()) {
    if (!fixtures.containsKey(f.uri.pathSegments.last)) f.deleteSync();
  }
  fixtures.forEach((name, content) {
    File('${out.path}/$name').writeAsStringSync(content);
  });
  stdout.writeln('${fixtures.length} Dateien geschrieben.');
}
