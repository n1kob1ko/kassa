import 'dart:io' show Directory, File, Platform;

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/data/database.dart';
import 'package:kassa/data/settings_repository.dart';
import 'package:kassa/data/sync_state_repository.dart';
import 'package:kassa/sync/file_sync.dart';
import 'package:kassa/sync/server_api.dart';
import 'package:kassa/sync/server_changes.dart';

import '../support/fake_server.dart';
import '../support/webp_samples.dart';

const photoA = 'aaaaaaaa-0000-4000-8000-000000000001';
const photoB = 'bbbbbbbb-0000-4000-8000-000000000002';
const photoC = 'cccccccc-0000-4000-8000-000000000003';
const logoA = 'dddddddd-0000-4000-8000-000000000004';
const logoB = 'eeeeeeee-0000-4000-8000-000000000005';

final at = DateTime(2026, 11, 19, 10);

/// Ein gekoppeltes Tablet mit dem Beispiel-Imbiss, ein Server im Speicher und
/// ein echter Ordner. Nur der Server ist nachgebaut.
class Rig {
  Rig._(this.db, this.server, this.api, this.dir);

  static Future<Rig> create() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final db = KassaDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final server = FakeServer.beispiel(pageSize: 20);
    final dir = Directory.systemTemp.createTempSync('kassa-files-');
    addTearDown(() => dir.deleteSync(recursive: true));
    await SyncStateRepository(db).saveRegister(
      registerId: FakeServer.registerId,
      registerName: 'Kassa 1',
      businessId: FakeServer.businessId,
    );
    await ServerChanges(db).replaceAll(server.pages(), at: at);
    final api = ServerApi(
      baseUrl: 'https://kassa.example',
      client: server,
      appVersion: '1',
    );
    return Rig._(db, server, api, dir);
  }

  final KassaDatabase db;
  final FakeServer server;
  final ServerApi api;
  final Directory dir;

  late final fileSync = FileSync(db, api, () async => dir);

  Future<bool> run() => fileSync.run(FakeServer.token);

  /// Der Server bekommt [bytes] unter [id] und der Artikel dieses Foto.
  void putPhoto(String item, String id, [Uint8List? bytes]) {
    server.files[id] = bytes ?? photoWebp;
    server.change('items', item, {
      'photo': {'id': id, 'color': '#a1b2c3'},
    });
  }

  void removePhoto(String item) =>
      server.change('items', item, {'photo': null});

  void putLogo(String id) {
    server.files[id] = logoWebp;
    server.changeBusiness({
      'logo': {'id': id, 'color': '#ffffff'},
    });
  }

  /// Holt die Änderungen des Servers, wie der Abgleich es tut.
  Future<void> pull() async {
    var state = await SyncStateRepository(db).current();
    while (true) {
      final page = server.page(state.pullCursor);
      final applied = await ServerChanges(db).applyPage(
        page,
        at: at,
        since: state.pullCursor,
        registerId: FakeServer.registerId,
      );
      expect(applied, isTrue);
      if (!page.more) return;
      state = await SyncStateRepository(db).current();
    }
  }

  Future<ItemRow> item(String id) =>
      (db.select(db.itemRows)..where((t) => t.id.equals(id))).getSingle();

  Future<BusinessRow> business() => db.select(db.businessRows).getSingle();

  String path(String id) => '${dir.path}/$id.webp';

  List<String> names() => [
    for (final e in dir.listSync()) e.path.split(Platform.pathSeparator).last,
  ]..sort();
}

