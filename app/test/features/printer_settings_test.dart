import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/ui/address_keypad.dart';
import 'package:kassa/data/providers.dart';
import 'package:kassa/data/settings_repository.dart';
import 'package:kassa/devices/printer.dart';
import 'package:kassa/devices/printer_discovery.dart';
import 'package:kassa/ui/pressable.dart';
import 'package:material_ui/material_ui.dart';

import '../support/fake_devices.dart';
import '../support/kassa_pump.dart' show containerOf;
import '../support/pump.dart' show tapKeys;
import '../support/settings_pump.dart';

const _lan = FoundPrinter(
  kind: PrinterKind.network,
  name: 'Drucker 192.168.1.50',
  address: '192.168.1.50:9100',
);
const _usb = FoundPrinter(
  kind: PrinterKind.usb,
  name: 'Bondrucker USB',
  address: '1208:514',
);
const _bt = FoundPrinter(
  kind: PrinterKind.bluetooth,
  name: 'Bondrucker BT',
  address: '00:11:22:33:44:55',
);

const _noPermission =
    'Kassa darf den Drucker nicht verwenden. Bitte die Erlaubnis geben.';

Future<void> _openPanel(WidgetTester t) async {
  await t.tap(find.byKey(const Key('printer-row')));
  await t.pumpAndSettle();
}

Future<void> _tapKind(WidgetTester t, String kind) async {
  await t.tap(find.byKey(Key('printer-kind-$kind')));
  await t.pumpAndSettle();
}

Future<void> _typeAddress(WidgetTester t, String address) async {
  await t.tap(find.byKey(const Key('printer-address-open')));
  await t.pumpAndSettle();
  await tapKeys(
    t,
    address.split('').map((c) => c == '.' ? 'dot' : c).join(' '),
  );
}

bool _saveEnabled(WidgetTester t) {
  final p = t.widget<Pressable>(
    find.descendant(
      of: find.byKey(const Key('printer-address-save')),
      matching: find.byType(Pressable),
    ),
  );
  return p.onTap != null;
}

String _text(WidgetTester t, String key) {
  final f = find.byKey(Key(key));
  final w = t.widget(f);
  return (w is Text
          ? w
          : t.widget<Text>(find.descendant(of: f, matching: find.byType(Text))))
      .data!;
}

