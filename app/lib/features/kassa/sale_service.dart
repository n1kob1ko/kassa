// Der Verkauf: Bon speichern, Lade öffnen, Bon drucken. Der Drucker hält
// nie einen Verkauf auf: gewartet wird nur auf die Datenbank.

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

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
import 'cart_controller.dart';

class SaleResult {
  const SaleResult({required this.receipt, required this.print});

  /// Der gespeicherte Bon.
  final Receipt receipt;

  /// Das Ergebnis des Druckens; endet nach höchstens einem Druckaufruf
  /// (5 Sekunden) und wirft nie.
  final Future<PrintOutcome> print;
}

sealed class CardSaleOutcome {
  const CardSaleOutcome();
}

class CardSaleDone extends CardSaleOutcome {
  const CardSaleDone(this.sale);

  final SaleResult sale;
}

/// Es wurde sicher nicht bezahlt; der Bon ist noch offen.
class CardSaleFailed extends CardSaleOutcome {
  const CardSaleFailed(this.message);

  final String message;
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

  /// Nimmt die Kartenzahlung für [cart] am Terminal an. Die offene Zahlung
  /// steht in der Datenbank, bevor das Terminal etwas erfährt. Wirft nie.
  Future<CardSaleOutcome> payByCard({
    required String paymentId,
    required Cart cart,
    required Staff staff,
  }) async {
    if (_ref.read(activeCardPaymentProvider) != null) {
      return const CardSaleFailed('Es läuft schon eine Kartenzahlung.');
    }
    final terminal = _ref.read(cardTerminalProvider);
    if (cart.isEmpty || cart.totalCents < terminal.minimumCents) {
      return CardSaleFailed(
        cart.isEmpty
            ? 'Der Bon ist leer.'
            : 'Kartenzahlung geht erst ab ${_euro(terminal.minimumCents)}.',
      );
    }
    final active = _ref.read(activeCardPaymentProvider.notifier)
      ..set(paymentId);
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
          return CardSaleDone(SaleResult(receipt: known, print: print));
        }
        final open = await pending.pending();
        if (open.any((p) => p.id == paymentId)) {
          return await _unclear(paymentId);
        }
      } catch (_) {
        return const CardSaleFailed(
          'Die Kartenzahlung konnte nicht gestartet werden.',
        );
      }
      try {
        await pending.begin(paymentId: paymentId, cart: cart, staff: staff);
      } catch (_) {
        return const CardSaleFailed(
          'Die Kartenzahlung konnte nicht gestartet werden.',
        );
      }
      final CardPaymentResult result;
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
          _ref.read(cartProvider.notifier).clear();
          return CardSaleDone(await _printCard(receipt));
        case CardFailed():
          await pending.discard(paymentId);
          return CardSaleFailed(result.message);
        case CardUnknown():
          return await _unclear(paymentId);
      }
    } finally {
      active.set(null);
    }
  }

  /// Der Ausgang ist unklar: die Zahlung wird so markiert und der offene Bon
  /// geleert (er steckt in der offenen Zahlung).
  Future<CardSaleOutcome> _unclear(String paymentId) async {
    await _ref.read(cardPaymentRepositoryProvider).markUnknown(paymentId);
    _ref.read(cartProvider.notifier).clear();
    return CardSaleUnclear(paymentId);
  }

  /// Der Kunde hat bezahlt: schließt den Bon aus der offenen Zahlung als
  /// Kartenzahlung ohne Beleg-Code ab. Wirft, wenn sich der Bon nicht mehr
  /// lesen lässt; die offene Zahlung bleibt dann stehen.
  Future<SaleResult> confirmUnclear(
    PendingCardPayment p, {
    required Catalog catalog,
  }) async {
    final Cart cart;
    try {
      cart = Cart.fromJson(
        jsonDecode(p.cartJson) as Map<String, dynamic>,
        catalog,
      );
    } catch (_) {
      throw const UnreadableCardPaymentException();
    }
    // Der Betrag muss zu dem passen, was das Terminal verlangt hat.
    if (cart.isEmpty || cart.totalCents != p.amountCents) {
      throw const UnreadableCardPaymentException();
    }
    final receipt = await _ref
        .read(receiptRepositoryProvider)
        .finalizeCardSale(
          saleId: p.id,
          cart: cart,
          staff: Staff(id: p.staffId, name: p.staffName, role: StaffRole.staff),
          provider: _ref.read(cardTerminalProvider).providerName,
        );
    return await _printCard(receipt);
  }

  /// Der Kunde hat nicht bezahlt: die offene Zahlung geht weg, der Bon kommt
  /// zurück auf die Kassa.
  Future<void> discardUnclear(PendingCardPayment p) async {
    await _ref.read(cardPaymentRepositoryProvider).discard(p.id);
    try {
      final catalog = await _ref.read(catalogRepositoryProvider).current();
      if (catalog == null) return;
      final cart = Cart.fromJson(
        jsonDecode(p.cartJson) as Map<String, dynamic>,
        catalog,
      );
      _ref.read(cartProvider.notifier).restore(cart);
    } catch (_) {
      // Lässt sich der Bon nicht lesen, bleibt die Kassa leer.
    }
  }

  Future<SaleResult> _printCard(Receipt receipt) async {
    final settings = await _settings();
    final print = _prints[receipt.id] ??= _output(
      receipt,
      settings,
      openDrawer: false,
    );
    return SaleResult(receipt: receipt, print: print);
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
