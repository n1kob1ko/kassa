// Helfer für Tests der Karte "Server": ein eingerichtetes Tablet mit einem
// Server im Speicher, ungekoppelt oder wirklich gekoppelt (über den Dienst,
// nicht über Zustände von Hand).

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/app_sync_providers.dart';
import 'package:kassa/data/providers.dart';
import 'package:kassa/sync/server_api.dart';
import 'package:kassa/sync/token_store.dart';
import 'package:material_ui/material_ui.dart' show Brightness;

import 'fake_server.dart';
import 'kassa_pump.dart';
import 'pump.dart';
import 'settings_pump.dart';

List<Override> serverOverrides(FakeServer server, {bool hasServer = true}) => [
  hasServerProvider.overrideWithValue(hasServer),
  tokenStoreProvider.overrideWithValue(MemoryTokenStore()),
  serverApiProvider.overrideWithValue(
    ServerApi(
      baseUrl: 'https://kassa.example',
      client: server,
      appVersion: '1',
    ),
  ),
];

/// Ein eingerichtetes Tablet, noch nicht gekoppelt, in den Einstellungen.
Future<FakeServer> pumpUnpaired(
  WidgetTester t, {
  bool hasServer = true,
  Brightness brightness = Brightness.light,
}) async {
  final server = FakeServer.beispiel();
  await pumpSettings(
    t,
    brightness: brightness,
    extra: serverOverrides(server, hasServer: hasServer),
  );
  return server;
}

/// Ein Tablet, das gekoppelt ist (mit [load] auch geladen), in den
/// Einstellungen. Die Anmeldung danach ist die der Speisekarte vom Server.
Future<FakeServer> pumpPaired(
  WidgetTester t, {
  FakeServer? server,
  bool load = true,
  Brightness brightness = Brightness.light,
}) async {
  final s = server ?? FakeServer.beispiel();
  await pumpSettings(t, brightness: brightness, extra: serverOverrides(s));
  final service = containerOf(t).read(pairingServiceProvider);
  await service.pair(FakeServer.code);
  if (load) {
    await service.loadInitial();
    await t.pumpAndSettle();
    await typePin(t, '1234');
    await t.pumpAndSettle();
    await openSettings(t);
  } else {
    try {
      await service.loadInitial();
    } on ServerException {
      // gewollt: die Speisekarte bleibt ungeladen
    }
    await t.pumpAndSettle();
  }
  return s;
}
