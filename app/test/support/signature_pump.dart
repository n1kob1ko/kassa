// Helfer für Tests der Karte "Signatur": geschützter Speicher und Speichern
// des Protokolls als Attrappen, und ein fester Stand der Signatur direkt in
// der Datenbank (für Bildvergleiche mit immer derselben Kassen-ID).

import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderContainer;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/data/database.dart';
import 'package:kassa/data/providers.dart';
import 'package:kassa/rksv/rksv_providers.dart';
import 'package:kassa/rksv/rksv_secrets.dart';
import 'package:kassa/rksv/rksv_state.dart';

import 'kassa_pump.dart' show containerOf;
import 'rksv_rig.dart' show RecordingProtocolSaver;

export 'rksv_rig.dart' show RecordingProtocolSaver;

/// Geschützter Speicher im Speicher und [saver] statt des Android-Fensters.
List<Override> signatureOverrides({
  MemoryRksvSecrets? secrets,
  RecordingProtocolSaver? saver,
}) => [
  rksvSecretsProvider.overrideWithValue(secrets ?? MemoryRksvSecrets()),
  protocolSaverProvider.overrideWithValue(saver ?? RecordingProtocolSaver()),
];

/// Die Kassen-ID der Bildvergleiche.
const fixedCashBoxId = 'K7QM2XB4HN';

/// Schreibt eine laufende Probe (Kette 1, [fixedCashBoxId]) mit [tasks],
/// auf Wunsch mit Ausfall seit [outageSince] und einem Hinweis, ohne einen
/// Bon zu signieren. Mit [ended] ist die Kette beendet und die Signatur aus.
/// Ohne [container] gilt der der laufenden App.
Future<void> seedProbe(
  WidgetTester t, {
  List<RksvTask> tasks = const [],
  DateTime? outageSince,
  String? notice,
  bool ended = false,
  ProviderContainer? container,
}) async {
  final db = (container ?? containerOf(t)).read(databaseProvider);
  await db
      .into(db.rksvCertificateRows)
      .insert(
        RksvCertificateRowsCompanion.insert(
          serialHex: '01',
          certificate: Uint8List.fromList([1, 2, 3]),
        ),
      );
  await db
      .into(db.rksvChainRows)
      .insert(
        RksvChainRowsCompanion.insert(
          chain: const Value(1),
          mode: RksvMode.probe.name,
          cashBoxId: fixedCashBoxId,
          zdaId: 'AT100',
          certSerial: '01',
          startedAt: DateTime(2026, 11, 17, 9),
          endedAt: Value(ended ? DateTime(2026, 11, 17, 10) : null),
        ),
      );
  await (db.update(db.rksvStateRows)..where((r) => r.id.equals(1))).write(
    RksvStateRowsCompanion(
      mode: Value((ended ? RksvMode.off : RksvMode.probe).name),
      chain: Value(ended ? null : 1),
      outageSince: Value(outageSince),
      outageReason: Value(
        outageSince == null ? null : 'Die Signatur hat nicht geantwortet.',
      ),
      tasks: Value(encodeRksvTasks(tasks)),
      notice: Value(notice),
    ),
  );
  await t.pumpAndSettle();
}

/// Die zwei Aufgaben aus dem Bild `s1b-2`.
final twoTasks = [
  RksvTask(
    id: 'check-start-1',
    kind: RksvTaskKind.checkStart,
    createdAt: DateTime(2026, 11, 17, 9),
  ),
  RksvTask(
    id: 'backup-2026-Q4',
    kind: RksvTaskKind.backupProtocol,
    createdAt: DateTime(2026, 11, 17, 9),
  ),
];
