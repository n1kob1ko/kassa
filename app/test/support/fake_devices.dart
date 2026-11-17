// Falsche Geräte für Tests.

import 'dart:async';

import 'package:kassa/devices/printer.dart';
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
