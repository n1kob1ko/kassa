// Bondrucker hinter einer Schnittstelle: der Druckdienst setzt einen Bon zu
// Bytes und schickt sie über einen Transport (Netzwerk, USB, Bluetooth).

import 'dart:async';
import 'dart:typed_data';

import '../core/clock.dart';
import '../domain/business_info.dart';
import '../domain/print_document.dart';
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
  const PrintOutcome.ok({this.drawerSent = false}) : problem = null;
  const PrintOutcome.failed(
    PrintProblem this.problem, {
    this.drawerSent = false,
  });

  final PrintProblem? problem;

  /// Der Befehl für die Geldlade ist beim Drucker angekommen (nur bei einem
  /// Aufruf, der die Lade öffnen sollte).
  final bool drawerSent;

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

  /// Der Druckdienst beginnt einen Aufruf (Zustandsfragen und Senden), der
  /// höchstens [limit] dauern darf. Was danach noch käme, geht nicht mehr zum
  /// Drucker.
  void startCall(Duration limit);

  /// Der Druckdienst gibt den laufenden Aufruf auf (Limit abgelaufen). Offene
  /// oder später zustande kommende Verbindungen dieses Aufrufs werden
  /// geschlossen; danach darf nichts mehr zum Drucker gehen.
  void abandon();
}

abstract interface class ReceiptPrinter {
  /// Druckt den Bon. Mit [openDrawer] sind die ersten Befehle desselben
  /// Auftrags die für die Geldlade: ein Aufruf, eine Verbindung. Meldet der
  /// Drucker, dass er nicht drucken kann (Papier leer, Deckel offen), geht der
  /// Befehl für die Lade allein hinaus, und das Ergebnis ist das Problem des
  /// Druckers.
  Future<PrintOutcome> printReceipt(Receipt receipt, {bool openDrawer = false});
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
  Future<PrintOutcome> printReceipt(
    Receipt receipt, {
    bool openDrawer = false,
  }) => _run(
    checkStatus: true,
    openDrawer: openDrawer,
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
      return encodeEscPos([
        if (openDrawer) const PrintDrawerKick(),
        ...layoutReceipt(
          receipt,
          business,
          columns: columns,
          voidedNumber: voidedNumber,
        ),
      ]);
    },
  );

  @override
  Future<PrintOutcome> openDrawer() => _run(
    checkStatus: false,
    openDrawer: true,
    bytes: () async => encodeDrawerKick(),
  );

  @override
  Future<PrintOutcome> testPrint() => _run(
    checkStatus: true,
    bytes: () async =>
        encodeEscPos(layoutTestPrint(business, clock.now(), columns: columns)),
  );

  /// Ende des letzten Aufrufs. Das Limit gilt je Transport für einen Aufruf,
  /// darum läuft immer nur einer: der nächste beginnt, wenn der vorige zu Ende
  /// ist oder aufgegeben wurde.
  Future<void> _last = Future.value();

  /// [openDrawer]: Die Bytes enthalten den Befehl für die Lade; kann der
  /// Drucker nicht drucken, geht dieser Befehl allein hinaus.
  Future<PrintOutcome> _run({
    required bool checkStatus,
    bool openDrawer = false,
    required Future<Uint8List> Function() bytes,
  }) {
    final previous = _last;
    final finished = Completer<void>();
    _last = finished.future;
    return previous
        .then(
          (_) => _runNow(
            checkStatus: checkStatus,
            openDrawer: openDrawer,
            bytes: bytes,
          ),
        )
        .whenComplete(finished.complete);
  }

  Future<PrintOutcome> _runNow({
    required bool checkStatus,
    required bool openDrawer,
    required Future<Uint8List> Function() bytes,
  }) async {
    final transport = this.transport;
    if (transport == null) {
      return const PrintOutcome.failed(PrintProblem.notSetUp);
    }
    final call = _Call();
    try {
      transport.startCall(limit);
      return await _attempt(
        transport,
        call,
        checkStatus,
        openDrawer,
        bytes,
      ).timeout(
        limit,
        onTimeout: () {
          call.givenUp = true;
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

  /// Nach dem Limit ([_Call.givenUp]) beginnt kein weiterer Schritt mehr:
  /// keine zweite Zustandsfrage und kein Senden.
  Future<PrintOutcome> _attempt(
    PrinterTransport transport,
    _Call call,
    bool checkStatus,
    bool openDrawer,
    Future<Uint8List> Function() bytes,
  ) async {
    if (checkStatus) {
      final problem = await _offlineProblem(transport, call);
      if (problem != null) {
        if (!openDrawer || call.givenUp) return PrintOutcome.failed(problem);
        // Die Lade geht trotzdem auf: das Rückgeld wartet nicht auf Papier.
        var sent = false;
        try {
          await transport.send(encodeDrawerKick());
          sent = !call.givenUp;
        } catch (_) {}
        return PrintOutcome.failed(problem, drawerSent: sent);
      }
    }
    final data = await bytes();
    if (call.givenUp) return const PrintOutcome.failed(PrintProblem.timeout);
    await transport.send(data);
    return PrintOutcome.ok(drawerSent: openDrawer);
  }

  /// Bit 3 (0x08) der Druckerstatus-Antwort heißt offline. Ein Fehler oder
  /// keine Antwort ist kein Grund, nicht zu drucken.
  Future<PrintProblem?> _offlineProblem(
    PrinterTransport transport,
    _Call call,
  ) async {
    try {
      final state = await transport.status(escposStatusPrinter);
      if (state == null || state & 0x08 == 0) return null;
      if (call.givenUp) return PrintProblem.timeout;
      final paper = await transport.status(escposStatusPaper);
      if (paper != null && paper & 0x60 != 0) return PrintProblem.paperOut;
      return PrintProblem.coverOpen;
    } catch (_) {
      return null;
    }
  }
}

/// Zustand eines einzelnen Druckaufrufs.
class _Call {
  bool givenUp = false;
}
