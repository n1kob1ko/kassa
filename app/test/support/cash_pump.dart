// Helfer für Tests des Bezahlens: Bon bonieren, "Bar" tippen, Bons zählen.

import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/data/providers.dart';
import 'package:kassa/data/settings_repository.dart';
import 'package:material_ui/material_ui.dart';

import 'kassa_pump.dart';

/// Startet die Kassa, bonniert die Artikel und tippt "Bar".
Future<void> openCash(
  WidgetTester t,
  List<String> ids, {
  Size size = const Size(1280, 800),
  Brightness brightness = Brightness.light,
  double textScale = 1.0,
  bool withPrinter = false,
}) async {
  await pumpKassaWith(
    t,
    ids,
    size: size,
    brightness: brightness,
    textScale: textScale,
  );
  if (withPrinter) await setUpPrinter(t);
  await t.tap(find.byKey(const Key('pay-cash')));
  await t.pumpAndSettle();
}

Future<List<Map<String, Object?>>> queryRows(WidgetTester t, String sql) async {
  final rows = await containerOf(t)
      .read(databaseProvider)
      .customSelect(sql)
      .get();
  return [for (final r in rows) r.data];
}

Future<int> receiptCount(WidgetTester t) async =>
    (await queryRows(t, 'SELECT COUNT(*) AS c FROM receipts')).single['c']!
        as int;

/// Richtet einen Netzwerkdrucker in den Einstellungen ein (der Drucker der
/// Tests ist der [FakePrinter], die Einstellung entscheidet nur, ob die
/// Kassa einen Drucker kennt).
Future<void> setUpPrinter(WidgetTester t) async {
  final repo = containerOf(t).read(settingsRepositoryProvider);
  await repo.save(
    (await repo.current()).copyWith(
      printerKind: PrinterKind.network,
      printerAddress: '192.168.0.50',
      printerName: 'Kassendrucker',
    ),
  );
  await t.pumpAndSettle();
}
