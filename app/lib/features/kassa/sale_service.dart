// Der Verkauf: Bon speichern, Lade öffnen, Bon und Küchenbon drucken. Der
// Drucker hält nie einen Verkauf auf: gewartet wird nur auf die Datenbank.

import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_language.dart';
import '../../data/card_payment_repository.dart';
import '../../data/providers.dart';
import '../../data/settings_repository.dart';
import '../../devices/card_terminal.dart';
import '../../devices/device_providers.dart';
import '../../devices/printer.dart';
import '../../domain/cart.dart';
import '../../domain/catalog.dart';
import '../../domain/receipt.dart';
import '../../domain/staff.dart';
import '../../rksv/setup_facts.dart';
import 'cart_controller.dart';
import 'kitchen_service.dart';

class SaleResult {
  SaleResult({
    required this.receipt,
    required this.print,
    Future<PrintOutcome?>? kitchen,
  }) : kitchen = kitchen ?? Future.value();

  /// Der gespeicherte Bon.
  final Receipt receipt;

  /// Das Ergebnis des Druckens (des Bons); endet nach höchstens einem
  /// Druckaufruf (5 Sekunden, Lade und Bon zusammen), steht davor ein
  /// Jahresbeleg, nach zweien. Wirft nie.
  final Future<PrintOutcome> print;

  /// Das Ergebnis des Küchenbons; `null`, wenn keiner fällig ist (aus,
  /// keine Zeile für die Küche). Am Bondrucker kommt er nach dem Bon, am
  /// Küchendrucker gleichzeitig. Jeder Fehler endet hier als gescheitertes
  /// Ergebnis; [print] und der gespeicherte Bon bleiben davon unberührt.
  /// Wirft nie.
  final Future<PrintOutcome?> kitchen;
}

sealed class CardSaleOutcome {
  const CardSaleOutcome();
}

class CardSaleDone extends CardSaleOutcome {
  const CardSaleDone(this.sale);

  final SaleResult sale;
}

/// Warum eine Kartenzahlung sicher nicht zustande kam.
enum CardSaleProblem {
  /// Es läuft schon eine Kartenzahlung.
  alreadyRunning,

  /// Der Bon ist leer.
  emptyCart,

  /// Die Summe liegt unter dem Kleinstbetrag des Terminals.
  belowMinimum,

  /// Die Zahlung ließ sich nicht starten (vor dem Aufruf des Terminals).
  notStarted,

  /// Das Terminal meldet, dass nicht bezahlt wurde ([CardSaleFailed.terminal]).
  terminal,
}

/// Es wurde sicher nicht bezahlt; der Bon ist noch offen. Die Oberfläche
/// übersetzt [problem]; [message] ist die deutsche Fassung.
class CardSaleFailed extends CardSaleOutcome {
  const CardSaleFailed(this.problem, {this.minimumCents = 0, this.terminal});

  final CardSaleProblem problem;

  /// Der Kleinstbetrag des Terminals, bei [CardSaleProblem.belowMinimum].
  final int minimumCents;

  /// Die Antwort des Terminals, bei [CardSaleProblem.terminal].
  final CardFailed? terminal;

  String get message => switch (problem) {
    CardSaleProblem.alreadyRunning => 'Es läuft schon eine Kartenzahlung.',
    CardSaleProblem.emptyCart => 'Der Bon ist leer.',
    CardSaleProblem.belowMinimum =>
      'Kartenzahlung geht erst ab ${SaleService._euro(minimumCents)}.',
    CardSaleProblem.notStarted =>
      'Die Kartenzahlung konnte nicht gestartet werden.',
    CardSaleProblem.terminal => terminal?.message ?? '',
  };
}

/// Ob bezahlt wurde, ist unklar; die offene Zahlung steht in der Datenbank.
class CardSaleUnclear extends CardSaleOutcome {
  const CardSaleUnclear(this.paymentId);

  final String paymentId;
}

