// Bondrucker hinter einer Schnittstelle: der Druckdienst setzt einen Bon zu
// Bytes und schickt sie über einen Transport (Netzwerk, USB, Bluetooth).

import 'dart:async';
import 'dart:typed_data';

import '../core/clock.dart';
import '../domain/business_info.dart';
import '../domain/receipt.dart';
import '../domain/receipt_layout.dart';
import 'escpos.dart';

enum PrintProblem {
  notSetUp,
  unreachable,
  noPermission,
  paperOut,
  coverOpen,
  timeout,
}

/// Ergebnis eines Druckversuchs. Ein Druckfehler ist nie eine Ausnahme: die
/// Kassa darf wegen des Druckers keinen Verkauf aufhalten.
class PrintOutcome {
  const PrintOutcome.ok() : problem = null;
  const PrintOutcome.failed(PrintProblem this.problem);

  final PrintProblem? problem;

  bool get ok => problem == null;

  /// Text für die Bedienerin; leer, wenn alles gut ging.
  String get message => switch (problem) {
    null => '',
    PrintProblem.notSetUp => 'Kein Bondrucker eingerichtet.',
    PrintProblem.unreachable =>
      'Drucker nicht bereit. Ist er eingeschaltet und verbunden?',
    PrintProblem.noPermission =>
      'Kassa darf den Drucker nicht verwenden. Bitte die Erlaubnis geben.',
    PrintProblem.paperOut => 'Drucker nicht bereit. Das Papier ist leer.',
    PrintProblem.coverOpen => 'Drucker nicht bereit. Der Deckel ist offen.',
    PrintProblem.timeout => 'Drucker nicht bereit. Er antwortet nicht.',
  };
}

class PrinterException implements Exception {
  const PrinterException(this.problem);

  final PrintProblem problem;

  @override
  String toString() => 'PrinterException($problem)';
}

abstract interface class PrinterTransport {
  /// Schickt die Bytes. Wirft [PrinterException] mit einem [PrintProblem].
  Future<void> send(Uint8List bytes);

  /// Schickt eine Zustandsfrage und gibt das Antwort-Byte zurück. `null`, wenn
  /// der Drucker binnen 1 Sekunde nicht antwortet oder die Frage scheitert.
  Future<int?> status(List<int> request);

  /// Der Druckdienst gibt den laufenden Aufruf auf (Limit abgelaufen). Offene
  /// oder später zustande kommende Verbindungen dieses Aufrufs werden
  /// geschlossen; danach darf nichts mehr zum Drucker gehen.
  void abandon();
}

abstract interface class ReceiptPrinter {
  Future<PrintOutcome> printReceipt(Receipt receipt);
  Future<PrintOutcome> openDrawer();
  Future<PrintOutcome> testPrint();
}

/// Höchstdauer eines ganzen Aufrufs (Zustandsfragen und Senden).
const printCallLimit = Duration(seconds: 5);

class EscPosPrinter implements ReceiptPrinter {
  EscPosPrinter({
    required this.transport,
    required this.business,
    required this.columns,
    required this.clock,
    required this.numberOfReceipt,
    this.limit = printCallLimit,
  });

  final PrinterTransport? transport;
  final BusinessInfo business;
  final int columns;
  final Clock clock;

  /// Nummer des Bons mit dieser Id; `null`, wenn er nicht zu finden ist.
  final Future<int?> Function(String receiptId) numberOfReceipt;

  /// Höchstdauer eines Aufrufs; nur Tests setzen einen anderen Wert.
  final Duration limit;

  @override
  Future<PrintOutcome> printReceipt(Receipt receipt) => _run(
    checkStatus: true,
    bytes: () async {
      final voidsId = receipt.voidsReceiptId;
      int? voidedNumber;
      if (receipt.kind == ReceiptKind.voided && voidsId != null) {
        try {
          voidedNumber = await numberOfReceipt(voidsId);
        } catch (_) {
          voidedNumber = null; // ohne Nummer trotzdem drucken
        }
      }
      return encodeEscPos(
        layoutReceipt(
          receipt,
          business,
          columns: columns,
          voidedNumber: voidedNumber,
        ),
      );
    },
  );

  @override
  Future<PrintOutcome> openDrawer() =>
      _run(checkStatus: false, bytes: () async => encodeDrawerKick());

  @override
  Future<PrintOutcome> testPrint() => _run(
    checkStatus: true,
    bytes: () async =>
        encodeEscPos(layoutTestPrint(business, clock.now(), columns: columns)),
  );

  Future<PrintOutcome> _run({
    required bool checkStatus,
    required Future<Uint8List> Function() bytes,
  }) async {
    final transport = this.transport;
    if (transport == null) {
      return const PrintOutcome.failed(PrintProblem.notSetUp);
    }
    try {
      return await _attempt(transport, checkStatus, bytes).timeout(
        limit,
        onTimeout: () {
          transport.abandon();
          return const PrintOutcome.failed(PrintProblem.timeout);
        },
      );
    } on PrinterException catch (e) {
      return PrintOutcome.failed(e.problem);
    } catch (_) {
      return const PrintOutcome.failed(PrintProblem.unreachable);
    }
  }

  Future<PrintOutcome> _attempt(
    PrinterTransport transport,
    bool checkStatus,
    Future<Uint8List> Function() bytes,
  ) async {
    if (checkStatus) {
      final problem = await _offlineProblem(transport);
      if (problem != null) return PrintOutcome.failed(problem);
    }
    await transport.send(await bytes());
    return const PrintOutcome.ok();
  }

  /// Bit 3 (0x08) der Druckerstatus-Antwort heißt offline. Ein Fehler oder
  /// keine Antwort ist kein Grund, nicht zu drucken.
  Future<PrintProblem?> _offlineProblem(PrinterTransport transport) async {
    try {
      final state = await transport.status(escposStatusPrinter);
      if (state == null || state & 0x08 == 0) return null;
      final paper = await transport.status(escposStatusPaper);
      if (paper != null && paper & 0x60 != 0) return PrintProblem.paperOut;
      return PrintProblem.coverOpen;
    } catch (_) {
      return null;
    }
  }
}
