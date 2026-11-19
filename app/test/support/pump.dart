// Gemeinsame Helfer für Widget-Tests.
//
// Datenbank im Speicher: `memoryOverrides` ist asynchron. Drift auf
// `NativeDatabase.memory()` läuft im selben Isolate und antwortet über
// Microtasks. Das reicht, damit `await memoryOverrides()` direkt im Körper
// von `testWidgets` funktioniert (der Testkörper wartet in der FakeAsync-Zone
// auf Microtasks). Nach dem Aufbau der Oberfläche gilt: Datenbankaufrufe, die
// ein Widget über Riverpod auslöst, werden von `t.pump()` vorangebracht;
// Aufrufe der Repositories direkt im Testkörper (`await repo.x()`) laufen
// ebenfalls ohne `t.runAsync`. Nur echte Zeit (Timer, Dateien, Isolate) braucht
// `t.runAsync`.

import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/app.dart';
import 'package:kassa/app_sync_providers.dart';
import 'package:kassa/sync/file_sync.dart';
import 'package:kassa/sync/server_api.dart';
import 'package:kassa/core/clock.dart';
import 'package:kassa/data/catalog_repository.dart';
import 'package:kassa/data/database.dart';
import 'package:kassa/data/providers.dart';
import 'package:kassa/data/staff_repository.dart';
import 'package:kassa/devices/device_providers.dart';
import 'package:kassa/devices/card_terminal.dart';
import 'package:kassa/devices/printer.dart';
import 'package:kassa/devices/printer_discovery.dart';
import 'package:kassa/features/setup/menu_file_picker.dart';
import 'package:kassa/domain/staff.dart';
import 'package:kassa/ui/theme.dart';
import 'package:material_ui/material_ui.dart';

import 'demo_fixtures.dart';
import 'fake_devices.dart';
import 'kassa_pump.dart' show containerOf;

Future<void>? _fonts;

/// Lädt Figtree aus `assets/fonts` und die Lucide-Symbole, damit Bildvergleiche
/// echten Text und echte Symbole zeigen.
Future<void> loadFigtree() => _fonts ??= () async {
  final loader = FontLoader('Figtree');
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    final bytes = File('assets/fonts/Figtree-$w.ttf').readAsBytesSync();
    loader.addFont(
      Future.value(ByteData.sublistView(Uint8List.fromList(bytes))),
    );
  }
  await loader.load();
  // Lucide-Symbole kommen aus dem Paket, nicht aus dem Testgerät.
  final lucide = FontLoader('packages/lucide_icons_flutter/Lucide')
    ..addFont(
      rootBundle.load('packages/lucide_icons_flutter/assets/lucide.ttf'),
    );
  await lucide.load();
}();

/// Baut [child] in einer Umgebung wie in der App: Größe, Pixelverhältnis 1,0,
/// Textskala, Thema, [ProviderScope]. Ist [child] die [KassaApp] selbst, kommen
/// nur [ProviderScope] und die Einstellung der Fläche dazu.
Future<void> pumpApp(
  WidgetTester t,
  Widget child, {
  Size size = const Size(1280, 800),
  Brightness brightness = Brightness.light,
  double textScale = 1.0,
  List<Override> overrides = const [],
}) async {
  // Schriften laden braucht echte Zeit, nicht die FakeAsync-Uhr des Tests.
  await t.runAsync(loadFigtree);
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1.0;
  t.platformDispatcher.textScaleFactorTestValue = textScale;
  t.platformDispatcher.platformBrightnessTestValue = brightness;
  addTearDown(() async {
    // Die Oberfläche zuerst abbauen: Datenbank-Ströme (Kassa) müssen
    // abbestellt sein, bevor `memoryOverrides` die Datenbank schließt.
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(milliseconds: 10));
    t.view.resetPhysicalSize();
    t.view.resetDevicePixelRatio();
    t.platformDispatcher.clearTextScaleFactorTestValue();
    t.platformDispatcher.clearPlatformBrightnessTestValue();
  });

  final Widget root;
  if (child is KassaApp) {
    root = ProviderScope(overrides: overrides, child: child);
  } else {
    root = ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: kassaTheme(brightness),
        home: Scaffold(body: child),
      ),
    );
  }
  await t.pumpWidget(root);
}

