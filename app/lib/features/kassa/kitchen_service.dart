// Der Küchenbon: aus dem gespeicherten Bon den Zettel bauen, zeichnen und als
// Raster an den Drucker der Küche schicken. Wirft nie und schreibt nichts in
// die Datenbank; der Verkauf wartet nicht darauf.

import 'dart:async';
import 'dart:typed_data';

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
      return await _queue(receipt, settings, copy: copy);
    } catch (_) {
      return const PrintOutcome.failed(PrintProblem.unreachable);
    }
  }

  /// Wie [printFor], für den Verkauf mit dessen [settings]: der Auftrag steht
  /// beim Zurückkehren schon in der Warteschlange des Druckers (am Bondrucker
  /// direkt hinter dem Bon, vor dem Bon eines nächsten Verkaufs). Ob etwas
  /// für die Küche dabei ist, steht erst nach dem Lesen der Datenbank fest:
  /// ist es nichts, ist das Ergebnis `null`, und der Auftrag geht leer durch
  /// die Warteschlange, ohne den Drucker zu fragen.
  Future<PrintOutcome?> printForSale(
    Receipt receipt,
    RegisterSettings settings,
  ) {
    try {
      return _queue(receipt, settings, copy: false);
    } catch (_) {
      return Future.value(const PrintOutcome.failed(PrintProblem.unreachable));
    }
  }

  /// Bis zum Einreihen ohne `await`. Das Lesen der Datenbank beginnt sofort,
  /// neben der Warteschlange; Zeichnen und Umsetzen laufen im Druckaufruf.
  Future<PrintOutcome?> _queue(
    Receipt receipt,
    RegisterSettings settings, {
    required bool copy,
  }) {
    if (settings.kitchenMode == KitchenMode.off) return Future.value();
    if (receipt.kind != ReceiptKind.sale &&
        receipt.kind != ReceiptKind.voided) {
      return Future.value();
    }
    final ticket = _ticket(receipt, settings, copy: copy);
    final job = _enqueue(ticket, settings);
    return _outcome(ticket, job);
  }

  Future<KitchenTicket?> _ticket(
    Receipt receipt,
    RegisterSettings settings, {
    required bool copy,
  }) async {
    final language = settings.kitchenLanguage;
    return buildKitchenTicket(
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
  }

  /// `null`, wenn kein Zettel fällig ist, sonst das Ergebnis des Drucks.
  Future<PrintOutcome?> _outcome(
    Future<KitchenTicket?> ticket,
    Future<PrintOutcome> job,
  ) async {
    // Ein Fehler des Auftrags gilt als behandelt, auch wenn nach einem leeren
    // Zettel niemand mehr auf ihn wartet.
    unawaited(job.then<void>((_) {}, onError: (Object _) {}));
    try {
      if (await ticket == null) return null;
      return await job;
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
      return await _enqueue(Future.value(ticket), settings);
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

  /// Reiht den Druck ohne `await` ein. Zeichnen und Umsetzen laufen im
  /// Druckaufruf und zählen zu seinem Limit; ist kein Zettel fällig, sind die
  /// Daten leer und nichts geht zum Drucker.
  Future<PrintOutcome> _enqueue(
    Future<KitchenTicket?> ticket,
    RegisterSettings settings,
  ) {
    final atReceiptPrinter = settings.kitchenMode == KitchenMode.receiptPrinter;
    final kind = atReceiptPrinter
        ? settings.printerKind
        : settings.kitchenPrinterKind;
    final columns = atReceiptPrinter
        ? settings.printerColumns
        : settings.kitchenPrinterColumns;
    if (kind == PrinterKind.none) {
      return Future.value(const PrintOutcome.failed(PrintProblem.notSetUp));
    }
    final printer = _ref.read(kitchenPrinterProvider);
    if (printer == null) {
      return Future.value(const PrintOutcome.failed(PrintProblem.notSetUp));
    }
    final render = _ref.read(kitchenImageRendererProvider);
    return printer.printRaster(() async {
      final t = await ticket;
      if (t == null) return Uint8List(0);
      return encodeRasterTicket(await render(t, widthDots: columns * 12));
    });
  }
}

final kitchenServiceProvider = Provider<KitchenService>(KitchenService.new);
