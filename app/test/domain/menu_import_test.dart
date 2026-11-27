import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/domain/catalog.dart';
import 'package:kassa/domain/menu_import.dart';
import 'package:kassa/domain/staff.dart';

void main() {
  late String demo;
  setUpAll(
    () => demo = File('assets/demo/beispiel-imbiss.json').readAsStringSync(),
  );

  /// Beispiel-Datei mit geänderten Angaben; ein Wert `null` entfernt die Angabe.
  String demoWith(Map<String, Object?> changes) {
    final json = jsonDecode(demo) as Map<String, dynamic>;
    changes.forEach((key, value) {
      if (value == null) {
        json.remove(key);
      } else {
        json[key] = value;
      }
    });
    return jsonEncode(json);
  }

  String demoMit(String extra) => demo.replaceFirst('{', '{$extra,');

  test('Beispiel-Imbiss wird gelesen', () {
    final c = parseMenuFile(demo);
    expect(c.businessName, 'Beispiel-Imbiss');
    expect(c.categories.map((k) => k.name), [
      'Bowls',
      'Snacks',
      'Süßes',
      'Getränke',
    ]);
    expect(c.items, hasLength(14));
    final cola = c.item('cola');
    expect(
      (cola.priceCents, cola.taxRate, cola.depositCents),
      (290, TaxRate.normal, 25),
    );
    final bowl = c.item('huhn-bowl');
    expect(bowl.tags, {ItemTag.spicy});
    final groups = c.templateOf(bowl)!.groups;
    expect(groups.map((g) => (g.name, g.min, g.max)), [
      ('Größe', 1, 1),
      ('Basis', 1, 1),
      ('Extra-Topping', 0, 4),
      ('Extra-Sauce', 0, null),
    ]);
    expect(groups.first.options.first.isDefault, isTrue);
    expect(groups.first.options.last.surchargeCents, 200);
    expect(c.items.every((i) => i.inSale && !i.favorite), isTrue);
  });

  test('Kennungen und Reihenfolge', () {
    final c = parseMenuFile(demo);
    final bowl = c.templateOf(c.item('tofu-bowl'))!;
    expect(bowl.id, 'bowl');
    expect(bowl.groups[1].id, 'bowl/1');
    expect(bowl.groups[1].options[2].id, 'bowl/1/2');
    expect(c.categories.map((k) => k.position), [0, 1, 2, 3]);
    expect(c.items.map((i) => i.position), List.generate(14, (i) => i));
    expect(c.item('teigtaschen').info, '5 Stück');
    expect(c.item('leitungswasser').priceCents, 0);
    expect(c.item('leitungswasser').depositCents, 0);
    expect(c.templateOf(c.item('cola')), isNull);
  });

  test('alle Fehler werden auf einmal gemeldet', () {
    const bad = '''{"betrieb":"X","kategorien":[{"id":"a","name":"A"}],
    "artikel":[{"id":"x","name":"X","preis_cent":100,"kategorie":"b","mwst":7},
               {"id":"x","name":"Y","preis_cent":-1,"kategorie":"a","mwst":10,"auswahl":"fehlt"}],
    "auswahlgruppen":{}}''';
    expect(
      () => parseMenuFile(bad),
      throwsA(
        isA<MenuImportException>().having((e) => e.problems, 'problems', [
          'Artikel "x": Kategorie "b" gibt es nicht.',
          'Artikel "x": Steuersatz 7 ist nicht erlaubt. Erlaubt sind 20, 10, 13, 0 und 19.',
          'Artikel "x" kommt doppelt vor.',
          'Artikel "x": Preis darf nicht negativ sein.',
          'Artikel "x": Auswahl "fehlt" gibt es nicht.',
        ]),
      ),
    );
  });

  test('eine Kennung mit "open-amount-" vorn ist für den freien Betrag '
      'vergeben', () {
    const bad = '''{"betrieb":"X","kategorien":[{"id":"a","name":"A"}],
    "artikel":[{"id":"open-amount-20","name":"X","preis_cent":100,"kategorie":"a","mwst":20}],
    "auswahlgruppen":{}}''';
    expect(
      () => parseMenuFile(bad),
      throwsA(
        isA<MenuImportException>().having((e) => e.problems, 'problems', [
          'Artikel "open-amount-20": Die Kennung darf nicht mit '
              '"open-amount-" beginnen.',
        ]),
      ),
    );
  });

  test('Kennungen für Pfand zurück und Gutschein sind vergeben '
      '(gemeinsame Prüfdateien)', () {
    for (final name in [
      'fehler-artikel-kennung-pfand-zurueck.json',
      'fehler-artikel-kennung-gutschein.json',
    ]) {
      final input = File('../shared/fixtures/menu/inputs/$name')
          .readAsStringSync();
      final expected = jsonDecode(
        File('../shared/fixtures/menu/expected/$name').readAsStringSync(),
      ) as Map<String, dynamic>;
      expect(expected['problems'], hasLength(1), reason: name);
      expect(
        () => parseMenuFile(input),
        throwsA(
          isA<MenuImportException>().having(
            (e) => e.problems,
            'problems',
            expected['problems'],
          ),
        ),
        reason: name,
      );
    }
  });

  test('Meldung nennt die vergebene Kennung wörtlich', () {
    for (final (id, message) in [
      (
        'deposit-return-25',
        'Die Kennung darf nicht mit "deposit-return-" beginnen.',
      ),
      ('voucher-sale', 'Die Kennung darf nicht "voucher-sale" sein.'),
    ]) {
      final bad =
          '{"betrieb":"X","kategorien":[{"id":"a","name":"A"}],'
          '"artikel":[{"id":"$id","name":"X","preis_cent":100,'
          '"kategorie":"a","mwst":20}]}';
      expect(
        () => parseMenuFile(bad),
        throwsA(
          isA<MenuImportException>().having((e) => e.problems, 'problems', [
            'Artikel "$id": $message',
          ]),
        ),
        reason: id,
      );
    }
  });

  test('kein JSON, fehlende Pflichtangabe, BOM', () {
    expect(
      () => parseMenuFile('hallo'),
      throwsA(
        isA<MenuImportException>().having(
          (e) => e.problems.single,
          'problem',
          'Die Datei ist keine gültige Speisekarten-Datei.',
        ),
      ),
    );
    expect(
      () => parseMenuFile(
        '{"betrieb":"X","kategorien":[],"artikel":[{"id":"x"}],"auswahlgruppen":{}}',
      ),
      throwsA(
        isA<MenuImportException>().having(
          (e) => e.problems.first,
          'problem',
          'Artikel "x": Name fehlt.',
        ),
      ),
    );
    expect(parseMenuFile('﻿$demo').items, hasLength(14));
  });

  test('Mitarbeiter in der Datei', () {
    final c = parseMenuFile(
      demoMit(
        '"mitarbeiter":[{"name":"Anna","pin":"1234","rolle":"mitarbeiter"}]',
      ),
    );
    expect(c.staffSeeds.single, (
      name: 'Anna',
      pin: '1234',
      role: StaffRole.staff,
    ));
    expect(parseMenuFile(demo).staffSeeds, isEmpty);
    final chef = parseMenuFile(
      demoMit('"mitarbeiter":[{"name":"Bea","pin":"0000","rolle":"chef"}]'),
    );
    expect(chef.staffSeeds.single.role, StaffRole.chef);
    expect(
      () => parseMenuFile(
        demoMit(
          '"mitarbeiter":[{"name":"Anna","pin":"12a","rolle":"mitarbeiter"}]',
        ),
      ),
      throwsA(
        isA<MenuImportException>().having((e) => e.problems, 'problems', [
          'Mitarbeiter "Anna": Die PIN muss aus genau vier Ziffern bestehen.',
        ]),
      ),
    );
  });

  test('zwei Mitarbeiter mit gleicher PIN werden abgelehnt', () {
    expect(
      () => parseMenuFile(
        demoMit(
          '"mitarbeiter":['
          '{"name":"Anna","pin":"1234","rolle":"mitarbeiter"},'
          '{"name":"Ben","pin":"1234","rolle":"mitarbeiter"}]',
        ),
      ),
      throwsA(
        isA<MenuImportException>().having((e) => e.problems, 'problems', [
          'Mitarbeiter "Ben": Die PIN ist in der Datei schon vergeben.',
        ]),
      ),
    );
  });

  test('Gruppe mit min größer als max und zu vielen Vorgaben', () {
    const bad = '''{"betrieb":"X","kategorien":[],"artikel":[],"auswahlgruppen":{"bowl":[
      {"name":"Basis","min":2,"max":1,"optionen":[{"name":"Reis","aufpreis_cent":0}]},
      {"name":"Größe","min":1,"max":1,"optionen":[
        {"name":"Normal","aufpreis_cent":0,"vorgabe":true},
        {"name":"XXL","aufpreis_cent":200,"vorgabe":true}]}]}}''';
    expect(
      () => parseMenuFile(bad),
      throwsA(
        isA<MenuImportException>().having((e) => e.problems, 'problems', [
          'Auswahl "bowl", Gruppe "Basis": mindestens 2 und höchstens 1 passt nicht zusammen.',
          'Auswahl "bowl", Gruppe "Größe": 2 Vorgaben, aber höchstens 1 wählbar.',
        ]),
      ),
    );
  });

  test('Kennzeichen als Liste, Option mit eigenem Steuersatz und Pfand, Item.copyWith', () {
    const text = '''{"betrieb":"X","kategorien":[{"id":"a","name":"A"}],
      "artikel":[{"id":"x","name":"X","preis_cent":100,"kategorie":"a","mwst":10,
                  "kennzeichen":["VEGAN","SCHARF"],"auswahl":"t"}],
      "auswahlgruppen":{"t":[{"name":"G","min":0,"max":1,"optionen":[
        {"name":"Saft","aufpreis_cent":100,"mwst":20,"pfand_cent":25}]}]}}''';
    final c = parseMenuFile(text);
    expect(c.item('x').tags, {ItemTag.vegan, ItemTag.spicy});
    final o = c.templateOf(c.item('x'))!.groups.single.options.single;
    expect((o.taxRate, o.depositCents), (TaxRate.normal, 25));
    final f = c.item('x').copyWith(favorite: true, inSale: false);
    expect((f.favorite, f.inSale, f.name), (true, false, 'X'));
  });

  test('Adresse, UID und Bon-Ende werden gelesen', () {
    final c = parseMenuFile(
      demoWith({
        'adresse': ['Musterstraße 1', '1010 Wien'],
        'uid': 'ATU12345678',
        'bon_ende': 'Danke und bis bald!',
      }),
    );
    expect(c.business.addressLines, ['Musterstraße 1', '1010 Wien']);
    expect(c.business.vatId, 'ATU12345678');
    expect(c.business.receiptFooter, 'Danke und bis bald!');
    expect(c.businessName, c.business.name);
  });

  test('ohne die Angaben bleibt alles leer', () {
    final c = parseMenuFile(
      demoWith({'adresse': null, 'uid': null, 'bon_ende': null}),
    );
    expect(c.business.addressLines, isEmpty);
    expect(c.business.vatId, isNull);
    expect(c.business.receiptFooter, isNull);
  });

  test('Zeilen werden gekürzt, leere Zeilen und leere Angaben entfallen', () {
    final c = parseMenuFile(
      demoWith({
        'adresse': ['  Musterstraße 1 ', '', '   ', '1010 Wien'],
        'uid': '  ',
        'bon_ende': ' Danke! ',
      }),
    );
    expect(c.business.addressLines, ['Musterstraße 1', '1010 Wien']);
    expect(c.business.vatId, isNull);
    expect(c.business.receiptFooter, 'Danke!');
  });

  test('falsche Form wird in einfachen Worten gemeldet', () {
    List<String> problemsOf(String json) {
      try {
        parseMenuFile(json);
        return const [];
      } on MenuImportException catch (e) {
        return e.problems;
      }
    }

    expect(
      problemsOf(demoWith({'adresse': 'Musterstraße 1'})),
      contains('"adresse" muss eine Liste von Zeilen sein.'),
    );
    expect(
      problemsOf(
        demoWith({
          'adresse': ['a', 5],
        }),
      ),
      contains('"adresse" muss eine Liste von Zeilen sein.'),
    );
    expect(
      problemsOf(
        demoWith({
          'adresse': ['a', 'b', 'c', 'd', 'e'],
        }),
      ),
      contains('"adresse" darf höchstens 4 Zeilen haben.'),
    );
    expect(
      problemsOf(demoWith({'uid': 12})),
      contains('"uid" muss ein Text sein.'),
    );
    expect(
      problemsOf(demoWith({'bon_ende': 12})),
      contains('"bon_ende" muss ein Text sein.'),
    );
    expect(
      problemsOf(demoWith({'bon_ende': 'x' * 201})),
      contains('"bon_ende" darf höchstens 200 Zeichen haben.'),
    );
    expect(problemsOf(demoWith({'bon_ende': 'x' * 200})), isEmpty);
  });

  group('Übersetzungen', () {
    List<String> problemsOf(String json) {
      try {
        parseMenuFile(json);
        return const [];
      } on MenuImportException catch (e) {
        return e.problems;
      }
    }

    test('ohne den Schlüssel ist das Wörterbuch leer', () {
      expect(parseMenuFile(demo).translations, isEmpty);
    });

    test('Datei mit uebersetzungen wird gelesen', () {
      final c = parseMenuFile(
        demoWith({
          'uebersetzungen': {
            'Bowls': {'en': 'Rice bowls', 'tr': 'Kaseler'},
            'Cola 0,33 l': {'en': 'Cola', 'zh': '可乐'},
          },
        }),
      );
      expect(c.translations, {
        'Bowls': {'en': 'Rice bowls', 'tr': 'Kaseler'},
        'Cola 0,33 l': {'en': 'Cola', 'zh': '可乐'},
      });
    });

    test('Namen aus Kategorie, Artikel, Info, Gruppe und Option gelten', () {
      final c = parseMenuFile(
        demoWith({
          'uebersetzungen': {
            'Süßes': {'en': 'Sweets'},
            'Teigtaschen': {'en': 'Dumplings'},
            '5 Stück': {'en': '5 pieces'},
            'Größe': {'en': 'Size'},
            'XXL': {'en': 'Extra large'},
          },
        }),
      );
      expect(c.translations.keys, [
        'Süßes',
        'Teigtaschen',
        '5 Stück',
        'Größe',
        'XXL',
      ]);
    });

    test(
      'Leerzeichen werden entfernt, leere Texte entfallen, gleiche zählen',
      () {
        final c = parseMenuFile(
          demoWith({
            'uebersetzungen': {
              ' Cola 0,33 l ': {
                'en': '  Soda ',
                'tr': '   ',
                'zh': 'Cola 0,33 l',
              },
              'Bowls': {'en': ''},
            },
          }),
        );
        expect(c.translations, {
          'Cola 0,33 l': {'en': 'Soda', 'zh': 'Cola 0,33 l'},
        });
      },
    );

    test('Meldungen wörtlich', () {
      expect(problemsOf(demoWith({'uebersetzungen': 'x'})), [
        '"uebersetzungen" muss eine Liste von Namen mit ihren Übersetzungen sein.',
      ]);
      expect(
        problemsOf(
          demoWith({
            'uebersetzungen': {
              'Pizza': {'en': 'Pizza'},
            },
          }),
        ),
        ['Übersetzung "Pizza": Diesen Namen gibt es in der Speisekarte nicht.'],
      );
      expect(
        problemsOf(
          demoWith({
            'uebersetzungen': {
              'Pommes': {'fr': 'Frites'},
            },
          }),
        ),
        [
          'Übersetzung "Pommes": Die Sprache "fr" kennt die Kassa nicht. Erlaubt sind en, zh, tr und ar.',
        ],
      );
      expect(
        problemsOf(
          demoWith({
            'uebersetzungen': {
              'Pommes': {'en': 5},
            },
          }),
        ),
        ['Übersetzung "Pommes", Sprache "en": Der Text fehlt.'],
      );
      expect(
        problemsOf(
          demoWith({
            'uebersetzungen': {
              'Pommes': {'en': 'x' * 201},
            },
          }),
        ),
        ['Übersetzung "Pommes", Sprache "en": Höchstens 200 Zeichen.'],
      );
      expect(
        parseMenuFile(
          demoWith({
            'uebersetzungen': {
              'Pommes': {'en': 'x' * 200},
            },
          }),
        ).translations['Pommes'],
        isNotNull,
      );
    });
  });

  group('gemeinsame Prüfdateien', () {
    final root = Directory('../shared/fixtures/menu');
    final names = [
      for (final f in Directory('${root.path}/inputs').listSync())
        if (f is File && f.path.contains('uebersetzung'))
          f.uri.pathSegments.last,
    ]..sort();

    test(
      'es gibt Dateien',
      () => expect(names.length, greaterThanOrEqualTo(6)),
    );

    for (final name in names) {
      test(name, () {
        final input = File('${root.path}/inputs/$name').readAsStringSync();
        final expected = jsonDecode(
          File('${root.path}/expected/$name').readAsStringSync(),
        ) as Map<String, dynamic>;
        if (expected.containsKey('problems')) {
          expect(
            () => parseMenuFile(input),
            throwsA(
              isA<MenuImportException>().having(
                (e) => e.problems,
                'problems',
                expected['problems'],
              ),
            ),
          );
        } else {
          final menu = expected['menu'] as Map<String, dynamic>;
          expect(parseMenuFile(input).translations, menu['translations']);
        }
      });
    }
  });
}
