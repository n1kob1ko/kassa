import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/core/app_language.dart';
import 'package:kassa/data/providers.dart';
import 'package:kassa/data/settings_repository.dart';
import 'package:kassa/devices/device_providers.dart';
import 'package:kassa/devices/printer.dart';
import 'package:kassa/devices/printer_discovery.dart';
import 'package:kassa/features/kassa/kitchen_service.dart';
import 'package:material_ui/material_ui.dart';

import '../support/fake_devices.dart';
import '../support/kassa_pump.dart' show containerOf;
import '../support/settings_pump.dart';

// Abschnitt "Küche" in den Einstellungen: Ort des Küchenbons, Sprache,
// Küchendrucker, Kategorien, Vorschau und Probe.

const _kitchenLan = FoundPrinter(
  kind: PrinterKind.network,
  name: 'Küche 192.168.1.60',
  address: '192.168.1.60:9100',
);

Future<FakeKitchenService> _pump(
  WidgetTester t, {
  FakeDiscovery? discovery,
  FakePrinter? kitchenPrinter,
}) async {
  final kitchen = FakeKitchenService();
  await pumpSettings(
    t,
    discovery: discovery,
    extra: [
      kitchenServiceProvider.overrideWithValue(kitchen),
      kitchenPrinterProvider.overrideWithValue(kitchenPrinter ?? FakePrinter()),
    ],
  );
  return kitchen;
}

Future<void> _tap(WidgetTester t, String key) async {
  await t.ensureVisible(find.byKey(Key(key)));
  await t.pumpAndSettle();
  await t.tap(find.byKey(Key(key)));
  await t.pumpAndSettle();
}

Future<void> _save(
  WidgetTester t,
  RegisterSettings Function(RegisterSettings s) change,
) async {
  final repo = containerOf(t).read(settingsRepositoryProvider);
  await repo.save(change(await repo.current()));
  await t.pumpAndSettle();
}

/// Lässt das Zeichnen der Vorschau zu Ende laufen (echtes `dart:ui`).
Future<void> _paint(WidgetTester t) async {
  for (var i = 0; i < 5; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await t.pump();
  }
}

ui.Image? _previewImage(WidgetTester t) {
  final raw = find.descendant(
    of: find.byKey(const Key('kitchen-preview')),
    matching: find.byType(RawImage),
  );
  if (raw.evaluate().isEmpty) return null;
  return t.widget<RawImage>(raw).image;
}

