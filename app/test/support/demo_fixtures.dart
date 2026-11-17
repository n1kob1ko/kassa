// Fixtures aus dem Beispiel-Imbiss, für Tests rund um Bon und Kassa.

import 'dart:io';

import 'package:kassa/domain/catalog.dart';
import 'package:kassa/domain/menu_import.dart';

final Catalog catalog = parseMenuFile(
  File('assets/demo/beispiel-imbiss.json').readAsStringSync(),
);

final Item cola = catalog.item('cola');
final Item teigtaschen = catalog.item('teigtaschen');
final Item huhnBowl = catalog.item('huhn-bowl');
final Item leitungswasser = catalog.item('leitungswasser');

final ModifierTemplate bowlTemplate = catalog.templates.firstWhere(
  (t) => t.id == 'bowl',
);

ModifierGroup _group(String name) =>
    bowlTemplate.groups.firstWhere((g) => g.name == name);

ModifierOption _option(ModifierGroup g, String name) =>
    g.options.firstWhere((o) => o.name == name);

final ModifierGroup groesse = _group('Größe');
final ModifierGroup basis = _group('Basis');
final ModifierGroup topping = _group('Extra-Topping');
final ModifierGroup sauce = _group('Extra-Sauce');

final ModifierOption normal = _option(groesse, 'Normal');
final ModifierOption xxl = _option(groesse, 'XXL');
final ModifierOption reis = _option(basis, 'Reis');
final ModifierOption nudeln = _option(basis, 'Nudeln');
final ModifierOption teriyaki = _option(sauce, 'Teriyaki');