void main() {
  testWidgets('ohne Drucker steht "Nicht eingerichtet"', (t) async {
    await pumpSettings(t);
    expect(find.byKey(const Key('printer-row')), findsOneWidget);
    // Der Drucker und die Signatur der Bons.
    expect(find.text('Nicht eingerichtet'), findsNWidgets(2));
    expect(find.text('Noch nicht dabei'), findsNothing);
    expect(find.byKey(const Key('printer-test')), findsNothing);
  });

  testWidgets('mit Drucker steht sein Name in der Pille', (t) async {
    await pumpSettings(t);
    final repo = containerOf(t).read(settingsRepositoryProvider);
    await repo.save(
      (await repo.current()).copyWith(
        printerKind: PrinterKind.network,
        printerAddress: '192.168.1.50:9100',
        printerName: 'Drucker 192.168.1.50',
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Drucker 192.168.1.50'), findsOneWidget);
    // Nur noch die Signatur der Bons.
    expect(find.text('Nicht eingerichtet'), findsOneWidget);
  });

  testWidgets(
    'Schalter "QR-Code als Bild drucken": nur mit Drucker, speichert',
    (t) async {
      await pumpSettings(t);
      expect(find.byKey(const Key('printer-qr-image')), findsNothing);
      final repo = containerOf(t).read(settingsRepositoryProvider);
      await repo.save(
        (await repo.current()).copyWith(
          printerKind: PrinterKind.network,
          printerAddress: '192.168.1.50:9100',
          printerName: 'Drucker 192.168.1.50',
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('QR-Code als Bild drucken'), findsOneWidget);
      expect(
        find.text(
          'Einschalten, wenn am Bon statt des QR-Codes nur Zeichen stehen.',
        ),
        findsOneWidget,
      );
      expect((await settingsOf(t)).printerQrAsImage, isFalse);
      await t.tap(find.byKey(const Key('printer-qr-image')));
      await t.pumpAndSettle();
      expect((await settingsOf(t)).printerQrAsImage, isTrue);
      await t.tap(find.byKey(const Key('printer-qr-image')));
      await t.pumpAndSettle();
      expect((await settingsOf(t)).printerQrAsImage, isFalse);
    },
  );

  testWidgets('Tipp öffnet das Feld in der Karte, noch ein Tipp schließt es', (
    t,
  ) async {
    await pumpSettings(t);
    expect(find.byKey(const Key('printer-kind-usb')), findsNothing);
    await _openPanel(t);
    expect(find.byKey(const Key('printer-kind-network')), findsOneWidget);
    expect(find.byKey(const Key('printer-kind-usb')), findsOneWidget);
    expect(find.byKey(const Key('printer-kind-bluetooth')), findsOneWidget);
    await _openPanel(t);
    expect(find.byKey(const Key('printer-kind-usb')), findsNothing);
  });

  testWidgets(
    'Netzwerk: gefundenen Drucker antippen speichert Art, Adresse und Name',
    (t) async {
      await pumpSettings(t, discovery: FakeDiscovery(foundNetwork: [_lan]));
      await _openPanel(t);
      await t.tap(find.byKey(const Key('printer-found-192.168.1.50:9100')));
      await t.pumpAndSettle();
      final s = await settingsOf(t);
      expect(s.printerKind, PrinterKind.network);
      expect(s.printerAddress, '192.168.1.50:9100');
      expect(s.printerName, 'Drucker 192.168.1.50');
      expect(find.byKey(const Key('printer-test')), findsOneWidget);
    },
  );

  testWidgets('beim Speichern bleiben die anderen Einstellungen erhalten', (
    t,
  ) async {
    await pumpSettings(t, discovery: FakeDiscovery(foundNetwork: [_lan]));
    final repo = containerOf(t).read(settingsRepositoryProvider);
    await repo.save(
      (await repo.current()).copyWith(
        showImages: true,
        voidRequiresChef: true,
        themeMode: AppThemeMode.dark,
        cashDrawerEnabled: false,
      ),
    );
    await t.pumpAndSettle();
    await _openPanel(t);
    await t.tap(find.byKey(const Key('printer-found-192.168.1.50:9100')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('printer-width-42')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('printer-remove')));
    await t.pumpAndSettle();
    final s = await settingsOf(t);
    expect(s.showImages, isTrue);
    expect(s.voidRequiresChef, isTrue);
    expect(s.themeMode, AppThemeMode.dark);
    expect(s.cashDrawerEnabled, isFalse);
    expect(s.printerColumns, 42);
  });

  testWidgets('USB: mit Erlaubnis wird gespeichert', (t) async {
    final discovery = FakeDiscovery(foundUsb: [_usb]);
    await pumpSettings(t, discovery: discovery);
    await _openPanel(t);
    await _tapKind(t, 'usb');
    await t.tap(find.byKey(const Key('printer-found-1208:514')));
    await t.pumpAndSettle();
    expect(discovery.accessRequests, ['usb:1208:514']);
    final s = await settingsOf(t);
    expect(s.printerKind, PrinterKind.usb);
    expect(s.printerAddress, '1208:514');
    expect(s.printerName, 'Bondrucker USB');
  });

  testWidgets('Bluetooth: ohne Erlaubnis wird nichts gespeichert', (t) async {
    final discovery = FakeDiscovery(foundBluetooth: [_bt], access: false);
    await pumpSettings(t, discovery: discovery);
    await _openPanel(t);
    await _tapKind(t, 'bluetooth');
    await t.tap(find.byKey(const Key('printer-found-00:11:22:33:44:55')));
    await t.pumpAndSettle();
    expect(discovery.accessRequests, ['bluetooth:00:11:22:33:44:55']);
    final s = await settingsOf(t);
    expect(s.printerKind, PrinterKind.none);
    expect(s.printerAddress, isNull);
    expect(find.text(_noPermission), findsOneWidget);
    expect(find.byKey(const Key('printer-test')), findsNothing);
  });

  testWidgets('Netzwerk braucht keine Frage nach der Erlaubnis', (t) async {
    final discovery = FakeDiscovery(foundNetwork: [_lan]);
    await pumpSettings(t, discovery: discovery);
    await _openPanel(t);
    await t.tap(find.byKey(const Key('printer-found-192.168.1.50:9100')));
    await t.pumpAndSettle();
    expect(discovery.accessRequests, isEmpty);
  });

  testWidgets('Adresse mit führenden Nullen: 192.168.001.050 wird als '
      '192.168.1.50 gespeichert', (t) async {
    await pumpSettings(t);
    await _openPanel(t);
    await _typeAddress(t, '192.168.001.050');
    expect(_saveEnabled(t), isTrue);
    await t.tap(find.byKey(const Key('printer-address-save')));
    await t.pumpAndSettle();
    final s = await settingsOf(t);
    expect(s.printerAddress, '192.168.1.50:9100');
    expect(s.printerName, 'Drucker 192.168.1.50');
  });

  test('normalizedIpv4: jede Zahl ohne führende Nullen', () {
    expect(normalizedIpv4('192.168.001.050'), '192.168.1.50');
    expect(normalizedIpv4('010.000.000.001'), '10.0.0.1');
    expect(normalizedIpv4('192.168.1.50'), '192.168.1.50');
  });

  testWidgets(
    'Adresse eintippen: 192.168.1.50 wird übernommen, 192.168.1 nicht, 300.1.1.1 nicht',
    (t) async {
      await pumpSettings(t);
      await _openPanel(t);

      await _typeAddress(t, '192.168.1');
      expect(_text(t, 'printer-address'), '192.168.1');
      expect(_saveEnabled(t), isFalse);

      await tapKeys(t, 'dot 5 0');
      expect(_text(t, 'printer-address'), '192.168.1.50');
      expect(_saveEnabled(t), isTrue);

      await tapKeys(t, 'back back');
      expect(_text(t, 'printer-address'), '192.168.1.');
      expect(_saveEnabled(t), isFalse);

      // 300 ist zu groß: 300.1.1.1 geht nicht.
      await tapKeys(t, List.filled(12, 'back').join(' '));
      await tapKeys(t, '3 0 0 dot 1 dot 1 dot 1');
      expect(_text(t, 'printer-address'), '300.1.1.1');
      expect(_saveEnabled(t), isFalse);

      await tapKeys(t, List.filled(12, 'back').join(' '));
      await tapKeys(t, '1 9 2 dot 1 6 8 dot 1 dot 5 0');
      await t.tap(find.byKey(const Key('printer-address-save')));
      await t.pumpAndSettle();
      final s = await settingsOf(t);
      expect(s.printerKind, PrinterKind.network);
      expect(s.printerAddress, '192.168.1.50:9100');
      expect(s.printerName, 'Drucker 192.168.1.50');
      expect(find.byKey(const Key('printer-address')), findsNothing);
    },
  );

  testWidgets('Adresse eintippen: Punkt nur nach einer Zahl, höchstens drei', (
    t,
  ) async {
    await pumpSettings(t);
    await _openPanel(t);
    await _typeAddress(t, '.');
    expect(_text(t, 'printer-address'), '');
    await tapKeys(t, '1 dot dot 2 dot 3 dot 4 dot 5');
    expect(_text(t, 'printer-address'), '1.2.3.45');
  });

  testWidgets('Testdruck: Erfolg und Fehler stehen als Satz da', (t) async {
    final printer = FakePrinter();
    await pumpSettings(
      t,
      discovery: FakeDiscovery(foundNetwork: [_lan]),
      printer: printer,
    );
    await _openPanel(t);
    await t.tap(find.byKey(const Key('printer-found-192.168.1.50:9100')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('printer-result')), findsNothing);

    await t.tap(find.byKey(const Key('printer-test')));
    await t.pumpAndSettle();
    expect(printer.log, ['test']);
    expect(_text(t, 'printer-result'), 'Testdruck geschickt. Kommt Papier?');

    printer.next = const PrintOutcome.failed(PrintProblem.unreachable);
    await t.tap(find.byKey(const Key('printer-test')));
    await t.pumpAndSettle();
    expect(
      _text(t, 'printer-result'),
      'Drucker nicht bereit. Ist er eingeschaltet und verbunden?',
    );
  });

  testWidgets('Testdruck: während er läuft ist die Taste aus', (t) async {
    final printer = FakePrinter()..hold = Completer<void>();
    await pumpSettings(
      t,
      discovery: FakeDiscovery(foundNetwork: [_lan]),
      printer: printer,
    );
    await _openPanel(t);
    await t.tap(find.byKey(const Key('printer-found-192.168.1.50:9100')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('printer-test')));
    await t.pump();
    await t.tap(find.byKey(const Key('printer-test')));
    await t.pump();
    expect(printer.log, ['test']);
    printer.hold!.complete();
    await t.pumpAndSettle();
    expect(find.byKey(const Key('printer-result')), findsOneWidget);
  });

  testWidgets('Schmal stellt 42 Zeichen ein, Normal 48', (t) async {
    await pumpSettings(t, discovery: FakeDiscovery(foundNetwork: [_lan]));
    await _openPanel(t);
    await t.tap(find.byKey(const Key('printer-found-192.168.1.50:9100')));
    await t.pumpAndSettle();
    expect(
      find.text('Schmal wählen, wenn der Testdruck am Rand umbricht.'),
      findsOneWidget,
    );
    await t.tap(find.byKey(const Key('printer-width-42')));
    await t.pumpAndSettle();
    expect((await settingsOf(t)).printerColumns, 42);
    await t.tap(find.byKey(const Key('printer-width-48')));
    await t.pumpAndSettle();
    expect((await settingsOf(t)).printerColumns, 48);
  });

  testWidgets('Drucker entfernen setzt alles zurück', (t) async {
    await pumpSettings(t, discovery: FakeDiscovery(foundNetwork: [_lan]));
    await _openPanel(t);
    await t.tap(find.byKey(const Key('printer-found-192.168.1.50:9100')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('printer-remove')));
    await t.pumpAndSettle();
    final s = await settingsOf(t);
    expect(s.printerKind, PrinterKind.none);
    expect(s.printerAddress, isNull);
    expect(s.printerName, isNull);
    expect(find.byKey(const Key('printer-test')), findsNothing);
    // Der Drucker und die Signatur der Bons.
    expect(find.text('Nicht eingerichtet'), findsNWidgets(2));
  });

  testWidgets('nichts gefunden: der Satz passt zur Verbindung, Nochmal suchen '
      'sucht neu', (t) async {
    final discovery = FakeDiscovery();
    await pumpSettings(t, discovery: discovery);
    await _openPanel(t);
    expect(
      find.text(
        'Kein Drucker gefunden. Ist er eingeschaltet und im selben WLAN?',
      ),
      findsOneWidget,
    );
    await _tapKind(t, 'usb');
    expect(
      find.text('Kein Drucker am USB-Anschluss gefunden.'),
      findsOneWidget,
    );
    await _tapKind(t, 'bluetooth');
    expect(
      find.text(
        'Kein Drucker gekoppelt. Bitte zuerst in den Bluetooth-Einstellungen '
        'des Tablets koppeln.',
      ),
      findsOneWidget,
    );
    expect(discovery.calls, ['network', 'usb', 'bluetooth']);

    discovery.foundBluetooth = [_bt];
    await t.tap(find.byKey(const Key('printer-search')));
    await t.pumpAndSettle();
    expect(discovery.calls, ['network', 'usb', 'bluetooth', 'bluetooth']);
    expect(
      find.byKey(const Key('printer-found-00:11:22:33:44:55')),
      findsOneWidget,
    );
  });

  testWidgets('Suche wirft: es steht "Die Suche hat nicht geklappt." und '
      'Nochmal suchen', (t) async {
    final discovery = FakeDiscovery(error: StateError('kaputt'));
    await pumpSettings(t, discovery: discovery);
    await _openPanel(t);
    await _tapKind(t, 'usb');
    expect(find.text('Die Suche hat nicht geklappt.'), findsOneWidget);
    expect(find.byKey(const Key('printer-search')), findsOneWidget);

    discovery
      ..error = null
      ..foundUsb = [_usb];
    await t.tap(find.byKey(const Key('printer-search')));
    await t.pumpAndSettle();
    expect(find.text('Die Suche hat nicht geklappt.'), findsNothing);
    expect(find.byKey(const Key('printer-found-1208:514')), findsOneWidget);
  });

  testWidgets(
    'Suche wirft PrinterException ohne Erlaubnis: Satz zur Erlaubnis',
    (t) async {
      final discovery = FakeDiscovery(
        error: const PrinterException(PrintProblem.noPermission),
      );
      await pumpSettings(t, discovery: discovery);
      await _openPanel(t);
      await _tapKind(t, 'bluetooth');
      expect(find.text(_noPermission), findsOneWidget);
      expect(find.byKey(const Key('printer-search')), findsOneWidget);
    },
  );

  testWidgets('Suche wirft eine andere PrinterException: allgemeiner Satz', (
    t,
  ) async {
    final discovery = FakeDiscovery(
      error: const PrinterException(PrintProblem.unreachable),
    );
    await pumpSettings(t, discovery: discovery);
    await _openPanel(t);
    await _tapKind(t, 'usb');
    expect(find.text('Die Suche hat nicht geklappt.'), findsOneWidget);
  });

  testWidgets('während der Suche stehen drei graue Platzhalter-Zeilen', (
    t,
  ) async {
    final discovery = FakeDiscovery(foundNetwork: [_lan])
      ..hold = Completer<void>();
    await pumpSettings(t, discovery: discovery);
    await _openPanel(t);
    expect(find.byKey(const Key('printer-skeleton')), findsNWidgets(3));
    expect(
      find.byKey(const Key('printer-found-192.168.1.50:9100')),
      findsNothing,
    );
    discovery.hold!.complete();
    await t.pumpAndSettle();
    expect(find.byKey(const Key('printer-skeleton')), findsNothing);
    expect(
      find.byKey(const Key('printer-found-192.168.1.50:9100')),
      findsOneWidget,
    );
  });

  testWidgets('eine späte Antwort einer früheren Suche wird nicht gezeigt', (
    t,
  ) async {
    final discovery = FakeDiscovery(foundNetwork: [_lan], foundUsb: [_usb])
      ..hold = Completer<void>();
    await pumpSettings(t, discovery: discovery);
    await _openPanel(t);
    await _tapKind(t, 'usb');
    discovery.hold!.complete();
    await t.pumpAndSettle();
    expect(find.byKey(const Key('printer-found-1208:514')), findsOneWidget);
    expect(
      find.byKey(const Key('printer-found-192.168.1.50:9100')),
      findsNothing,
    );
  });

  testWidgets('alle Tippflächen im Feld sind mindestens 48 dp hoch', (t) async {
    await pumpSettings(
      t,
      discovery: FakeDiscovery(foundNetwork: [_lan]),
      printer: FakePrinter(),
    );
    await _openPanel(t);
    await t.tap(find.byKey(const Key('printer-found-192.168.1.50:9100')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('printer-test')));
    await t.pumpAndSettle();

    void checkAll() {
      final taps = find.descendant(
        of: find.byKey(const Key('printer-panel')),
        matching: find.byType(Pressable),
      );
      expect(taps, findsWidgets);
      for (final e in taps.evaluate()) {
        final size = t.getSize(find.byWidget(e.widget));
        expect(
          size.height,
          greaterThanOrEqualTo(48),
          reason: '${e.widget.key}',
        );
      }
    }

    checkAll();
    await t.tap(find.byKey(const Key('printer-address-open')));
    await t.pumpAndSettle();
    checkAll();
  });
}
