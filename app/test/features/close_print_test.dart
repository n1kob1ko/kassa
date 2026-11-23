import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/data/providers.dart';
import 'package:kassa/data/settings_repository.dart';
import 'package:kassa/devices/printer.dart';
import 'package:kassa/ui/primary_button.dart';
import 'package:material_ui/material_ui.dart';

import '../support/bons_pump.dart';
import '../support/close_pump.dart';
import '../support/kassa_pump.dart';
import '../support/pump.dart';

const _printKey = Key('print-day-report');
const _resultKey = Key('day-report-result');

/// Richtet in den Einstellungen einen Netzwerkdrucker ein.
Future<void> setUpPrinter(WidgetTester t) async {
  final repo = containerOf(t).read(settingsRepositoryProvider);
  await repo.save(
    (await repo.current()).copyWith(
      printerKind: PrinterKind.network,
      printerAddress: '192.168.0.50',
    ),
  );
  await t.pump();
}

/// Öffnet den Abschluss mit Wechselgeld und einem Verkauf, optional mit
/// Drucker.
Future<void> _open(WidgetTester t, {bool printer = true}) async {
  await pumpClose(t, floatCents: 15000, openArea: false);
  if (printer) await setUpPrinter(t);
  await openClose(t);
}

Future<void> _tap(WidgetTester t, String key) async {
  await t.ensureVisible(find.byKey(Key(key)));
  await t.tap(find.byKey(Key(key)));
  await t.pumpAndSettle();
}

/// Zählt 168,20 €, lässt 150 € in der Lade und schließt.
Future<void> _closeDay(WidgetTester t) async {
  await tapKeys(t, '1 6 8 , 2 0');
  await _tap(t, 'count-next');
  await tapKeys(t, '1 5 0');
  await _tap(t, 'close-day');
}

Future<String> _closedDayId(WidgetTester t) async =>
    (await containerOf(t).read(dayRepositoryProvider).lastClosedDay())!.id;

void main() {
  testWidgets('Tag abschließen druckt den Bericht einmal', (t) async {
    await _open(t);
    await _closeDay(t);
    expect(printerOf(t).log, ['day-report:${await _closedDayId(t)}']);
    expect(find.text('Der Tag ist abgeschlossen.'), findsOneWidget);
    expect(find.text('Bericht gedruckt.'), findsOneWidget);
    expect(find.byKey(_printKey), findsOneWidget);
  });

  testWidgets('Drucker hängt: der Tag ist trotzdem sofort abgeschlossen', (
    t,
  ) async {
    await _open(t);
    final hold = Completer<void>();
    printerOf(t).hold = hold;
    await _closeDay(t);
    expect(find.text('Der Tag ist abgeschlossen.'), findsOneWidget);
    expect(
      await containerOf(t).read(dayRepositoryProvider).lastClosedDay(),
      isNotNull,
    );
    expect(printerOf(t).log, hasLength(1));
    expect(find.byKey(_resultKey), findsNothing);
    // Während des Drucks ist die Taste gesperrt.
    expect(t.widget<PrimaryButton>(find.byKey(_printKey)).onPressed, isNull);
    hold.complete();
    await t.pumpAndSettle();
    expect(find.text('Bericht gedruckt.'), findsOneWidget);
  });

  testWidgets(
    'Drucker nicht bereit: Meldung steht da, "Bericht drucken" geht danach',
    (t) async {
      await _open(t);
      printerOf(t).next = const PrintOutcome.failed(PrintProblem.unreachable);
      await _closeDay(t);
      expect(find.text('Der Tag ist abgeschlossen.'), findsOneWidget);
      expect(
        find.text(
          const PrintOutcome.failed(PrintProblem.unreachable).message,
        ),
        findsOneWidget,
      );
      expect(find.text('Bericht gedruckt.'), findsNothing);
      printerOf(t).next = const PrintOutcome.ok();
      await _tap(t, 'print-day-report');
      expect(printerOf(t).log, hasLength(2));
      expect(printerOf(t).log.last, printerOf(t).log.first);
      expect(find.text('Bericht gedruckt.'), findsOneWidget);
    },
  );

  testWidgets('ohne Drucker: keine Taste, kein Druck', (t) async {
    await _open(t, printer: false);
    await _closeDay(t);
    expect(find.text('Der Tag ist abgeschlossen.'), findsOneWidget);
    expect(printerOf(t).log, isEmpty);
    expect(find.byKey(_printKey), findsNothing);
    expect(find.byKey(_resultKey), findsNothing);
  });

  testWidgets(
    'später wieder geöffnet (kein neuer Tag): Taste druckt den letzten Tag',
    (t) async {
      await _open(t);
      await _closeDay(t);
      await _tap(t, 'tab-Bons');
      await _tap(t, 'tab-Abschluss');
      expect(find.text('Es gibt keinen offenen Tag.'), findsOneWidget);
      expect(find.byKey(_printKey), findsOneWidget);
      await _tap(t, 'print-day-report');
      final id = await _closedDayId(t);
      expect(printerOf(t).log, ['day-report:$id', 'day-report:$id']);
      expect(find.text('Bericht gedruckt.'), findsOneWidget);
    },
  );

  testWidgets('doppelt getippt: ein Druck', (t) async {
    await _open(t);
    await _closeDay(t);
    printerOf(t).hold = Completer<void>();
    await t.ensureVisible(find.byKey(_printKey));
    await t.tap(find.byKey(_printKey));
    await t.tap(find.byKey(_printKey));
    await t.pump();
    expect(printerOf(t).log, hasLength(2)); // der erste vom Abschluss
    printerOf(t).hold!.complete();
    await t.pumpAndSettle();
  });

  testWidgets('nach dem ersten Bon des neuen Tages ist die Taste weg', (
    t,
  ) async {
    await _open(t);
    await _closeDay(t);
    expect(find.byKey(_printKey), findsOneWidget);
    await sellCash(t);
    await _tap(t, 'tab-Bons');
    await _tap(t, 'tab-Abschluss');
    expect(find.byKey(_printKey), findsNothing);
    expect(find.byKey(_resultKey), findsNothing);
  });
}
