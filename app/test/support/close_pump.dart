// Helfer für Tests des Bereichs Abschluss: Wechselgeld und Verkäufe anlegen,
// als Chef anmelden und den Bereich öffnen.

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/core/clock.dart';
import 'package:kassa/data/providers.dart';
import 'package:kassa/data/settings_repository.dart';
import 'package:kassa/features/login/session.dart';
import 'package:material_ui/material_ui.dart';

import 'bons_pump.dart';
import 'kassa_pump.dart';
import 'overview_pump.dart';
import 'pump.dart';

/// Meldet [pin] an (Standard: Chef), legt auf Wunsch das Wechselgeld
/// ([floatCents]) fest, [sales] Barverkäufe zu 18,20 € an und öffnet den
/// Bereich Abschluss. Mit `drawer: false` ist die Geldlade ausgeschaltet.
Future<void> pumpClose(
  WidgetTester t, {
  int sales = 1,
  int? floatCents,
  String pin = '4711',
  bool drawer = true,
  bool openArea = true,
  Size size = const Size(1280, 800),
  Brightness brightness = Brightness.light,
  double textScale = 1.0,
  FixedClock? clock,
  List<Override> extra = const [],
}) async {
  final overrides = [
    ...await memoryOverrides(
      clock: clock ?? FixedClock(DateTime(2026, 11, 17, 11)),
    ),
    ...extra,
  ];
  await pumpKassa(
    t,
    size: size,
    brightness: brightness,
    textScale: textScale,
    overrides: overrides,
  );
  if (pin != '1234') {
    await containerOf(t).read(sessionProvider.notifier).login(pin);
    await t.pump();
  }
  final c = containerOf(t);
  if (!drawer) {
    await c
        .read(settingsRepositoryProvider)
        .save(const RegisterSettings(cashDrawerEnabled: false));
    await t.pump();
  }
  if (floatCents != null) {
    await c.read(dayRepositoryProvider).setOpeningFloat(floatCents);
  }
  for (var i = 0; i < sales; i++) {
    await sellCash(t, cart: bowlCart());
  }
  if (openArea) await openClose(t);
}

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

Future<void> openClose(WidgetTester t) async {
  await t.tap(find.byKey(const Key('tab-Abschluss')));
  await t.pumpAndSettle();
}

/// Ein Verkauf (18,20 €), kein Wechselgeld bekannt.
Future<void> pumpCloseWithSales(WidgetTester t, int n) =>
    pumpClose(t, sales: n);

/// Wechselgeld 150,00 €, ein Verkauf (18,20 €): Soll 168,20 €.
Future<void> pumpCloseReady(
  WidgetTester t, {
  Size size = const Size(1280, 800),
  Brightness brightness = Brightness.light,
  double textScale = 1.0,
  bool drawer = true,
}) => pumpClose(
  t,
  floatCents: 15000,
  size: size,
  brightness: brightness,
  textScale: textScale,
  drawer: drawer,
);

/// Der Tag begann gestern mit einem Verkauf und ist noch offen, jetzt ist
/// der nächste Morgen und [pin] meldet sich neu an.
Future<void> pumpShellNextMorningWithOpenDay(
  WidgetTester t, {
  String pin = '4711',
}) async {
  final clock = FixedClock(DateTime(2026, 11, 17, 20));
  await pumpKassa(t, overrides: await memoryOverrides(clock: clock));
  await sellCash(t, cart: bowlCart());
  clock.value = DateTime(2026, 11, 18, 8);
  containerOf(t).read(sessionProvider.notifier).logout();
  await t.pumpAndSettle();
  await typePin(t, pin);
  await t.pumpAndSettle();
}