void main() {
  test('lädt das Foto und setzt den Pfad', () async {
    final r = await Rig.create();
    r.putPhoto('huhn-bowl', photoA);
    await r.pull();
    expect((await r.item('huhn-bowl')).photoPath, isNull);

    expect(await r.run(), isTrue);

    final row = await r.item('huhn-bowl');
    expect(row.photoPath, r.path(photoA));
    expect(row.photoFileId, photoA);
    expect(File(r.path(photoA)).readAsBytesSync(), photoWebp);
    expect(r.names(), ['$photoA.webp']);
    // Ein zweiter Lauf hat nichts zu tun und fragt den Server nicht mehr.
    expect(await r.run(), isFalse);
    expect(r.server.fileRequests, [photoA]);
  });

  test('Datei fehlt trotz Pfad: der nächste Lauf lädt sie neu', () async {
    final r = await Rig.create();
    r.putPhoto('huhn-bowl', photoA);
    await r.pull();
    await r.run();
    File(r.path(photoA)).deleteSync();

    expect(await r.run(), isTrue);
    expect(File(r.path(photoA)).existsSync(), isTrue);
    expect(r.server.fileRequests, [photoA, photoA]);
  });

  test('Abbruch mitten im Laden: kein Pfad, keine halbe Datei außer .part, '
      'nächster Lauf lädt neu', () async {
    final r = await Rig.create();
    r.putPhoto('huhn-bowl', photoA);
    await r.pull();
    r.server.breakNextFileAfter = 100;

    expect(await r.run(), isFalse);

    expect((await r.item('huhn-bowl')).photoPath, isNull);
    expect(
      r.names().where((n) => n != '$photoA.part'),
      isEmpty,
      reason: 'außer der vorläufigen Datei liegt nichts im Ordner',
    );
    expect(File(r.path(photoA)).existsSync(), isFalse);

    expect(await r.run(), isTrue);
    expect((await r.item('huhn-bowl')).photoPath, r.path(photoA));
    expect(File(r.path(photoA)).readAsBytesSync(), photoWebp);
    expect(r.names(), ['$photoA.webp']);
  });

  test('keine Bilddatei vom Server: kein Pfad, nichts bleibt liegen', () async {
    final r = await Rig.create();
    r.putPhoto('huhn-bowl', photoA, Uint8List.fromList(List.filled(50, 7)));
    await r.pull();

    expect(await r.run(), isFalse);

    expect((await r.item('huhn-bowl')).photoPath, isNull);
    expect(r.names(), isEmpty);
  });

  test(
    '404 für eine Datei: Artikel bleibt ohne Bild, die anderen laden',
    () async {
      final r = await Rig.create();
      r.putPhoto('huhn-bowl', photoA);
      r.putPhoto('cola', photoB);
      r.putPhoto('teigtaschen', photoC);
      r.server.files.remove(photoA); // verschwindet am Server
      await r.pull();

      expect(await r.run(), isTrue);

      expect((await r.item('huhn-bowl')).photoPath, isNull);
      expect((await r.item('cola')).photoPath, r.path(photoB));
      expect((await r.item('teigtaschen')).photoPath, r.path(photoC));
      expect(r.names(), ['$photoB.webp', '$photoC.webp']);
    },
  );

  test('Foto ersetzt: altes Bild bleibt bis das neue da ist, danach ist die '
      'alte Datei weg', () async {
    final r = await Rig.create();
    r.putPhoto('huhn-bowl', photoA);
    await r.pull();
    await r.run();
    r.putPhoto('huhn-bowl', photoB);
    await r.pull();
    // Die neue Kennung steht da, das alte Bild gilt weiter.
    expect((await r.item('huhn-bowl')).photoFileId, photoB);
    expect((await r.item('huhn-bowl')).photoPath, r.path(photoA));

    String? pathWhileLoading;
    var oldFileWhileLoading = false;
    r.server.beforeNextFile = () async {
      pathWhileLoading = (await r.item('huhn-bowl')).photoPath;
      oldFileWhileLoading = File(r.path(photoA)).existsSync();
    };
    expect(await r.run(), isTrue);

    expect(pathWhileLoading, r.path(photoA));
    expect(oldFileWhileLoading, isTrue);
    expect((await r.item('huhn-bowl')).photoPath, r.path(photoB));
    expect(r.names(), ['$photoB.webp']);
  });

  test('Foto ersetzt, das neue lädt nicht: das alte Bild bleibt', () async {
    final r = await Rig.create();
    r.putPhoto('huhn-bowl', photoA);
    await r.pull();
    await r.run();
    r.putPhoto('huhn-bowl', photoB);
    r.server.files.remove(photoB);
    await r.pull();

    expect(await r.run(), isFalse);

    expect((await r.item('huhn-bowl')).photoPath, r.path(photoA));
    expect(r.names(), ['$photoA.webp']);
  });

  test('Foto entfernt: Pfad leer, Datei weg', () async {
    final r = await Rig.create();
    r.putPhoto('huhn-bowl', photoA);
    await r.pull();
    await r.run();
    r.removePhoto('huhn-bowl');
    await r.pull();

    expect((await r.item('huhn-bowl')).photoPath, isNull);
    expect((await r.item('huhn-bowl')).photoFileId, isNull);
    await r.run();

    expect(r.names(), isEmpty);
  });

  test('erstes Foto schaltet Bilder anzeigen ein, ein späteres nach dem '
      'Ausschalten nicht mehr', () async {
    final r = await Rig.create();
    final settings = SettingsRepository(r.db);
    expect((await settings.current()).showImages, isFalse);
    r.putPhoto('huhn-bowl', photoA);
    await r.pull();

    await r.run();

    expect((await settings.current()).showImages, isTrue);
    expect(
      (await r.db.select(r.db.syncStateRows).getSingle()).photosAutoEnabled,
      isTrue,
    );

    await settings.save((await settings.current()).copyWith(showImages: false));
    r.putPhoto('cola', photoB);
    await r.pull();
    await r.run();

    expect((await r.item('cola')).photoPath, r.path(photoB));
    expect((await settings.current()).showImages, isFalse);
  });

  test('ein Logo allein schaltet Bilder anzeigen nicht ein', () async {
    final r = await Rig.create();
    r.putLogo(logoA);
    await r.pull();

    expect(await r.run(), isTrue);

    expect((await SettingsRepository(r.db).current()).showImages, isFalse);
  });

  test('Logo genauso', () async {
    final r = await Rig.create();
    r.putLogo(logoA);
    await r.pull();
    expect((await r.business()).logoPath, isNull);

    // Laden, mit Abbruch zuerst.
    r.server.breakNextFileAfter = 50;
    expect(await r.run(), isFalse);
    expect((await r.business()).logoPath, isNull);

    expect(await r.run(), isTrue);
    expect((await r.business()).logoPath, r.path(logoA));
    expect((await r.business()).logoColor, '#ffffff');
    expect(r.names(), ['$logoA.webp']);

    // Ersetzen: das alte Logo bleibt bis das neue da ist.
    r.putLogo(logoB);
    await r.pull();
    expect((await r.business()).logoPath, r.path(logoA));
    expect(await r.run(), isTrue);
    expect((await r.business()).logoPath, r.path(logoB));
    expect(r.names(), ['$logoB.webp']);

    // Entfernen.
    r.server.changeBusiness({'logo': null});
    await r.pull();
    expect((await r.business()).logoPath, isNull);
    expect((await r.business()).logoFileId, isNull);
    await r.run();
    expect(r.names(), isEmpty);
  });

  test('eine Kennung, die kein UUID ist, wird übersprungen', () async {
    final r = await Rig.create();
    r.putPhoto('huhn-bowl', '../evil');
    r.putPhoto('cola', photoB);
    await r.pull();

    expect(await r.run(), isTrue);

    expect((await r.item('huhn-bowl')).photoPath, isNull);
    expect((await r.item('cola')).photoPath, r.path(photoB));
    expect(r.server.fileRequests, [photoB]);
    expect(
      r.dir.parent.listSync().whereType<File>().map((f) => f.path),
      isNot(contains(endsWith('evil.webp'))),
    );
  });

  test(
    'aufräumen löscht nur <Kennung>.webp und <Kennung>.part im Ordner',
    () async {
      final r = await Rig.create();
      File('${r.dir.path}/$photoC.webp').writeAsBytesSync(photoWebp);
      File('${r.dir.path}/$photoB.part').writeAsBytesSync([1, 2, 3]);
      File('${r.dir.path}/notiz.txt').writeAsStringSync('bleibt');
      File('${r.dir.path}/foto.webp').writeAsBytesSync(photoWebp);
      Directory('${r.dir.path}/$photoA.webp').createSync();
      final outside = File('${r.dir.parent.path}/$photoA.webp')
        ..writeAsBytesSync(photoWebp);
      addTearDown(() {
        if (outside.existsSync()) outside.deleteSync();
      });

      await r.run();

      // Das Verzeichnis namens <Kennung>.webp ist keine Datei und bleibt.
      expect(r.names(), ['$photoA.webp', 'foto.webp', 'notiz.txt']);
      expect(outside.existsSync(), isTrue);
    },
  );

  test('wirft nie, auch wenn der Ordner nicht anzulegen ist', () async {
    final r = await Rig.create();
    r.putPhoto('huhn-bowl', photoA);
    await r.pull();
    final blocked = File('${r.dir.path}/gesperrt')..writeAsStringSync('x');
    final broken = FileSync(
      r.db,
      r.api,
      () async => Directory('${blocked.path}/files'),
    );

    expect(await broken.run(FakeServer.token), isFalse);
    expect((await r.item('huhn-bowl')).photoPath, isNull);
  });

  test('ein falscher Schlüssel: nichts wird geladen, kein Wurf', () async {
    final r = await Rig.create();
    r.putPhoto('huhn-bowl', photoA);
    r.putPhoto('cola', photoB);
    await r.pull();

    expect(await r.fileSync.run('falsch'), isFalse);

    expect(r.server.fileRequests, [photoA]);
    expect((await r.item('huhn-bowl')).photoPath, isNull);
  });
}
