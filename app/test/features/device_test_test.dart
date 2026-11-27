import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/data/providers.dart';
import 'package:kassa/devices/printer.dart';
import 'package:kassa/ui/pressable.dart';
import 'package:material_ui/material_ui.dart';

import '../support/kassa_pump.dart' show containerOf;
import '../support/pump.dart' show printerOf;
import '../support/settings_pump.dart';

Future<void> _open(WidgetTester t) async {
  await t.ensureVisible(find.byKey(const Key('open-device-test')));
  await t.tap(find.byKey(const Key('open-device-test')));
  await t.pumpAndSettle();
}

String _text(WidgetTester t, String key) => (t.widget(
  find.descendant(of: find.byKey(Key(key)), matching: find.byType(Text)),
) as Text).data!;

void main() {
  testWidgets('Zeile "Geräte testen" öffnet die Seite, Zurück führt zurück', (
    t,
  ) async {
    await pumpSettings(t);
    expect(find.byKey(const Key('device-test-back')), findsNothing);
    await _open(t);
    expect(find.byKey(const Key('device-test-back')), findsOneWidget);
    expect(find.byKey(const Key('test-printer')), findsOneWidget);
    expect(find.byKey(const Key('test-drawer')), findsOneWidget);
    expect(find.text('Einstellungen'), findsNothing);

    await t.tap(find.byKey(const Key('device-test-back')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('device-test-back')), findsNothing);
    expect(find.text('Einstellungen'), findsOneWidget);
    expect(find.byKey(const Key('open-device-test')), findsOneWidget);
  });

  testWidgets('Testdruck in Ordnung', (t) async {
    await pumpSettings(t);
    await _open(t);
    expect(find.byKey(const Key('result-printer')), findsNothing);
    await t.tap(find.byKey(const Key('test-printer')));
    await t.pumpAndSettle();
    expect(printerOf(t).log, ['test']);
    expect(_text(t, 'result-printer'), 'Testdruck geschickt. Kommt Papier?');
  });

  testWidgets('Ein Lauf schreibt einen Bericht device_test mit der Zeile', (
    t,
  ) async {
    await pumpSettings(t);
    await _open(t);
    await t.tap(find.byKey(const Key('test-printer')));
    await t.pumpAndSettle();
    final db = containerOf(t).read(databaseProvider);
    final rows = await t.runAsync(() => db.select(db.reportRows).get());
    expect(rows!.single.kind, 'device_test');
    expect(
      rows.single.content,
      '[{"device":"printer","ok":true,'
      '"text":"Testdruck geschickt. Kommt Papier?"}]',
    );
  });

  testWidgets('Testdruck mit Problem zeigt die Druckmeldung', (t) async {
    await pumpSettings(t);
    printerOf(t).next = const PrintOutcome.failed(PrintProblem.paperOut);
    await _open(t);
    await t.tap(find.byKey(const Key('test-printer')));
    await t.pumpAndSettle();
    expect(
      _text(t, 'result-printer'),
      'Drucker nicht bereit. Das Papier ist leer.',
    );
  });

  testWidgets('Lade öffnen in Ordnung', (t) async {
    await pumpSettings(t);
    await _open(t);
    await t.tap(find.byKey(const Key('test-drawer')));
    await t.pumpAndSettle();
    expect(printerOf(t).log, ['drawer']);
    expect(
      _text(t, 'result-drawer'),
      'Befehl geschickt. Ist die Lade aufgegangen?',
    );
  });

  testWidgets('Lade mit Problem zeigt die Druckmeldung', (t) async {
    await pumpSettings(t);
    printerOf(t).next = const PrintOutcome.failed(PrintProblem.unreachable);
    await _open(t);
    await t.tap(find.byKey(const Key('test-drawer')));
    await t.pumpAndSettle();
    expect(
      _text(t, 'result-drawer'),
      'Drucker nicht bereit. Ist er eingeschaltet und verbunden?',
    );
  });

  testWidgets(
    'Geldlade in den Einstellungen aus: "Ausgeschaltet", keine Taste',
    (t) async {
      await pumpSettings(t);
      await t.tap(find.byKey(const Key('toggle-drawer')));
      await t.pumpAndSettle();
      expect((await settingsOf(t)).cashDrawerEnabled, isFalse);
      await _open(t);
      expect(find.byKey(const Key('test-drawer')), findsNothing);
      expect(find.text('Ausgeschaltet'), findsOneWidget);
      expect(printerOf(t).log, isEmpty);
    },
  );

  testWidgets(
    'zwei schnelle Tipps lösen einen Test aus, Ring während des Tests',
    (t) async {
      await pumpSettings(t);
      final hold = Completer<void>();
      printerOf(t).hold = hold;
      await _open(t);
      await t.tap(find.byKey(const Key('test-printer')));
      await t.pump();
      await t.tap(find.byKey(const Key('test-printer')));
      await t.pump();
      expect(printerOf(t).log, ['test']);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      hold.complete();
      await t.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(printerOf(t).log, ['test']);
      expect(find.byKey(const Key('result-printer')), findsOneWidget);
    },
  );

  testWidgets('ein Fehler im Drucker bleibt ein Ergebnis, keine Ausnahme', (
    t,
  ) async {
    await pumpSettings(t, printer: _ThrowingPrinter());
    await _open(t);
    await t.tap(find.byKey(const Key('test-printer')));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(
      _text(t, 'result-printer'),
      'Drucker nicht bereit. Ist er eingeschaltet und verbunden?',
    );
  });

  testWidgets('Zeilen 88 dp hoch, Tippflächen mindestens 48 dp', (t) async {
    await pumpSettings(t);
    await _open(t);
    expect(t.getSize(find.byKey(const Key('device-row-printer'))).height, 88);
    final taps = find.byType(Pressable);
    expect(taps, findsWidgets);
    for (final e in taps.evaluate()) {
      final size = t.getSize(find.byWidget(e.widget));
      expect(size.height, greaterThanOrEqualTo(48), reason: '${e.widget.key}');
      expect(size.width, greaterThanOrEqualTo(48), reason: '${e.widget.key}');
    }
    expect(
      t.getSize(find.byKey(const Key('test-printer'))).height,
      greaterThanOrEqualTo(64),
    );
  });
}

class _ThrowingPrinter implements ReceiptPrinter {
  @override
  Future<PrintOutcome> printReceipt(
    receipt, {
    openDrawer = false,
    recipient,
  }) async => throw StateError('x');
  @override
  Future<PrintOutcome> openDrawer() async => throw StateError('x');
  @override
  Future<PrintOutcome> testPrint() async => throw StateError('x');
  @override
  Future<PrintOutcome> printSetupFacts(facts) async => throw StateError('x');
  @override
  Future<PrintOutcome> printDayReport(
    summary, {
    required registerName,
    required drawer,
  }) async => throw StateError('x');
  @override
  Future<PrintOutcome> printPeriodReport(
    report, {
    required registerName,
  }) async => throw StateError('x');
  @override
  Future<PrintOutcome> printRaster(bytes) async => throw StateError('x');
  @override
  Future<PrintOutcome> printVoucher(
    voucher, {
    required soldAt,
    required isTest,
  }) async => throw StateError('x');
}
