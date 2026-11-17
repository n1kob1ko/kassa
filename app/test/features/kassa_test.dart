import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/data/providers.dart';
import 'package:kassa/domain/catalog.dart';
import 'package:kassa/features/kassa/cart_controller.dart';
import 'package:kassa/features/kassa/kassa_screen.dart';
import 'package:kassa/features/login/session.dart';
import 'package:kassa/ui/pressable.dart';
import 'package:kassa/ui/primary_button.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../support/demo_fixtures.dart';
import '../support/kassa_pump.dart';
import '../support/pump.dart';

Finder _text(String s) => find.text(s);

String _total(WidgetTester t) => textOf(t, const Key('cart-total'));

PrimaryButton _button(WidgetTester t, String key) =>
    t.widget<PrimaryButton>(find.byKey(Key(key)));

int _columns(WidgetTester t) {
  final grid = t.widget<GridView>(find.byKey(const Key('item-grid')));
  return (grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
      .crossAxisCount;
}

Future<void> _openBowl(WidgetTester t) async {
  await t.tap(find.byKey(const Key('item-huhn-bowl')));
  await t.pump();
}

/// Wählt Größe und Basis und legt die Bowl auf den Bon.
Future<void> _addBowl(WidgetTester t, {String size = 'bowl/0/1', String base = 'bowl/1/0'}) async {
  await _openBowl(t);
  await t.tap(find.byKey(Key('opt-$base')));
  await t.tap(find.byKey(Key('opt-$size')));
  await t.pump();
  await t.tap(find.byKey(const Key('add-to-cart')));
  await t.pump();
}

void main() {
  testWidgets('Tipp auf Artikel legt ihn auf den Bon, Pfand steht getrennt', (t) async {
    await pumpKassa(t);
    await t.tap(find.byKey(const Key('cat-getraenke')));
    await t.pump();
    await t.tap(find.byKey(const Key('item-cola')));
    await t.tap(find.byKey(const Key('item-cola')));
    await t.pump();
    final line = cartOf(t).lines.single;
    final row = find.byKey(Key('line-${line.lineId}'));
    expect(find.descendant(of: row, matching: _text('Cola 0,33 l')), findsOneWidget);
    expect(textOf(t, Key('qty-${line.lineId}')), '2');
    expect(find.descendant(of: row, matching: _text('5,80 €')), findsOneWidget);
    expect(_text('Pfand'), findsOneWidget);
    expect(_text('0,50 €'), findsOneWidget);
    expect(_total(t), '6,30 €');
    expect(textOf(t, const Key('cart-count')), '2 Artikel');
  });

  testWidgets('Artikel mit Auswahl: "Auf den Bon" erst, wenn die Pflichtgruppen gewählt sind', (t) async {
    await pumpKassa(t);
    await _openBowl(t);
    expect(_button(t, 'add-to-cart').onPressed, isNull);
    expect(_button(t, 'add-to-cart').label, 'Noch wählen: Basis');
    expect(_text('Noch wählen: Basis'), findsOneWidget);
    expect(_text('Bitte wählen'), findsOneWidget);
    // Der Bon bleibt, solange zusammengestellt wird, und Bar ist gesperrt.
    expect(cartOf(t).isEmpty, isTrue);
    await t.tap(find.byKey(const Key('opt-bowl/1/0')));
    await t.tap(find.byKey(const Key('opt-bowl/0/1')));
    await t.pump();
    expect(_button(t, 'add-to-cart').label, 'Auf den Bon');
    expect(_button(t, 'add-to-cart').onPressed, isNotNull);
    expect(_text('Bitte wählen'), findsNothing);
    await t.tap(find.byKey(const Key('add-to-cart')));
    await t.pump();
    expect(_total(t), '11,90 €');
    expect(_text('XXL, Reis'), findsOneWidget);
    // Das Zusammenstellen ist zu, das Raster wieder da.
    expect(find.byKey(const Key('item-grid')), findsOneWidget);
    expect(find.byKey(const Key('add-to-cart')), findsNothing);
  });

  testWidgets('Abbrechen im Zusammenstellen legt nichts auf den Bon', (t) async {
    await pumpKassa(t);
    await _openBowl(t);
    await t.tap(find.byKey(const Key('opt-bowl/1/0')));
    await t.pump();
    await t.tap(find.byKey(const Key('cancel-build')));
    await t.pump();
    expect(cartOf(t).isEmpty, isTrue);
    expect(_total(t), '0,00 €');
    expect(find.byKey(const Key('add-to-cart')), findsNothing);
    expect(find.byKey(const Key('item-huhn-bowl')), findsOneWidget);
    expect(await draftOf(t), isNull);
  });

  testWidgets('derselbe einfache Artikel gibt eine Zeile, zwei Bowls mit anderer Auswahl zwei', (t) async {
    await pumpKassa(t);
    await t.tap(find.byKey(const Key('cat-snacks')));
    await t.pump();
    await t.tap(find.byKey(const Key('item-pommes')));
    await t.tap(find.byKey(const Key('item-pommes')));
    await t.pump();
    expect(cartOf(t).lines, hasLength(1));
    expect(cartOf(t).lines.single.quantity, 2);
    await t.tap(find.byKey(const Key('cat-bowls')));
    await t.pump();
    await _addBowl(t, size: 'bowl/0/1', base: 'bowl/1/0');
    await _addBowl(t, size: 'bowl/0/0', base: 'bowl/1/1');
    final lines = cartOf(t).lines;
    expect(lines.map((l) => l.item.id), ['pommes', 'huhn-bowl', 'huhn-bowl']);
    expect(lines[1].options.map((o) => o.id), contains('bowl/0/1'));
    expect(lines[2].options.map((o) => o.id), contains('bowl/1/1'));
    expect(find.byKey(Key('line-${lines[1].lineId}')), findsOneWidget);
    expect(find.byKey(Key('line-${lines[2].lineId}')), findsOneWidget);
  });

  testWidgets('Minus bei Menge 1 entfernt die Zeile, Plus erhöht Menge und Summe', (t) async {
    await pumpKassaWith(t, ['teigtaschen']);
    final id = cartOf(t).lines.single.lineId;
    expect(_total(t), '6,50 €');
    await t.tap(find.byKey(Key('qty-plus-$id')));
    await t.pump();
    expect(textOf(t, Key('qty-$id')), '2');
    expect(_total(t), '13,00 €');
    await t.tap(find.byKey(Key('qty-minus-$id')));
    await t.pump();
    expect(textOf(t, Key('qty-$id')), '1');
    await t.tap(find.byKey(Key('qty-minus-$id')));
    await t.pump();
    expect(find.byKey(Key('line-$id')), findsNothing);
    expect(cartOf(t).isEmpty, isTrue);
    expect(_text('Noch nichts boniert'), findsOneWidget);
    expect(_total(t), '0,00 €');
  });

  testWidgets('Bon leeren lässt sich rückgängig machen', (t) async {
    await pumpKassaWith(t, ['cola', 'teigtaschen']);
    expect(_total(t), '9,65 €');
    await t.tap(find.byKey(const Key('clear-cart')));
    await t.pump();
    expect(_total(t), '0,00 €');
    expect(_text('Bon geleert'), findsOneWidget);
    expect(_text('Noch nichts boniert'), findsOneWidget);
    await t.tap(_text('Rückgängig'));
    await t.pump();
    expect(_total(t), '9,65 €');
    expect(_text('Bon geleert'), findsNothing);
  });

  testWidgets('leerer Bon: Bar ist gesperrt. Karte ist in dieser Version immer gesperrt', (t) async {
    await pumpKassa(t);
    expect(_text('Noch nichts boniert'), findsOneWidget);
    expect(_text('Tippe links auf einen Artikel. Jeder Tipp legt ihn einmal auf den Bon.'), findsOneWidget);
    expect(_button(t, 'pay-cash').onPressed, isNull);
    expect(_button(t, 'pay-card').onPressed, isNull);
    expect(_text('kommt mit Schritt 3'), findsOneWidget);
    await t.tap(find.byKey(const Key('cat-snacks')));
    await t.pump();
    await t.tap(find.byKey(const Key('item-pommes')));
    await t.pump();
    expect(_button(t, 'pay-cash').onPressed, isNotNull);
    expect(_button(t, 'pay-card').onPressed, isNull);
    expect(t.getSize(find.byKey(const Key('pay-cash'))).height, 80);
    expect(t.getSize(find.byKey(const Key('pay-card'))).height, 80);
  });

  testWidgets('Bar ruft onPayCash, aber nur mit Artikeln auf dem Bon', (t) async {
    var paid = 0;
    await pumpApp(
      t,
      KassaScreen(onPayCash: () => paid++),
      overrides: await memoryOverrides(),
    );
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('pay-cash')));
    await t.pump();
    expect(paid, 0);
    await t.tap(find.byKey(const Key('cat-snacks')));
    await t.pump();
    await t.tap(find.byKey(const Key('item-teigtaschen')));
    await t.pump();
    await t.tap(find.byKey(const Key('pay-cash')));
    await t.pump();
    expect(paid, 1);
  });

  testWidgets('Artikel, die nicht im Verkauf sind, lassen sich nicht antippen', (t) async {
    await pumpKassa(t);
    await containerOf(t)
        .read(catalogRepositoryProvider)
        .updateItem('cola', inSale: false);
    await t.pump();
    await t.pump();
    await t.tap(find.byKey(const Key('cat-getraenke')));
    await t.pump();
    expect(
      find.descendant(of: find.byKey(const Key('item-cola')), matching: _text('Nicht im Verkauf')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: find.byKey(const Key('item-cola')), matching: _text('2,90 €')),
      findsNothing,
    );
    await t.tap(find.byKey(const Key('item-cola')));
    await t.pump();
    expect(cartOf(t).isEmpty, isTrue);
    // Ein anderer Artikel derselben Kategorie geht weiter.
    await t.tap(find.byKey(const Key('item-eistee')));
    await t.pump();
    expect(cartOf(t).lines.single.item.id, 'eistee');
  });

  testWidgets('ohne Favoriten gibt es keine Kategorie "Favoriten", die erste ist gewählt', (t) async {
    await pumpKassa(t);
    expect(find.byKey(const Key('cat-favorites')), findsNothing);
    expect(_text('Favoriten'), findsNothing);
    expect(textOf(t, const Key('area-title')), 'Bowls');
    expect(find.byKey(const Key('item-huhn-bowl')), findsOneWidget);
    expect(find.byKey(const Key('item-cola')), findsNothing);
  });

  testWidgets('mit Favorit: "Favoriten" steht zuerst und ist gewählt, mit Anzahl', (t) async {
    await pumpKassa(t);
    await containerOf(t)
        .read(catalogRepositoryProvider)
        .updateItem('cola', favorite: true);
    await t.pump();
    await t.pump();
    expect(find.byKey(const Key('cat-favorites')), findsOneWidget);
    expect(
      t.getTopLeft(find.byKey(const Key('cat-favorites'))).dy,
      lessThan(t.getTopLeft(find.byKey(const Key('cat-bowls'))).dy),
    );
    expect(textOf(t, const Key('area-title')), 'Favoriten');
    expect(find.byKey(const Key('item-cola')), findsOneWidget);
    expect(find.byKey(const Key('item-huhn-bowl')), findsNothing);
    expect(
      find.descendant(of: find.byKey(const Key('cat-favorites')), matching: _text('1')),
      findsOneWidget,
    );
    // Die Anzahl der Kategorien steht in ihrer Taste.
    expect(
      find.descendant(of: find.byKey(const Key('cat-bowls')), matching: _text('4')),
      findsOneWidget,
    );
  });

  testWidgets('der offene Bon ist nach einem Neustart wieder da', (t) async {
    await pumpKassaWith(t, ['cola']);
    await t.pump();
    expect(await draftOf(t), isNotNull);
    await pumpKassa(t, sameDatabase: true);
    await t.pump();
    expect(_total(t), '3,15 €');
    expect(cartOf(t).lines.single.item.id, 'cola');
  });

  testWidgets('Abmelden und Anmelden lässt den Bon stehen', (t) async {
    await pumpKassaWith(t, ['cola', 'pommes']);
    await t.tap(find.byKey(const Key('staff')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('cart-total')), findsNothing);
    expect(containerOf(t).read(sessionProvider), isNull);
    await typePin(t, '4711');
    await t.pumpAndSettle();
    expect(_total(t), '7,05 €');
  });

  for (final (name, draft) in [
    ('kaputtes JSON', '{kaputt'),
    ('Liste statt Objekt', '[1, 2]'),
    ('falsche Typen', '{"lines": [{"lineId": 1, "itemId": "cola", "quantity": "x"}]}'),
    ('lines ist keine Liste', '{"lines": 5}'),
    ('Menge 0', '{"lines": [{"lineId": "a", "itemId": "cola", "quantity": 0, "optionIds": []}]}'),
  ]) {
    testWidgets('unlesbarer Entwurf ($name): leerer Bon, kein Fehler, Entwurf gelöscht', (t) async {
      final overrides = await memoryOverrides();
      final c = ProviderContainer(overrides: overrides);
      await c.read(settingsRepositoryProvider).writeDraft(draft);
      c.dispose();
      await pumpKassa(t, overrides: overrides);
      await t.pump();
      await t.pump();
      expect(t.takeException(), isNull);
      expect(_total(t), '0,00 €');
      expect(_text('Noch nichts boniert'), findsOneWidget);
      expect(await draftOf(t), isNull);
      // Und die Kassa nimmt weiter Artikel an.
      await tapItem(t, 'pommes');
      expect(_total(t), '3,90 €');
    });
  }

  testWidgets('der Schalter "Mit Bildern" wechselt die Tasten und bleibt nach dem Neustart', (t) async {
    await pumpKassa(t);
    // Vorgabe: kompakt, 90 dp hohe Tasten, kein Platzhalter-Bild.
    expect(t.getSize(find.byKey(const Key('item-huhn-bowl'))).height, 90);
    expect(find.byIcon(LucideIcons.utensils), findsNothing);
    await t.tap(find.byKey(const Key('segment-Mit Bildern')));
    await t.pump();
    expect(t.getSize(find.byKey(const Key('item-huhn-bowl'))).height, 157);
    expect(find.byIcon(LucideIcons.utensils), findsWidgets);
    await t.pump();
    await t.pump();
    expect((await containerOf(t).read(settingsRepositoryProvider).current()).showImages, isTrue);

    await pumpKassa(t, sameDatabase: true);
    expect(t.getSize(find.byKey(const Key('item-huhn-bowl'))).height, 157);
    await t.tap(find.byKey(const Key('segment-Kompakt')));
    await t.pump();
    expect(t.getSize(find.byKey(const Key('item-huhn-bowl'))).height, 90);
  });

  testWidgets('Spalten: 4 bei 1280 x 800, weniger bei 960 x 600', (t) async {
    await pumpKassa(t);
    expect(_columns(t), 4);
    // Mit 692 dp Mitte und 16 dp Rand wird die Taste etwa 157 breit.
    expect(t.getSize(find.byKey(const Key('item-huhn-bowl'))).width, closeTo(157.5, 0.1));
    expect(t.getSize(find.byKey(const Key('cat-bowls'))).width, 184);
    await pumpKassa(t, size: const Size(960, 600));
    expect(_columns(t), lessThan(4));
    expect(_columns(t), greaterThanOrEqualTo(1));
    expect(t.takeException(), isNull);
    await pumpKassa(t, size: const Size(1600, 900));
    expect(_columns(t), greaterThan(4));
  });

  testWidgets('lange Namen und 99 Stück laufen nicht über', (t) async {
    await pumpKassa(t, size: const Size(960, 600), textScale: 1.3);
    final long = 'Ein sehr langer Artikelname für den Test ${'x' * 20} Ende';
    expect(long.length, greaterThanOrEqualTo(60));
    final changed = Catalog(
      businessName: catalog.businessName,
      categories: catalog.categories,
      templates: catalog.templates,
      items: [
        for (final i in catalog.items)
          i.id == 'pommes' || i.id == 'huhn-bowl' ? i.copyWith(name: long) : i,
      ],
    );
    await containerOf(t).read(catalogRepositoryProvider).importCatalog(changed);
    await t.pump();
    await t.pump();
    await t.tap(find.byKey(const Key('cat-snacks')));
    await t.pump();
    await t.tap(find.byKey(const Key('item-pommes')));
    await t.pump();
    final id = cartOf(t).lines.single.lineId;
    containerOf(t).read(cartProvider.notifier).setQuantity(id, 99);
    await t.pump();
    expect(textOf(t, Key('qty-$id')), '99');
    expect(t.takeException(), isNull);
    // Dasselbe mit Bildern, im Zusammenstellen und mit Pfand-Zeile.
    await t.tap(find.byKey(const Key('segment-Mit Bildern')));
    await t.pump();
    expect(t.takeException(), isNull);
    await t.tap(find.byKey(const Key('cat-getraenke')));
    await t.pump();
    await t.tap(find.byKey(const Key('item-cola')));
    await t.pump();
    expect(t.takeException(), isNull);
    await t.tap(find.byKey(const Key('cat-bowls')));
    await t.pump();
    await _openBowl(t);
    expect(t.takeException(), isNull);
  });

  Future<void> expectTapTargets(WidgetTester t) async {
    final small = <String>[];
    for (final e in find.byType(Pressable).evaluate()) {
      final box = e.renderObject! as RenderBox;
      final size = box.size;
      final shorter = size.width < size.height ? size.width : size.height;
      if (shorter < 47.99) small.add('${e.widget.key ?? e.widget} $size');
    }
    expect(small, isEmpty);
  }

  testWidgets('jede Tippfläche ist mindestens 48 dp (Raster, Bon, Zusammenstellen)', (t) async {
    await pumpKassaWith(t, ['cola', 'teigtaschen']);
    expect(find.byType(Pressable), findsWidgets);
    await expectTapTargets(t);
    await t.tap(find.byKey(const Key('segment-Mit Bildern')));
    await t.pump();
    await expectTapTargets(t);
    await t.tap(find.byKey(const Key('clear-cart')));
    await t.pump();
    await expectTapTargets(t);
    await t.tap(find.byKey(const Key('cat-bowls')));
    await t.pump();
    await _openBowl(t);
    await expectTapTargets(t);
    await t.tap(find.byKey(const Key('opt-bowl/1/0')));
    await t.pump();
    await expectTapTargets(t);
    await t.tap(find.byKey(const Key('cancel-build')));
    await t.pump(const Duration(seconds: 8));
  });

  testWidgets('kleiner Bildschirm mit großer Schrift: kein Überlauf', (t) async {
    await pumpKassaWith(t, ['cola', 'pommes'], size: const Size(960, 600), textScale: 1.3);
    await t.tap(find.byKey(const Key('cat-bowls')));
    await t.pump();
    await _addBowl(t);
    expect(t.takeException(), isNull);
    expect(_text('XXL, Reis'), findsOneWidget);
  });
}
