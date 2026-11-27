import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/domain/cart.dart';
import 'package:kassa/domain/catalog.dart';
import 'package:kassa/domain/discount.dart';

import '../support/demo_fixtures.dart';
import '../support/sales.dart' as sales;

void main() {
  test('gleiche Artikel ohne Auswahl werden eine Zeile', () {
    final cart = const Cart.empty().add(cola).add(cola).add(teigtaschen);
    expect(cart.lines.map((l) => (l.item.id, l.quantity)), [
      ('cola', 2),
      ('teigtaschen', 1),
    ]);
    expect(
      (cart.goodsCents, cart.depositCents, cart.totalCents),
      (1230, 50, 1280),
    );
  });

  test('Artikel mit Auswahl bleiben eigene Zeilen, Aufpreise zählen', () {
    var sel = Selection.defaults(bowlTemplate);
    expect(sel.isComplete, isFalse);
    expect(sel.missing.map((g) => g.name), ['Basis']);
    sel = sel.toggle(basis, reis).toggle(basis, nudeln);
    expect(sel.chosen.map((o) => o.name), ['Normal', 'Nudeln']);
    sel = sel.toggle(groesse, xxl).toggle(sauce, teriyaki);
    expect(sel.surchargeCents, 250);
    final cart = const Cart.empty()
        .add(huhnBowl, options: sel.chosen)
        .add(huhnBowl, options: sel.chosen);
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

  test(
    'Tippen auf die gewählte Option einer Pflichtgruppe lässt sie gewählt',
    () {
      final sel = Selection.defaults(bowlTemplate).toggle(groesse, normal);
      expect(sel.isChosen(normal), isTrue);
    },
  );

  test('Tippen entfernt eine gewählte Option in Gruppen mit mehreren', () {
    final sel = Selection.defaults(bowlTemplate)
        .toggle(sauce, teriyaki)
        .toggle(sauce, teriyaki);
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

  test(
    'Summe 0 ist erlaubt',
    () => expect(const Cart.empty().add(leitungswasser).totalCents, 0),
  );

  group('rebind (Bon folgt dem Katalog)', () {
    Catalog withItems(List<Item> items) => Catalog(
      business: catalog.business,
      categories: catalog.categories,
      items: items,
      templates: catalog.templates,
    );

    test(
      'nimmt Preis aus dem neuen Katalog, behält Zeilenkennung und Menge',
      () {
        final cart = const Cart.empty().add(cola, lineId: 'a').add(cola);
        final next = withItems([
          for (final i in catalog.items)
            i.id == 'cola' ? i.copyWith(priceCents: 320) : i,
        ]);
        final rebuilt = cart.rebind(next);
        expect(rebuilt.lines.single.lineId, 'a');
        expect(rebuilt.lines.single.quantity, 2);
        expect(rebuilt.lines.single.unitPriceCents, 320);
        expect(cart.lines.single.unitPriceCents, cola.priceCents);
      },
    );

    test('Zeilen, die es nicht mehr gibt, fallen weg', () {
      final cart = const Cart.empty()
          .add(cola, lineId: 'a')
          .add(teigtaschen, lineId: 'b');
      final next = withItems([
        for (final i in catalog.items)
          if (i.id != 'cola') i,
      ]);
      expect(cart.rebind(next).lines.map((l) => l.lineId), ['b']);
    });

    test('Optionen werden aus dem neuen Katalog genommen, unbekannte lassen die Zeile fallen', () {
      final cart = const Cart.empty().add(
        huhnBowl,
        options: [normal, reis],
        lineId: 'x',
      );
      expect(cart.rebind(catalog).lines.single.options.map((o) => o.id), [
        normal.id,
        reis.id,
      ]);
      final noTemplates = Catalog(
        business: catalog.business,
        categories: catalog.categories,
        items: catalog.items,
        templates: const [],
      );
      expect(cart.rebind(noTemplates).isEmpty, isTrue);
    });
  });

  test('Bon übersteht Speichern und Laden', () {
    final cart = const Cart.empty()
        .add(cola)
        .add(huhnBowl, options: [normal, reis]);
    expect(Cart.fromJson(cart.toJson(), catalog).totalCents, cart.totalCents);
  });

  test('Zeile mit unbekanntem Artikel oder unbekannter Option fällt beim Laden weg', () {
    final cart = const Cart.empty()
        .add(cola)
        .add(huhnBowl, options: [normal, reis]);
    final json = cart.toJson();
    final lines = (json['lines'] as List).cast<Map<String, dynamic>>();
    final broken = {
      'lines': [
        lines[0],
        {
          ...lines[1],
          'optionIds': ['gibt-es-nicht'],
        },
        {...lines[0], 'lineId': 'x', 'itemId': 'weg'},
      ],
    };
    expect(Cart.fromJson(broken, catalog).lines.map((l) => l.item.id), [
      'cola',
    ]);
  });

  test('Pfand einer Option kommt zum Pfand des Artikels dazu', () {
    const bottle = ModifierOption(
      id: 'm/0/0',
      name: 'Flasche',
      depositCents: 100,
    );
    final cart = const Cart.empty().add(cola, options: [bottle]);
    expect(cart.depositCents, 25 + 100);
  });

  group('Bon aus einem gespeicherten Entwurf lesen', () {
    Map<String, dynamic> line(
      Object? quantity, {
      Object? lineId = 'a',
      Object? itemId = 'cola',
      Object? optionIds,
    }) => {
      'lineId': lineId,
      'itemId': itemId,
      'quantity': quantity,
      'optionIds': ?optionIds,
    };

    test('Zeilen mit Menge unter 1 fallen weg', () {
      final cart = Cart.fromJson({
        'lines': [
          line(0, lineId: 'a'),
          line(-3, lineId: 'b'),
          line(2, lineId: 'c'),
        ],
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
      expect(
        Cart.fromJson({
          'lines': [line(500)],
        }, catalog).lines.single.quantity,
        99,
      );
    });
  });

  group('Rabatt im offenen Bon', () {
    final cart = sales.cart;

    test('der Bon ändert sich: Prozent rechnet mit, Betrag wird gekappt, leerer Bon hat keinen Bon-Rabatt', () {
      final cola = cart.lines[0].lineId, bowl = cart.lines[1].lineId;
      var c = cart.setLineDiscount(
        cola,
        const Discount.percent(10, DiscountReason.regular),
      );
      expect(c.setQuantity(cola, 4).pricing.lines[0].ownDiscountCents, 116);
      c = cart.setLineDiscount(
        cola,
        const Discount.amount(500, DiscountReason.staff),
      );
      expect(c.setQuantity(cola, 1).pricing.lines[0].ownDiscountCents, 290);
      c = cart.setReceiptDiscount(
        const Discount.amount(5000, DiscountReason.staff),
      );
      expect(c.pricing.receiptDiscountCents, 1770);
      expect(c.remove(cola).remove(bowl).discount, isNull);
    });

    test('add, setQuantity und remove behalten die Rabatte', () {
      final colaId = cart.lines[0].lineId, bowl = cart.lines[1].lineId;
      final c = cart
          .setLineDiscount(
            colaId,
            const Discount.percent(10, DiscountReason.regular),
          )
          .setReceiptDiscount(
            const Discount.percent(5, DiscountReason.promotion),
          );
      final after = c.add(cola).setQuantity(colaId, 5).remove(bowl);
      expect(after.lines.single.quantity, 5);
      expect(after.lines.single.discount?.percent, 10);
      expect(after.discount?.percent, 5);
      expect(c.setQuantity(colaId, 0).discount?.percent, 5);
      expect(c.setQuantity(colaId, 0).setQuantity(bowl, 0).discount, isNull);
    });

    test('Rabatt ab- und umsetzen, der alte Bon bleibt unverändert', () {
      final colaId = cart.lines[0].lineId;
      final c = cart.setLineDiscount(
        colaId,
        const Discount.percent(10, DiscountReason.regular),
      );
      expect(cart.lines[0].discount, isNull);
      expect(c.setLineDiscount(colaId, null).lines[0].discount, isNull);
      expect(
        c.setLineDiscount('gibt-es-nicht', null).lines[0].discount,
        isNotNull,
      );
      final r = c.setReceiptDiscount(
        const Discount.percent(10, DiscountReason.regular),
      );
      expect(r.setReceiptDiscount(null).discount, isNull);
      expect(c.discount, isNull);
      expect(
        const Cart.empty()
            .setReceiptDiscount(
              const Discount.percent(10, DiscountReason.regular),
            )
            .discount,
        isNull,
      );
    });

    test('Pfand wird nie rabattiert', () {
      final c = cart
          .setLineDiscount(
            cart.lines[0].lineId,
            const Discount.percent(100, DiscountReason.invitation),
          )
          .setReceiptDiscount(
            const Discount.amount(99999, DiscountReason.staff),
          );
      expect((c.goodsCents, c.depositCents, c.totalCents), (0, 50, 50));
      expect(c.pricing.lines.map((l) => l.depositCents), [50, 0]);
    });

    test('Entwurf: Rabatte überstehen toJson, fromJson und rebind; ein Entwurf aus 1.10.0 bleibt lesbar', () {
      final colaId = cart.lines[0].lineId;
      final c = cart
          .setLineDiscount(
            colaId,
            const Discount.percent(10, DiscountReason.regular),
          )
          .setReceiptDiscount(const Discount.amount(200, DiscountReason.staff));
      final json = c.toJson();
      expect((json['lines'] as List)[0]['discount'], {
        'percent': 10,
        'reason': 'regular',
      });
      expect((json['lines'] as List)[1], isNot(contains('discount')));
      expect(json['discount'], {'amountCents': 200, 'reason': 'staff'});
      for (final back in [Cart.fromJson(json, catalog), c.rebind(catalog)]) {
        expect(back.lines[0].discount?.toJson(), {
          'percent': 10,
          'reason': 'regular',
        });
        expect(back.lines[1].discount, isNull);
        expect(back.discount?.toJson(), {
          'amountCents': 200,
          'reason': 'staff',
        });
        expect(back.totalCents, c.totalCents);
      }
      expect(cart.toJson(), isNot(contains('discount')));

      // Ein Entwurf aus 1.10.0 kennt keine Rabatte.
      final old = {
        'lines': [
          {
            'lineId': 'a',
            'itemId': 'cola',
            'quantity': 2,
            'optionIds': <String>[],
          },
        ],
      };
      final read = Cart.fromJson(old, catalog);
      expect(read.lines.single.quantity, 2);
      expect(read.lines.single.discount, isNull);
      expect(read.discount, isNull);
      expect(read.totalCents, 630);
    });

    group('Entwurf mit kaputtem Rabatt: die Zeile bleibt, ohne Rabatt', () {
      for (final (name, broken) in <(String, Object?)>[
        ('falscher Typ', 'zehn Prozent'),
        ('Prozent als Text', {'percent': '10', 'reason': 'regular'}),
        ('unbekannter Grund', {'percent': 10, 'reason': 'geburtstag'}),
        ('Prozent 0', {'percent': 0, 'reason': 'regular'}),
        ('Prozent 150', {'percent': 150, 'reason': 'regular'}),
        ('negativer Betrag', {'amountCents': -200, 'reason': 'staff'}),
      ]) {
        test(name, () {
          final read = Cart.fromJson({
            'lines': [
              {
                'lineId': 'a',
                'itemId': 'cola',
                'quantity': 2,
                'optionIds': <String>[],
                'discount': broken,
              },
            ],
            'discount': broken,
          }, catalog);
          expect(read.lines.single.lineId, 'a');
          expect(read.lines.single.quantity, 2);
          expect(read.lines.single.discount, isNull);
          expect(read.discount, isNull);
          expect(read.totalCents, 630);
        });
      }
    });

    test('Bon-Rabatt in einem Entwurf, dessen Zeilen alle wegfallen: leerer Bon ohne Rabatt', () {
      final read = Cart.fromJson({
        'lines': [
          {'lineId': 'a', 'itemId': 'weg', 'quantity': 1},
        ],
        'discount': {'percent': 10, 'reason': 'regular'},
      }, catalog);
      expect(read.isEmpty, isTrue);
      expect(read.discount, isNull);
    });
  });

  group('freier Betrag', () {
    test('freier Betrag: eigene Zeile je Tipp, Steuersatz zählt, Entwurf bleibt lesbar', () {
      final c = const Cart.empty()
          .addOpenAmount(amountCents: 1250, rate: TaxRate.normal)
          .addOpenAmount(amountCents: 300, rate: TaxRate.normal);
      expect(
        [
          for (final l in c.lines)
            (l.item.id, l.item.name, l.quantity, l.goodsCents, l.isOpenAmount),
        ],
        [
          ('open-amount-20', 'Diverses 20 %', 1, 1250, true),
          ('open-amount-20', 'Diverses 20 %', 1, 300, true),
        ],
      );
      expect(c.pricing.grossByRate, {TaxRate.normal: 1550});
      final back = Cart.fromJson(c.toJson(), catalog);
      expect([for (final l in back.lines) l.goodsCents], [1250, 300]);
      expect(c.rebind(catalog).lines, hasLength(2));
    });

    test('Grenzen: 0, 10.000,00 € und der Satz 19 % werfen ArgumentError', () {
      for (final cents in [0, 1000000]) {
        expect(
          () => const Cart.empty().addOpenAmount(
            amountCents: cents,
            rate: TaxRate.normal,
          ),
          throwsArgumentError,
        );
      }
      expect(
        () => const Cart.empty().addOpenAmount(
          amountCents: 100,
          rate: TaxRate.special,
        ),
        throwsArgumentError,
      );
      expect(
        const Cart.empty()
            .addOpenAmount(amountCents: 999999, rate: TaxRate.zero)
            .totalCents,
        999999,
      );
    });

    test('Kennung, Name und Sätze', () {
      expect(openAmountRates, [
        TaxRate.normal,
        TaxRate.reduced1,
        TaxRate.reduced2,
        TaxRate.zero,
      ]);
      expect([for (final r in openAmountRates) openAmountItemId(r)], [
        'open-amount-20',
        'open-amount-10',
        'open-amount-13',
        'open-amount-0',
      ]);
      expect(openAmountName(TaxRate.reduced2), 'Diverses 13 %');
      expect(isOpenAmountItemId('open-amount-10'), isTrue);
      expect(isOpenAmountItemId('cola'), isFalse);
      final line = const Cart.empty()
          .addOpenAmount(amountCents: 450, rate: TaxRate.reduced1)
          .lines
          .single;
      expect(
        (
          line.item.priceCents,
          line.item.taxRate,
          line.unitDepositCents,
          line.options.length,
        ),
        (450, TaxRate.reduced1, 0, 0),
      );
      expect(
        const Cart.empty().add(cola).lines.single.isOpenAmount,
        isFalse,
      );
    });

    test('Menge und Rabatt gehen wie bei jeder Zeile; Minus bei Menge 1 nimmt sie weg', () {
      var c = const Cart.empty()
          .add(cola)
          .addOpenAmount(amountCents: 500, rate: TaxRate.reduced1, lineId: 'o');
      c = c.setQuantity('o', 3);
      expect(c.lines[1].goodsCents, 1500);
      expect(c.lines[1].isOpenAmount, isTrue);
      c = c.setLineDiscount(
        'o',
        const Discount.percent(10, DiscountReason.regular),
      );
      expect(c.lines[1].isOpenAmount, isTrue);
      expect(c.pricing.grossByRate[TaxRate.reduced1], 1350);
      final back = Cart.fromJson(c.toJson(), catalog);
      expect(back.lines[1].discount, c.lines[1].discount);
      expect(back.lines[1].quantity, 3);
      expect(back.totalCents, c.totalCents);
      c = c.setQuantity('o', 1).setQuantity('o', 0);
      expect(c.lines.map((l) => l.item.id), ['cola']);
    });

    test('ein Artikel des Katalogs verschmilzt nie mit einem freien Betrag', () {
      final c = const Cart.empty()
          .addOpenAmount(amountCents: 290, rate: TaxRate.normal)
          .add(cola)
          .add(cola);
      expect(c.lines.map((l) => (l.item.id, l.quantity)), [
        ('open-amount-20', 1),
        ('cola', 2),
      ]);
    });

    test('toJson schreibt "open" mit Betrag und Satz', () {
      final c = const Cart.empty().addOpenAmount(
        amountCents: 1250,
        rate: TaxRate.normal,
        lineId: 'o',
      );
      expect((c.toJson()['lines'] as List).single, {
        'lineId': 'o',
        'itemId': 'open-amount-20',
        'quantity': 1,
        'optionIds': <String>[],
        'open': {'cents': 1250, 'taxPercent': 20},
      });
      expect(
        (const Cart.empty().add(cola).toJson()['lines'] as List).single,
        isNot(contains('open')),
      );
    });

    test('rebind mit einem Katalog ohne die Kennung des freien Betrags: die Zeile bleibt', () {
      final c = const Cart.empty()
          .add(cola)
          .addOpenAmount(amountCents: 700, rate: TaxRate.zero);
      expect(
        catalog.items.where((i) => isOpenAmountItemId(i.id)),
        isEmpty,
      );
      final r = c.rebind(catalog);
      expect(r.lines.map((l) => (l.item.id, l.goodsCents)), [
        ('cola', 290),
        ('open-amount-0', 700),
      ]);
      expect(r.lines[1].item.taxRate, TaxRate.zero);
    });

    group('Entwurf mit kaputtem freien Betrag: nur diese Zeile fällt weg', () {
      for (final (name, open) in <(String, Object?)>[
        ('kein Objekt', 'zwölf Euro'),
        ('Betrag 0', {'cents': 0, 'taxPercent': 20}),
        ('Betrag über 9.999,99 €', {'cents': 1000000, 'taxPercent': 20}),
        ('negativer Betrag', {'cents': -5, 'taxPercent': 20}),
        ('Betrag als Text', {'cents': '1250', 'taxPercent': 20}),
        ('Betrag als Kommazahl', {'cents': 12.5, 'taxPercent': 20}),
        ('Betrag fehlt', {'taxPercent': 20}),
        ('Satz 19 %', {'cents': 1250, 'taxPercent': 19}),
        ('Satz 7 %', {'cents': 1250, 'taxPercent': 7}),
        ('Satz als Text', {'cents': 1250, 'taxPercent': '20'}),
        ('Satz fehlt', {'cents': 1250}),
        ('Kennung passt nicht zum Satz', {'cents': 1250, 'taxPercent': 10}),
      ]) {
        test(name, () {
          final read = Cart.fromJson({
            'lines': [
              {
                'lineId': 'a',
                'itemId': 'cola',
                'quantity': 2,
                'optionIds': <String>[],
              },
              {
                'lineId': 'o',
                'itemId': 'open-amount-20',
                'quantity': 1,
                'optionIds': <String>[],
                'open': open,
              },
              {
                'lineId': 'b',
                'itemId': 'teigtaschen',
                'quantity': 1,
                'optionIds': <String>[],
              },
            ],
            'discount': {'percent': 10, 'reason': 'regular'},
          }, catalog);
          expect(read.lines.map((l) => l.lineId), ['a', 'b']);
          expect(
            read.discount,
            const Discount.percent(10, DiscountReason.regular),
          );
        });
      }
    });

    test('Entwurf: ein gültiger freier Betrag mit falscher Menge oder Optionen fällt weg', () {
      Map<String, dynamic> open(Object? quantity, {Object? optionIds}) => {
        'lineId': 'o$quantity$optionIds',
        'itemId': 'open-amount-10',
        'quantity': quantity,
        'optionIds': optionIds ?? <String>[],
        'open': {'cents': 300, 'taxPercent': 10},
      };
      final read = Cart.fromJson({
        'lines': [
          open(0),
          open('1'),
          open(1, optionIds: ['reis']),
          open(2),
        ],
      }, catalog);
      expect(read.lines.map((l) => (l.quantity, l.goodsCents)), [(2, 600)]);
    });

    test('Entwurf aus 1.10.0 (ohne "open") bleibt lesbar', () {
      final read = Cart.fromJson({
        'lines': [
          {
            'lineId': 'a',
            'itemId': 'cola',
            'quantity': 2,
            'optionIds': <String>[],
          },
        ],
      }, catalog);
      expect(read.lines.single.isOpenAmount, isFalse);
      expect(read.totalCents, 630);
    });
  });

  group('Stufe 1b: Pfand zurück, Gutschein-Zeile, gewählte Gutscheine', () {
    final cart = sales.cart;
    final cartCard = sales.cartCard;
    const a = AppliedVoucher(
      voucherId: 'v-a',
      code: '11112222',
      balanceCents: 500,
    );
    const b = AppliedVoucher(
      voucherId: 'v-b',
      code: '33334444',
      balanceCents: 300,
    );

    /// Der Text, den 1.11.0 (Commit a06aeb3) mit `jsonEncode` für
    /// `sales.cart` schreibt. Die Zeilenkennungen sind zufällig und stehen
    /// hier als `<L0>`, `<L1>`.
    String draft1_11_0(List<String> lineIds) =>
        '{"lines":[{"lineId":"<L0>","itemId":"cola","quantity":2,'
                '"optionIds":[]},{"lineId":"<L1>","itemId":"huhn-bowl",'
                '"quantity":1,"optionIds":["bowl/0/1","bowl/1/1"]}]}'
            .replaceAll('<L0>', lineIds[0])
            .replaceAll('<L1>', lineIds[1]);

    test(
      'Pfand zurück: eine Zeile je Betrag, Summe sinkt, Menge 0 nimmt sie weg',
      () {
        final c = cart.setDepositReturn(depositCents: 25, quantity: 3);
        final line = c.lines.last;
        expect(
          (
            line.item.id,
            line.item.name,
            line.quantity,
            line.goodsCents,
            line.depositCents,
            line.isDepositReturn,
          ),
          ('deposit-return-25', 'Pfand zurück', 3, 0, -75, true),
        );
        expect((c.goodsCents, c.depositCents, c.totalCents), (1770, -25, 1745));
        expect(
          c.setDepositReturn(depositCents: 25, quantity: 5).lines,
          hasLength(3),
        );
        expect(c.depositReturnQuantity(25), 3);
        expect(
          c.setDepositReturn(depositCents: 25, quantity: 0).totalCents,
          1820,
        );
        expect(
          const Cart.empty()
              .setDepositReturn(depositCents: 25, quantity: 3)
              .totalCents,
          -75,
        );
        expect(
          () => c.setLineDiscount(
            line.lineId,
            const Discount.percent(10, DiscountReason.regular),
          ),
          throwsArgumentError,
        );
      },
    );

    test('Pfand zurück: Artikel, Grenzen, Menge wie bei jeder Zeile', () {
      expect(depositReturnItemId(25), 'deposit-return-25');
      expect(depositReturnName, 'Pfand zurück');
      expect(isDepositReturnItemId('deposit-return-100'), isTrue);
      expect(isDepositReturnItemId('cola'), isFalse);
      final c = const Cart.empty()
          .add(cola)
          .setDepositReturn(depositCents: 100, quantity: 2)
          .setDepositReturn(depositCents: 25, quantity: 1);
      final line = c.lines[1];
      expect(
        (
          line.item.priceCents,
          line.item.depositCents,
          line.item.taxRate,
          line.options.length,
          line.isVoucherSale,
          line.isOpenAmount,
        ),
        (0, -100, TaxRate.zero, 0, false, false),
      );
      expect(c.lines.map((l) => l.item.id), [
        'cola',
        'deposit-return-100',
        'deposit-return-25',
      ]);
      expect(c.depositReturnQuantity(50), 0);
      expect(cola.depositCents, 25);
      expect(c.depositCents, 25 - 200 - 25);
      // Ändern behält die Stelle der Zeile.
      final more = c.setDepositReturn(depositCents: 100, quantity: 7);
      expect(more.lines.map((l) => (l.item.id, l.quantity)), [
        ('cola', 1),
        ('deposit-return-100', 7),
        ('deposit-return-25', 1),
      ]);
      expect(more.lines[1].lineId, line.lineId);
      // setQuantity wie bei jeder Zeile.
      expect(c.setQuantity(line.lineId, 4).depositReturnQuantity(100), 4);
      expect(c.setQuantity(line.lineId, 0).depositReturnQuantity(100), 0);
      for (final (cents, quantity) in [(0, 1), (-25, 1), (25, -1), (25, 100)]) {
        expect(
          () => c.setDepositReturn(depositCents: cents, quantity: quantity),
          throwsArgumentError,
          reason: '$cents/$quantity',
        );
      }
      expect(
        c
            .setDepositReturn(depositCents: 25, quantity: 99)
            .depositReturnQuantity(25),
        99,
      );
      // Ohne Zeile nimmt Menge 0 nichts weg.
      expect(
        c.setDepositReturn(depositCents: 50, quantity: 0).lines,
        hasLength(3),
      );
      expect(
        const Cart.empty()
            .setDepositReturn(depositCents: 25, quantity: 0)
            .isEmpty,
        isTrue,
      );
    });

    test('Pfand zurück bekommt keinen Anteil am Bon-Rabatt', () {
      final c = cart
          .setDepositReturn(depositCents: 25, quantity: 2)
          .setReceiptDiscount(
            const Discount.percent(10, DiscountReason.promotion),
          );
      final p = c.pricing;
      expect(p.lines.last.discountCents, 0);
      expect(p.receiptDiscountCents, 177);
      expect(p.totalCents, 1770 - 177 + 50 - 50);
      expect(p.grossByRate.values.fold<int>(0, (s, v) => s + v), p.goodsCents);
    });

    test('Gutschein-Zeile: eigene Zeile je Tipp, Satz 0, kein Rabatt, kein Anteil am Bon-Rabatt', () {
      final c = cartCard
          .addVoucherSale(valueCents: 2500)
          .setReceiptDiscount(
            const Discount.percent(10, DiscountReason.promotion),
          );
      expect(
        (
          c.pricing.voucherSaleCents,
          c.pricing.receiptDiscountCents,
          c.goodsCents,
          c.totalCents,
        ),
        (2500, 94, 3346, 3371),
      );
      expect(c.pricing.lines.last.discountCents, 0);
      expect(c.pricing.grossByRate[TaxRate.zero], 2500);
      expect(() => c.setQuantity(c.lines.last.lineId, 2), throwsArgumentError);
      for (final cents in [99, 50001]) {
        expect(
          () => const Cart.empty().addVoucherSale(valueCents: cents),
          throwsArgumentError,
        );
      }
    });

    test('Gutschein-Zeile: Artikel, Grenzen, neue Zeile je Tipp, Minus nimmt sie weg', () {
      expect(voucherSaleItemId, 'voucher-sale');
      expect(voucherSaleName, 'Gutschein');
      expect((voucherMinCents, voucherMaxCents), (100, 50000));
      expect(voucherPresetCents, [1000, 2000, 2500, 5000]);
      expect(isVoucherSaleItemId('voucher-sale'), isTrue);
      expect(isVoucherSaleItemId('voucher-sale-2'), isFalse);
      final c = const Cart.empty()
          .addVoucherSale(valueCents: 100, lineId: 'g1')
          .addVoucherSale(valueCents: 50000);
      expect(c.hasVoucherSale, isTrue);
      expect(cartCard.hasVoucherSale, isFalse);
      expect(
        [
          for (final l in c.lines)
            (
              l.item.id,
              l.item.name,
              l.item.priceCents,
              l.item.taxRate,
              l.item.depositCents,
              l.quantity,
              l.isVoucherSale,
              l.isDepositReturn,
            ),
        ],
        [
          ('voucher-sale', 'Gutschein', 100, TaxRate.zero, 0, 1, true, false),
          ('voucher-sale', 'Gutschein', 50000, TaxRate.zero, 0, 1, true, false),
        ],
      );
      expect(c.lines.first.lineId, 'g1');
      expect(c.pricing.voucherSaleCents, 50100);
      expect(c.setQuantity('g1', 1).lines, hasLength(2));
      expect(c.setQuantity('g1', 0).lines, hasLength(1));
      expect(
        () => c.setLineDiscount(
          'g1',
          const Discount.amount(50, DiscountReason.regular),
        ),
        throwsArgumentError,
      );
      // Ohne Rabatt zu setzen geht (nimmt nichts weg, was es gäbe).
      expect(c.setLineDiscount('g1', null).lines.first.discount, isNull);
    });

    test('discountBaseCents: Zwischensumme ohne Gutschein-Zeilen', () {
      final p = cartCard.addVoucherSale(valueCents: 2500).pricing;
      // Teigtaschen 6,50 + Cola 2,90 = 9,40 € (das Pfand 0,25 € zählt nie).
      expect((p.discountBaseCents, p.subtotalCents), (940, 3440));
      expect(cartCard.pricing.discountBaseCents, cartCard.pricing.subtotalCents);
      expect(
        cart
            .setDepositReturn(depositCents: 25, quantity: 2)
            .pricing
            .discountBaseCents,
        cart.pricing.subtotalCents,
      );
    });

    test('setLineDiscount mit null auf Pfand zurück wirft nicht', () {
      final c = cart.setDepositReturn(depositCents: 25, quantity: 2);
      final r = c.setLineDiscount(c.lines.last.lineId, null);
      expect((r.lines.last.discount, r.totalCents), (null, c.totalCents));
    });

    test('Bon-Rabatt als Betrag: rechnet ohne Gutschein-Zeilen', () {
      final c = cartCard
          .addVoucherSale(valueCents: 2500)
          .setReceiptDiscount(
            const Discount.amount(5000, DiscountReason.promotion),
          );
      final p = c.pricing;
      expect(p.receiptDiscountCents, 940);
      expect((p.goodsCents, p.totalCents), (2500, 2525));
      expect(p.lines.last.discountCents, 0);
      expect(p.grossByRate, {TaxRate.zero: 2500});
    });

    test(
      'gewählte Gutscheine decken der Reihe nach; noch zu zahlen ist der Rest',
      () {
        final c = cartCard.applyVoucher(a).applyVoucher(b);
        expect(
          [
            for (final u in c.pricing.voucherUses)
              (u.voucherId, u.amountCents, u.balanceAfterCents),
          ],
          [('v-a', 500, 0), ('v-b', 300, 0)],
        );
        expect((c.pricing.voucherCents, c.pricing.dueCents), (800, 165));
        final big = cartCard
            .applyVoucher(
              const AppliedVoucher(
                voucherId: 'v-c',
                code: '55556666',
                balanceCents: 2500,
              ),
            )
            .applyVoucher(a);
        expect(
          [
            for (final u in big.pricing.voucherUses)
              (u.voucherId, u.amountCents, u.balanceAfterCents),
          ],
          [('v-c', 965, 1535)],
        );
        expect(big.pricing.dueCents, 0);
        expect(c.removeVoucher('v-a').pricing.dueCents, 665);
        expect(c.withVoucherBalance('v-a', 100).pricing.dueCents, 565);
        expect(() => c.applyVoucher(a), throwsStateError);
        expect(() => c.addVoucherSale(valueCents: 1000), throwsStateError);
        expect(
          () => cartCard.addVoucherSale(valueCents: 1000).applyVoucher(a),
          throwsStateError,
        );
      },
    );

    test('gewählte Gutscheine: Code, Reihenfolge, leerer Bon, Summe bis 0', () {
      final c = cartCard.applyVoucher(a).applyVoucher(b);
      expect([for (final v in c.vouchers) v.voucherId], ['v-a', 'v-b']);
      expect(c.pricing.voucherUses.first.code, '11112222');
      expect(cartCard.vouchers, isEmpty);
      expect(cartCard.pricing.voucherUses, isEmpty);
      expect(cartCard.pricing.dueCents, cartCard.totalCents);
      // Ohne den gewählten Gutschein ändern removeVoucher und
      // withVoucherBalance nichts.
      expect(c.removeVoucher('v-x').vouchers, hasLength(2));
      expect(c.withVoucherBalance('v-x', 0).pricing.dueCents, 165);
      // Ein Gutschein mit Guthaben 0 deckt nichts und fehlt in der Liste.
      expect(
        [
          for (final u in c.withVoucherBalance('v-a', 0).pricing.voucherUses)
            u.voucherId,
        ],
        ['v-b'],
      );
      // Ändert sich der Bon, rechnen die Gutscheine neu; sie bleiben.
      final more = c.add(cola);
      expect(more.vouchers, hasLength(2));
      expect(more.pricing.dueCents, 165 + 315);
      // Summe 0 oder darunter: nichts wird gedeckt.
      final low = const Cart.empty()
          .add(cola)
          .setDepositReturn(depositCents: 315, quantity: 1)
          .applyVoucher(a);
      expect(low.totalCents, 0);
      expect(low.pricing.voucherUses, isEmpty);
      expect(low.pricing.dueCents, 0);
      final minus = low.setDepositReturn(depositCents: 400, quantity: 1);
      expect(minus.pricing.voucherUses, isEmpty);
      expect(minus.pricing.dueCents, minus.totalCents);
      expect(
        () => const Cart.empty().applyVoucher(a),
        throwsStateError,
      );
      // Der letzten Zeile weg: keine gewählten Gutscheine mehr.
      final one = const Cart.empty().add(cola).applyVoucher(a);
      expect(one.remove(one.lines.single.lineId).vouchers, isEmpty);
      expect(one.setQuantity(one.lines.single.lineId, 0).vouchers, isEmpty);
      // Gutscheine bleiben bei Rabatten.
      expect(
        c
            .setReceiptDiscount(
              const Discount.percent(10, DiscountReason.promotion),
            )
            .vouchers,
        hasLength(2),
      );
    });

    test('Entwurf: Pfand zurück, Gutschein-Zeile und gewählte Gutscheine überstehen toJson und fromJson; ohne sie ist das JSON wie in 1.11.0', () {
      final c = cart
          .setDepositReturn(depositCents: 25, quantity: 2)
          .applyVoucher(a);
      final back = Cart.fromJson(c.toJson(), catalog);
      expect(
        (back.totalCents, back.pricing.dueCents, back.vouchers.single.code),
        (c.totalCents, c.pricing.dueCents, '11112222'),
      );
      expect(
        jsonEncode(cart.toJson()),
        draft1_11_0([for (final l in cart.lines) l.lineId]),
      );
      expect(
        Cart.fromJson({...c.toJson(), 'vouchers': 'kaputt'}, catalog).vouchers,
        isEmpty,
      );
    });

    test('Entwurf: die Felder im JSON', () {
      final c = const Cart.empty()
          .add(cola)
          .setDepositReturn(depositCents: 25, quantity: 2)
          .applyVoucher(a);
      final json = c.toJson();
      expect((json['lines'] as List)[1], {
        'lineId': c.lines[1].lineId,
        'itemId': 'deposit-return-25',
        'quantity': 2,
        'optionIds': <String>[],
        'depositReturn': {'cents': 25},
      });
      expect(json['vouchers'], [
        {'id': 'v-a', 'code': '11112222', 'balanceCents': 500},
      ]);
      final g = const Cart.empty().addVoucherSale(
        valueCents: 2500,
        lineId: 'g',
      );
      expect(g.toJson(), {
        'lines': [
          {
            'lineId': 'g',
            'itemId': 'voucher-sale',
            'quantity': 1,
            'optionIds': <String>[],
            'voucherSale': {'cents': 2500},
          },
        ],
      });
      final back = Cart.fromJson(g.toJson(), catalog).lines.single;
      expect(
        (back.isVoucherSale, back.item.priceCents, back.item.taxRate),
        (true, 2500, TaxRate.zero),
      );
      final dep = Cart.fromJson(json, catalog).lines[1];
      expect(
        (dep.isDepositReturn, dep.quantity, dep.depositCents),
        (true, 2, -50),
      );
      // rebind lässt alles stehen, auch ohne die Kennungen im Katalog.
      final r = c.rebind(catalog);
      expect(r.toJson(), json);
      expect(g.rebind(catalog).toJson(), g.toJson());
    });

    group('Entwurf mit kaputten neuen Feldern: nur diese Zeile fällt weg', () {
      Map<String, dynamic> draft(Map<String, dynamic> bad) => {
        'lines': [
          {
            'lineId': 'a',
            'itemId': 'cola',
            'quantity': 2,
            'optionIds': <String>[],
          },
          {'lineId': 'x', 'quantity': 1, 'optionIds': <String>[], ...bad},
        ],
      };
      for (final (name, bad) in <(String, Map<String, dynamic>)>[
        (
          'Pfand kein Objekt',
          {'itemId': 'deposit-return-25', 'depositReturn': 25},
        ),
        (
          'Pfand 0',
          {
            'itemId': 'deposit-return-0',
            'depositReturn': {'cents': 0},
          },
        ),
        (
          'Pfand unter 0',
          {
            'itemId': 'deposit-return--25',
            'depositReturn': {'cents': -25},
          },
        ),
        (
          'Pfand als Text',
          {
            'itemId': 'deposit-return-25',
            'depositReturn': {'cents': '25'},
          },
        ),
        (
          'Pfand passt nicht zur Kennung',
          {
            'itemId': 'deposit-return-50',
            'depositReturn': {'cents': 25},
          },
        ),
        (
          'Pfand mit Optionen',
          {
            'itemId': 'deposit-return-25',
            'optionIds': ['reis'],
            'depositReturn': {'cents': 25},
          },
        ),
        (
          'Gutschein unter 1,00 €',
          {
            'itemId': 'voucher-sale',
            'voucherSale': {'cents': 99},
          },
        ),
        (
          'Gutschein über 500,00 €',
          {
            'itemId': 'voucher-sale',
            'voucherSale': {'cents': 50001},
          },
        ),
        (
          'Gutschein kein Objekt',
          {'itemId': 'voucher-sale', 'voucherSale': 'x'},
        ),
        (
          'Gutschein mit falscher Kennung',
          {
            'itemId': 'cola',
            'voucherSale': {'cents': 2500},
          },
        ),
        (
          'Gutschein Menge 2',
          {
            'itemId': 'voucher-sale',
            'quantity': 2,
            'voucherSale': {'cents': 2500},
          },
        ),
      ]) {
        test(name, () {
          final read = Cart.fromJson(draft(bad), catalog);
          expect(read.lines.map((l) => l.lineId), ['a']);
        });
      }
    });

    test('Entwurf: eine zweite Zeile "Pfand zurück" mit demselben Betrag fällt weg', () {
      Map<String, dynamic> ret(String lineId, int quantity) => {
        'lineId': lineId,
        'itemId': 'deposit-return-25',
        'quantity': quantity,
        'optionIds': <String>[],
        'depositReturn': {'cents': 25},
      };
      final read = Cart.fromJson({
        'lines': [ret('r1', 2), ret('r2', 5)],
      }, catalog);
      expect(read.lines.map((l) => (l.lineId, l.quantity)), [('r1', 2)]);
    });

    test('Entwurf: kaputte gewählte Gutscheine fallen einzeln weg', () {
      final read = Cart.fromJson({
        'lines': [
          {
            'lineId': 'a',
            'itemId': 'cola',
            'quantity': 2,
            'optionIds': <String>[],
          },
        ],
        'vouchers': [
          {'id': 'v-a', 'code': '11112222', 'balanceCents': 500},
          'kaputt',
          {'id': 'v-b', 'code': 33334444, 'balanceCents': 300},
          {'id': 'v-c', 'code': '55556666', 'balanceCents': '1'},
          {'code': '77778888', 'balanceCents': 1},
          {'id': 'v-a', 'code': '11112222', 'balanceCents': 500},
          {'id': 'v-d', 'code': '99990000', 'balanceCents': 0},
        ],
      }, catalog);
      expect([for (final v in read.vouchers) v.voucherId], ['v-a', 'v-d']);
      // Ein Bon mit Gutschein-Zeile hat keine gewählten Gutscheine.
      final withSale = Cart.fromJson({
        ...const Cart.empty().addVoucherSale(valueCents: 1000).toJson(),
        'vouchers': [
          {'id': 'v-a', 'code': '11112222', 'balanceCents': 500},
        ],
      }, catalog);
      expect(withSale.hasVoucherSale, isTrue);
      expect(withSale.vouchers, isEmpty);
      // Ein leerer Bon auch nicht.
      expect(
        Cart.fromJson({
          'lines': <Object>[],
          'vouchers': [
            {'id': 'v-a', 'code': '11112222', 'balanceCents': 500},
          ],
        }, catalog).vouchers,
        isEmpty,
      );
    });

    test('isReservedItemId', () {
      for (final id in [
        'open-amount-20',
        'deposit-return-25',
        'voucher-sale',
      ]) {
        expect(isReservedItemId(id), isTrue, reason: id);
      }
      for (final id in ['cola', 'voucher-sale-1', 'deposit-25']) {
        expect(isReservedItemId(id), isFalse, reason: id);
      }
    });
  });
}
