import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/domain/catalog.dart';
import 'package:kassa/domain/menu_import.dart';
import 'package:kassa/domain/staff.dart';

void main() {
  late String demo;
  setUpAll(() => demo = File('assets/demo/beispiel-imbiss.json').readAsStringSync());

  String demoMit(String extra) => demo.replaceFirst('{', '{$extra,');

  test('Beispiel-Imbiss wird gelesen', () {
    final c = parseMenuFile(demo);
    expect(c.businessName, 'Beispiel-Imbiss');
    expect(c.categories.map((k) => k.name), ['Bowls', 'Snacks', 'Süßes', 'Getränke']);
    expect(c.items, hasLength(14));
    final cola = c.item('cola');
    expect((cola.priceCents, cola.taxRate, cola.depositCents), (290, TaxRate.normal, 25));
    final bowl = c.item('huhn-bowl');
    expect(bowl.tags, {ItemTag.spicy});
    final groups = c.templateOf(bowl)!.groups;
    expect(groups.map((g) => (g.name, g.min, g.max)),
        [('Größe', 1, 1), ('Basis', 1, 1), ('Extra-Topping', 0, 4), ('Extra-Sauce', 0, null)]);
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
        throwsA(isA<MenuImportException>().having((e) => e.problems, 'problems', [
          'Artikel "x": Kategorie "b" gibt es nicht.',
          'Artikel "x": Steuersatz 7 ist nicht erlaubt. Erlaubt sind 20, 10, 13, 0 und 19.',
          'Artikel "x" kommt doppelt vor.',
          'Artikel "x": Preis darf nicht negativ sein.',
          'Artikel "x": Auswahl "fehlt" gibt es nicht.',
        ])));
  });

  test('kein JSON, fehlende Pflichtangabe, BOM', () {
    expect(
        () => parseMenuFile('hallo'),
        throwsA(isA<MenuImportException>().having(
            (e) => e.problems.single, 'problem', 'Die Datei ist keine gültige Speisekarten-Datei.')));
    expect(
        () => parseMenuFile('{"betrieb":"X","kategorien":[],"artikel":[{"id":"x"}],"auswahlgruppen":{}}'),
        throwsA(isA<MenuImportException>()
            .having((e) => e.problems.first, 'problem', 'Artikel "x": Name fehlt.')));
    expect(parseMenuFile('﻿$demo').items, hasLength(14));
  });

  test('Mitarbeiter in der Datei', () {
    final c = parseMenuFile(
        demoMit('"mitarbeiter":[{"name":"Anna","pin":"1234","rolle":"mitarbeiter"}]'));
    expect(c.staffSeeds.single, (name: 'Anna', pin: '1234', role: StaffRole.staff));
    expect(parseMenuFile(demo).staffSeeds, isEmpty);
    final chef = parseMenuFile(demoMit('"mitarbeiter":[{"name":"Bea","pin":"0000","rolle":"chef"}]'));
    expect(chef.staffSeeds.single.role, StaffRole.chef);
    expect(
        () => parseMenuFile(
            demoMit('"mitarbeiter":[{"name":"Anna","pin":"12a","rolle":"mitarbeiter"}]')),
        throwsA(isA<MenuImportException>().having((e) => e.problems, 'problems',
            ['Mitarbeiter "Anna": Die PIN muss aus genau vier Ziffern bestehen.'])));
  });

  test('Gruppe mit min größer als max und zu vielen Vorgaben', () {
    const bad = '''{"betrieb":"X","kategorien":[],"artikel":[],"auswahlgruppen":{"bowl":[
      {"name":"Basis","min":2,"max":1,"optionen":[{"name":"Reis","aufpreis_cent":0}]},
      {"name":"Größe","min":1,"max":1,"optionen":[
        {"name":"Normal","aufpreis_cent":0,"vorgabe":true},
        {"name":"XXL","aufpreis_cent":200,"vorgabe":true}]}]}}''';
    expect(
        () => parseMenuFile(bad),
        throwsA(isA<MenuImportException>().having((e) => e.problems, 'problems', [
          'Auswahl "bowl", Gruppe "Basis": mindestens 2 und höchstens 1 passt nicht zusammen.',
          'Auswahl "bowl", Gruppe "Größe": 2 Vorgaben, aber höchstens 1 wählbar.',
        ])));
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
}
