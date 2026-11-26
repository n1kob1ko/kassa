// Helfer für Tests des Kassenbildschirms: App starten, anmelden, Artikel
// tippen.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/app.dart';
import 'package:kassa/data/providers.dart';
import 'package:kassa/data/settings_repository.dart';
import 'package:kassa/domain/cart.dart';
import 'package:kassa/features/kassa/cart_controller.dart';
import 'package:material_ui/material_ui.dart';

import 'demo_fixtures.dart';
import 'pump.dart';

List<Override>? _lastOverrides;

/// Startet die App auf einer Datenbank im Speicher, meldet "Anna" an (mit
/// [pin] '4711' den Chef) und endet auf dem Kassenbildschirm. Mit
/// [sameDatabase] baut sie einen neuen `ProviderScope` auf die Datenbank des
/// letzten Aufrufs: so sieht man, was einen Neustart übersteht (die Anmeldung
/// gehört nicht dazu).
Future<void> pumpKassa(
  WidgetTester t, {
  bool sameDatabase = false,
  Size size = const Size(1280, 800),
  Brightness brightness = Brightness.light,
  double textScale = 1.0,
  List<Override>? overrides,
  String pin = '1234',
}) async {
  // Einen früheren ProviderScope abbauen, damit der neue wirklich neu beginnt.
  await t.pumpWidget(const SizedBox());
  final o = sameDatabase
      ? _lastOverrides!
      : overrides ?? await memoryOverrides();
  _lastOverrides = o;
  await pumpApp(
    t,
    const KassaApp(),
    overrides: o,
    size: size,
    brightness: brightness,
    textScale: textScale,
  );
  await t.pumpAndSettle();
  await typePin(t, pin);
  await t.pumpAndSettle();
}

/// Wie [pumpKassa], tippt danach die Artikel mit diesen Ids (wechselt die
/// Kategorie, wenn nötig). Ein Artikel mit Auswahl öffnet nur das
/// Zusammenstellen.
Future<void> pumpKassaWith(
  WidgetTester t,
  List<String> ids, {
  Size size = const Size(1280, 800),
  Brightness brightness = Brightness.light,
  double textScale = 1.0,
}) async {
  await pumpKassa(t, size: size, brightness: brightness, textScale: textScale);
  for (final id in ids) {
    await tapItem(t, id);
  }
}

/// Wählt die Kategorie des Artikels und tippt ihn.
Future<void> tapItem(WidgetTester t, String id) async {
  final item = catalog.item(id);
  await t.tap(find.byKey(Key('cat-${item.categoryId}')));
  await t.pump();
  await t.tap(find.byKey(Key('item-$id')));
  await t.pump();
}

/// Der Bon, wie die Kassa ihn gerade hält.
Cart cartOf(WidgetTester t) =>
    ProviderScope.containerOf(t.element(find.byType(KassaApp)))
        .read(cartProvider);

ProviderContainer containerOf(WidgetTester t) =>
    ProviderScope.containerOf(t.element(find.byType(KassaApp)));

/// Der Bon steht nach den Tests auch in der Datenbank.
Future<String?> draftOf(WidgetTester t) =>
    containerOf(t).read(settingsRepositoryProvider).readDraft();

/// Ändert die Einstellungen, speichert sie und wartet, bis die Oberfläche
/// ihnen folgt.
Future<void> setSettings(
  WidgetTester t,
  RegisterSettings Function(RegisterSettings s) change,
) async {
  final repo = containerOf(t).read(settingsRepositoryProvider);
  await repo.save(change(await repo.current()));
  await t.pumpAndSettle();
}
