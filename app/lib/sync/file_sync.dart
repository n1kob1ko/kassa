// Lädt die Fotos der Artikel und das Logo des Betriebs auf das Tablet und
// räumt Dateien weg, auf die nichts mehr zeigt.
//
// Eine Datei kommt erst in `<id>.part`, wird dann in `<id>.webp` umbenannt, und
// erst danach zeigt `photoPath` bzw. `logoPath` auf sie. Das Tablet zeigt also
// nie eine halbe Datei. Bis das neue Bild da ist, gilt das alte weiter. Die
// Kassa wartet auf nichts davon: `run` wirft nie.

import 'dart:io';

import 'package:drift/drift.dart';

import '../data/database.dart';
import '../data/settings_repository.dart';
import 'server_api.dart';

/// Eine Kennung vom Server wird Teil eines Dateinamens: nur Ziffern, Buchstaben
/// a bis f und Bindestriche, nie ein Punkt oder ein Schrägstrich.
final _fileId = RegExp(r'^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$');

/// Die Dateien, die dieser Ordner enthalten darf und `FileSync` aufräumt.
final _ownFile = RegExp(
  r'^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}\.(webp|part)$',
);

/// So viele Fehler beim Verbinden in Folge, dann ist das Netz weg und der
/// Lauf endet, statt jede Datei einzeln auf die Zeitgrenze warten zu lassen.
const _connectionFailuresInARow = 3;

class FileSync {
  /// [dir] liefert den Ordner für die Dateien (er wird bei Bedarf angelegt).
  /// Nur Dateien der Form `<Kennung>.webp` und `<Kennung>.part` darin werden je
  /// gelöscht, sonst nichts.
  FileSync(this._db, this._api, this._dir);

  final KassaDatabase _db;
  final ServerApi _api;
  final Future<Directory> Function() _dir;

  /// Lädt, was fehlt, und räumt auf. `true`, wenn sich ein Pfad geändert hat
  /// (ein Bild ist neu da): dann soll die Kassa den Katalog neu lesen. Wirft
  /// nie; ein Fehler bei einer Datei hält die anderen nicht auf.
  Future<bool> run(String token) async {
    var changed = false;
    try {
      final dir = await _dir();
      await dir.create(recursive: true);
      // Eine vorläufige Datei aus einem früheren, abgebrochenen Lauf ist
      // wertlos: Läufe gehen nie gleichzeitig.
      await _removeParts(dir);
      final loader = _Loader(_api, token, dir);
      changed = await _photos(loader, dir);
      if (!loader.stopped) changed = await _logo(loader, dir) || changed;
      await _cleanUp(dir);
    } catch (_) {
      // Die Kassa braucht die Bilder nicht: kein Wurf, der nächste Lauf
      // versucht es wieder.
    }
    return changed;
  }

  Future<bool> _photos(_Loader loader, Directory dir) async {
    var changed = false;
    var firstPhoto = false;
    final rows = await (_db.select(
      _db.itemRows,
    )..where((t) => t.photoFileId.isNotNull())).get();
    for (final row in rows) {
      if (loader.stopped) break;
      final id = row.photoFileId!;
      final target = _pathOf(dir, id);
      if (target == null || await _present(row.photoPath, target)) continue;
      if (!await loader.load(id)) continue;
      // Nur setzen, wenn der Artikel noch dieses Foto will: er kann sich
      // während des Ladens geändert haben.
      final updated =
          await (_db.update(_db.itemRows)
                ..where((t) => t.id.equals(row.id) & t.photoFileId.equals(id)))
              .write(ItemRowsCompanion(photoPath: Value(target)));
      if (updated > 0) {
        changed = true;
        firstPhoto = true;
      }
    }
    if (firstPhoto) await _enableImagesOnce();
    return changed;
  }

  Future<bool> _logo(_Loader loader, Directory dir) async {
    final row = await (_db.select(
      _db.businessRows,
    )..where((t) => t.id.equals(1))).getSingleOrNull();
    final id = row?.logoFileId;
    if (row == null || id == null) return false;
    final target = _pathOf(dir, id);
    if (target == null || await _present(row.logoPath, target)) return false;
    if (!await loader.load(id)) return false;
    final updated =
        await (_db.update(_db.businessRows)
              ..where((t) => t.id.equals(1) & t.logoFileId.equals(id)))
            .write(BusinessRowsCompanion(logoPath: Value(target)));
    return updated > 0;
  }

  /// Der Zielpfad der Datei [id], oder `null` für eine Kennung, die nicht wie
  /// eine UUID aussieht.
  static String? _pathOf(Directory dir, String id) => _fileId.hasMatch(id)
      ? '${dir.path}${Platform.pathSeparator}$id.webp'
      : null;