/// Die Id der Kartenzahlung, die gerade läuft, sonst `null`. Wer eine offene
/// Zahlung in der Datenbank findet, die nicht dazu passt, kennt sie als
/// Rest eines Absturzes.
class ActiveCardPayment extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? id) => state = id;
}

final activeCardPaymentProvider = NotifierProvider<ActiveCardPayment, String?>(
  ActiveCardPayment.new,
);

/// Die offene Zahlung lässt sich nicht mehr zu einem Bon machen.
class UnreadableCardPaymentException implements Exception {
  const UnreadableCardPaymentException();

  @override
  String toString() =>
      'Der Bon dieser Kartenzahlung lässt sich nicht mehr lesen. Bitte beim '
      'Kartenanbieter nachsehen, ob bezahlt wurde.';
}

/// Die Zahlung läuft gerade am Terminal und ist keine unklare Zahlung.
class CardPaymentRunningException implements Exception {
  const CardPaymentRunningException();

  @override
  String toString() => 'Diese Kartenzahlung läuft gerade.';
}

/// Die offene Zahlung gibt es nicht mehr (sie wurde schon abgeschlossen oder
/// verworfen).
class CardPaymentGoneException implements Exception {
  const CardPaymentGoneException();

  @override
  String toString() => 'Diese Kartenzahlung ist schon abgeschlossen.';
}

class SaleService {
  SaleService(this._ref);

  final Ref _ref;

  /// Das Drucken je `saleId`: ein zweiter Aufruf mit derselben Id druckt nicht
  /// noch einmal, sondern gibt das erste Ergebnis zurück.
  final Map<String, Future<PrintOutcome>> _prints = {};

  /// Der Küchenbon je `saleId`, wie [_prints].
  final Map<String, Future<PrintOutcome?>> _kitchenPrints = {};

  /// Barverkäufe, bei denen der Befehl für die Lade nicht beim Drucker
  /// angekommen ist: "Nochmal drucken" in der Fertig-Ansicht holt ihn nach.
  final Set<String> _drawerMissing = {};

