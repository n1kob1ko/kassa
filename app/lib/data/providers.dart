// Provider für Datenbank, Uhr und Repositories.

import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/clock.dart';
import '../domain/catalog.dart';
import 'catalog_repository.dart';
import 'database.dart';
import 'day_repository.dart';
import 'receipt_repository.dart';
import 'settings_repository.dart';
import 'staff_repository.dart';
import 'stats_repository.dart';

/// Öffnet die echte Datenbank. Tests ersetzen ihn durch
/// `KassaDatabase(NativeDatabase.memory())`.
final databaseProvider = Provider<KassaDatabase>((ref) {
  final db = KassaDatabase(driftDatabase(name: 'kassa'));
  ref.onDispose(db.close);
  return db;
});

final clockProvider = Provider<Clock>((ref) => const SystemClock());

final catalogRepositoryProvider = Provider((ref) => CatalogRepository(ref.watch(databaseProvider)));

final staffRepositoryProvider = Provider((ref) => StaffRepository(ref.watch(databaseProvider)));

final settingsRepositoryProvider = Provider(
  (ref) => SettingsRepository(ref.watch(databaseProvider)),
);

final dayRepositoryProvider = Provider(
  (ref) => DayRepository(ref.watch(databaseProvider), ref.watch(clockProvider)),
);

final receiptRepositoryProvider = Provider(
  (ref) => ReceiptRepository(
    ref.watch(databaseProvider),
    ref.watch(clockProvider),
    ref.watch(dayRepositoryProvider),
  ),
);

final statsRepositoryProvider = Provider(
  (ref) => StatsRepository(ref.watch(databaseProvider), ref.watch(clockProvider)),
);

/// Die eingespielte Speisekarte, `null` solange keine da ist.
final catalogProvider = FutureProvider<Catalog?>(
  (ref) => ref.watch(catalogRepositoryProvider).current(),
);

/// Die Einrichtung ist fertig, wenn es eine Speisekarte und mindestens einen
/// Chef gibt.
final setupCompleteProvider = FutureProvider<bool>((ref) async {
  final catalog = await ref.watch(catalogProvider.future);
  if (catalog == null) return false;
  final staff = await ref.read(staffRepositoryProvider).all();
  return staff.any((s) => s.isChef);
});

/// Die Speisekarte als Strom: ändert sich ein Artikel (zum Beispiel "im
/// Verkauf"), sieht es die Kassa sofort.
final catalogStreamProvider = StreamProvider<Catalog?>(
  (ref) => ref.watch(catalogRepositoryProvider).watch(),
);

/// Die Einstellungen der Kassa als Strom.
final settingsStreamProvider = StreamProvider<RegisterSettings>(
  (ref) => ref.watch(settingsRepositoryProvider).watch(),
);
