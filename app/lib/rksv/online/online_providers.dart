// Provider der Online-Probe: Verbindung ins Netz, Sitzungshalter und
// "Verbindung prüfen" für das Testsystem von A-Trust. Keiner von ihnen
// schickt beim Erzeugen eine Anfrage; das tut erst eine Kette mit einer
// Online-Einheit oder ein Lauf von "Verbindung prüfen".

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../data/providers.dart';
import '../rksv_providers.dart';
import 'atrust_client.dart';
import 'atrust_session_keeper.dart';
import 'connection_check.dart';

/// Die Verbindung zu A-Trust. Tests setzen `FakeAtrust.client` ein.
final atrustHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

/// Der Sitzungshalter für das Testsystem mit dem öffentlichen Test-Benutzer
/// (P6). Er lädt das Kennzeichen "abgelehnt" gleich beim Erzeugen, damit die
/// Oberfläche es früh kennt; darauf gewartet wird nicht, und ein Fehler dabei
/// ist egal: Der Halter schickt nichts, solange er es nicht kennt, und liest
/// beim nächsten Gebrauch neu.
final atrustTestKeeperProvider = Provider<AtrustSessionKeeper>((ref) {
  final keeper = AtrustSessionKeeper(
    client: AtrustClient(
      ref.watch(atrustHttpClientProvider),
      AtrustSystem.test,
    ),
    user: atrustTestUser,
    password: atrustTestPassword,
    secrets: ref.watch(rksvSecretsProvider),
    clock: ref.watch(clockProvider),
  );
  keeper.restore().ignore();
  return keeper;
});

/// "Verbindung prüfen" am Testsystem mit dem Halter der Bons, also derselben
/// Sitzung und demselben Kennzeichen "abgelehnt".
final connectionCheckProvider = Provider<ConnectionCheck>((ref) {
  final check = ConnectionCheck(
    client: AtrustClient(
      ref.watch(atrustHttpClientProvider),
      AtrustSystem.test,
    ),
    keeper: ref.watch(atrustTestKeeperProvider),
    user: atrustTestUser,
    clock: ref.watch(clockProvider),
  );
  ref.onDispose(check.dispose);
  return check;
});
