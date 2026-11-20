// Provider der Online-Signatur: Verbindung ins Netz, Sitzungshalter je
// System und "Verbindung prüfen" für das Testsystem von A-Trust. Keiner von
// ihnen schickt beim Erzeugen eine Anfrage; das tut erst eine Kette mit einer
// Online-Einheit oder ein Lauf von "Verbindung prüfen".

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import '../../data/providers.dart';
import '../rksv_providers.dart';
import '../rksv_secrets.dart';
import 'atrust_client.dart';
import 'atrust_session_keeper.dart';
import 'connection_check.dart';

/// Die Verbindung zu A-Trust. Tests setzen `FakeAtrust.client` ein. Der
/// Aufbau einer Verbindung darf 10 Sekunden dauern; die Zeit, die eine
/// offene Verbindung ungenutzt bleibt, ist die Vorgabe von [HttpClient].
final atrustHttpClientProvider = Provider<http.Client>((ref) {
  final client = IOClient(
    HttpClient()..connectionTimeout = const Duration(seconds: 10),
  );
  ref.onDispose(client.close);
  return client;
});

/// Der Sitzungshalter je System. Am Testsystem mit dem öffentlichen
/// Test-Benutzer (P6), am echten System mit den Zugangsdaten aus dem
/// geschützten Speicher, bei jeder Anmeldung neu gelesen (Q5), und dessen
/// eigenem Kennzeichen "abgelehnt" (Q4). Er lädt das Kennzeichen gleich beim
/// Erzeugen, damit die Oberfläche es früh kennt; darauf gewartet wird nicht,
/// und ein Fehler dabei ist egal: Der Halter schickt nichts, solange er es
/// nicht kennt, und liest beim nächsten Gebrauch neu.
final atrustKeeperProvider = Provider.family<AtrustSessionKeeper, AtrustSystem>(
  (ref, system) {
    final secrets = ref.watch(rksvSecretsProvider);
    final keeper = AtrustSessionKeeper(
      client: AtrustClient(ref.watch(atrustHttpClientProvider), system),
      credentials: switch (system) {
        AtrustSystem.test => () async => const AtrustCredentials(
          atrustTestUser,
          atrustTestPassword,
        ),
        AtrustSystem.live => secrets.atrustCredentials,
      },
      secrets: secrets,
      clock: ref.watch(clockProvider),
      live: system == AtrustSystem.live,
    );
    keeper.restore().ignore();
    return keeper;
  },
);

/// "Verbindung prüfen" je System mit dem Halter der Bons, also derselben
/// Sitzung und demselben Kennzeichen "abgelehnt". Der Benutzer ist am
/// Testsystem fest, am echten System wird er bei jedem Lauf aus dem
/// geschützten Speicher gelesen. Am echten System vergleicht der Lauf das
/// Zertifikat des Kontos mit dem der laufenden Kette `live` (B21).
final connectionCheckProvider = Provider.family<ConnectionCheck, AtrustSystem>((
  ref,
  system,
) {
  final secrets = ref.watch(rksvSecretsProvider);
  final check = ConnectionCheck(
    client: AtrustClient(ref.watch(atrustHttpClientProvider), system),
    keeper: ref.watch(atrustKeeperProvider(system)),
    user: switch (system) {
      AtrustSystem.test => () async => atrustTestUser,
      AtrustSystem.live =>
        () async => (await secrets.atrustCredentials())?.user,
    },
    clock: ref.watch(clockProvider),
    liveChainSerial: switch (system) {
      AtrustSystem.test => null,
      AtrustSystem.live =>
        () => ref.read(rksvServiceProvider).liveChainSerial(),
    },
  );
  ref.onDispose(check.dispose);
  return check;
});
