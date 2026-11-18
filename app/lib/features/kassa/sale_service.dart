// Der Verkauf: Bon speichern, Lade öffnen, Bon drucken. Der Drucker hält
// nie einen Verkauf auf: gewartet wird nur auf die Datenbank.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/settings_repository.dart';
import '../../devices/device_providers.dart';
import '../../devices/printer.dart';
import '../../domain/cart.dart';
import '../../domain/receipt.dart';
import '../../domain/staff.dart';

class SaleResult {
  const SaleResult({required this.receipt, required this.print});

  /// Der gespeicherte Bon.
  final Receipt receipt;

  /// Das Ergebnis des Druckens; endet nach höchstens einem Druckaufruf
  /// (5 Sekunden) und wirft nie.
  final Future<PrintOutcome> print;
}

class SaleService {
  SaleService(this._ref);

  final Ref _ref;

  /// Das Drucken je `saleId`: ein zweiter Aufruf mit derselben Id druckt nicht
  /// noch einmal, sondern gibt das erste Ergebnis zurück.
  final Map<String, Future<PrintOutcome>> _prints = {};

  /// Speichert den Barverkauf und stößt dann Lade und Druck an. Wartet auf die
  /// Datenbank, nicht auf den Drucker.
  Future<SaleResult> completeCash({
    required String saleId,
    required Cart cart,
    required int givenCents,
    required Staff staff,
  }) async {
    final receipt = await _ref
        .read(receiptRepositoryProvider)
        .finalizeCashSale(
          saleId: saleId,
          cart: cart,
          givenCents: givenCents,
          staff: staff,
        );
    final settings = await _settings();
    final print = _prints[saleId] ??= _output(
      receipt,
      settings,
      openDrawer: settings.cashDrawerEnabled,
    );
    return SaleResult(receipt: receipt, print: print);
  }

  /// Druckt den Bon noch einmal, ohne die Lade.
  Future<PrintOutcome> reprint(Receipt receipt) async =>
      _output(receipt, await _settings(), openDrawer: false);

  /// Storniert den Bon und druckt den Storno-Bon. Die Lade bleibt zu.
  Future<SaleResult> voidReceipt(
    String receiptId, {
    required Staff staff,
  }) async {
    final receipt = await _ref
        .read(receiptRepositoryProvider)
        .voidReceipt(receiptId, staff: staff);
    final print = _output(receipt, await _settings(), openDrawer: false);
    return SaleResult(receipt: receipt, print: print);
  }

  Future<RegisterSettings> _settings() async {
    try {
      return await _ref.read(settingsRepositoryProvider).current();
    } catch (_) {
      return const RegisterSettings();
    }
  }

  Future<PrintOutcome> _output(
    Receipt receipt,
    RegisterSettings settings, {
    required bool openDrawer,
  }) async {
    if (settings.printerKind == PrinterKind.none) {
      return const PrintOutcome.failed(PrintProblem.notSetUp);
    }
    try {
      final printer = _ref.read(receiptPrinterProvider);
      if (openDrawer) {
        final drawer = await printer.openDrawer();
        // Antwortet der Drucker gar nicht, käme der Bon erst nach einem
        // zweiten Limit: dann gleich melden, "Nochmal drucken" bleibt.
        if (drawer.problem == PrintProblem.timeout) return drawer;
      }
      return await printer.printReceipt(receipt);
    } catch (_) {
      return const PrintOutcome.failed(PrintProblem.unreachable);
    }
  }
}

final saleServiceProvider = Provider<SaleService>(SaleService.new);
