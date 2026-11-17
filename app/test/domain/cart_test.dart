import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/domain/cart.dart';
import 'package:kassa/domain/catalog.dart';

import '../support/demo_fixtures.dart';

void main() {
  test('gleiche Artikel ohne Auswahl werden eine Zeile', () {
    final cart = const Cart.empty().add(cola).add(cola).add(teigtaschen);
    expect(cart.lines.map((l) => (l.item.id, l.quantity)), [('cola', 2), ('teigtaschen', 1)]);
    expect((cart.goodsCents, cart.depositCents, cart.totalCents), (1230, 50, 1280));
  });

  test('Artikel mit Auswahl bleiben eigene Zeilen, Aufpreise zählen', () {
    var sel = Selection.defaults(bowlTemplate);
    expect(sel.isComplete, isFalse);
    expect(sel.missing.map((g) => g.name), ['Basis']);
    sel = sel.toggle(basis, reis).toggle(basis, nudeln);
    expect(sel.chosen.map((o) => o.name), ['Normal', 'Nudeln']);
    sel = sel.toggle(groesse, xxl).toggle(sauce, teriyaki);
    expect(sel.surchargeCents, 250);
    final cart = const Cart.empty().add(huhnBowl, options: sel.chosen).add(huhnBowl, options: sel.chosen);
    expect(cart.lines, hasLength(2));
    expect(cart.lines.first.unitPriceCents, 1240);
  });

  test('höchstens 4 Toppings: das fünfte wird nicht angenommen', () {
    var sel = Selection.defaults(bowlTemplate);
    for (final o in topping.options) {
      sel = sel.toggle(topping, o);
    }
    expect(sel.chosen.where((o) => topping.options.contains(o)), hasLength(4));
  });

  test('Tippen auf die gewählte Option einer Pflichtgruppe lässt sie gewählt', () {
    final sel = Selection.defaults(bowlTemplate).toggle(groesse, normal);
    expect(sel.isChosen(normal), isTrue);
  });

  test('Tippen entfernt eine gewählte Option in Gruppen mit mehreren', () {
    final sel = Selection.defaults(bowlTemplate).toggle(sauce, teriyaki).toggle(sauce, teriyaki);
    expect(sel.isChosen(teriyaki), isFalse);
  });

  test('Menge', () {
    var cart = const Cart.empty().add(cola, lineId: 'a');
    cart = cart.setQuantity('a', 99).setQuantity('a', 100);
    expect(cart.lines.single.quantity, 99);
    expect(cart.setQuantity('a', 0).isEmpty, isTrue);
  });

  test('Menge wird beim Zusammenführen auf 99 begrenzt', () {
    var cart = const Cart.empty().add(cola, lineId: 'a').setQuantity('a', 99);
    cart = cart.add(cola);
    expect(cart.lines.single.quantity, 99);
  });

  test('remove entfernt die Zeile, der alte Bon bleibt unverändert', () {
    final cart = const Cart.empty().add(cola, lineId: 'a');
    expect(cart.remove('a').isEmpty, isTrue);
    expect(cart.lines, hasLength(1));
  });

  test('Summe 0 ist erlaubt', () => expect(const Cart.empty().add(leitungswasser).totalCents, 0));

  test('Bon übersteht Speichern und Laden', () {
    final cart = const Cart.empty().add(cola).add(huhnBowl, options: [normal, reis]);
    expect(Cart.fromJson(cart.toJson(), catalog).totalCents, cart.totalCents);
  });

  test('Zeile mit unbekanntem Artikel oder unbekannter Option fällt beim Laden weg', () {
    final cart = const Cart.empty().add(cola).add(huhnBowl, options: [normal, reis]);
    final json = cart.toJson();
    final lines = (json['lines'] as List).cast<Map<String, dynamic>>();
    final broken = {
      'lines': [
        lines[0],
        {...lines[1], 'optionIds': ['gibt-es-nicht']},
        {...lines[0], 'lineId': 'x', 'itemId': 'weg'},
      ],
    };
    expect(Cart.fromJson(broken, catalog).lines.map((l) => l.item.id), ['cola']);
  });

  test('Pfand einer Option kommt zum Pfand des Artikels dazu', () {
    const bottle = ModifierOption(id: 'm/0/0', name: 'Flasche', depositCents: 100);
    final cart = const Cart.empty().add(cola, options: [bottle]);
    expect(cart.depositCents, 25 + 100);
  });

  group('Bon aus einem gespeicherten Entwurf lesen', () {
    Map<String, dynamic> line(Object? quantity, {Object? lineId = 'a', Object? itemId = 'cola', Object? optionIds}) => {
          'lineId': lineId,
          'itemId': itemId,
          'quantity': quantity,
          'optionIds': ?optionIds,
        };

    test('Zeilen mit Menge unter 1 fallen weg', () {
      final cart = Cart.fromJson({
        'lines': [line(0, lineId: 'a'), line(-3, lineId: 'b'), line(2, lineId: 'c')],
      }, catalog);
      expect(cart.lines.map((l) => (l.lineId, l.quantity)), [('c', 2)]);
    });

    test('Zeilen mit falschen Typen fallen weg, der Rest bleibt', () {
      final cart = Cart.fromJson({
        'lines': [
          line('2', lineId: 'a'),
          line(1, lineId: 'b', itemId: 7),
          line(1, lineId: 3),
          line(1, lineId: 'd', optionIds: 'Reis'),
          line(1, lineId: 'e', optionIds: [4]),
          'keine Zeile',
          null,
          line(1, lineId: 'ok'),
        ],
      }, catalog);
      expect(cart.lines.map((l) => l.lineId), ['ok']);
    });

    test('lines ist keine Liste: leerer Bon', () {
      expect(Cart.fromJson({'lines': 'x'}, catalog).isEmpty, isTrue);
      expect(Cart.fromJson({'lines': 5}, catalog).isEmpty, isTrue);
      expect(Cart.fromJson(const {}, catalog).isEmpty, isTrue);
    });

    test('doppelte Zeilen-Kennung: nur die erste bleibt', () {
      final cart = Cart.fromJson({
        'lines': [line(1, lineId: 'a'), line(2, lineId: 'a')],
      }, catalog);
      expect(cart.lines.single.quantity, 1);
    });

    test('zu große Menge wird auf 99 begrenzt', () {
      expect(Cart.fromJson({'lines': [line(500)]}, catalog).lines.single.quantity, 99);
    });
  });
}
