// Provider der Signatur (RKSV): geschützter Speicher, Journal, Service.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import 'rksv_journal.dart';
import 'rksv_secrets.dart';
import 'rksv_service.dart';

/// Schlüssel der Signatur im geschützten Speicher. Tests setzen
/// `MemoryRksvSecrets` ein.
final rksvSecretsProvider = Provider<RksvSecrets>((ref) => SecureRksvSecrets());

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
  ),
);
