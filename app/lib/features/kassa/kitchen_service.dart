// Der Küchenbon: aus dem gespeicherten Bon den Zettel bauen, zeichnen und als
// Raster an den Drucker der Küche schicken. Wirft nie und schreibt nichts in
// die Datenbank; der Verkauf wartet nicht darauf.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_language.dart';
import '../../data/providers.dart';
import '../../data/settings_repository.dart';
import '../../devices/device_providers.dart';
import '../../devices/escpos.dart';
import '../../devices/printer.dart';
import '../../domain/catalog.dart';
import '../../domain/kitchen_ticket.dart';
import '../../domain/receipt.dart';
import '../../ui/kitchen_texts.dart';

class KitchenService {
  KitchenService(this._ref);

  final Ref _ref;

  /// `null`: für diesen Bon ist kein Küchenbon fällig (aus, Sonderbeleg, keine Zeile für die Küche).
  Future<PrintOutcome?> printFor(Receipt receipt, {bool copy = false}) async {
    try {
      final settings = await _ref.read(settingsRepositoryProvider).current();
      if (settings.kitchenMode == KitchenMode.off) return null;
      if (receipt.kind != ReceiptKind.sale &&
          receipt.kind != ReceiptKind.voided) {
        return null;
      }
      final language = settings.kitchenLanguage;
      final ticket = buildKitchenTicket(
        receipt,
        language: language,
        texts: kitchenTextsFor(language),
        dictionary: await _ref.read(translationRepositoryProvider).current(),
        categoryOfItem: await _ref
            .read(catalogRepositoryProvider)
            .categoryOfItems(),
        skipCategories: settings.kitchenSkipCategories,
        copy: copy,
        voidedNumber: await _voidedNumber(receipt),
      );
      if (ticket == null) return null;
      return await _print(ticket, settings);
    } catch (_) {
      return const PrintOutcome.failed(PrintProblem.unreachable);
    }
  }

  /// Druckt den Beispiel-Küchenbon der Vorschau am gewählten Drucker; bei
  /// "Aus" `notSetUp`.
  Future<PrintOutcome> printSample() async {
    try {
      final settings = await _ref.read(settingsRepositoryProvider).current();
      if (settings.kitchenMode == KitchenMode.off) {
        return const PrintOutcome.failed(PrintProblem.notSetUp);
      }
      final language = settings.kitchenLanguage;
      final catalog =
          await _ref.read(catalogRepositoryProvider).current() ??
          const Catalog(
            business: BusinessInfo(name: ''),
            categories: [],
            items: [],
            templates: [],
          );
      final ticket = sampleKitchenTicket(
        catalog,
        language: language,
        texts: kitchenTextsFor(language),
        dictionary: await _ref.read(translationRepositoryProvider).current(),
        skipCategories: settings.kitchenSkipCategories,
        now: _ref.read(clockProvider).now(),
      );
      return await _print(ticket, settings);
    } catch (_) {
      return const PrintOutcome.failed(PrintProblem.unreachable);
    }
  }

  /// Die Nummer des stornierten Bons; ohne sie trägt der Zettel die eigene.
  Future<int?> _voidedNumber(Receipt receipt) async {
    final voidsId = receipt.voidsReceiptId;
    if (receipt.kind != ReceiptKind.voided || voidsId == null) return null;
    try {
      return (await _ref.read(receiptRepositoryProvider).byId(voidsId)).number;
    } catch (_) {
      return null;
    }
  }

  /// Zeichnen und Umsetzen laufen im Druckaufruf und zählen zu seinem Limit.
  Future<PrintOutcome> _print(
    KitchenTicket ticket,
    RegisterSettings settings,
  ) async {
    final atReceiptPrinter = settings.kitchenMode == KitchenMode.receiptPrinter;
    final kind = atReceiptPrinter
        ? settings.printerKind
        : settings.kitchenPrinterKind;
    final columns = atReceiptPrinter
        ? settings.printerColumns
        : settings.kitchenPrinterColumns;
    if (kind == PrinterKind.none) {
      return const PrintOutcome.failed(PrintProblem.notSetUp);
    }
    final printer = _ref.read(kitchenPrinterProvider);
    if (printer == null) {
      return const PrintOutcome.failed(PrintProblem.notSetUp);
    }
    final render = _ref.read(kitchenImageRendererProvider);
    return await printer.printRaster(
      () async =>
          encodeRasterTicket(await render(ticket, widthDots: columns * 12)),
    );
  }
}

final kitchenServiceProvider = Provider<KitchenService>(KitchenService.new);
