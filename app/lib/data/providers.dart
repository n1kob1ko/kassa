// Provider für Datenbank, Uhr und Repositories.

import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../core/app_info.dart';
import '../core/clock.dart';
import '../domain/catalog.dart';
import '../domain/day.dart';
import '../domain/receipt.dart';
import '../domain/stats.dart';
import '../sync/server_api.dart';
import '../sync/server_changes.dart';
import '../sync/token_store.dart';
import 'card_payment_repository.dart';
import 'catalog_repository.dart';
import 'database.dart';
import 'day_repository.dart';
import 'receipt_repository.dart';
import 'settings_repository.dart';
import 'staff_repository.dart';
import 'stats_repository.dart';
import 'sync_state_repository.dart';

/// Öffnet die echte Datenbank. Tests ersetzen ihn durch
/// `KassaDatabase(NativeDatabase.memory())`.
final databaseProvider = Provider<KassaDatabase>((ref) {
  final db = KassaDatabase(driftDatabase(name: 'kassa'));
  ref.onDispose(db.close);
  return db;
});

final clockProvider = Provider<Clock>((ref) => const SystemClock());

final catalogRepositoryProvider = Provider(
  (ref) => CatalogRepository(ref.watch(databaseProvider)),
);

final staffRepositoryProvider = Provider(
  (ref) => StaffRepository(ref.watch(databaseProvider)),
);

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

final cardPaymentRepositoryProvider = Provider(
  (ref) => CardPaymentRepository(
    ref.watch(databaseProvider),
    ref.watch(clockProvider),
  ),
);

final statsRepositoryProvider = Provider(
  (ref) =>
      StatsRepository(ref.watch(databaseProvider), ref.watch(clockProvider)),
);

final syncStateRepositoryProvider = Provider(
  (ref) => SyncStateRepository(ref.watch(databaseProvider)),
);

/// Stand des Abgleichs mit dem Server als Strom.
final syncStateProvider = StreamProvider<SyncState>(
  (ref) => ref.watch(syncStateRepositoryProvider).watch(),
);

/// Der Geräte-Schlüssel im geschützten Speicher. Tests setzen
/// `MemoryTokenStore` ein.
final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());

final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

/// Zugang zum Server unter [serverUrl]. Nur sinnvoll, wenn [hasServer] gilt.
final serverApiProvider = Provider(
  (ref) => ServerApi(
    baseUrl: serverUrl,
    client: ref.watch(httpClientProvider),
    appVersion: appVersion,
  ),
);

final serverChangesProvider = Provider(
  (ref) => ServerChanges(ref.watch(databaseProvider)),
);

/// Die eingespielte Speisekarte, `null` solange keine da ist.
final catalogProvider = FutureProvider<Catalog?>(
  (ref) => ref.watch(catalogRepositoryProvider).current(),
);

/// Die Einrichtung ist fertig, wenn es eine Speisekarte und mindestens einen
/// Mitarbeiter gibt. Ein Mitarbeiter vom Server kommt mit dem Abgleich, der
/// `catalogProvider` neu laden lässt: der Bildschirm schaltet von selbst weiter.
final setupCompleteProvider = FutureProvider<bool>((ref) async {
  final catalog = await ref.watch(catalogProvider.future);
  if (catalog == null) return false;
  final staff = await ref.read(staffRepositoryProvider).all();
  return staff.isNotEmpty;
});

/// Die Speisekarte als Strom: ändert sich ein Artikel (zum Beispiel "im
/// Verkauf"), sieht es die Kassa sofort.
final catalogStreamProvider = StreamProvider<Catalog?>(
  (ref) => ref.watch(catalogRepositoryProvider).watch(),
);

/// Alle offenen Kartenzahlungen (gestartet und unklar), die älteste zuerst.
final pendingCardPaymentsProvider = StreamProvider<List<PendingCardPayment>>(
  (ref) => ref.watch(cardPaymentRepositoryProvider).watchPending(),
);

/// Die Einstellungen der Kassa als Strom.
final settingsStreamProvider = StreamProvider<RegisterSettings>(
  (ref) => ref.watch(settingsRepositoryProvider).watch(),
);

/// Der offene Geschäftstag als Strom, `null` ohne offenen Tag.
final openDayStreamProvider = StreamProvider<BusinessDay?>(
  (ref) => ref.watch(dayRepositoryProvider).watchOpenDay(),
);

/// Die Bons des offenen Tages, nach Nummer aufsteigend. Ohne offenen Tag leer.
/// Folgt jedem Verkauf und jedem Storno.
final todayReceiptsProvider = StreamProvider<List<Receipt>>((ref) {
  final dayId = ref.watch(openDayStreamProvider.select((d) => d.value?.id));
  if (dayId == null) return Stream.value(const <Receipt>[]);
  return ref.watch(receiptRepositoryProvider).watchDay(dayId);
});

/// Die Zahlen der Übersicht für einen Zeitraum. Wird verworfen, sobald der
/// Bereich nicht mehr angezeigt wird: beim nächsten Öffnen sind die Zahlen neu.
final overviewProvider = FutureProvider.autoDispose
    .family<Overview, StatsRange>(
      (ref, range) => ref.watch(statsRepositoryProvider).overview(range),
    );

/// Die Zahlen des Abschlusses: der offene Tag, sonst der zuletzt
/// abgeschlossene, `null`, solange es noch gar keinen Tag gab. Wird verworfen,
/// sobald der Bereich nicht mehr angezeigt wird, und nach jedem Schreiben dort
/// neu geholt.
final closeSummaryProvider = FutureProvider.autoDispose<DaySummary?>((
  ref,
) async {
  final days = ref.watch(dayRepositoryProvider);
  return await days.summary() ?? await days.lastClosedSummary();
});

/// Wahr, wenn der offene Tag an einem früheren Kalendertag begann als heute:
/// der Abschluss wurde vergessen. Folgt dem offenen Tag, fällt also mit dem
/// Abschluss weg. Die Uhr allein löst keine Neuberechnung aus: wer das Ergebnis
/// anzeigt, holt es mit `ref.invalidate` neu (die Kopfleiste tut das, wenn die
/// App in den Vordergrund kommt und jede Minute).
final forgottenCloseProvider = Provider.autoDispose<bool>((ref) {
  final open = ref.watch(openDayStreamProvider).value;
  return isForgottenClose(open, ref.watch(clockProvider).now());
});
