// Falsche Geräte für Tests.

import 'dart:async';

import 'package:kassa/data/settings_repository.dart';
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
