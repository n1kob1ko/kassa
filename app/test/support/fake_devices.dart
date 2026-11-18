// Falsche Geräte für Tests.

import 'dart:async';

import 'package:kassa/data/settings_repository.dart';
import 'package:kassa/devices/card_terminal.dart';
import 'package:kassa/devices/printer.dart';
import 'package:kassa/devices/printer_discovery.dart';
import 'package:kassa/domain/receipt.dart';

class FakePrinter implements ReceiptPrinter {
  /// Die Aufrufe in der Reihenfolge: `drawer`, `print:<Bon-Id>`, `test`.
  final List<String> log = [];

  /// Die Bon-Ids der gedruckten Bons.
  List<String> get printed => [
    for (final e in log)
      if (e.startsWith('print:')) e.substring('print:'.length),
  ];

  /// Das Ergebnis des nächsten und aller weiteren Aufrufe.
  PrintOutcome next = const PrintOutcome.ok();

  /// Solange gesetzt, wartet jeder Aufruf darauf.
  Completer<void>? hold;

  Future<PrintOutcome> _call(String entry) async {
    log.add(entry);
    final h = hold;
    if (h != null) await h.future;
    return next;
  }

  @override
  Future<PrintOutcome> printReceipt(Receipt receipt) =>
      _call('print:${receipt.id}');

  @override
  Future<PrintOutcome> openDrawer() => _call('drawer');

  @override
  Future<PrintOutcome> testPrint() => _call('test');
}

/// Falsche Druckersuche: je Verbindung eine Liste, optional ein Fehler.
class FakeDiscovery implements PrinterDiscovery {
  FakeDiscovery({
    this.foundNetwork = const [],
    this.foundUsb = const [],
    this.foundBluetooth = const [],
    this.error,
    this.access = true,
  });

  List<FoundPrinter> foundNetwork;
  List<FoundPrinter> foundUsb;
  List<FoundPrinter> foundBluetooth;

  /// Wird von `usb()` und `bluetooth()` geworfen, solange gesetzt.
  Object? error;

  /// Die Antwort von `requestAccess`.
  bool access;

  /// Solange gesetzt, wartet jede Suche darauf.
  Completer<void>? hold;

  /// Die Aufrufe der Suche in der Reihenfolge: `usb`, `bluetooth`, `network`.
  final List<String> calls = [];

  /// Die Fragen nach der Erlaubnis: `<Art>:<Adresse>`.
  final List<String> accessRequests = [];

  Future<List<FoundPrinter>> _search(
    String name,
    List<FoundPrinter> list, {
    bool canFail = true,
  }) async {
    calls.add(name);
    final h = hold;
    if (h != null) await h.future;
    if (canFail && error != null) throw error!;
    return list;
  }

  @override
  Future<List<FoundPrinter>> usb() => _search('usb', foundUsb);

  @override
  Future<List<FoundPrinter>> bluetooth() =>
      _search('bluetooth', foundBluetooth);

  @override
  Future<List<FoundPrinter>> network() =>
      _search('network', foundNetwork, canFail: false);

  @override
  Future<bool> requestAccess(PrinterKind kind, String address) async {
    accessRequests.add('${kind.name}:$address');
    return access;
  }
}

/// Ein Aufruf von `pay` am falschen Terminal.
class CardPayment {
  const CardPayment(this.paymentId, this.amountCents, this.title);

  final String paymentId;
  final int amountCents;
  final String title;
}

/// Falsches Kartenterminal. [next] ist ein [CardPaymentResult] oder eine
/// Funktion, die eines (auch als `Future`) liefert oder wirft.
class FakeCardTerminal implements CardTerminal {
  FakeCardTerminal({
    this.statusValue = const CardTerminalStatus(CardTerminalState.ready),
  });

  CardTerminalStatus statusValue;

  /// Der Stand nach `login`; ohne Wert ändert sich nichts (Anmeldung
  /// abgebrochen).
  CardTerminalStatus? statusAfterLogin;

  /// Ein [CardPaymentResult] oder eine Funktion `() => ...` dazu.
  Object next = const CardPaid(txCode: 'TX1');

  /// Solange gesetzt, wartet `pay` darauf ("hängt").
  Completer<CardPaymentResult>? hang;

  /// Die Aufrufe von `pay` in der Reihenfolge.
  final List<CardPayment> payments = [];

  /// Die übrigen Aufrufe: `login`, `logout`, `readerSettings`, `prepare`.
  final List<String> calls = [];

  @override
  String get providerName => 'sumup';

  @override
  int get minimumCents => 100;

  @override
  Future<CardTerminalStatus> status() async => statusValue;

  @override
  Future<CardTerminalStatus> login() async {
    calls.add('login');
    return statusValue = statusAfterLogin ?? statusValue;
  }

  @override
  Future<void> logout() async {
    calls.add('logout');
    statusValue = const CardTerminalStatus(CardTerminalState.loggedOut);
  }

  @override
  Future<void> openReaderSettings() async => calls.add('readerSettings');

  @override
  Future<void> prepare() async => calls.add('prepare');

  @override
  Future<CardPaymentResult> pay({
    required String paymentId,
    required int amountCents,
    required String title,
  }) async {
    payments.add(CardPayment(paymentId, amountCents, title));
    final h = hang;
    if (h != null) return h.future;
    final n = next;
    if (n is CardPaymentResult) return n;
    return await (n as dynamic Function())() as CardPaymentResult;
  }
}