  /// Ob [path] schon die richtige Datei ist und es sie gibt.
  static Future<bool> _present(String? path, String target) async =>
      path == target && await File(target).exists();

  /// Schaltet "Bilder anzeigen" beim ersten Foto ein Mal von selbst ein.
  /// Danach gilt, was am Tablet eingestellt wird.
  Future<void> _enableImagesOnce() async {
    await _db.transaction(() async {
      final state = await (_db.select(
        _db.syncStateRows,
      )..where((t) => t.id.equals(1))).getSingleOrNull();
      if (state == null || state.photosAutoEnabled) return;
      final settings = SettingsRepository(_db);
      await settings.save(
        (await settings.current()).copyWith(showImages: true),
      );
      await (_db.update(_db.syncStateRows)..where((t) => t.id.equals(1))).write(
        const SyncStateRowsCompanion(photosAutoEnabled: Value(true)),
      );
    });
  }

  Future<void> _removeParts(Directory dir) async {
    await for (final e in dir.list(followLinks: false)) {
      final name = e.uri.pathSegments.last;
      if (e is File && name.endsWith('.part') && _ownFile.hasMatch(name)) {
        await _delete(e);
      }
    }
  }

  /// Löscht `<Kennung>.webp`, auf die keine Zeile mehr zeigt.
  Future<void> _cleanUp(Directory dir) async {
    final used = <String>{
      for (final r in await _db.select(_db.itemRows).get())
        if (r.photoPath != null) r.photoPath!,
      for (final r in await _db.select(_db.businessRows).get())
        if (r.logoPath != null) r.logoPath!,
    };
    await for (final e in dir.list(followLinks: false)) {
      final name = e.uri.pathSegments.last;
      if (e is! File || !_ownFile.hasMatch(name)) continue;
      if (!used.contains(e.path)) await _delete(e);
    }
  }

  static Future<void> _delete(File f) async {
    try {
      await f.delete();
    } on FileSystemException {
      // Der nächste Lauf versucht es noch einmal.
    }
  }
}

/// Lädt einzelne Dateien und merkt sich, wann es keinen Sinn mehr hat.
class _Loader {
  _Loader(this._api, this._token, this._dir);

  final ServerApi _api;
  final String _token;
  final Directory _dir;

  /// Das Netz ist weg oder der Schlüssel gilt nicht: weitere Versuche wären
  /// gleich vergebens.
  bool stopped = false;
  int _connectionFailures = 0;

  /// Dieselbe Datei wird in einem Lauf nur einmal geladen.
  final _done = <String, bool>{};

  /// Lädt [id] nach `<id>.webp`. `true`, wenn die Datei danach ganz da ist.
  Future<bool> load(String id) async {
    final known = _done[id];
    if (known != null) return known;
    return _done[id] = await _download(id);
  }

  Future<bool> _download(String id) async {
    final part = File('${_dir.path}${Platform.pathSeparator}$id.part');
    try {
      final bytes = await _api.downloadFile(token: _token, id: id);
      if (!_isWebp(bytes)) return false;
      _connectionFailures = 0;
      await part.writeAsBytes(bytes, flush: true);
      await part.rename('${_dir.path}${Platform.pathSeparator}$id.webp');
      return true;
    } on ServerException catch (e) {
      switch (e.failure) {
        case ServerFailure.offline || ServerFailure.timeout:
          if (++_connectionFailures >= _connectionFailuresInARow) {
            stopped = true;
          }
        case ServerFailure.unauthorized || ServerFailure.blocked:
          stopped = true;
        default:
          _connectionFailures = 0;
      }
      return false;
    } catch (_) {
      return false;
    } finally {
      try {
        if (await part.exists()) await part.delete();
      } on FileSystemException {
        // Wird beim nächsten Lauf aufgeräumt.
      }
    }
  }

  /// Eine WebP-Datei beginnt mit `RIFF`, vier Bytes Länge (little endian, die
  /// Bytes nach diesen acht) und `WEBP`. Passt die Länge nicht zur Datei, ist
  /// sie abgeschnitten oder hat etwas angehängt und ersetzt kein gutes Bild.
  static bool _isWebp(List<int> b) =>
      b.length > 12 &&
      String.fromCharCodes(b.sublist(0, 4)) == 'RIFF' &&
      String.fromCharCodes(b.sublist(8, 12)) == 'WEBP' &&
      (b[4] | b[5] << 8 | b[6] << 16 | b[7] << 24) + 8 == b.length;
}
