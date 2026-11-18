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
import 'package:kassa/rksv/card/atrust_card.dart';
import 'package:kassa/rksv/card/card_providers.dart';
import 'package:kassa/rksv/card/pin_guard.dart';
import 'package:kassa/rksv/card/reader_transport.dart';
import 'package:kassa/rksv/card/share_sheet.dart';
import 'package:material_ui/material_ui.dart';

import '../rksv/fixtures/test_card.dart';
import 'fake_card_reader.dart';
import 'kassa_pump.dart';
import 'pump.dart';
import 'scripted_reader.dart' show bytesOf;

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

/// ATR einer a.sign RK CHIP mit ACOS-ID 2.1 (Tabelle von Task 4).
const _acosId2Atr = '3BDF96FF910131FE4680319052410264050200AC73D622C017';

/// Die nachgebaute Signaturkarte des Beispiel-Imbiss mit dem Test-Zertifikat
/// (gültig bis 30.06.2031). Die richtige PIN steht nur in [FakeCard].
FakeCard testSignatureCard({String atrHex = _acosId2Atr, int retriesLeft = 3}) {
  final atr = bytesOf(atrHex);
  return FakeCard(
    atr: atr,
    profile: profileForAtr(atr)!,
    retriesLeft: retriesLeft,
    certificate: testCertificate,
    signer: testSigner,
  );
}

/// Teilen-Fenster für Tests: merkt sich Betreff und Text jedes Aufrufs und
/// antwortet [result].
class FakeShareSheet implements ShareSheet {
  FakeShareSheet({this.result = true});

  bool result;
  final List<({String subject, String text})> calls = [];

  @override
  Future<bool> text({required String subject, required String text}) async {
    calls.add((subject: subject, text: text));
    return result;
  }
}

/// Der nachgebaute Kartenleser der laufenden Oberfläche.
FakeCardReader cardReaderOf(WidgetTester t) =>
    containerOf(t).read(readerTransportProvider) as FakeCardReader;

/// Das Teilen-Fenster der laufenden Oberfläche.
FakeShareSheet shareSheetOf(WidgetTester t) =>
    containerOf(t).read(shareSheetProvider) as FakeShareSheet;

/// Meldet den Chef an und öffnet die Einstellungen. Kartenleser, PIN-Wächter
/// und Teilen-Fenster sind immer nachgebaut: ohne [reader] ein Leser ohne
/// Karte, ohne [guard] ein leerer [MemoryPinGuard].
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
  ReaderTransport? reader,
  PinGuard? guard,
  ShareSheet? share,
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
      readerTransportProvider.overrideWithValue(reader ?? FakeCardReader()),
      pinGuardProvider.overrideWithValue(guard ?? MemoryPinGuard()),
      shareSheetProvider.overrideWithValue(share ?? FakeShareSheet()),
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
  ReaderTransport? reader,
  PinGuard? guard,
  ShareSheet? share,
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
    reader: reader,
    guard: guard,
    share: share,
  );
  await openSettings(t);
}

Future<RegisterSettings> settingsOf(WidgetTester t) =>
    containerOf(t).read(settingsRepositoryProvider).current();

/// Öffnet aus den Einstellungen "Karte prüfen". Mit [card] steckt die Karte im
/// Leser, mit [noCard] steckt keine; [guard] ist der PIN-Wächter. [wrap]
/// legt einen eigenen Leser um den nachgebauten (dann gilt [cardReaderOf]
/// nicht).
Future<FakeCardReader> pumpCardCheck(
  WidgetTester t, {
  FakeCard? card,
  bool noCard = false,
  PinGuard? guard,
  FakeShareSheet? share,
  Brightness brightness = Brightness.light,
  double textScale = 1.0,
  ReaderTransport Function(FakeCardReader reader)? wrap,
}) async {
  final reader = FakeCardReader(
    card: noCard ? null : (card ?? testSignatureCard()),
  );
  await pumpSettings(
    t,
    brightness: brightness,
    textScale: textScale,
    reader: wrap == null ? reader : wrap(reader),
    guard: guard,
    share: share,
  );
  await t.ensureVisible(find.byKey(const Key('open-card-check')));
  await t.pumpAndSettle();
  await t.tap(find.byKey(const Key('open-card-check')));
  await t.pumpAndSettle();
  return reader;
}
