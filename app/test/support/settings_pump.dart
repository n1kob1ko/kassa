// Helfer für Tests der Einstellungen: als Chef anmelden und sie öffnen.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/data/providers.dart';
import 'package:kassa/data/settings_repository.dart';
import 'package:kassa/devices/card_terminal.dart';
import 'package:kassa/devices/printer.dart';
import 'package:kassa/devices/printer_discovery.dart';
import 'package:kassa/features/login/session.dart';
import 'package:kassa/features/setup/menu_file_picker.dart';
import 'package:material_ui/material_ui.dart';

import 'kassa_pump.dart';
import 'pump.dart';

/// Die Speisekarte des Beispiel-Imbiss ohne die Teigtaschen: 13 Artikel.
String demoOhneTeigtaschen() {
  final json = jsonDecode(
    File('assets/demo/beispiel-imbiss.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  (json['artikel'] as List).removeWhere(
    (a) => (a as Map)['id'] == 'teigtaschen',
  );
  return jsonEncode(json);
}

Future<void> openSettings(WidgetTester t) async {
  await t.tap(find.byKey(const Key('settings')));
  await t.pumpAndSettle();
}

/// Meldet den Chef an und öffnet die Einstellungen.
Future<void> pumpAppLoggedInAsChef(
  WidgetTester t, {
  String? pickedFile,
  MenuFilePicker? picker,
  Size size = const Size(1280, 800),
  Brightness brightness = Brightness.light,
  double textScale = 1.0,
  List<Override> extra = const [],
  PrinterDiscovery? discovery,
  ReceiptPrinter? printer,
  CardTerminal? terminal,
  Stream<bool>? internet,
}) async {
  await pumpKassa(
    t,
    size: size,
    brightness: brightness,
    textScale: textScale,
    overrides: [
      ...await memoryOverrides(
        pickedFile: pickedFile,
        picker: picker,
        printer: printer,
        terminal: terminal,
        internet: internet,
        discovery: discovery,
      ),
      ...extra,
    ],
  );
  await containerOf(t).read(sessionProvider.notifier).login('4711');
  await t.pumpAndSettle();
}

Future<void> pumpSettings(
  WidgetTester t, {
  String? pickedFile,
  MenuFilePicker? picker,
  Size size = const Size(1280, 800),
  Brightness brightness = Brightness.light,
  double textScale = 1.0,
  List<Override> extra = const [],
  PrinterDiscovery? discovery,
  ReceiptPrinter? printer,
  CardTerminal? terminal,
  Stream<bool>? internet,
}) async {
  await pumpAppLoggedInAsChef(
    t,
    pickedFile: pickedFile,
    picker: picker,
    size: size,
    brightness: brightness,
    textScale: textScale,
    extra: extra,
    discovery: discovery,
    printer: printer,
    terminal: terminal,
    internet: internet,
  );
  await openSettings(t);
}

Future<RegisterSettings> settingsOf(WidgetTester t) =>
    containerOf(t).read(settingsRepositoryProvider).current();
