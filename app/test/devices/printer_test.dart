import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/core/clock.dart';
import 'package:kassa/devices/escpos.dart';
import 'package:kassa/devices/printer.dart';
import 'package:kassa/domain/business_info.dart';
import 'package:kassa/domain/print_document.dart';
import 'package:kassa/domain/receipt.dart';
import 'package:kassa/domain/receipt_layout.dart';

const business = BusinessInfo(name: 'Beispiel-Imbiss');

Receipt receipt({
  String id = 'r1',
  ReceiptKind kind = ReceiptKind.sale,
  String? voids,
}) => Receipt(
  id: id,
  number: 7,
  createdAt: DateTime(2026, 11, 17, 11),
  staffId: 's',
  staffName: 'Anna',
  businessDayId: 'd',
  kind: kind,
  voidsReceiptId: voids,
  lines: const [],
  payment: const Payment(
    kind: PaymentKind.cash,
    amountCents: 0,
    givenCents: 0,
    changeCents: 0,
  ),
  goodsCents: 0,
  depositCents: 0,
  totalCents: 0,
);

class RecordingTransport implements PrinterTransport {
  final sent = <Uint8List>[];
  final asked = <List<int>>[];
  final answers = <int?>[];
  Object? sendError;
  bool hang = false;
  bool abandoned = false;
  final started = <Duration>[];
  final late = Completer<void>();

  @override
  void startCall(Duration limit) => started.add(limit);

  int sendCalls = 0;
  Completer<void>? statusGate;

  @override
  Future<void> send(Uint8List bytes) async {
    sendCalls++;
    if (hang) {
      await late.future;
      if (abandoned) return; // aufgegeben: nichts kommt beim Drucker an
    }
    if (sendError != null) throw sendError!;
    sent.add(bytes);
  }

  @override
  void abandon() => abandoned = true;

  @override
  Future<int?> status(List<int> request) async {
    asked.add(request);
    final gate = statusGate;
    if (gate != null) await gate.future;
    return answers.isEmpty ? null : answers.removeAt(0);
  }
}

EscPosPrinter printerOf(
  PrinterTransport? t, {
  Future<int?> Function(String)? number,
  Duration limit = printCallLimit,
}) => EscPosPrinter(
  transport: t,
  business: business,
  columns: 48,
  clock: FixedClock(DateTime(2026, 11, 17, 12)),
  numberOfReceipt: number ?? (_) async => null,
  limit: limit,
);

