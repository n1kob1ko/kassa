// Helfer für Tests des Bereichs Artikel: als Chef anmelden, Bereich öffnen.

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/data/providers.dart';
import 'package:kassa/domain/catalog.dart';
import 'package:kassa/features/login/session.dart';
import 'package:material_ui/material_ui.dart';

import 'demo_fixtures.dart';
import 'kassa_pump.dart';

/// Meldet den Chef (PIN 4711) an und öffnet den Bereich Artikel. Mit
/// [category] wird diese Kategorie gewählt (sonst die erste, Bowls).
Future<void> pumpItems(
  WidgetTester t, {
  String? category,
  Size size = const Size(1280, 800),
  Brightness brightness = Brightness.light,
  double textScale = 1.0,
  List<Override>? overrides,
}) async {
  await pumpKassa(
    t,
    size: size,
    brightness: brightness,
    textScale: textScale,
    overrides: overrides,
  );
  await containerOf(t).read(sessionProvider.notifier).login('4711');
  await t.pump();
  await t.tap(find.byKey(const Key('tab-Artikel')));
  await t.pumpAndSettle();
  if (category != null) await selectCategory(t, category);
}

Future<void> selectCategory(WidgetTester t, String id) async {
  await t.tap(find.byKey(Key('cat-$id')));
  await t.pumpAndSettle();
}

/// Wählt die Kategorie des Artikels und tippt seine Zeile an.
Future<void> openItem(WidgetTester t, String id) async {
  await selectCategory(t, catalog.item(id).categoryId);
  await t.tap(find.byKey(Key('row-$id')));
  await t.pumpAndSettle();
}

/// Der Katalog, wie die Datenbank ihn gerade hält.
Future<Catalog> catalogNow(WidgetTester t) async =>
    (await containerOf(t).read(catalogRepositoryProvider).current())!;
