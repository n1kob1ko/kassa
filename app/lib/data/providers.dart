// Provider für Datenbank, Uhr und Repositories.

import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/clock.dart';
import 'catalog_repository.dart';
import 'database.dart';
import 'settings_repository.dart';
import 'staff_repository.dart';

/// Öffnet die echte Datenbank. Tests ersetzen ihn durch
/// `KassaDatabase(NativeDatabase.memory())`.
final databaseProvider = Provider<KassaDatabase>((ref) {
  final db = KassaDatabase(driftDatabase(name: 'kassa'));
  ref.onDispose(db.close);
  return db;
});

final clockProvider = Provider<Clock>((ref) => const SystemClock());

final catalogRepositoryProvider =
    Provider((ref) => CatalogRepository(ref.watch(databaseProvider)));

final staffRepositoryProvider =
    Provider((ref) => StaffRepository(ref.watch(databaseProvider)));

final settingsRepositoryProvider =
    Provider((ref) => SettingsRepository(ref.watch(databaseProvider)));
