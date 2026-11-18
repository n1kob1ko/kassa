// Ausgabe des Protokolls in der Form des Finanzministeriums (DEP-Export) und
// das Speichern der Datei über das Fenster von Android.

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:file_picker/file_picker.dart';

import '../data/database.dart';

/// Zeitraum der Ausgabe. Vierteljahre sind Kalender-Vierteljahre in der
/// Ortszeit des Tablets.
enum ExportRange { all, thisQuarter, lastQuarter }

/// Ergebnis von "Protokoll ausgeben". [empty]: kein Eintrag im Zeitraum.
enum ExportOutcome { saved, cancelled, empty }

/// JSON in der Form des Finanzministeriums:
/// `{"Belege-Gruppe":[{"Signaturzertifikat":"<base64 DER>","Zertifizierungsstellen":["<base64>",…],"Belege-kompakt":["<jws>",…]}]}`.
/// Eine Gruppe je zusammenhängender Folge von Einträgen der Kette [chain] mit
/// derselben Seriennummer, Einträge in Reihenfolge. Mit [from] und [until]
/// nur die Einträge, deren Bon in `from <= Zeit < until` entstand. Die Datei
/// enthält nur Zertifikate und JWS, nie einen Schlüssel.
Future<String> buildDepExport(
  KassaDatabase db, {
  required int chain,
  DateTime? from,
  DateTime? until,
}) async {
  final entries = db.rksvEntryRows;
  final receipts = db.receiptRows;
  var where = entries.chain.equals(chain);
  if (from != null) {
    where = where & receipts.createdAt.isBiggerOrEqualValue(from);
  }
  if (until != null) {
    where = where & receipts.createdAt.isSmallerThanValue(until);
  }
  final rows =
      await (db.select(entries).join([
              innerJoin(receipts, receipts.id.equalsExp(entries.receiptId)),
            ])
            ..where(where)
            ..orderBy([OrderingTerm.asc(entries.position)]))
          .map((r) => r.readTable(entries))
          .get();

  final serials = {for (final e in rows) e.certSerial};
  final certificates = <String, RksvCertificateRow>{
    for (final c in await (db.select(
      db.rksvCertificateRows,
    )..where((t) => t.serialHex.isIn(serials))).get())
      c.serialHex: c,
  };

  final groups = <Map<String, Object>>[];
  String? serial;
  late List<String> compact;
  for (final e in rows) {
    if (e.certSerial != serial) {
      serial = e.certSerial;
      final cert = certificates[serial];
      if (cert == null) {
        throw StateError('Zertifikat $serial fehlt in rksv_certificates.');
      }
      compact = [];
      groups.add({
        'Signaturzertifikat': base64.encode(cert.certificate),
        'Zertifizierungsstellen': (jsonDecode(cert.issuers) as List)
            .cast<String>(),
        'Belege-kompakt': compact,
      });
    }
    compact.add(e.jws);
  }
  return jsonEncode({'Belege-Gruppe': groups});
}

/// `kassa-protokoll-PROBE-<Kennung>-<JJJJMMTT>.json` bei Probe, sonst ohne
/// `PROBE-`.
String depFileName({
  required String cashBoxId,
  required bool probe,
  required DateTime now,
}) {
  String two(int v) => v.toString().padLeft(2, '0');
  final date =
      '${now.year.toString().padLeft(4, '0')}${two(now.month)}'
      '${two(now.day)}';
  return 'kassa-protokoll-${probe ? 'PROBE-' : ''}$cashBoxId-$date.json';
}

/// Speichert eine Datei an einem Ort, den die Person wählt.
abstract interface class ProtocolSaver {
  /// false: Die Person hat abgebrochen.
  Future<bool> save(String fileName, Uint8List bytes);
}

/// Das Speichern-Fenster des Systems (auf Android der Dokumente-Dialog); die
/// Bytes schreibt das Plugin selbst an den gewählten Ort.
class FilePickerProtocolSaver implements ProtocolSaver {
  const FilePickerProtocolSaver();

  @override
  Future<bool> save(String fileName, Uint8List bytes) async =>
      await FilePicker.saveFile(
        fileName: fileName,
        bytes: bytes,
        mimeType: 'application/json',
      ) !=
      null;
}
