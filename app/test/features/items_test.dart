import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/core/money.dart';
import 'package:kassa/data/catalog_repository.dart';
import 'package:kassa/data/providers.dart';
import 'package:kassa/domain/catalog.dart';
import 'package:kassa/ui/app_toggle.dart';
import 'package:kassa/ui/pressable.dart';
import 'package:kassa/ui/primary_button.dart';
import 'package:material_ui/material_ui.dart';

import '../support/demo_fixtures.dart';
import '../support/items_pump.dart';
import '../support/kassa_pump.dart';
import '../support/pump.dart';

/// Speicher, dessen Änderungen von Artikeln immer scheitern.
class _FailingCatalog extends CatalogRepository {
  _FailingCatalog(super.db);

  @override
  Future<void> updateItem(
    String itemId, {
    int? priceCents,
    bool? inSale,
    bool? favorite,
    int? depositCents,
    Set<ItemTag>? tags,
  }) => Future.error(StateError('Platte voll'));
}

Future<void> _tapKeyAt(WidgetTester t, String key) async {
  await t.tap(find.byKey(Key(key)));
  await t.pumpAndSettle();
}

bool _toggleOn(WidgetTester t, String key) {
  final f = find.byKey(Key(key));
  return t
      .widget<AppToggle>(
        t.widget(f) is AppToggle
            ? f
            : find.descendant(of: f, matching: find.byType(AppToggle)),
      )
      .value;
}

PrimaryButton _button(WidgetTester t, String key) =>
    t.widget<PrimaryButton>(find.byKey(Key(key)));

