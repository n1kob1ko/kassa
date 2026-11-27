// Der Verkauf: Bon speichern, Lade öffnen, Bon und Küchenbon drucken. Der
// Drucker hält nie einen Verkauf auf: gewartet wird nur auf die Datenbank.

import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_language.dart';
import '../../data/card_payment_repository.dart';
import '../../data/providers.dart';
import '../../data/receipt_repository.dart' show VoucherBalanceException;
import '../../data/settings_repository.dart';
import '../../devices/card_terminal.dart';
import '../../devices/device_providers.dart';
import '../../devices/printer.dart';
import '../../domain/cart.dart';
import '../../domain/catalog.dart';
import '../../domain/customer.dart';
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
    Future<List<PrintOutcome>>? voucherPrints,
  }) : kitchen = kitchen ?? Future.value(),
       voucherPrints = voucherPrints ?? Future.value(const []);

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

  /// Die Abschnitte der verkauften Gutscheine, je Gutschein ein Ergebnis in
  /// der Reihenfolge der Zeilen. Sie kommen nach dem Kundenbon und nur, wenn
  /// er ohne Fehler gedruckt ist; sonst (und ohne verkauften Gutschein) ist
  /// die Liste leer: "Gutschein drucken" in "Verkauf fertig" holt sie nach.
  /// Wirft nie.
  final Future<List<PrintOutcome>> voucherPrints;
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

  /// Die Abschnitte der Gutscheine je `saleId`, wie [_prints].
  final Map<String, Future<List<PrintOutcome>>> _voucherPrints = {};

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

  /// Schließt einen Bon ab, den die gewählten Gutscheine ganz bezahlen
  /// ("Einlösen", "Mit Gutschein abschließen"): nur Gutschein-Zahlungen, die
  /// Lade bleibt zu, der Kundenbon kommt wie immer. Reicht ein Guthaben
  /// nicht mehr, [VoucherBalanceException], und nichts ist gespeichert.
  Future<SaleResult> completeVoucher({
    required String saleId,
    required Cart cart,
    required Staff staff,
  }) async {
    final receipt = await _ref
        .read(receiptRepositoryProvider)
        .finalizeVoucherSale(saleId: saleId, cart: cart, staff: staff);
    return _printSale(saleId, receipt, await _settings(), openDrawer: false);
  }

  /// Schließt einen Bon mit Summe 0,00 € ab (etwa eine Einladung mit 100 %
  /// Rabatt ohne Pfand): eine Bar-Zahlung über 0 ohne Rückgeld, die Lade
  /// bleibt zu. Bei einer anderen Summe [ArgumentError], und nichts wird
  /// gespeichert.
  Future<SaleResult> completeFree({
    required String saleId,
    required Cart cart,
    required Staff staff,
  }) async {
    if (cart.totalCents != 0) {
      throw ArgumentError.value(
        cart.totalCents,
        'cart',
        'Die Summe des Bons ist nicht 0,00 €',
      );
    }
    final receipt = await _ref
        .read(receiptRepositoryProvider)
        .finalizeCashSale(
          saleId: saleId,
          cart: cart,
          givenCents: 0,
          staff: staff,
        );
    return _printSale(saleId, receipt, await _settings(), openDrawer: false);
  }

  /// Schließt einen Bon unter 0 ab ("Bar auszahlen", etwa nur Pfand zurück):
  /// eine Bar-Zahlung über die Summe, gegeben 0, kein Rückgeld. Die Lade
  /// geht auf wie beim Barverkauf, wenn sie eingeschaltet ist; der Küchenbon
  /// kommt wie immer (ein Bon unter 0 kann Ware enthalten). Bei einer Summe
  /// ab 0 [ArgumentError], und nichts wird gespeichert.
  Future<SaleResult> completePayout({
    required String saleId,
    required Cart cart,
    required Staff staff,
  }) async {
    final receipt = await _ref
        .read(receiptRepositoryProvider)
        .finalizePayout(saleId: saleId, cart: cart, staff: staff);
    final settings = await _settings();
    return _printSale(
      saleId,
      receipt,
      settings,
      openDrawer: settings.cashDrawerEnabled,
    );
  }

  /// Nimmt die Kartenzahlung für [cart] am Terminal an: [cashPartCents] ist
  /// schon bar bezahlt, die Karte bucht den Rest nach den gewählten
  /// Gutscheinen (`cart.pricing.dueCents`) und das Trinkgeld [tipCents] (für
  /// [staff]). Die offene Zahlung steht mit beiden Beträgen in der Datenbank,
  /// bevor das Terminal etwas erfährt.
  ///
  /// Die Reihenfolge: (1) Guthaben der Gutscheine prüfen, (2) offene Zahlung
  /// schreiben, (3) Terminal, (4) Bon. Reicht ein Guthaben bei (1) nicht,
  /// wirft der Aufruf [VoucherBalanceException]: nichts ist geschrieben, das
  /// Terminal weiß nichts. Sonst wirft er nie; ab (3) endet jeder Fehler als
  /// unklar.
  Future<CardSaleOutcome> payByCard({
    required String paymentId,
    required Cart cart,
    required Staff staff,
    int cashPartCents = 0,
    int tipCents = 0,
  }) async {
    if (_ref.read(activeCardPaymentProvider) != null) {
      return const CardSaleFailed(CardSaleProblem.alreadyRunning);
    }
    // Ein Bar-Teil ab der Summe lässt der Karte nichts: nie starten, auch
    // nicht bei einem Terminal ohne Kleinstbetrag.
    // Ohne Gutschein ist das die Summe des Bons.
    final due = cart.pricing.dueCents;
    if (cashPartCents < 0 ||
        tipCents < 0 ||
        (cashPartCents > 0 && cashPartCents >= due) ||
        // Bezahlen die Gutscheine alles, bekommt das Terminal nie 0,00 €.
        (cart.vouchers.isNotEmpty && due - cashPartCents <= 0)) {
      return const CardSaleFailed(CardSaleProblem.notStarted);
    }
    final terminal = _ref.read(cardTerminalProvider);
    // Der Kleinstbetrag gilt für den Rest ohne Trinkgeld.
    final rest = due - cashPartCents;
    if (cart.isEmpty || rest < terminal.minimumCents) {
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
              voucherPrints: _voucherPrints[paymentId],
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
      // (1) Jedes Guthaben neu, bevor etwas geschrieben wird und das
      // Terminal etwas erfährt. Ohne gewählten Gutschein fragt die Kassa
      // nichts (wie in 1.11.0).
      if (cart.pricing.voucherUses.isNotEmpty) {
        try {
          await _ref.read(receiptRepositoryProvider).checkVoucherBalances(cart);
        } on VoucherBalanceException {
          rethrow;
        } catch (_) {
          return const CardSaleFailed(CardSaleProblem.notStarted);
        }
      }
      // (2) Die offene Zahlung, mit den Gutscheinen im Bon.
      try {
        await pending.begin(
          paymentId: paymentId,
          cart: cart,
          staff: staff,
          cashPartCents: cashPartCents,
          tipCents: tipCents,
        );
      } catch (_) {
        return const CardSaleFailed(CardSaleProblem.notStarted);
      }
      final CardPaymentResult result;
      // (3) Ab hier kann Geld geflossen sein.
      terminalAsked = true;
      try {
        result = await terminal.pay(
          paymentId: paymentId,
          amountCents: terminalAmountCents(
            totalCents: due,
            cashPartCents: cashPartCents,
            tipCents: tipCents,
          ),
          title: 'Bon ${await _businessName()}',
        );
      } catch (_) {
        return await _unclear(paymentId);
      }
      switch (result) {
        case CardPaid():
          final Receipt receipt;
          // (4) Die Karte ist belastet: der Bon entsteht, auch wenn ein
          // Gutschein inzwischen weniger Guthaben hat (er ist dann
          // überzogen).
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
                  cashPartCents: cashPartCents,
                  tipCents: tipCents,
                  allowOverdraw: true,
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
    } catch (e) {
      if (!terminalAsked) {
        // Das Terminal weiß nichts: ein Guthaben, das nicht reicht, geht an
        // die Kassa (sie zeigt den Bon mit dem neuen Guthaben).
        if (e is VoucherBalanceException) rethrow;
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
  /// Terminal verlangt hat (was nach den Gutscheinen offen war, ohne
  /// Bar-Teil, mit Trinkgeld). Die Gutscheine stehen mit dem Guthaben von
  /// damals im Bon, so ergibt sich derselbe Betrag.
  static Cart? cartOfPending(PendingCardPayment p, Catalog catalog) {
    try {
      final cart = Cart.fromJson(
        jsonDecode(p.cartJson) as Map<String, dynamic>,
        catalog,
      );
      final expected = terminalAmountCents(
        totalCents: cart.pricing.dueCents,
        cashPartCents: p.cashPartCents,
        tipCents: p.tipCents,
      );
      if (cart.isEmpty || expected != p.amountCents) {
        return null;
      }
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
  /// Kartenzahlung ohne Beleg-Code ab, mit ihrem Bar-Teil und ihrem
  /// Trinkgeld; das Trinkgeld gehört der Person der offenen Zahlung, nicht
  /// der, die gerade angemeldet ist. Wirft, wenn sich der Bon nicht mehr
  /// lesen lässt; die offene Zahlung bleibt dann stehen. Liegt derselbe Bon
  /// noch auf der Kassa (Absturz: der Entwurf hat ihn zurückgebracht), wird
  /// die Kassa geleert, damit er nicht noch einmal kassiert wird; anderer
  /// Inhalt bleibt stehen.
  ///
  /// Die Karte ist belastet: der Bon entsteht mit den Gutscheinen der
  /// offenen Zahlung, auch wenn eines ihrer Guthaben inzwischen nicht mehr
  /// reicht (der Gutschein ist dann überzogen). Kennt die Kassa einen der
  /// Gutscheine gar nicht mehr, lässt sich der Bon nicht bauen:
  /// [UnreadableCardPaymentException], die offene Zahlung bleibt.
  Future<SaleResult> confirmUnclear(
    PendingCardPayment p, {
    required Catalog catalog,
  }) async {
    await _requireDecidable(p);
    final cart = cartOfPending(p, catalog);
    if (cart == null) throw const UnreadableCardPaymentException();
    final Receipt receipt;
    try {
      receipt = await _ref
          .read(receiptRepositoryProvider)
          .finalizeCardSale(
            saleId: p.id,
            cart: cart,
            staff: Staff(
              id: p.staffId,
              name: p.staffName,
              role: StaffRole.staff,
            ),
            provider: _ref.read(cardTerminalProvider).providerName,
            cashPartCents: p.cashPartCents,
            tipCents: p.tipCents,
            allowOverdraw: true,
          );
    } on VoucherBalanceException {
      throw const UnreadableCardPaymentException();
    }
    final onRegister = _ref.read(cartProvider);
    if (!onRegister.isEmpty) {
      // Beide Seiten so verglichen, wie die Kassa sie liest: Zeilen, die es
      // nicht mehr gibt, fehlen auf beiden. Das Guthaben eines gewählten
      // Gutscheins zählt dabei nicht (die Kassa liest es nach dem Neustart
      // neu).
      if (_sameCart(onRegister, cart)) {
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

  /// Ob [a] und [b] derselbe Bon sind; das Guthaben gewählter Gutscheine
  /// zählt nicht. Ohne Gutschein derselbe Vergleich wie in 1.11.0.
  static bool _sameCart(Cart a, Cart b) {
    String key(Cart c) {
      final json = c.toJson();
      final vouchers = json['vouchers'];
      if (vouchers is List) {
        json['vouchers'] = [
          for (final v in vouchers)
            Map<String, Object?>.of(v as Map<String, Object?>)
              ..remove('balanceCents'),
        ];
      }
      return jsonEncode(json);
    }

    return key(a) == key(b);
  }

  /// Der Kunde hat nicht bezahlt: die offene Zahlung geht weg, der Bon kommt
  /// zurück auf die Kassa, aber nur auf eine leere (derselbe Bon wird nicht
  /// verdoppelt, ein anderer nicht ersetzt). Gewählte Gutscheine kommen mit
  /// und bekommen ihr Guthaben von jetzt.
  Future<void> discardUnclear(PendingCardPayment p) async {
    await _requireDecidable(p);
    await _ref.read(cardPaymentRepositoryProvider).discard(p.id);
    try {
      final catalog = await _ref.read(catalogRepositoryProvider).current();
      if (catalog == null) return;
      final cart = cartToRestore(p, catalog);
      if (cart == null) return;
      final register = _ref.read(cartProvider.notifier);
      final before = _ref.read(cartProvider);
      register.restore(cart);
      if (before.isEmpty && cart.vouchers.isNotEmpty) {
        await register.refreshVouchers();
      }
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

  /// Druck nach einer Kartenzahlung. Mit Bar-Teil geht die Lade auf, wenn sie
  /// eingeschaltet ist, im selben Auftrag wie beim Barverkauf.
  Future<SaleResult> _printCard(Receipt receipt) async {
    final settings = await _settings();
    return _printSale(
      receipt.id,
      receipt,
      settings,
      openDrawer: settings.cashDrawerEnabled && receipt.cashCents > 0,
    );
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
        voucherPrints: _voucherPrints[key],
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
    final vouchers = _vouchersAfter(
      receipt,
      print,
      startWhen: (customer) => customer.ok,
    );
    _prints[key] = print;
    _kitchenPrints[key] = kitchen;
    _voucherPrints[key] = vouchers;
    return SaleResult(
      receipt: receipt,
      print: print,
      kitchen: kitchen,
      voucherPrints: vouchers,
    );
  }

  /// Die Abschnitte der Gutscheine von [receipt], einer nach dem anderen in
  /// der Reihenfolge der Zeilen, sobald das Ergebnis des Kundenbons
  /// ([customer]) feststeht und [startWhen] es erlaubt (heute: der Bon ist
  /// ohne Fehler gedruckt). Ohne verkauften Gutschein oder ohne Erlaubnis
  /// eine leere Liste. Wirft nie.
  Future<List<PrintOutcome>> _vouchersAfter(
    Receipt receipt,
    Future<PrintOutcome> customer, {
    required bool Function(PrintOutcome customer) startWhen,
  }) async {
    if (receipt.kind != ReceiptKind.sale || receipt.soldVouchers.isEmpty) {
      return const [];
    }
    final PrintOutcome outcome;
    try {
      outcome = await customer;
    } catch (_) {
      return const [];
    }
    if (!startWhen(outcome)) return const [];
    final sold = [...receipt.soldVouchers]
      ..sort((a, b) => a.linePosition.compareTo(b.linePosition));
    return [for (final v in sold) await printVoucher(receipt, v)];
  }

  /// Druckt den Abschnitt des Gutscheins [voucher], der auf [receipt]
  /// verkauft wurde ("Gutschein drucken" in "Verkauf fertig" und in "Bons").
  /// Ohne eingerichteten Drucker `notSetUp`, ein unerwarteter Fehler ist
  /// `unreachable`. Ob es ein Übungs-Gutschein ist, sagt der Gutschein
  /// selbst; findet die Kassa ihn nicht, druckt sie ihn als Übung (lieber
  /// ungültig als falsch gültig). Wirft nie.
  Future<PrintOutcome> printVoucher(
    Receipt receipt,
    SoldVoucher voucher,
  ) async {
    if ((await _settings()).printerKind == PrinterKind.none) {
      return const PrintOutcome.failed(PrintProblem.notSetUp);
    }
    try {
      final known = await _ref
          .read(voucherRepositoryProvider)
          .byId(voucher.voucherId);
      return await _ref
          .read(receiptPrinterProvider)
          .printVoucher(
            voucher,
            soldAt: receipt.createdAt,
            isTest: known?.isTest ?? true,
          );
    } catch (_) {
      return const PrintOutcome.failed(PrintProblem.unreachable);
    }
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

  /// Druckt [receipt] als Rechnung an [recipient] ("Rechnung drucken" in
  /// "Verkauf fertig" und in "Bons"): derselbe Bon mit "RECHNUNG" und dem
  /// Empfänger darüber. Die Lade bleibt zu, ein Küchenbon kommt nicht. Ohne
  /// eingerichteten Drucker `notSetUp`, ein unerwarteter Fehler ist
  /// `unreachable`. Wirft nie.
  Future<PrintOutcome> printInvoice(
    Receipt receipt,
    ReceiptRecipient recipient,
  ) async {
    if ((await _settings()).printerKind == PrinterKind.none) {
      return const PrintOutcome.failed(PrintProblem.notSetUp);
    }
    try {
      return await _ref
          .read(receiptPrinterProvider)
          .printReceipt(receipt, recipient: recipient);
    } catch (_) {
      return const PrintOutcome.failed(PrintProblem.unreachable);
    }
  }

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

  /// "Nochmal drucken" in der Fertig-Ansicht. Ist bei diesem Verkauf mit
  /// Bargeld (bar oder mit Bar-Teil) die Lade nicht aufgegangen (und ist sie
  /// eingeschaltet), geht sie jetzt mit dem Bon auf. Ist der Bon schon gedruckt und fehlt nur die Lade, öffnet
  /// sich nur die Lade: der Gast bekommt keinen zweiten Bon.
  Future<PrintOutcome> printAgain(Receipt receipt) async {
    final settings = await _settings();
    final kick =
        _drawerMissing.contains(receipt.id) &&
        settings.cashDrawerEnabled &&
        receipt.kind == ReceiptKind.sale &&
        receipt.cashPayment != null;
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
  /// Bondruckers steht. Am Bondrucker (auch wenn als Küchendrucker derselbe
  /// Drucker gewählt ist) kommt der Küchenbon direkt dahinter in dieselbe
  /// Warteschlange (eigener Auftrag, eigener Schnitt), also vor den Bon eines
  /// nächsten Verkaufs; an einem eigenen Küchendrucker geht er gleichzeitig
  /// los. Bei "Aus" wird nichts gerufen. Der Küchenbon wirft nie.
  (Future<PrintOutcome>, Future<PrintOutcome?>) _withKitchen(
    Receipt receipt,
    RegisterSettings settings,
    Future<PrintOutcome> Function(void Function() queued) customer,
  ) {
    switch (settings.kitchenMode) {
      case KitchenMode.off:
        return (customer(() {}), Future.value());
      case KitchenMode.kitchenPrinter
          when !kitchenSharesReceiptPrinter(settings):
        final print = customer(() {});
        return (print, _startKitchen(receipt, settings));
      case KitchenMode.kitchenPrinter:
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
