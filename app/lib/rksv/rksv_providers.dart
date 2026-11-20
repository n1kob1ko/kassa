// Provider der Signatur (RKSV): geschützter Speicher, Journal, Service und
// das Speichern des Protokolls.

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import 'dep_export.dart';
import 'online/atrust_client.dart';
import 'online/online_providers.dart';
import 'online/online_signature_unit.dart';
import 'rksv_journal.dart';
import 'rksv_secrets.dart';
import 'rksv_service.dart';
import 'rksv_state.dart';

/// Schlüssel der Signatur im geschützten Speicher. Tests setzen
/// `MemoryRksvSecrets` ein.
final rksvSecretsProvider = Provider<RksvSecrets>((ref) => SecureRksvSecrets());

/// Speichert das ausgegebene Protokoll. Tests setzen eine Attrappe ein.
final protocolSaverProvider = Provider<ProtocolSaver>(
  (ref) => const FilePickerProtocolSaver(),
);

/// Die Online-Einheiten der App: eine [OnlineSignatureUnit] mit Kennung,
/// Zertifikat und Ausstellern der Kette, bei `atrustTest` am Testsystem, bei
/// `atrust` am echten System, jeweils mit dem Halter des Systems aus
/// [atrustKeeperProvider]. Halter und Verbindung entstehen erst beim ersten
/// Bon einer solchen Kette. Auf das Laden des Halters wird hier nicht
/// gewartet: Ein Fehler beim Bauen der Einheit wäre ein unerwarteter Fehler
/// und beendete die Probe; der Halter schützt das Konto selbst (R6).
OnlineUnitOf onlineSignatureUnitOf(Ref ref) => (chain, certificate) async {
  final system = switch (RksvUnit.values.asNameMap()[chain.unit]) {
    RksvUnit.atrustTest => AtrustSystem.test,
    RksvUnit.atrust => AtrustSystem.live,
    RksvUnit.probe ||
    null => throw StateError('Kette ${chain.chain} hat keine Online-Einheit.'),
  };
  return OnlineSignatureUnit(
    client: AtrustClient(ref.read(atrustHttpClientProvider), system),
    keeper: ref.read(atrustKeeperProvider(system)),
    zdaId: chain.zdaId,
    certificateDer: certificate.certificate,
    issuerCertificatesDer: [
      for (final i in issuersBase64(certificate)) base64.decode(i),
    ],
  );
};

final rksvJournalProvider = Provider((ref) {
  final db = ref.watch(databaseProvider);
  final secrets = ref.watch(rksvSecretsProvider);
  return RksvJournal(
    db,
    secrets,
    signatureUnitOf(db, secrets, online: onlineSignatureUnitOf(ref)),
    ref.watch(clockProvider),
  );
});

final rksvServiceProvider = Provider(
  (ref) => RksvService(
    ref.watch(databaseProvider),
    ref.watch(rksvSecretsProvider),
    ref.watch(receiptRepositoryProvider),
    ref.watch(clockProvider),
    saver: ref.watch(protocolSaverProvider),
  ),
);
