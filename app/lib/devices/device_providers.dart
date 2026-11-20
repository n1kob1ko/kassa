// Provider für die Geräte der Kassa.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import '../data/settings_repository.dart';
import '../domain/receipt.dart';
import '../rksv/setup_facts.dart';
import 'card_terminal.dart';
import 'channel_transport.dart';
import 'network_transport.dart';
import 'printer.dart';
import 'sumup_terminal.dart';

export 'internet.dart' show internetProvider;

/// Das Kartenterminal der Kassa.
final cardTerminalProvider = Provider<CardTerminal>((ref) => SumUpTerminal());

/// Der Stand des Kartenterminals (angemeldet oder nicht). Wer anmeldet oder
/// abmeldet, holt ihn mit `ref.invalidate` neu. Er wird auch neu geholt, wenn
/// die App wieder in den Vordergrund kommt: die Seiten von SumUp für Anmeldung
/// und Kartenleser sind eigene Android-Bildschirme über der App.
final cardStatusProvider = FutureProvider<CardTerminalStatus>((ref) {
  final observer = _ResumeObserver(ref.invalidateSelf);
  WidgetsBinding.instance.addObserver(observer);
  ref.onDispose(() => WidgetsBinding.instance.removeObserver(observer));
  return ref.watch(cardTerminalProvider).status();
});

class _ResumeObserver with WidgetsBindingObserver {
  _ResumeObserver(this._onResumed);

  final VoidCallback _onResumed;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _onResumed();
  }
}

typedef TransportFactory = PrinterTransport? Function(
  RegisterSettings settings,
);

/// Baut den Transport zu den Einstellungen; `null`, wenn kein Drucker
/// eingerichtet ist.
final transportFactoryProvider = Provider<TransportFactory>(
  (ref) => (settings) {
    final address = settings.printerAddress?.trim();
    if (address == null || address.isEmpty) return null;
    return switch (settings.printerKind) {
      PrinterKind.network => NetworkTransport(address),
      PrinterKind.usb => ChannelTransport(PrinterKind.usb, address),
      PrinterKind.bluetooth => ChannelTransport(PrinterKind.bluetooth, address),
      PrinterKind.none => null,
    };
  },
);

/// Der Drucker folgt den Einstellungen und den Betriebsdaten. Solange eines
/// von beiden noch lädt, melden seine Aufrufe "nicht eingerichtet".
final receiptPrinterProvider = Provider<ReceiptPrinter>((ref) {
  final settings = ref.watch(settingsStreamProvider).value;
  final catalog = ref.watch(catalogStreamProvider).value;
  if (settings == null || catalog == null) return const _NoPrinter();
  final receipts = ref.watch(receiptRepositoryProvider);
  return EscPosPrinter(
    transport: ref.watch(transportFactoryProvider)(settings),
    business: catalog.business,
    columns: settings.printerColumns,
    qrAsImage: settings.printerQrAsImage,
    clock: ref.watch(clockProvider),
    numberOfReceipt: (id) async => (await receipts.byId(id)).number,
  );
});

class _NoPrinter implements ReceiptPrinter {
  const _NoPrinter();

  static const _outcome = PrintOutcome.failed(PrintProblem.notSetUp);

  @override
  Future<PrintOutcome> printReceipt(
    Receipt receipt, {
    bool openDrawer = false,
  }) async => _outcome;

  @override
  Future<PrintOutcome> openDrawer() async => _outcome;

  @override
  Future<PrintOutcome> testPrint() async => _outcome;

  @override
  Future<PrintOutcome> printSetupFacts(SetupFacts facts) async => _outcome;
}
