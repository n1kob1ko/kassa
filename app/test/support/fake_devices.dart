// Falsche Geräte für Tests.

import 'dart:async';
import 'dart:typed_data';

import 'package:kassa/data/settings_repository.dart';
import 'package:kassa/devices/card_terminal.dart';
import 'package:kassa/devices/printer.dart';
import 'package:kassa/devices/printer_discovery.dart';
import 'package:kassa/domain/day.dart';
import 'package:kassa/domain/period_report.dart';
import 'package:kassa/domain/receipt.dart';
import 'package:kassa/features/kassa/kitchen_service.dart';
import 'package:kassa/rksv/setup_facts.dart';

class FakePrinter implements ReceiptPrinter {
  /// Die Aufrufe in der Reihenfolge: `drawer`, `print:<Bon-Id>`,
  /// `print+drawer:<Bon-Id>` (Bon mit dem Befehl für die Lade im selben
  /// Auftrag), `test`, `day-report:<Tag-Id>`, `period-report:<Zeitraum>`,
  /// `raster` (Rasterdaten, zum Beispiel ein Küchenbon; leere zählen nicht).
  final List<String> log = [];

  /// Die Bon-Ids der gedruckten Bons, mit und ohne Lade.
  List<String> get printed => [
    for (final e in log)
      if (e.startsWith('print')) e.substring(e.indexOf(':') + 1),
  ];

  /// Wie oft der Befehl für die Lade geschickt wurde: allein (`drawer`) oder
  /// mit einem Bon (`print+drawer:`).
  int get drawerOpened =>
      log.where((e) => e == 'drawer' || e.startsWith('print+drawer:')).length;

  /// Das Ergebnis des nächsten und aller weiteren Aufrufe.
  PrintOutcome next = const PrintOutcome.ok();

  /// Ob bei einem Druck mit Lade der Befehl für die Lade ankommt; ohne Wert
  /// genau dann, wenn [next] gelingt.
  bool? kickGoesOut;

  /// Solange gesetzt, wartet jeder Aufruf darauf.
  Completer<void>? hold;

  Future<PrintOutcome> _call(String entry) async {
    log.add(entry);
    final h = hold;
    if (h != null) await h.future;
    return next;
  }

  @override
  Future<PrintOutcome> printReceipt(
    Receipt receipt, {
    bool openDrawer = false,
  }) async {
    if (!openDrawer) return _call('print:${receipt.id}');
    final o = await _call('print+drawer:${receipt.id}');
    final sent = kickGoesOut ?? o.ok;
    final problem = o.problem;
    return problem == null
        ? PrintOutcome.ok(drawerSent: sent)
        : PrintOutcome.failed(problem, drawerSent: sent);
  }

  @override
  Future<PrintOutcome> openDrawer() => _call('drawer');

  @override
  Future<PrintOutcome> testPrint() => _call('test');

  /// Die Angaben jedes Zettels "Angaben für FinanzOnline", in der Reihenfolge
  /// der Aufrufe (im Protokoll als `setup`).
  final List<SetupFacts> setupSlips = [];

  @override
  Future<PrintOutcome> printSetupFacts(SetupFacts facts) {
    setupSlips.add(facts);
    return _call('setup');
  }

  @override
  Future<PrintOutcome> printDayReport(
    DaySummary summary, {
    required String? registerName,
    required bool drawer,
  }) => _call('day-report:${summary.day.id}');

  @override
  Future<PrintOutcome> printPeriodReport(
    PeriodReport report, {
    required String? registerName,
  }) => _call('period-report:${report.range.key}');

  /// Die Rasterdaten jedes Aufrufs von [printRaster], in der Reihenfolge.
  final List<Uint8List> rasters = [];

  /// Solange gesetzt, wirft [printRaster] diesen Fehler (statt eines
  /// Ergebnisses), wie ein unerwarteter Fehler im Drucker.
  Object? rasterError;

  /// Wie der echte Drucker: die Daten entstehen erst nach [hold]; leere
  /// Daten gehen nicht hinaus und stehen nicht im Protokoll.
  @override
  Future<PrintOutcome> printRaster(Future<Uint8List> Function() bytes) async {
    final error = rasterError;
    if (error != null) {
      log.add('raster');
      throw error;
    }
    final h = hold;
    if (h != null) await h.future;
    final Uint8List data;
    try {
      data = await bytes();
    } catch (_) {
      log.add('raster');
      rethrow;
    }
    if (data.isEmpty) return const PrintOutcome.ok();
    log.add('raster');
    rasters.add(data);
    return next;
  }
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

  /// Wird von `requestAccess` geworfen, solange gesetzt.
  Object? accessError;

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
    if (accessError != null) throw accessError!;
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

  /// Der Kleinstbetrag; SumUp: 1,00 €.
  int minimum = 100;

  @override
  int get minimumCents => minimum;

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

/// Falscher Küchenbon: merkt sich die Aufrufe und antwortet [next] (für einen
/// Bon) und [nextSample] (für die Probe).
class FakeKitchenService implements KitchenService {
  /// Die Aufrufe in der Reihenfolge: `for:<Bon-Nummer>`, mit `:copy` für eine
  /// Kopie, und `sample`.
  final List<String> calls = [];

  /// Das Ergebnis jedes Küchenbons; `null`: keiner fällig.
  PrintOutcome? next = const PrintOutcome.ok();

  /// Das Ergebnis jeder Probe.
  PrintOutcome nextSample = const PrintOutcome.ok();

  /// Solange gesetzt, wartet jeder Aufruf darauf.
  Completer<void>? hold;

  @override
  Future<PrintOutcome?> printFor(Receipt receipt, {bool copy = false}) async {
    calls.add('for:${receipt.number}${copy ? ':copy' : ''}');
    final h = hold;
    if (h != null) await h.future;
    return next;
  }

  /// Wie [printFor]; im Protokoll ebenso `for:<Bon-Nummer>`.
  @override
  Future<PrintOutcome?> printForSale(
    Receipt receipt,
    RegisterSettings settings,
  ) => printFor(receipt);

  @override
  Future<PrintOutcome> printSample() async {
    calls.add('sample');
    final h = hold;
    if (h != null) await h.future;
    return nextSample;
  }
}