  /// Bons, die in diesem Lauf schon gedruckt wurden.
  final Set<String> _printedOk = {};

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
    return _printSale(
      saleId,
      receipt,
      settings,
      openDrawer: settings.cashDrawerEnabled,
    );
  }

  /// Nimmt die Kartenzahlung für [cart] am Terminal an. Die offene Zahlung
  /// steht in der Datenbank, bevor das Terminal etwas erfährt. Wirft nie.
  Future<CardSaleOutcome> payByCard({
    required String paymentId,
    required Cart cart,
    required Staff staff,
  }) async {
    if (_ref.read(activeCardPaymentProvider) != null) {
      return const CardSaleFailed(CardSaleProblem.alreadyRunning);
    }
    final terminal = _ref.read(cardTerminalProvider);
    if (cart.isEmpty || cart.totalCents < terminal.minimumCents) {
      return cart.isEmpty
          ? const CardSaleFailed(CardSaleProblem.emptyCart)
          : CardSaleFailed(
              CardSaleProblem.belowMinimum,
              minimumCents: terminal.minimumCents,
            );
    }
    final active = _ref.read(activeCardPaymentProvider.notifier)
      ..set(paymentId);
    // Ab dem Aufruf des Terminals kann Geld geflossen sein: was dann noch
    // schiefgeht, endet als unklar, nie als gescheitert.
    var terminalAsked = false;
    try {
      final pending = _ref.read(cardPaymentRepositoryProvider);
      // Dieselbe Id nie ein zweites Mal am Terminal abbuchen: gibt es schon
      // einen Bon oder eine offene Zahlung dazu, wird nur das gemeldet.
      try {
        final known = await _ref
            .read(receiptRepositoryProvider)
            .find(paymentId);
        if (known != null) {
          final print =
              _prints[paymentId] ?? Future.value(const PrintOutcome.ok());
          return CardSaleDone(
            SaleResult(
              receipt: known,
              print: print,
              kitchen: _kitchenPrints[paymentId],
            ),
          );
        }
        final open = await pending.pending();
        if (open.any((p) => p.id == paymentId)) {
          return await _unclear(paymentId);
        }
      } catch (_) {
        return const CardSaleFailed(CardSaleProblem.notStarted);
      }
      try {
        await pending.begin(paymentId: paymentId, cart: cart, staff: staff);
      } catch (_) {
        return const CardSaleFailed(CardSaleProblem.notStarted);
      }
      final CardPaymentResult result;
      terminalAsked = true;
      try {
        result = await terminal.pay(
          paymentId: paymentId,
          amountCents: cart.totalCents,
          title: 'Bon ${await _businessName()}',
        );
      } catch (_) {
        return await _unclear(paymentId);
      }
      switch (result) {
        case CardPaid():
          final Receipt receipt;
          try {
            receipt = await _ref
                .read(receiptRepositoryProvider)
                .finalizeCardSale(
                  saleId: paymentId,
                  cart: cart,
                  staff: staff,
                  provider: terminal.providerName,
                  txCode: result.txCode,
                  cardScheme: result.cardScheme,
                  cardLast4: result.cardLast4,
                );
          } catch (_) {
            // Bezahlt, aber nicht gespeichert: die offene Zahlung bleibt.
            return await _unclear(paymentId);
          }
          _clearRegister();
          return CardSaleDone(await _printCard(receipt));
        case CardFailed():
          try {
            await pending.discard(paymentId);
          } catch (_) {
            // Die Zeile bleibt stehen; das Blatt fragt danach, sobald diese
            // Zahlung nicht mehr läuft. Bezahlt wurde sicher nicht.
          }
          return CardSaleFailed(CardSaleProblem.terminal, terminal: result);
        case CardUnknown():
          return await _unclear(paymentId);
      }
    } catch (_) {
      if (!terminalAsked) {
        return const CardSaleFailed(CardSaleProblem.notStarted);
      }
      return await _unclear(paymentId);
    } finally {
      active.set(null);
    }
  }

  /// Der Ausgang ist unklar: der offene Bon wird geleert (er steckt in der
  /// offenen Zahlung), dann wird die Zahlung als unklar markiert. Scheitert
  /// das Markieren, bleibt sie "gestartet"; auch so fragt das Blatt danach.
  /// Wirft nie.
  Future<CardSaleOutcome> _unclear(String paymentId) async {
    _clearRegister();
    try {
      await _ref.read(cardPaymentRepositoryProvider).markUnknown(paymentId);
    } catch (_) {}
    return CardSaleUnclear(paymentId);
  }

  void _clearRegister() {
    try {
      _ref.read(cartProvider.notifier).clear();
    } catch (_) {}
  }

  /// Der Bon einer offenen Zahlung, oder `null`, wenn er sich nicht mehr
  /// zusammenstellen lässt: nicht lesbar, leer oder mit anderem Betrag, als das
  /// Terminal verlangt hat.
  static Cart? cartOfPending(PendingCardPayment p, Catalog catalog) {
    try {
      final cart = Cart.fromJson(
        jsonDecode(p.cartJson) as Map<String, dynamic>,
        catalog,
      );
      if (cart.isEmpty || cart.totalCents != p.amountCents) return null;
      return cart;
    } catch (_) {
      return null;
    }
  }

  /// Nur eine Zahlung, die es noch gibt und die nicht gerade am Terminal läuft,
  /// darf entschieden werden.
  Future<void> _requireDecidable(PendingCardPayment p) async {
    if (_ref.read(activeCardPaymentProvider) == p.id) {
      throw const CardPaymentRunningException();
    }
    final open = await _ref.read(cardPaymentRepositoryProvider).pending();
    if (!open.any((o) => o.id == p.id)) throw const CardPaymentGoneException();
  }

  /// Der Kunde hat bezahlt: schließt den Bon aus der offenen Zahlung als
  /// Kartenzahlung ohne Beleg-Code ab. Wirft, wenn sich der Bon nicht mehr
  /// lesen lässt; die offene Zahlung bleibt dann stehen. Liegt derselbe Bon
  /// noch auf der Kassa (Absturz: der Entwurf hat ihn zurückgebracht), wird
  /// die Kassa geleert, damit er nicht noch einmal kassiert wird; anderer
  /// Inhalt bleibt stehen.
  Future<SaleResult> confirmUnclear(
    PendingCardPayment p, {
    required Catalog catalog,
  }) async {
    await _requireDecidable(p);
    final cart = cartOfPending(p, catalog);
    if (cart == null) throw const UnreadableCardPaymentException();
    final receipt = await _ref
        .read(receiptRepositoryProvider)
        .finalizeCardSale(
          saleId: p.id,
          cart: cart,
          staff: Staff(id: p.staffId, name: p.staffName, role: StaffRole.staff),
          provider: _ref.read(cardTerminalProvider).providerName,
        );
    final onRegister = _ref.read(cartProvider);
    if (!onRegister.isEmpty) {
      // Beide Seiten so verglichen, wie die Kassa sie liest: Zeilen, die es
      // nicht mehr gibt, fehlen auf beiden.
      if (jsonEncode(onRegister.toJson()) == jsonEncode(cart.toJson())) {
        _ref.read(cartProvider.notifier).clear();
      } else {
        // Das Abschließen hat den Entwurf gelöscht; der andere Bon auf der
        // Kassa soll einen Neustart überstehen.
        try {
          await _ref
              .read(settingsRepositoryProvider)
              .writeDraft(jsonEncode(onRegister.toJson()));
        } catch (_) {}
      }
    }
    return await _printCard(receipt);
  }

  /// Der Kunde hat nicht bezahlt: die offene Zahlung geht weg, der Bon kommt
  /// zurück auf die Kassa, aber nur auf eine leere (derselbe Bon wird nicht
  /// verdoppelt, ein anderer nicht ersetzt).
  Future<void> discardUnclear(PendingCardPayment p) async {
    await _requireDecidable(p);
    await _ref.read(cardPaymentRepositoryProvider).discard(p.id);
    try {
      final catalog = await _ref.read(catalogRepositoryProvider).current();
      if (catalog == null) return;
      final cart = cartToRestore(p, catalog);
      if (cart != null) _ref.read(cartProvider.notifier).restore(cart);
    } catch (_) {
      // Lässt sich der Bon nicht lesen, bleibt die Kassa leer.
    }
  }

  /// Der Bon, den [discardUnclear] auf eine leere Kassa zurücklegt, oder
  /// `null`, wenn sich nichts davon lesen lässt.
  static Cart? cartToRestore(PendingCardPayment p, Catalog catalog) {
    try {
      final cart = Cart.fromJson(
        jsonDecode(p.cartJson) as Map<String, dynamic>,
        catalog,
      );
      return cart.isEmpty ? null : cart;
    } catch (_) {
      return null;
    }
  }

  Future<SaleResult> _printCard(Receipt receipt) async {
    final settings = await _settings();
    return _printSale(receipt.id, receipt, settings, openDrawer: false);
  }

  /// Bon und Küchenbon eines eben abgeschlossenen Verkaufs, je [key] nur
  /// einmal: ein zweiter Aufruf gibt die ersten Ergebnisse zurück.
  SaleResult _printSale(
    String key,
    Receipt receipt,
    RegisterSettings settings, {
    required bool openDrawer,
  }) {
    final known = _prints[key];
    if (known != null) {
      return SaleResult(
        receipt: receipt,
        print: known,
        kitchen: _kitchenPrints[key],
      );
    }
    final (print, kitchen) = _withKitchen(
      receipt,
      settings,
      (queued) => _outputSale(
        receipt,
        settings,
        openDrawer: openDrawer,
        queued: queued,
      ),
    );
    _prints[key] = print;
    _kitchenPrints[key] = kitchen;
    return SaleResult(receipt: receipt, print: print, kitchen: kitchen);
  }

  Future<String> _businessName() async {
    try {
      final catalog = await _ref.read(catalogRepositoryProvider).current();
      return catalog?.business.name ?? '';
    } catch (_) {
      return '';
    }
  }

  static String _euro(int cents) =>
      '${cents ~/ 100},${(cents % 100).toString().padLeft(2, '0')} €';

  /// Druckt den Bon noch einmal, ohne die Lade (Bon-Detail).
  Future<PrintOutcome> reprint(Receipt receipt) async =>
      _output(receipt, await _settings(), openDrawer: false);

  /// Druckt den Zettel "Angaben für FinanzOnline" über denselben Drucker wie
  /// die Bons: ohne eingerichteten Drucker `notSetUp`, ein unerwarteter
  /// Fehler ist `unreachable`.
  Future<PrintOutcome> printSetupFacts(SetupFacts facts) async {
    if ((await _settings()).printerKind == PrinterKind.none) {
      return const PrintOutcome.failed(PrintProblem.notSetUp);
    }
    try {
      return await _ref.read(receiptPrinterProvider).printSetupFacts(facts);
    } catch (_) {
      return const PrintOutcome.failed(PrintProblem.unreachable);
    }
  }

  /// "Nochmal drucken" in der Fertig-Ansicht. Ist bei diesem Barverkauf die
  /// Lade nicht aufgegangen (und ist sie eingeschaltet), geht sie jetzt mit
  /// dem Bon auf. Ist der Bon schon gedruckt und fehlt nur die Lade, öffnet
  /// sich nur die Lade: der Gast bekommt keinen zweiten Bon.
  Future<PrintOutcome> printAgain(Receipt receipt) async {
    final settings = await _settings();
    final kick =
        _drawerMissing.contains(receipt.id) &&
        settings.cashDrawerEnabled &&
        receipt.kind == ReceiptKind.sale &&
        receipt.payment?.kind == PaymentKind.cash;
    if (kick && _printedOk.contains(receipt.id)) {
      return _drawerOnly(receipt.id, settings);
    }
    return _output(receipt, settings, openDrawer: kick);
  }

  Future<PrintOutcome> _drawerOnly(
    String receiptId,
    RegisterSettings settings,
  ) async {
    if (settings.printerKind == PrinterKind.none) {
      return const PrintOutcome.failed(PrintProblem.notSetUp);
    }
    try {
      final outcome = await _ref.read(receiptPrinterProvider).openDrawer();
      if (outcome.ok) _drawerMissing.remove(receiptId);
      return outcome;
    } catch (_) {
      return const PrintOutcome.failed(PrintProblem.unreachable);
    }
  }

  /// Storniert den Bon und druckt den Storno-Bon. Die Lade bleibt zu.
  Future<SaleResult> voidReceipt(
    String receiptId, {
    required Staff staff,
  }) async {
    final receipt = await _ref
        .read(receiptRepositoryProvider)
        .voidReceipt(receiptId, staff: staff);
    final settings = await _settings();
    final (print, kitchen) = _withKitchen(
      receipt,
      settings,
      (queued) => _output(receipt, settings, openDrawer: false, queued: queued),
    );
    return SaleResult(receipt: receipt, print: print, kitchen: kitchen);
  }

  /// Bon und Küchenbon zum eben gespeicherten Bon. [customer] stößt den Bon
  /// an und ruft `queued`, sobald sein Auftrag in der Warteschlange des
  /// Bondruckers steht. Am Bondrucker kommt der Küchenbon direkt dahinter in
  /// dieselbe Warteschlange (eigener Auftrag, eigener Schnitt), also vor den
  /// Bon eines nächsten Verkaufs; am Küchendrucker geht er gleichzeitig los.
  /// Bei "Aus" wird nichts gerufen. Der Küchenbon wirft nie.
  (Future<PrintOutcome>, Future<PrintOutcome?>) _withKitchen(
    Receipt receipt,
    RegisterSettings settings,
    Future<PrintOutcome> Function(void Function() queued) customer,
  ) {
    switch (settings.kitchenMode) {
      case KitchenMode.off:
        return (customer(() {}), Future.value());
      case KitchenMode.kitchenPrinter:
        final print = customer(() {});
        return (print, _startKitchen(receipt, settings));
      case KitchenMode.receiptPrinter:
        final started = Completer<Future<PrintOutcome?>>();
        void queue() {
          if (!started.isCompleted) {
            started.complete(_startKitchen(receipt, settings));
          }
        }
        final print = customer(queue);
        // Kam der Bon nie in die Warteschlange (kein Drucker, Fehler), geht
        // der Küchenbon los, sobald das Ergebnis des Bons feststeht.
        unawaited(print.whenComplete(queue));
        return (print, started.future.then((kitchen) => kitchen));
    }
  }

  /// Stellt den Küchenbon sofort in die Warteschlange. Wirft nie.
  Future<PrintOutcome?> _startKitchen(
    Receipt receipt,
    RegisterSettings settings,
  ) {
    const failed = PrintOutcome.failed(PrintProblem.unreachable);
    try {
      return _ref
          .read(kitchenServiceProvider)
          .printForSale(receipt, settings)
          .then((o) => o, onError: (Object _) => failed);
    } catch (_) {
      return Future.value(failed);
    }
  }

  Future<RegisterSettings> _settings() async {
    try {
      return await _ref.read(settingsRepositoryProvider).current();
    } catch (_) {
      return const RegisterSettings();
    }
  }

  /// Druck nach einem eben abgeschlossenen Verkauf: Steht direkt davor ein
  /// Jahresbeleg (er entsteht im selben Schritt), kommt er zuerst. Scheitert
  /// sein Druck, wird der Bon trotzdem gedruckt; das Ergebnis ist das des
  /// Bons. Monats- und Sammelbelege werden nicht gedruckt.
  ///
  /// [queued] läuft, sobald der Auftrag des Bons (nicht des Jahresbelegs) in
  /// der Warteschlange des Druckers steht.
  Future<PrintOutcome> _outputSale(
    Receipt receipt,
    RegisterSettings settings, {
    required bool openDrawer,
    void Function()? queued,
  }) async {
    if (settings.printerKind != PrinterKind.none) {
      try {
        final year = await _ref
            .read(receiptRepositoryProvider)
            .yearReceiptBefore(receipt);
        if (year != null) await _send(year, settings, openDrawer: false);
      } catch (_) {
        // Der Jahresbeleg steht gespeichert und lässt sich in den Bons
        // nachdrucken; der Bon des Verkaufs geht trotzdem hinaus.
      }
    }
    return _output(receipt, settings, openDrawer: openDrawer, queued: queued);
  }

  /// Druckt den Bon, mit [openDrawer] im selben Auftrag mit der Lade, und
  /// merkt sich, ob die Lade aufging. [queued] wie bei [_send].
  Future<PrintOutcome> _output(
    Receipt receipt,
    RegisterSettings settings, {
    required bool openDrawer,
    void Function()? queued,
  }) async {
    final outcome = await _send(
      receipt,
      settings,
      openDrawer: openDrawer,
      queued: queued,
    );
    if (openDrawer) {
      if (outcome.drawerSent) {
        _drawerMissing.remove(receipt.id);
      } else {
        _drawerMissing.add(receipt.id);
      }
    }
    if (outcome.ok) _printedOk.add(receipt.id);
    return outcome;
  }

  /// [queued] läuft, sobald der Auftrag in der Warteschlange des Druckers
  /// steht (ohne Drucker oder bei einem Fehler nicht).
  Future<PrintOutcome> _send(
    Receipt receipt,
    RegisterSettings settings, {
    required bool openDrawer,
    void Function()? queued,
  }) async {
    if (settings.printerKind == PrinterKind.none) {
      return const PrintOutcome.failed(PrintProblem.notSetUp);
    }
    try {
      final job = _ref
          .read(receiptPrinterProvider)
          .printReceipt(receipt, openDrawer: openDrawer);
      queued?.call();
      return await job;
    } catch (_) {
      return const PrintOutcome.failed(PrintProblem.unreachable);
    }
  }
}

final saleServiceProvider = Provider<SaleService>(SaleService.new);
