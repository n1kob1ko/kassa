// Provider für "Karte prüfen". Tests ersetzen Leser und Wächter durch
// FakeCardReader und MemoryPinGuard.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_info.dart';
import '../../data/providers.dart' show clockProvider;
import 'card_check.dart';
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

/// Ein Prüflauf für die ganze App: ein zweiter Bildschirm sieht denselben
/// Lauf und kann keinen zweiten starten, solange der erste den Leser hat.
/// Das Anlegen startet keinen Lauf.
final cardCheckProvider = Provider<CardCheck>((ref) {
  final check = CardCheck(
    transport: ref.watch(readerTransportProvider),
    guard: ref.watch(pinGuardProvider),
    now: ref.watch(clockProvider).now,
    appVersion: appVersion,
  );
  ref.onDispose(check.dispose);
  return check;
});