void main() {
  testWidgets('Aus: nur die Segmente; die Segmente blenden die Zeilen ein '
      'und speichern sofort', (t) async {
    await _pump(t);
    expect(find.text('Küche'), findsOneWidget);
    expect(find.text('Küchenbon'), findsOneWidget);
    expect(find.byKey(const Key('kitchen-mode-off')), findsOneWidget);
    expect(find.byKey(const Key('kitchen-language-de')), findsNothing);
    expect(find.byKey(const Key('kitchen-sample')), findsNothing);

    await _tap(t, 'kitchen-mode-receiptPrinter');
    expect((await settingsOf(t)).kitchenMode, KitchenMode.receiptPrinter);
    expect(find.text('Sprache am Küchenbon'), findsOneWidget);
    expect(find.byKey(const Key('kitchen-language-de')), findsOneWidget);
    expect(find.text('Kategorien für die Küche'), findsOneWidget);
    expect(find.byKey(const Key('kitchen-sample')), findsOneWidget);
    // Am Bondrucker gibt es keinen eigenen Küchendrucker.
    expect(find.byKey(const Key('kitchen-printer-row')), findsNothing);

    await _tap(t, 'kitchen-mode-kitchenPrinter');
    expect((await settingsOf(t)).kitchenMode, KitchenMode.kitchenPrinter);
    expect(find.byKey(const Key('kitchen-printer-row')), findsOneWidget);
    expect(find.text('Küchendrucker'), findsOneWidget);
    expect(
      find.text('Kein Küchendrucker eingerichtet. Es kommt kein Küchenbon.'),
      findsOneWidget,
    );

    await _tap(t, 'kitchen-mode-off');
    expect((await settingsOf(t)).kitchenMode, KitchenMode.off);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('kitchen-language-de')), findsNothing);
    expect(find.byKey(const Key('kitchen-printer-row')), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('mit eingerichtetem Küchendrucker: Name statt Hinweis', (
    t,
  ) async {
    await _pump(t);
    await _save(
      t,
      (s) => s.copyWith(
        kitchenMode: KitchenMode.kitchenPrinter,
        kitchenPrinterKind: PrinterKind.network,
        kitchenPrinterAddress: '192.168.1.60:9100',
        kitchenPrinterName: 'Küche 192.168.1.60',
      ),
    );
    expect(find.text('Küche 192.168.1.60'), findsOneWidget);
    expect(
      find.text('Kein Küchendrucker eingerichtet. Es kommt kein Küchenbon.'),
      findsNothing,
    );
  });

  testWidgets('Küchendrucker wählen speichert ihn als Küchendrucker, der '
      'Bondrucker bleibt', (t) async {
    final printer = FakePrinter();
    await _pump(
      t,
      discovery: FakeDiscovery(foundNetwork: [_kitchenLan]),
      kitchenPrinter: printer,
    );
    await _save(t, (s) => s.copyWith(kitchenMode: KitchenMode.kitchenPrinter));
    await _tap(t, 'kitchen-printer-row');
    expect(find.byKey(const Key('kitchen-printer-panel')), findsOneWidget);
    expect(find.byKey(const Key('printer-panel')), findsNothing);
    await _tap(t, 'kitchen-printer-found-192.168.1.60:9100');
    final s = await settingsOf(t);
    expect(s.kitchenPrinterKind, PrinterKind.network);
    expect(s.kitchenPrinterAddress, '192.168.1.60:9100');
    expect(s.kitchenPrinterName, 'Küche 192.168.1.60');
    expect(s.printerKind, PrinterKind.none);
    expect(s.printerAddress, isNull);

    // Testdruck geht an den Küchendrucker.
    await _tap(t, 'kitchen-printer-test');
    expect(printer.log, ['test']);
    expect(printerOfReceipt(t).log, isEmpty);

    // Breite des Küchendruckers, nicht des Bondruckers.
    await _tap(t, 'kitchen-printer-width-42');
    expect((await settingsOf(t)).kitchenPrinterColumns, 42);
    expect((await settingsOf(t)).printerColumns, 48);

    await _tap(t, 'kitchen-printer-remove');
    final removed = await settingsOf(t);
    expect(removed.kitchenPrinterKind, PrinterKind.none);
    expect(removed.kitchenPrinterAddress, isNull);
    expect(removed.kitchenMode, KitchenMode.kitchenPrinter);
    expect(t.takeException(), isNull);
  });

  testWidgets('Sprache am Küchenbon ändert die Bediensprache nicht, und '
      'umgekehrt', (t) async {
    await _pump(t);
    await _save(t, (s) => s.copyWith(kitchenMode: KitchenMode.receiptPrinter));
    await _tap(t, 'kitchen-language-tr');
    var s = await settingsOf(t);
    expect(s.kitchenLanguage, AppLanguage.tr);
    expect(s.language, AppLanguage.de);
    // Noch Deutsch am Bildschirm.
    expect(find.text('Sprache am Küchenbon'), findsOneWidget);

    await _tap(t, 'language-en');
    s = await settingsOf(t);
    expect(s.language, AppLanguage.en);
    expect(s.kitchenLanguage, AppLanguage.tr);
    expect(find.text('Kitchen ticket language'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('Schalter einer Kategorie landet in kitchenSkipCategories', (
    t,
  ) async {
    await _pump(t);
    await _save(t, (s) => s.copyWith(kitchenMode: KitchenMode.receiptPrinter));
    // Je Kategorie der Speisekarte ein Schalter, neu alle an.
    for (final id in ['bowls', 'snacks', 'suesses', 'getraenke']) {
      expect(find.byKey(Key('kitchen-category-$id')), findsOneWidget);
    }
    expect(find.text('Getränke'), findsOneWidget);
    await _tap(t, 'kitchen-category-getraenke');
    expect((await settingsOf(t)).kitchenSkipCategories, {'getraenke'});
    expect(find.text('kommen nicht auf den Küchenbon'), findsOneWidget);
    await _tap(t, 'kitchen-category-snacks');
    expect((await settingsOf(t)).kitchenSkipCategories, {
      'getraenke',
      'snacks',
    });
    await _tap(t, 'kitchen-category-getraenke');
    expect((await settingsOf(t)).kitchenSkipCategories, {'snacks'});
  });

  testWidgets('Kategorien stehen in der Bediensprache', (t) async {
    await _pump(t);
    await containerOf(t).read(translationRepositoryProvider).upsert({
      'Getränke': {'en': 'Drinks'},
    });
    await _save(
      t,
      (s) => s.copyWith(
        kitchenMode: KitchenMode.receiptPrinter,
        language: AppLanguage.en,
      ),
    );
    expect(find.text('Drinks'), findsOneWidget);
  });

  testWidgets('Vorschau zeichnet sich neu, wenn die Sprache wechselt, und '
      'zeigt bis dahin das alte Bild', (t) async {
    await _pump(t);
    await _save(t, (s) => s.copyWith(kitchenMode: KitchenMode.receiptPrinter));
    await _paint(t);
    final first = _previewImage(t);
    expect(first, isNotNull);
    // 48 Spalten am Bondrucker: 576 Punkte.
    expect(first!.width, 576);

    await _tap(t, 'kitchen-language-zh');
    // Das neue Bild ist noch nicht fertig: das alte bleibt stehen.
    expect(_previewImage(t), isNotNull);
    await _paint(t);
    final second = _previewImage(t);
    expect(identical(second, first), isFalse);

    // Eine Kategorie weniger: wieder neu gezeichnet.
    await _tap(t, 'kitchen-category-bowls');
    await _paint(t);
    expect(identical(_previewImage(t), second), isFalse);
    expect(t.takeException(), isNull);
  });

  testWidgets('Probe drucken ruft printSample und zeigt das Ergebnis', (
    t,
  ) async {
    final kitchen = await _pump(t);
    await _save(t, (s) => s.copyWith(kitchenMode: KitchenMode.receiptPrinter));
    final hold = kitchen.hold = Completer<void>();
    await _tapNoSettle(t, 'kitchen-sample');
    expect(kitchen.calls, ['sample']);
    expect(find.text('Druckt …'), findsOneWidget);
    // Ein zweiter Tipp während des Druckens druckt nicht noch einmal.
    await t.tap(find.byKey(const Key('kitchen-sample')), warnIfMissed: false);
    await t.pump();
    expect(kitchen.calls, ['sample']);
    kitchen.hold = null;
    hold.complete();
    await t.pumpAndSettle();
    expect(find.text('Probe gedruckt.'), findsOneWidget);

    kitchen.nextSample = const PrintOutcome.failed(PrintProblem.coverOpen);
    await _tap(t, 'kitchen-sample');
    expect(kitchen.calls, ['sample', 'sample']);
    expect(find.text('Probe gedruckt.'), findsNothing);
    expect(
      find.text('Drucker nicht bereit. Der Deckel ist offen.'),
      findsOneWidget,
    );
  });

  testWidgets('Probe ohne Küchendrucker sagt das in den Worten der Küche', (
    t,
  ) async {
    final kitchen = await _pump(t);
    await _save(t, (s) => s.copyWith(kitchenMode: KitchenMode.kitchenPrinter));
    kitchen.nextSample = const PrintOutcome.failed(PrintProblem.notSetUp);
    await _tap(t, 'kitchen-sample');
    expect(find.text('Kein Bondrucker eingerichtet.'), findsNothing);
    // Der Hinweis über den Zeilen und das Ergebnis der Probe.
    expect(
      find.text('Kein Küchendrucker eingerichtet. Es kommt kein Küchenbon.'),
      findsNWidgets(2),
    );
  });

  testWidgets('kein Sprung, wenn das Ergebnis der Probe erscheint', (t) async {
    await _pump(t);
    await _save(t, (s) => s.copyWith(kitchenMode: KitchenMode.receiptPrinter));
    await t.ensureVisible(find.byKey(const Key('kitchen-sample')));
    await t.pumpAndSettle();
    final before = t.getRect(find.byKey(const Key('kitchen-card')));
    await t.tap(find.byKey(const Key('kitchen-sample')));
    await t.pumpAndSettle();
    expect(find.text('Probe gedruckt.'), findsOneWidget);
    expect(t.getRect(find.byKey(const Key('kitchen-card'))), before);
  });

  testWidgets('Segmente und Schalter: Tippfläche mindestens 48 dp', (t) async {
    await _pump(t);
    await _save(t, (s) => s.copyWith(kitchenMode: KitchenMode.receiptPrinter));
    for (final mode in KitchenMode.values) {
      expect(
        t.getSize(find.byKey(Key('kitchen-mode-${mode.name}'))).height,
        greaterThanOrEqualTo(48),
      );
    }
    expect(
      t.getSize(find.byKey(const Key('kitchen-category-bowls'))).height,
      greaterThanOrEqualTo(48),
    );
    expect(
      t.getSize(find.byKey(const Key('kitchen-sample'))).height,
      greaterThanOrEqualTo(48),
    );
  });
}

Future<void> _tapNoSettle(WidgetTester t, String key) async {
  await t.ensureVisible(find.byKey(Key(key)));
  await t.pumpAndSettle();
  await t.tap(find.byKey(Key(key)));
  await t.pump();
}

FakePrinter printerOfReceipt(WidgetTester t) =>
    containerOf(t).read(receiptPrinterProvider) as FakePrinter;
