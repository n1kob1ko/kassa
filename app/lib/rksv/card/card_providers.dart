// Provider für "Karte prüfen", "Karte und PIN" und den Halter der
// Signaturkarte. Tests ersetzen Leser und Wächter durch FakeCardReader und
// MemoryPinGuard.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_info.dart';
import '../../data/providers.dart' show clockProvider;
import '../rksv_providers.dart' show rksvSecretsProvider;
import 'card_check.dart';
import 'card_setup.dart';
import 'card_signer.dart';
import 'pin_guard.dart';
import 'reader_transport.dart';
import 'share_sheet.dart';

final readerTransportProvider = Provider<ReaderTransport>(
  (ref) => ChannelReaderTransport(),
);

final shareSheetProvider = Provider<ShareSheet>(
  (ref) => const ChannelShareSheet(),
);

/// Der PIN-Wächter im geschützten Speicher des Geräts.
final pinGuardProvider = Provider<PinGuard>((ref) => SecurePinGuard());

/// Der eine Halter der Signaturkarte für die App: Bons und Prüfläufe teilen
/// sich den Leser über ihn. Das Anlegen öffnet nichts; beim Verwerfen gibt er
/// die Sitzung frei.
final cardSignerProvider = Provider<CardSigner>((ref) {
  final signer = CardSigner(
    transport: ref.watch(readerTransportProvider),
    secrets: ref.watch(rksvSecretsProvider),
    guard: ref.watch(pinGuardProvider),
  );
  ref.onDispose(() => unawaited(signer.release()));
  return signer;
});

/// Ein Prüflauf für die ganze App: ein zweiter Bildschirm sieht denselben
/// Lauf und kann keinen zweiten starten, solange der erste den Leser hat.
/// Das Anlegen startet keinen Lauf. Während eines Laufs hat der Halter keine
/// Sitzung (C13).
final cardCheckProvider = Provider<CardCheck>((ref) {
  final check = CardCheck(
    transport: ref.watch(readerTransportProvider),
    guard: ref.watch(pinGuardProvider),
    signer: ref.watch(cardSignerProvider),
    now: ref.watch(clockProvider).now,
    appVersion: appVersion,
  );
  ref.onDispose(check.dispose);
  return check;
});

/// "Karte und PIN" über demselben Prüflauf wie "Karte prüfen", mit dem
/// geschützten Speicher und dem einen Halter der App.
final cardSetupProvider = Provider<CardSetup>(
  (ref) => CardSetup(
    check: ref.watch(cardCheckProvider),
    secrets: ref.watch(rksvSecretsProvider),
    signer: ref.watch(cardSignerProvider),
  ),
);
