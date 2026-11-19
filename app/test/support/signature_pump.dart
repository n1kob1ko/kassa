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
import 'package:kassa/rksv/core/rksv_code.dart';
import 'package:kassa/rksv/online/online_providers.dart';
import 'package:kassa/rksv/rksv_journal.dart';
import 'package:kassa/rksv/rksv_providers.dart';
import 'package:kassa/rksv/rksv_secrets.dart';
import 'package:kassa/rksv/rksv_state.dart';

import 'fake_atrust.dart';
import 'fake_signature_unit.dart';
import 'kassa_pump.dart' show containerOf;
import 'rksv_rig.dart' show RecordingProtocolSaver;

export 'fake_signature_unit.dart';
export 'rksv_rig.dart' show RecordingProtocolSaver;

/// Geschützter Speicher im Speicher und [saver] statt des Android-Fensters.
List<Override> signatureOverrides({
  MemoryRksvSecrets? secrets,
  RecordingProtocolSaver? saver,
}) => [
  rksvSecretsProvider.overrideWithValue(secrets ?? MemoryRksvSecrets()),
  protocolSaverProvider.overrideWithValue(saver ?? RecordingProtocolSaver()),
];

/// Wie [signatureOverrides], dazu [fake] statt der Verbindung zu A-Trust.
List<Override> onlineOverrides(
  FakeAtrust fake, {
  MemoryRksvSecrets? secrets,
  RecordingProtocolSaver? saver,
}) => [
  ...signatureOverrides(secrets: secrets, saver: saver),
  atrustHttpClientProvider.overrideWithValue(fake.client),
];

/// Die Kassen-ID der Bildvergleiche.
const fixedCashBoxId = 'K7QM2XB4HN';

/// Schreibt eine laufende Probe (Kette 1, [fixedCashBoxId]) mit [tasks],
/// auf Wunsch mit Ausfall seit [outageSince] (Grund [outageReason]) und einem
/// Hinweis, ohne einen Bon zu signieren. Mit [ended] ist die Kette beendet und
/// die Signatur aus. [unit] signiert die Kette (`atrustTest`: Online-Probe).
/// Ohne [container] gilt der der laufenden App.
Future<void> seedProbe(
  WidgetTester t, {
  List<RksvTask> tasks = const [],
  DateTime? outageSince,
  String outageReason = 'Die Signatur hat nicht geantwortet.',
  RksvUnit unit = RksvUnit.probe,
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
          unit: Value(unit.name),
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
      outageReason: Value(outageSince == null ? null : outageReason),
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

/// Der Text im QR-Code der Bildvergleiche (fest, damit das Bild gleich
/// bleibt; kein echter signierter Bon).
const fixedQrPayload =
    '_R1-AT100_K7QM2XB4HN_1_2026-11-17T11:00:00_0,00_3,15_0,00_0,00_0,00_'
    'U2VLIGtpbmQgMA==_01_AAAAAAAAAAA=';

/// Gibt dem Bon [receiptId] einen festen Eintrag im Protokoll der Kette 1
/// (vorher [seedProbe]). Mit [damaged] als Ausfall-Eintrag.
Future<void> stampReceipt(
  WidgetTester t,
  String receiptId, {
  int position = 1,
  bool damaged = false,
}) async {
  final db = containerOf(t).read(databaseProvider);
  final signature = Uint8List.fromList([for (var i = 0; i < 64; i++) i * 3]);
  await db
      .into(db.rksvEntryRows)
      .insert(
        RksvEntryRowsCompanion.insert(
          chain: 1,
          position: position,
          receiptId: receiptId,
          jws: damaged
              ? jwsDamaged(fixedQrPayload)
              : jwsCompact(fixedQrPayload, signature),
          damaged: damaged,
          certSerial: '01',
        ),
      );
  await t.pumpAndSettle();
}

/// Wie [signatureOverrides], aber das Journal signiert mit [fake] statt mit
/// der Probe-Signatur: So lässt sich ein Ausfall herbeiführen und beenden.
List<Override> fakeSignatureOverrides(FakeSignatureUnit fake) => [
  ...signatureOverrides(),
  rksvJournalProvider.overrideWith(
    (ref) => RksvJournal(
      ref.watch(databaseProvider),
      ref.watch(rksvSecretsProvider),
      (_) async => fake,
      ref.watch(clockProvider),
    ),
  ),
];