void main() {
  test('printReceipt schickt den gesetzten Bon', () async {
    final t = RecordingTransport();
    final r = receipt();
    final outcome = await printerOf(t).printReceipt(r);
    expect(outcome.ok, isTrue);
    expect(t.sent, [encodeEscPos(layoutReceipt(r, business))]);
    expect(t.asked, [escposStatusPrinter]);
  });

  test('Storno-Bon trägt die Nummer des stornierten Bons', () async {
    final t = RecordingTransport();
    final r = receipt(id: 'v', kind: ReceiptKind.voided, voids: 'r1');
    String? asked;
    await printerOf(
      t,
      number: (id) async {
        asked = id;
        return 41;
      },
    ).printReceipt(r);
    expect(asked, 'r1');
    expect(
      t.sent.single,
      encodeEscPos(layoutReceipt(r, business, voidedNumber: 41)),
    );
  });

  test('Storno-Bon ohne gefundene Nummer wird trotzdem gedruckt', () async {
    final t = RecordingTransport();
    final r = receipt(id: 'v', kind: ReceiptKind.voided, voids: 'r1');
    final outcome = await printerOf(
      t,
      number: (_) async => null,
    ).printReceipt(r);
    expect(outcome.ok, isTrue);
    expect(t.sent.single, encodeEscPos(layoutReceipt(r, business)));
  });

  test('ohne Drucker: notSetUp, nichts wird geschickt', () async {
    final p = printerOf(null);
    for (final o in [
      await p.printReceipt(receipt()),
      await p.openDrawer(),
      await p.testPrint(),
    ]) {
      expect(o.problem, PrintProblem.notSetUp);
      expect(o.message, 'Kein Bondrucker eingerichtet.');
    }
  });

  test(
    'Drucker offline mit leerem Papier: paperOut, nichts wird gedruckt',
    () async {
      final t = RecordingTransport()..answers.addAll([0x1A, 0x72]);
      final outcome = await printerOf(t).printReceipt(receipt());
      expect(outcome.problem, PrintProblem.paperOut);
      expect(t.sent, isEmpty);
      expect(t.asked, [escposStatusPrinter, escposStatusPaper]);
    },
  );

  test('Drucker offline, Papier da: coverOpen', () async {
    final t = RecordingTransport()..answers.addAll([0x1A, 0x12]);
    final outcome = await printerOf(t).printReceipt(receipt());
    expect(outcome.problem, PrintProblem.coverOpen);
    expect(t.sent, isEmpty);
  });

  test('keine Statusantwort: es wird gedruckt', () async {
    final t = RecordingTransport();
    expect((await printerOf(t).printReceipt(receipt())).ok, isTrue);
    expect(t.sent, hasLength(1));
  });

  test(
    'Transport wirft: das Problem kommt als Ergebnis zurück, keine Ausnahme',
    () async {
      final t = RecordingTransport()
        ..sendError = const PrinterException(PrintProblem.noPermission);
      final outcome = await printerOf(t).printReceipt(receipt());
      expect(outcome.problem, PrintProblem.noPermission);
      t.sendError = StateError('kaputt');
      expect(
        (await printerOf(t).printReceipt(receipt())).problem,
        PrintProblem.unreachable,
      );
    },
  );

  group('printReceipt mit openDrawer', () {
    test('Lade und Bon in einem Auftrag: der Laden-Befehl zuerst', () async {
      final t = RecordingTransport();
      final r = receipt();
      final outcome = await printerOf(t).printReceipt(r, openDrawer: true);
      expect(outcome.ok, isTrue);
      expect(outcome.drawerSent, isTrue);
      expect(t.started, hasLength(1)); // ein Aufruf, eine Verbindung
      expect(t.sent, [
        encodeEscPos([const PrintDrawerKick(), ...layoutReceipt(r, business)]),
      ]);
      // Nach Initialisieren und Zeichentabelle kommt als Erstes die Lade.
      expect(t.sent.single.sublist(5, 10), encodeDrawerKick());
    });

    test('ohne openDrawer: kein Laden-Befehl, drawerSent false', () async {
      final t = RecordingTransport();
      final outcome = await printerOf(t).printReceipt(receipt());
      expect(outcome.drawerSent, isFalse);
      expect(t.sent, [encodeEscPos(layoutReceipt(receipt(), business))]);
    });

    test('Papier leer: die Lade geht allein auf, Ergebnis paperOut', () async {
      final t = RecordingTransport()..answers.addAll([0x1A, 0x72]);
      final outcome = await printerOf(t)
          .printReceipt(receipt(), openDrawer: true);
      expect(outcome.problem, PrintProblem.paperOut);
      expect(outcome.drawerSent, isTrue);
      expect(t.sent, [encodeDrawerKick()]);
      expect(t.started, hasLength(1));
    });

    test(
      'Deckel offen: die Lade geht allein auf, Ergebnis coverOpen',
      () async {
        final t = RecordingTransport()..answers.addAll([0x1A, 0x12]);
        final outcome = await printerOf(t)
            .printReceipt(receipt(), openDrawer: true);
        expect(outcome.problem, PrintProblem.coverOpen);
        expect(outcome.drawerSent, isTrue);
        expect(t.sent, [encodeDrawerKick()]);
      },
    );

    test('Papier leer und der Laden-Befehl scheitert: paperOut, drawerSent '
        'false', () async {
      final t = RecordingTransport()
        ..answers.addAll([0x1A, 0x72])
        ..sendError = const PrinterException(PrintProblem.unreachable);
      final outcome = await printerOf(t)
          .printReceipt(receipt(), openDrawer: true);
      expect(outcome.problem, PrintProblem.paperOut);
      expect(outcome.drawerSent, isFalse);
    });

    test('Senden scheitert: Problem, drawerSent false', () async {
      final t = RecordingTransport()
        ..sendError = const PrinterException(PrintProblem.noPermission);
      final outcome = await printerOf(t)
          .printReceipt(receipt(), openDrawer: true);
      expect(outcome.problem, PrintProblem.noPermission);
      expect(outcome.drawerSent, isFalse);
    });

    test('Drucker antwortet nicht: nach einem Limit timeout, drawerSent '
        'false', () async {
      final t = RecordingTransport()..hang = true;
      final outcome = await printerOf(
        t,
        limit: const Duration(milliseconds: 100),
      ).printReceipt(receipt(), openDrawer: true);
      expect(outcome.problem, PrintProblem.timeout);
      expect(outcome.drawerSent, isFalse);
      expect(t.started, hasLength(1));
    });

    test('ohne Drucker: notSetUp', () async {
      final outcome = await printerOf(null)
          .printReceipt(receipt(), openDrawer: true);
      expect(outcome.problem, PrintProblem.notSetUp);
      expect(outcome.drawerSent, isFalse);
    });
  });

  test('openDrawer schickt genau den Laden-Befehl', () async {
    final t = RecordingTransport();
    final outcome = await printerOf(t).openDrawer();
    expect(outcome.ok, isTrue);
    expect(outcome.drawerSent, isTrue);
    expect(t.sent, [encodeDrawerKick()]);
  });

  test(
    'zwei Aufrufe gleichzeitig: der zweite beginnt erst nach dem ersten',
    () async {
      final gate = Completer<void>();
      final t = RecordingTransport()..statusGate = gate;
      final p = printerOf(t);
      final first = p.printReceipt(receipt(id: 'a'));
      final second = p.openDrawer();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(t.started, hasLength(1)); // der zweite wartet
      expect(t.sent, isEmpty);
      gate.complete();
      expect((await first).ok, isTrue);
      expect((await second).ok, isTrue);
      expect(t.started, hasLength(2));
      expect(t.sent, [
        encodeEscPos(layoutReceipt(receipt(id: 'a'), business)),
        encodeDrawerKick(),
      ]);
    },
  );

  test(
    'ein hängender erster Aufruf blockiert den zweiten nicht für immer',
    () async {
      final t = RecordingTransport()..hang = true;
      final p = printerOf(t, limit: const Duration(milliseconds: 100));
      final first = p.printReceipt(receipt());
      final second = p.openDrawer();
      expect((await first).problem, PrintProblem.timeout);
      expect(t.started, hasLength(1)); // der zweite begann erst nach dem Limit
      t.hang = false;
      expect((await second).ok, isTrue);
      expect(t.started, hasLength(2));
    },
  );

  test('testPrint schickt den Testdruck', () async {
    final t = RecordingTransport();
    await printerOf(t).testPrint();
    expect(
      t.sent.single,
      encodeEscPos(layoutTestPrint(business, DateTime(2026, 11, 17, 12))),
    );
  });

  test('Senden dauert zu lange: timeout (Grenze im Test verkürzt)', () async {
    final t = RecordingTransport()..hang = true;
    final watch = Stopwatch()..start();
    final outcome = await printerOf(
      t,
      limit: const Duration(milliseconds: 100),
    ).printReceipt(receipt());
    expect(outcome.problem, PrintProblem.timeout);
    expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
    // Nach dem Limit wird der Transport aufgegeben; Spätes erreicht den
    // Drucker nicht mehr.
    expect(t.abandoned, isTrue);
    t.late.complete();
    await Future<void>.delayed(Duration.zero);
    expect(t.sent, isEmpty);
  });

  test(
    'Limit läuft während der Zustandsfrage ab: send wird nie aufgerufen',
    () async {
      final gate = Completer<void>();
      final t = RecordingTransport()
        ..statusGate = gate
        ..answers.addAll([0x08, 0x00]); // offline: zweite Frage würde folgen
      final outcome = await printerOf(
        t,
        limit: const Duration(milliseconds: 100),
      ).printReceipt(receipt());
      expect(outcome.problem, PrintProblem.timeout);
      gate.complete();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(t.sendCalls, 0);
      expect(t.asked, hasLength(1)); // keine zweite Frage nach dem Limit
    },
  );

  test(
    'Limit läuft während der Zustandsfrage ab (Antwort online): kein send',
    () async {
      final gate = Completer<void>();
      final t = RecordingTransport()..statusGate = gate;
      final outcome = await printerOf(
        t,
        limit: const Duration(milliseconds: 100),
      ).printReceipt(receipt());
      expect(outcome.problem, PrintProblem.timeout);
      gate.complete();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(t.sendCalls, 0);
    },
  );

  test('jeder Aufruf nennt dem Transport zuerst sein Zeitlimit', () async {
    final t = RecordingTransport();
    const limit = Duration(milliseconds: 1234);
    await printerOf(t, limit: limit).printReceipt(receipt());
    await printerOf(t, limit: limit).openDrawer();
    await printerOf(t, limit: limit).testPrint();
    expect(t.started, [limit, limit, limit]);
  });

  test('Meldungen', () {
    expect(
      const PrintOutcome.failed(PrintProblem.unreachable).message,
      'Drucker nicht bereit. Ist er eingeschaltet und verbunden?',
    );
    expect(
      const PrintOutcome.failed(PrintProblem.noPermission).message,
      'Kassa darf den Drucker nicht verwenden. Bitte die Erlaubnis geben.',
    );
    expect(
      const PrintOutcome.failed(PrintProblem.paperOut).message,
      'Drucker nicht bereit. Das Papier ist leer.',
    );
    expect(
      const PrintOutcome.failed(PrintProblem.coverOpen).message,
      'Drucker nicht bereit. Der Deckel ist offen.',
    );
    expect(
      const PrintOutcome.failed(PrintProblem.timeout).message,
      'Drucker nicht bereit. Er antwortet nicht.',
    );
  });

  test('Standardgrenze eines Aufrufs sind 5 Sekunden', () {
    expect(printCallLimit, const Duration(seconds: 5));
  });
}
