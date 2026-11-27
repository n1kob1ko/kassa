// Provider für die Geräte der Kassa.

import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_language.dart';
import '../data/providers.dart';
import '../data/settings_repository.dart';
import '../domain/kitchen_ticket.dart';
import '../domain/receipt.dart';
import '../domain/customer.dart';
import '../domain/day.dart';
import '../domain/period_report.dart';
import '../rksv/setup_facts.dart';
import 'card_terminal.dart';
import 'channel_transport.dart';
import 'kitchen_ticket_image.dart';
import 'mono_image.dart';
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
///
/// Er hört nur auf die Angaben des Bondruckers: in derselben Zeile der
/// Einstellungen steht der Entwurf des Bons, der sich bei jedem Verkauf
/// ändert, und ein neuer Drucker hätte eine neue, leere Warteschlange (der
/// Bon eines nächsten Verkaufs käme vor dem Küchenbon des vorigen).
final receiptPrinterProvider = Provider<ReceiptPrinter>((ref) {
  // Jedes Feld, das der Bau unten liest, muss hier stehen: sonst bliebe nach
  // einer Änderung der alte Drucker.
  final setup = ref.watch(
    settingsStreamProvider.select(
      (a) => switch (a.value) {
        null => null,
        final s => (
          s.printerKind,
          s.printerAddress,
          s.printerColumns,
          s.printerQrAsImage,
        ),
      },
    ),
  );
  final catalog = ref.watch(catalogStreamProvider).value;
  final settings = ref.read(settingsStreamProvider).value;
  if (setup == null || settings == null || catalog == null) {
    return const _NoPrinter();
  }
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

/// Drucker für den Küchenbon: bei `receiptPrinter` der Bondrucker (dieselbe Instanz), bei `kitchenPrinter` ein
/// eigener mit dem Küchen-Transport, bei `off` null. Ist als Küchendrucker
/// derselbe Drucker gewählt wie als Bondrucker (gleiche Art, gleiche
/// Adresse), ist es ebenfalls der Bondrucker: eine Warteschlange, Bon und
/// Küchenbon gehen nie gleichzeitig hinaus.
///
/// Hört wie [receiptPrinterProvider] nur auf die eigenen Angaben und auf Art
/// und Adresse des Bondruckers (für den Vergleich).
final kitchenPrinterProvider = Provider<ReceiptPrinter?>((ref) {
  // Jedes Feld, das der Bau unten liest, muss hier stehen: sonst bliebe nach
  // einer Änderung der alte Drucker.
  final setup = ref.watch(
    settingsStreamProvider.select(
      (a) => switch (a.value) {
        null => null,
        final s => (
          s.kitchenMode,
          s.kitchenPrinterKind,
          s.kitchenPrinterAddress,
          s.kitchenPrinterColumns,
          s.printerKind,
          s.printerAddress,
        ),
      },
    ),
  );
  final settings = ref.read(settingsStreamProvider).value;
  if (setup == null || settings == null) return const _NoPrinter();
  switch (settings.kitchenMode) {
    case KitchenMode.off:
      return null;
    case KitchenMode.receiptPrinter:
      // Dieselbe Instanz: Bon und Küchenbon gehen durch eine Warteschlange.
      return ref.watch(receiptPrinterProvider);
    case KitchenMode.kitchenPrinter:
      if (kitchenSharesReceiptPrinter(settings)) {
        return ref.watch(receiptPrinterProvider);
      }
      final address = settings.kitchenPrinterAddress?.trim();
      final catalog = ref.watch(catalogStreamProvider).value;
      if (catalog == null) return const _NoPrinter();
      // Ohne Adresse kein Transport, nie der des Bondruckers.
      final transport =
          settings.kitchenPrinterKind == PrinterKind.none ||
              address == null ||
              address.isEmpty
          ? null
          : ref.watch(transportFactoryProvider)(
              settings.copyWith(
                printerKind: settings.kitchenPrinterKind,
                printerAddress: address,
              ),
            );
      return EscPosPrinter(
        transport: transport,
        business: catalog.business,
        columns: settings.kitchenPrinterColumns,
        clock: ref.watch(clockProvider),
        numberOfReceipt: (_) async => null,
      );
  }
});

/// Der Küchenbon geht durch die Warteschlange des Bondruckers: bei "Am
/// Bondrucker", und bei "Am Küchendrucker", wenn dort derselbe Drucker
/// gewählt ist (gleiche Art, gleiche Adresse ohne Leerzeichen am Rand).
bool kitchenSharesReceiptPrinter(RegisterSettings settings) {
  switch (settings.kitchenMode) {
    case KitchenMode.off:
      return false;
    case KitchenMode.receiptPrinter:
      return true;
    case KitchenMode.kitchenPrinter:
      final address = settings.kitchenPrinterAddress?.trim();
      return settings.kitchenPrinterKind != PrinterKind.none &&
          address != null &&
          address.isNotEmpty &&
          settings.kitchenPrinterKind == settings.printerKind &&
          address == settings.printerAddress?.trim();
  }
}

/// Zeichnet den Küchenbon als Bild; Tests setzen einen falschen Zeichner ein
/// (das echte Zeichnen braucht `dart:ui` und echte Zeit).
typedef KitchenImageRenderer = Future<MonoImage> Function(
  KitchenTicket, {
  required int widthDots,
});

final kitchenImageRendererProvider = Provider<KitchenImageRenderer>(
  (ref) => renderKitchenTicket,
);

class _NoPrinter implements ReceiptPrinter {
  const _NoPrinter();

  static const _outcome = PrintOutcome.failed(PrintProblem.notSetUp);

  @override
  Future<PrintOutcome> printReceipt(
    Receipt receipt, {
    bool openDrawer = false,
    ReceiptRecipient? recipient,
  }) async => _outcome;

  @override
  Future<PrintOutcome> openDrawer() async => _outcome;

  @override
  Future<PrintOutcome> testPrint() async => _outcome;

  @override
  Future<PrintOutcome> printSetupFacts(SetupFacts facts) async => _outcome;

  @override
  Future<PrintOutcome> printVoucher(
    SoldVoucher voucher, {
    required DateTime soldAt,
    required bool isTest,
  }) async => _outcome;

  @override
  Future<PrintOutcome> printDayReport(
    DaySummary summary, {
    required String? registerName,
    required bool drawer,
  }) async => _outcome;

  @override
  Future<PrintOutcome> printPeriodReport(
    PeriodReport report, {
    required String? registerName,
  }) async => _outcome;

  @override
  Future<PrintOutcome> printRaster(Future<Uint8List> Function() bytes) async =>
      _outcome;
}
