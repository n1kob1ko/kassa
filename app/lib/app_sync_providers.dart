// Koppeln und Abgleich mit dem Server, verdrahtet mit der Anmeldung und dem
// offenen Bon. Liegt neben `app.dart`, damit `data/` nichts aus `features/`
// braucht.

import 'dart:async';

import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_info.dart';
import 'data/providers.dart';
import 'devices/internet.dart';
import 'features/kassa/cart_controller.dart';
import 'features/login/session.dart';
import 'sync/pairing_service.dart';
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
    clock: ref.watch(clockProvider),
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
  final lifecycle = AppLifecycleListener(onResume: () => resumed.add(null));
  ref.onDispose(lifecycle.dispose);
  service.start();
  return service;
});
