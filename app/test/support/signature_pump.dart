// Helfer für Tests der Karte "Signatur": geschützter Speicher und Speichern
// des Protokolls als Attrappen, und ein fester Stand der Signatur direkt in
// der Datenbank (für Bildvergleiche mit immer derselben Kassen-ID). Dazu
// der echte Betrieb: als fester Stand oder wirklich in Betrieb genommen.

import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderContainer;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/data/database.dart';
import 'package:kassa/data/providers.dart';
import 'package:kassa/features/login/session.dart';
import 'package:kassa/rksv/core/rksv_code.dart';
import 'package:kassa/rksv/online/atrust_client.dart';
import 'package:kassa/rksv/online/atrust_session_keeper.dart';
import 'package:kassa/rksv/online/connection_check.dart';
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

/// Die zwei Aufgaben aus dem Bild `s1b-2`, beide aus der Probe von
/// [seedProbe] (Kette 1, begonnen um 9 Uhr): Eine Aufgabe ohne Kettennummer
/// gehört zur Probe, wenn sie nach deren Beginn entstand.
final twoTasks = [
  RksvTask(
    id: 'check-start-1',
    kind: RksvTaskKind.checkStart,
    createdAt: DateTime(2026, 11, 17, 9),
  ),
  RksvTask(
    id: 'backup-2026-Q4',
    kind: RksvTaskKind.backupProtocol,
    createdAt: DateTime(2026, 11, 17, 9, 30),
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

/// Die Kassen-ID der Bildvergleiche im echten Betrieb (wie im Bild `s2b-08`,
/// erfunden).
const fixedLiveCashBoxId = 'R4TW9KD2PX';

/// Die erfundenen Zugangsdaten des echten Kontos in den Tests der Karte.
const exampleLiveCredentials = AtrustCredentials(
  'u-beispiel',
  'geheim-beispiel',
);

/// Schreibt eine laufende Kette `live` mit Einheit `atrust` (Kette 1,
/// [fixedLiveCashBoxId]) mit [tasks], auf Wunsch mit Ausfall seit
/// [outageSince] (Grund [outageReason]) und einem erfundenen AES-Schlüssel
/// im geschützten Speicher, ohne einen Bon zu signieren. Mit
/// [decommissioned] ist die Kette beendet und die Kassa außer Betrieb. Ohne
/// [container] gilt der der laufenden App. Mit [unit] `card` signiert die
/// Signaturkarte die Kette.
Future<void> seedLive(
  WidgetTester t, {
  List<RksvTask> tasks = const [],
  DateTime? outageSince,
  String outageReason = 'Kein Internet.',
  bool decommissioned = false,
  RksvUnit unit = RksvUnit.atrust,
  ProviderContainer? container,
}) async {
  final c = container ?? containerOf(t);
  final db = c.read(databaseProvider);
  // Erfundener AES-Schlüssel: Ohne ihn entstünde kein Eintrag (Q17).
  await c.read(rksvSecretsProvider).writeAesKey(1, Uint8List(32));
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
          mode: RksvMode.live.name,
          unit: Value(unit.name),
          cashBoxId: fixedLiveCashBoxId,
          zdaId: 'AT1',
          certSerial: '01',
          startedAt: DateTime(2026, 11, 17, 9),
          endedAt: Value(decommissioned ? DateTime(2026, 11, 17, 10) : null),
        ),
      );
  await (db.update(db.rksvStateRows)..where((r) => r.id.equals(1))).write(
    RksvStateRowsCompanion(
      mode: Value((decommissioned ? RksvMode.off : RksvMode.live).name),
      chain: Value(decommissioned ? null : 1),
      outageSince: Value(outageSince),
      outageReason: Value(outageSince == null ? null : outageReason),
      tasks: Value(encodeRksvTasks(tasks)),
    ),
  );
  await t.pumpAndSettle();
}

/// Die zwei Aufgaben nach der Inbetriebnahme (Bild `s2b-08`).
final liveTasks = [
  RksvTask(
    id: 'register-finanzonline-1',
    kind: RksvTaskKind.registerFinanzOnline,
    createdAt: DateTime(2026, 11, 17, 9),
    detail: '24.11.2026',
  ),
  RksvTask(
    id: 'check-start-1',
    kind: RksvTaskKind.checkStart,
    createdAt: DateTime(2026, 11, 17, 9),
  ),
];

/// Die zwei Aufgaben nach der Außerbetriebnahme (Bild `s2b-11`).
final decommissionTasks = [
  RksvTask(
    id: 'report-decommission-1',
    kind: RksvTaskKind.reportDecommission,
    createdAt: DateTime(2026, 11, 17, 10),
    detail: '24.11.2026',
  ),
  RksvTask(
    id: 'backup-decommission-1',
    kind: RksvTaskKind.backupProtocol,
    createdAt: DateTime(2026, 11, 17, 10),
  ),
];

/// Nimmt die Kassa der laufenden App wirklich in Betrieb, über
/// [RksvService.prepareSetup] und [RksvService.goLive]: [exampleLiveCredentials]
/// und ein PendingSetup mit [fixedLiveCashBoxId] im geschützten Speicher der
/// App, die Angaben aus einem eigenen Lauf von "Verbindung prüfen" gegen
/// einen eigenen nachgebauten A-Trust (dort, nicht im A-Trust der App,
/// landen dessen Anfragen). Den Startbeleg signiert der A-Trust der App
/// (`onlineOverrides`) über den Halter des echten Systems: eine Anmeldung
/// und eine Signatur. Ein Zertifikat, das heute gilt, braucht der A-Trust
/// der App dafür nicht.
Future<void> goLiveInApp(WidgetTester t) async {
  final c = containerOf(t);
  final secrets = c.read(rksvSecretsProvider);
  final clock = c.read(clockProvider);
  await secrets.writeAtrustCredentials(exampleLiveCredentials);
  await secrets.writePendingSetup(
    PendingSetup(
      cashBoxId: fixedLiveCashBoxId,
      aesKey: Uint8List.fromList(List.generate(32, (i) => i)),
    ),
  );
  final checked = FakeAtrust(validFrom: DateTime.utc(2020, 6, 1));
  final client = AtrustClient(checked.client, AtrustSystem.live);
  final check = ConnectionCheck(
    client: client,
    keeper: AtrustSessionKeeper(
      client: client,
      credentials: () async => exampleLiveCredentials,
      secrets: MemoryRksvSecrets(),
      clock: clock,
      live: true,
    ),
    user: () async => exampleLiveCredentials.user,
    clock: clock,
  );
  final facts = (await check.run(chefTapped: false)).facts!;
  check.dispose();
  final service = c.read(rksvServiceProvider);
  await service.prepareSetup(facts: facts);
  await service.goLive(staff: c.read(sessionProvider)!, facts: facts);
  await t.pumpAndSettle();
}
