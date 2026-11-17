// Helfer für Tests des Bezahlens: Bon bonieren, "Bar" tippen, Bons zählen.

import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/data/providers.dart';
import 'package:material_ui/material_ui.dart';

import 'kassa_pump.dart';

/// Startet die Kassa, bonniert die Artikel und tippt "Bar".
Future<void> openCash(
  WidgetTester t,
  List<String> ids, {
  Size size = const Size(1280, 800),
  double textScale = 1.0,
}) async {
  await pumpKassaWith(t, ids, size: size, textScale: textScale);
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
