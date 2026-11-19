// Koppeln und Abgleich mit dem Server, verdrahtet mit der Anmeldung und dem
// offenen Bon. Liegt neben `app.dart`, damit `data/` nichts aus `features/`
// braucht.

import 'dart:async';
import 'dart:io' show Directory;

import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'core/app_info.dart';
import 'data/providers.dart';
import 'devices/internet.dart';
import 'features/kassa/cart_controller.dart';
import 'features/login/session.dart';
import 'sync/file_sync.dart';
import 'sync/pairing_service.dart';
import 'sync/push_wire.dart';
import 'sync/sync_service.dart';

/// Ob die App eine Adresse des Servers hat. Tests setzen `true` ein.
final hasServerProvider = Provider<bool>((ref) => hasServer);

/// Koppeln und erstes Laden. Ist die Speisekarte ersetzt, ist niemand mehr
/// angemeldet, der offene Bon ist leer und die Einrichtung wird neu geprüft.
final pairingServiceProvider = Provider(
  (ref) => PairingService(
    api: ref.watch(serverApiProvider),
    tokens: ref.watch(tokenStoreProvider),
    syncState: ref.watch(syncStateRepositoryProvider),
    changes: ref.watch(serverChangesProvider),
    clock: ref.watch(clockProvider),
    deviceModel: ref.watch(deviceInfoProvider).model,
    onCatalogReplaced: () {
      ref.read(sessionProvider.notifier).logout();
      // Nicht invalidate: käme der neue Katalog zuerst, schriebe der Bon
      // seinen Entwurf beim Neuaufbau zurück. `clear` schreibt den leeren
      // Entwurf, und ein leerer Bon folgt dem Katalog nicht mehr.
      ref.read(cartProvider.notifier).clear();
      ref.invalidate(catalogProvider);
    },
  ),
);

/// Der Ordner für Fotos und Logo: ein Unterordner des Ordners der App, den
/// nur die App sieht. Tests setzen einen Ordner im Temp-Verzeichnis ein.
final fileDirProvider = Provider<Future<Directory> Function()>(
  (ref) =>
      () async =>
          Directory('${(await getApplicationSupportDirectory()).path}/files'),
);

/// Lädt Fotos und Logo vom Server, nach jedem Holen.
final fileSyncProvider = Provider(
  (ref) => FileSync(
    ref.watch(databaseProvider),
    ref.watch(serverApiProvider),
    ref.watch(fileDirProvider),
  ),
);

/// Der Abgleich im Hintergrund, schon gestartet. `KassaApp` liest ihn, sobald
/// die Kassa gekoppelt ist. Ohne Adresse des Servers tut er nichts.
final syncServiceProvider = Provider<SyncService>((ref) {
  final enabled = ref.watch(hasServerProvider);
  final internet = StreamController<bool>();
  final resumed = StreamController<void>();
  final service = SyncService(
    api: ref.watch(serverApiProvider),
    tokens: ref.watch(tokenStoreProvider),
    syncState: ref.watch(syncStateRepositoryProvider),
    changes: ref.watch(serverChangesProvider),
    outbox: ref.watch(outboxRepositoryProvider),
    payloads: PushPayloads(ref.watch(databaseProvider)),
    clock: ref.watch(clockProvider),
    files: ref.watch(fileSyncProvider),
    internet: internet.stream,
    resumed: resumed.stream,
    enabled: enabled,
    // Betriebsname, Mitarbeiter und "Einrichtung fertig" hängen daran.
    onChanged: () => ref.invalidate(catalogProvider),
  );
  ref.onDispose(() {
    service.dispose();
    internet.close();
    resumed.close();
  });
  if (!enabled) return service;
  ref.listen(internetProvider, (_, next) {
    final online = next.value;
    if (online != null) internet.add(online);
  }, fireImmediately: true);
  // Ein neuer Eintrag in der Liste "noch zu senden": bald ein Lauf. Sinkt die
  // Zahl (nach dem Senden), gibt es nichts zu tun.
  ref.listen(outboxCountsProvider, (previous, next) {
    final before = previous?.value?.pending;
    final now = next.value?.pending;
    if (before != null && now != null && now > before) service.poke();
  });
  final lifecycle = AppLifecycleListener(onResume: () => resumed.add(null));
  ref.onDispose(lifecycle.dispose);
  service.start();
  return service;
});