/// Datenbank im Speicher und feste Uhr (Standard 17.11.2026, 11 Uhr). Mit
/// [seeded] sind der Beispiel-Imbiss eingespielt, der Chef "Chef" (PIN 4711)
/// und die Mitarbeiterin "Anna" (PIN 1234) angelegt, sonst ist alles leer.
/// Die Datenbank wird am Ende des Tests geschlossen. [pickedFile] ist der Text,
/// den die Dateiauswahl liefert (`null`: die Person bricht ab). Der Drucker
/// ist ein [FakePrinter] (oder [printer]); Tests erreichen ihn mit [printerOf].
/// Das Kartenterminal ist ein [FakeCardTerminal] (oder [terminal]), erreichbar
/// mit [terminalOf]. Das Internet ist da, oder es folgt dem Strom [internet]
/// (siehe [InternetSwitch]). Die Druckersuche ist eine [FakeDiscovery] (oder
/// [discovery]), erreichbar mit [discoveryOf].
Future<List<Override>> memoryOverrides({
  bool seeded = true,
  Clock? clock,
  String? pickedFile,
  MenuFilePicker? picker,
  ReceiptPrinter? printer,
  CardTerminal? terminal,
  Stream<bool>? internet,
  PrinterDiscovery? discovery,
}) async {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final db = KassaDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  if (seeded) {
    await CatalogRepository(db).importCatalog(catalog);
    final staff = StaffRepository(db);
    await staff.create(name: 'Chef', pin: '4711', role: StaffRole.chef);
    await staff.create(name: 'Anna', pin: '1234', role: StaffRole.staff);
  }
  return [
    databaseProvider.overrideWithValue(db),
    receiptPrinterProvider.overrideWithValue(printer ?? FakePrinter()),
    cardTerminalProvider.overrideWithValue(terminal ?? FakeCardTerminal()),
    // Die Netzsuche öffnet Sockets: Tests ersetzen sie immer.
    printerDiscoveryProvider.overrideWithValue(discovery ?? FakeDiscovery()),
    internetProvider.overrideWith((ref) => internet ?? Stream.value(true)),
    clockProvider.overrideWithValue(
      clock ?? FixedClock(DateTime(2026, 11, 17, 11)),
    ),
    menuFilePickerProvider.overrideWithValue(picker ?? _FakePicker(pickedFile)),
    // Dateien auf der Platte brauchen echte Zeit, die ein Widget-Test nicht
    // abwartet: der Abgleich lädt in diesen Tests keine Bilder.
    fileSyncProvider.overrideWith(
      (ref) =>
          _NoFiles(ref.watch(databaseProvider), ref.watch(serverApiProvider)),
    ),
    demoMenuTextProvider.overrideWithValue(
      () async => File('assets/demo/beispiel-imbiss.json').readAsStringSync(),
    ),
  ];
}

/// Ein `FileSync`, das nichts lädt.
class _NoFiles extends FileSync {
  _NoFiles(KassaDatabase db, ServerApi api)
    : super(db, api, () async => Directory.systemTemp);

  @override
  Future<bool> run(String token) async => false;
}

/// Der falsche Drucker der laufenden Oberfläche.
FakePrinter printerOf(WidgetTester t) =>
    containerOf(t).read(receiptPrinterProvider) as FakePrinter;

/// Die falsche Druckersuche der laufenden Oberfläche.
FakeDiscovery discoveryOf(WidgetTester t) =>
    containerOf(t).read(printerDiscoveryProvider) as FakeDiscovery;

/// Schaltet das Internet der Tests an und aus: `memoryOverrides(internet:
/// switch_.stream)`.
class InternetSwitch {
  InternetSwitch({this.initial = true});

  /// Der Stand, mit dem der Strom beginnt.
  final bool initial;

  final StreamController<bool> _controller = StreamController<bool>.broadcast();

  /// Der Strom für `memoryOverrides`; liefert zuerst [initial].
  Stream<bool> get stream async* {
    yield initial;
    yield* _controller.stream;
  }

  void set(bool value) => _controller.add(value);
}

/// Das falsche Kartenterminal der laufenden Oberfläche.
FakeCardTerminal terminalOf(WidgetTester t) =>
    containerOf(t).read(cardTerminalProvider) as FakeCardTerminal;

/// Dateiwähler, der wirft, solange [broken] gesetzt ist, danach [text] liefert.
class BrokenPicker implements MenuFilePicker {
  BrokenPicker(this.text);

  final String? text;
  bool broken = true;
  int calls = 0;

  @override
  Future<String?> pickText() async {
    calls++;
    if (broken) throw StateError('Dateiwähler nicht erreichbar');
    return text;
  }
}

class _FakePicker implements MenuFilePicker {
  const _FakePicker(this.text);

  final String? text;

  @override
  Future<String?> pickText() async => text;
}

/// Text des [Text]-Widgets mit diesem [key], oder des ersten [Text] darunter.
String textOf(WidgetTester t, Key key) {
  final finder = find.byKey(key);
  final widget = t.widget(finder);
  final Text text = widget is Text
      ? widget
      : t.widget<Text>(
          find.descendant(of: finder, matching: find.byType(Text)).first,
        );
  return text.data ?? text.textSpan?.toPlainText() ?? '';
}

/// Tippt Tasten des Zahlenfelds, durch Leerzeichen getrennt, z. B.
/// `'1 2 , 5 0 back'`. Pumpt nach jeder Taste.
Future<void> tapKeys(WidgetTester t, String keys) async {
  for (final k in keys.split(' ').where((k) => k.isNotEmpty)) {
    final name = switch (k) {
      ',' => 'comma',
      'back' => 'back',
      _ => k,
    };
    await t.tap(find.byKey(Key('key-$name')));
    await t.pump();
  }
}

/// Tippt die Ziffern einer PIN.
Future<void> typePin(WidgetTester t, String pin) =>
    tapKeys(t, pin.split('').join(' '));
