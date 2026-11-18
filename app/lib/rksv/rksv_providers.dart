// Provider der Signatur (RKSV): geschützter Speicher, Journal, Service und
// das Speichern des Protokolls.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import 'dep_export.dart';
import 'rksv_journal.dart';
import 'rksv_secrets.dart';
import 'rksv_service.dart';

/// Schlüssel der Signatur im geschützten Speicher. Tests setzen
/// `MemoryRksvSecrets` ein.
final rksvSecretsProvider = Provider<RksvSecrets>((ref) => SecureRksvSecrets());

/// Speichert das ausgegebene Protokoll. Tests setzen eine Attrappe ein.
final protocolSaverProvider = Provider<ProtocolSaver>(
  (ref) => const FilePickerProtocolSaver(),
);

final rksvJournalProvider = Provider((ref) {
  final db = ref.watch(databaseProvider);
  final secrets = ref.watch(rksvSecretsProvider);
  return RksvJournal(
    db,
    secrets,
    probeSignatureUnitOf(db, secrets),
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