void main() {
  testWidgets('"Im Verkauf" aus wirkt sofort in der Kassa', (t) async {
    await pumpItems(t, category: 'getraenke');
    await t.tap(find.byKey(const Key('insale-cola')));
    await t.pump();
    expect((await catalogNow(t)).item('cola').inSale, isFalse);
    // In der Kassa ist der Artikel ausgeschaltet und lässt sich nicht tippen.
    await _tapKeyAt(t, 'tab-Kassa');
    await t.tap(find.byKey(const Key('cat-getraenke')));
    await t.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('item-cola')),
        matching: find.text('Nicht im Verkauf'),
      ),
      findsOneWidget,
    );
    await t.tap(find.byKey(const Key('item-cola')));
    await t.pump();
    expect(cartOf(t).lines, isEmpty);
    await t.tap(find.byKey(const Key('item-limonade')));
    await t.pump();
    expect(cartOf(t).lines, hasLength(1));
  });

  testWidgets('Preis über das Zahlenfeld ändern', (t) async {
    await pumpItems(t, category: 'getraenke');
    await _tapKeyAt(t, 'row-cola');
    await _tapKeyAt(t, 'edit-price');
    await tapKeys(t, '3 , 2');
    await t.tap(find.byKey(const Key('save-price')));
    await t.pump();
    expect((await catalogNow(t)).item('cola').priceCents, 320);
    await t.pumpAndSettle();
    expect(find.text('3,20 €'), findsWidgets);
    // Zurück im Normalzustand.
    expect(find.byKey(const Key('edit-price')), findsOneWidget);
    expect(find.byKey(const Key('save-price')), findsNothing);
  });

  testWidgets('leerer Preis lässt sich nicht speichern', (t) async {
    await pumpItems(t, category: 'getraenke');
    await t.tap(find.byKey(const Key('edit-price')));
    await t.pumpAndSettle();
    expect(textOf(t, const Key('price-field')), '0 €');
    expect(_button(t, 'save-price').onPressed, isNull);
    await t.tap(find.byKey(const Key('save-price')));
    await t.pump();
    expect(find.byKey(const Key('save-price')), findsOneWidget);
    expect((await catalogNow(t)).item('cola').priceCents, 290);
    // Ein Betrag macht die Taste frei, "Löschen" sperrt sie wieder.
    await tapKeys(t, '5');
    expect(_button(t, 'save-price').onPressed, isNotNull);
    await tapKeys(t, 'back');
    expect(_button(t, 'save-price').onPressed, isNull);
  });

  testWidgets('Preis 0 lässt sich nicht speichern', (t) async {
    await pumpItems(t, category: 'getraenke');
    await _tapKeyAt(t, 'edit-price');
    await tapKeys(t, '0 , 0');
    expect(_button(t, 'save-price').onPressed, isNull);
    await t.tap(find.byKey(const Key('save-price')));
    await t.pump();
    expect((await catalogNow(t)).item('cola').priceCents, 290);
  });

  testWidgets('Pfand-Schalter setzt 25 Cent oder 0', (t) async {
    await pumpItems(t);
    await openItem(t, 'teigtaschen');
    expect(find.text('Pfand 0,25 €'), findsOneWidget);
    expect(_toggleOn(t, 'toggle-deposit'), isFalse);
    await t.tap(find.byKey(const Key('toggle-deposit')));
    await t.pump();
    expect((await catalogNow(t)).item('teigtaschen').depositCents, 25);
    await t.pumpAndSettle();
    expect(_toggleOn(t, 'toggle-deposit'), isTrue);
    await t.tap(find.byKey(const Key('toggle-deposit')));
    await t.pump();
    expect((await catalogNow(t)).item('teigtaschen').depositCents, 0);
  });

  testWidgets('ein anderes Pfand zeigt seinen Betrag, Schalter an', (t) async {
    await pumpItems(t);
    await containerOf(t)
        .read(catalogRepositoryProvider)
        .updateItem('pommes', depositCents: 15);
    await openItem(t, 'pommes');
    expect(find.text('Pfand 0,15 €'), findsOneWidget);
    expect(find.text('Pfand 0,25 €'), findsNothing);
    expect(_toggleOn(t, 'toggle-deposit'), isTrue);
    await t.tap(find.byKey(const Key('toggle-deposit')));
    await t.pump();
    expect((await catalogNow(t)).item('pommes').depositCents, 0);
  });

  testWidgets(
    'Vegan und Scharf lassen sich einzeln schalten, Favorit über den Stern',
    (t) async {
      await pumpItems(t);
      await openItem(t, 'pommes');
      expect((await catalogNow(t)).item('pommes').tags, isEmpty);
      await t.tap(find.byKey(const Key('toggle-vegan')));
      await t.pumpAndSettle();
      expect((await catalogNow(t)).item('pommes').tags, {ItemTag.vegan});
      expect(find.text('VEGAN'), findsWidgets);
      await t.tap(find.byKey(const Key('toggle-spicy')));
      await t.pumpAndSettle();
      expect((await catalogNow(t)).item('pommes').tags, {
        ItemTag.vegan,
        ItemTag.spicy,
      });
      await t.tap(find.byKey(const Key('toggle-vegan')));
      await t.pumpAndSettle();
      expect((await catalogNow(t)).item('pommes').tags, {ItemTag.spicy});
      expect(_toggleOn(t, 'toggle-vegan'), isFalse);
      expect(_toggleOn(t, 'toggle-spicy'), isTrue);

      expect((await catalogNow(t)).item('pommes').favorite, isFalse);
      await t.tap(find.byKey(const Key('fav-pommes')));
      await t.pumpAndSettle();
      expect((await catalogNow(t)).item('pommes').favorite, isTrue);
      expect(
        find.bySemanticsLabel('Pommes aus den Favoriten nehmen'),
        findsOneWidget,
      );
      await t.tap(find.byKey(const Key('fav-pommes')));
      await t.pumpAndSettle();
      expect((await catalogNow(t)).item('pommes').favorite, isFalse);
      expect(find.bySemanticsLabel('Pommes zu den Favoriten'), findsOneWidget);
    },
  );

  testWidgets('zweite Zeile: nicht im Verkauf, Vorlage, Pfand, Zusatz', (
    t,
  ) async {
    await pumpItems(t);
    String? second(String id) {
      final item = catalog.item(id);
      final texts = find
          .descendant(
            of: find.byKey(Key('row-$id')),
            matching: find.byType(Text),
          )
          .evaluate()
          .map((e) => (e.widget as Text).data!)
          .where(
            (s) =>
                s != item.name &&
                s != 'VEGAN' &&
                s != 'SCHARF' &&
                s != formatEuro(item.priceCents),
          )
          .toList();
      return texts.isEmpty ? null : texts.single;
    }

    // Bowls haben eine Vorlage.
    expect(second('huhn-bowl'), 'bowl');
    await selectCategory(t, 'snacks');
    expect(second('teigtaschen'), '5 Stück');
    expect(second('pommes'), isNull);
    await selectCategory(t, 'getraenke');
    expect(second('cola'), 'plus 0,25 € Pfand');
    expect(second('leitungswasser'), isNull);
    await t.tap(find.byKey(const Key('insale-cola')));
    await t.pumpAndSettle();
    expect(second('cola'), 'Nicht im Verkauf');
    // Auch mit Vorlage zeigt ein Artikel außer Verkauf nur das.
    await selectCategory(t, 'bowls');
    await t.tap(find.byKey(const Key('insale-huhn-bowl')));
    await t.pumpAndSettle();
    expect(second('huhn-bowl'), 'Nicht im Verkauf');
  });

  testWidgets('Detail zeigt Steuersatz, Vorlage mit Gruppen und den Hinweis', (
    t,
  ) async {
    await pumpItems(t);
    expect(find.text('Huhn Bowl'), findsWidgets);
    expect(find.text('10 %'), findsOneWidget);
    expect(find.text('Auswahl beim Bonieren'), findsOneWidget);
    expect(
      find.text('Größe, Basis, Extra-Topping, Extra-Sauce.'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Namen, Fotos und neue Artikel kommen aus der Speisekarten-Datei.',
      ),
      findsOneWidget,
    );
    expect(find.text('Bowls, 4 Artikel'), findsOneWidget);
    await openItem(t, 'cola');
    expect(find.text('20 %'), findsOneWidget);
    expect(find.text('Auswahl beim Bonieren'), findsNothing);
  });

  testWidgets('zu Beginn ist der erste Artikel der Kategorie gewählt', (
    t,
  ) async {
    await pumpItems(t);
    expect(find.text('Neuer Preis, bisher 9,90 €'), findsNothing);
    expect(find.byKey(const Key('edit-price')), findsOneWidget);
    expect(textOf(t, const Key('detail-price')), '9,90 €');
    await selectCategory(t, 'getraenke');
    expect(textOf(t, const Key('detail-price')), '2,90 €');
  });

  testWidgets('"Abbrechen" behält den alten Preis', (t) async {
    await pumpItems(t, category: 'getraenke');
    await _tapKeyAt(t, 'edit-price');
    await tapKeys(t, '4 , 5');
    await _tapKeyAt(t, 'cancel-price');
    expect(find.byKey(const Key('save-price')), findsNothing);
    expect(textOf(t, const Key('detail-price')), '2,90 €');
    expect((await catalogNow(t)).item('cola').priceCents, 290);
    // Eine neue Eingabe beginnt leer.
    await t.tap(find.byKey(const Key('edit-price')));
    await t.pumpAndSettle();
    expect(textOf(t, const Key('price-field')), '0 €');
  });

  testWidgets('anderer Artikel oder andere Kategorie schließt die Eingabe', (
    t,
  ) async {
    await pumpItems(t, category: 'getraenke');
    await _tapKeyAt(t, 'edit-price');
    await tapKeys(t, '4');
    await _tapKeyAt(t, 'row-limonade');
    expect(find.byKey(const Key('save-price')), findsNothing);
    expect(find.byKey(const Key('edit-price')), findsOneWidget);
    await t.tap(find.byKey(const Key('edit-price')));
    await t.pumpAndSettle();
    expect(textOf(t, const Key('price-field')), '0 €');
    await selectCategory(t, 'snacks');
    expect(find.byKey(const Key('save-price')), findsNothing);
    expect(textOf(t, const Key('detail-price')), '6,50 €');
  });

  testWidgets('Schreibfehler zeigt den Hinweis und behält den Wert', (t) async {
    await pumpItems(
      t,
      category: 'getraenke',
      overrides: [
        ...await memoryOverrides(),
        catalogRepositoryProvider.overrideWith(
          (ref) => _FailingCatalog(ref.watch(databaseProvider)),
        ),
      ],
    );
    const hint = 'Das hat nicht geklappt. Bitte nochmal versuchen.';
    expect(find.text(hint), findsNothing);
    await t.tap(find.byKey(const Key('insale-cola')));
    await t.pumpAndSettle();
    expect(find.text(hint), findsOneWidget);
    expect(_toggleOn(t, 'insale-cola'), isTrue);
    await _tapKeyAt(t, 'edit-price');
    await tapKeys(t, '3');
    await t.tap(find.byKey(const Key('save-price')));
    await t.pumpAndSettle();
    expect(find.text(hint), findsOneWidget);
    // Die Eingabe bleibt offen, der Preis unverändert.
    expect(find.byKey(const Key('save-price')), findsOneWidget);
    expect((await catalogNow(t)).item('cola').priceCents, 290);
  });

  testWidgets('kleines Tablet mit Textskala 1,3 läuft nicht über', (t) async {
    await pumpItems(
      t,
      size: const Size(960, 600),
      textScale: 1.3,
      category: 'bowls',
    );
    expect(t.takeException(), isNull);
    await t.drag(
      find.byKey(const Key('item-detail-scroll')),
      const Offset(0, -2000),
    );
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    await t.tap(find.byKey(const Key('edit-price')), warnIfMissed: false);
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });

  testWidgets('Preiseingabe auf dem kleinen Tablet läuft nicht über', (
    t,
  ) async {
    await pumpItems(
      t,
      size: const Size(960, 600),
      textScale: 1.3,
      category: 'bowls',
    );
    await _tapKeyAt(t, 'edit-price');
    await tapKeys(t, '1 2 , 5 0');
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.byKey(const Key('save-price')), findsOneWidget);
  });

  testWidgets(
    'jede Tippfläche ist mindestens 48 dp in der kleineren Richtung',
    (t) async {
      await pumpItems(t, category: 'bowls');
      Future<void> check() async {
        final taps = find.descendant(
          of: find.byKey(const Key('area-items')),
          matching: find.byType(Pressable),
        );
        expect(taps, findsWidgets);
        for (final e in taps.evaluate()) {
          final size = t.getSize(find.byElementPredicate((x) => x == e));
          expect(
            size.shortestSide,
            greaterThanOrEqualTo(48),
            reason: '${e.widget.key}',
          );
        }
      }

      await check();
      await t.tap(find.byKey(const Key('edit-price')));
      await t.pumpAndSettle();
      await check();
    },
  );
}
