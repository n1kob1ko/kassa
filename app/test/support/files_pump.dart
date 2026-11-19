// Fotos und Logo für Widget-Tests: echte Dateien in einem Temp-Ordner und die
// Pfade in der Datenbank, so wie `FileSync` sie hinterlässt.

import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/data/database.dart';
import 'package:kassa/data/providers.dart';

import 'kassa_pump.dart' show containerOf;
import 'webp_samples.dart';

Directory? _dir;

/// Schreibt [bytes] als Datei in den Temp-Ordner dieses Tests und gibt den Pfad.
String writeTestFile(String name, List<int> bytes) {
  final dir = _dir ??= () {
    final d = Directory.systemTemp.createTempSync('kassa-bilder-');
    addTearDown(() {
      _dir = null;
      d.deleteSync(recursive: true);
    });
    return d;
  }();
  final file = File('${dir.path}/$name')..writeAsBytesSync(bytes);
  return file.path;
}

/// Der Artikel [id] hat ein Foto, das ganz geladen ist (oder, mit [bytes], eine
/// Datei mit anderem Inhalt, etwa einer kaputten).
Future<void> putPhoto(
  WidgetTester t,
  String id, {
  Uint8List? bytes,
  String color = '#e8c9a0',
}) async {
  final path = writeTestFile('$id.webp', bytes ?? photoWebp);
  final db = containerOf(t).read(databaseProvider);
  await (db.update(db.itemRows)..where((r) => r.id.equals(id))).write(
    ItemRowsCompanion(
      photoFileId: Value('foto-$id'),
      photoColor: Value(color),
      photoPath: Value(path),
    ),
  );
}

/// Der Betrieb hat ein Logo, das ganz geladen ist.
Future<void> putLogo(
  WidgetTester t, {
  Uint8List? bytes,
  String color = '#e65a32',
}) async {
  final path = writeTestFile('logo.webp', bytes ?? logoWebp);
  final db = containerOf(t).read(databaseProvider);
  await db
      .update(db.businessRows)
      .write(
        BusinessRowsCompanion(
          logoFileId: const Value('logo-1'),
          logoColor: Value(color),
          logoPath: Value(path),
        ),
      );
  containerOf(t).invalidate(catalogProvider);
}

/// Lässt Bilddateien lesen und entschlüsseln (echte Zeit) und zeichnet neu,
/// bis [until] zu finden ist (höchstens zwei Sekunden), ohne [until] eine feste
/// Weile.
Future<void> settleImages(WidgetTester t, {bool Function()? until}) async {
  for (var i = 0; i < 100; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await t.pump();
    if (until != null ? until() : i >= 9) break;
  }
  await t.pumpAndSettle();
}
