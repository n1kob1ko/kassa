// Liest die Einspiel-Datei der Speisekarte (Anhang A des Entwurfs).
// Reines Dart, ohne Flutter und ohne Datenbank.

import 'dart:convert';

import 'catalog.dart';
import 'staff.dart';

class MenuImportException implements Exception {
  const MenuImportException(this.problems);

  final List<String> problems;

  @override
  String toString() => 'MenuImportException: ${problems.join(' ')}';
}

const _invalidFile = 'Die Datei ist keine gültige Speisekarten-Datei.';
const _allowedRates = 'Erlaubt sind 20, 10, 13, 0 und 19.';

Catalog parseMenuFile(String jsonText) {
  final Object? root;
  try {
    root = jsonDecode(
      jsonText.startsWith('﻿') ? jsonText.substring(1) : jsonText,
    );
  } on FormatException {
    throw const MenuImportException([_invalidFile]);
  }
  if (root is! Map<String, dynamic>)
    throw const MenuImportException([_invalidFile]);
  final categoriesJson = root['kategorien'];
  final itemsJson = root['artikel'];
  final groupsJson = root['auswahlgruppen'] ?? <String, dynamic>{};
  final staffJson = root['mitarbeiter'] ?? <dynamic>[];
  if (categoriesJson is! List ||
      itemsJson is! List ||
      groupsJson is! Map<String, dynamic> ||
      staffJson is! List) {
    throw const MenuImportException([_invalidFile]);
  }

  final problems = <String>[];
  final businessName = _text(root['betrieb']);
  if (businessName == null) problems.add('Betrieb fehlt.');

  final categories = <Category>[];
  final categoryIds = <String>{};
  for (final raw in categoriesJson) {
    final k = raw is Map<String, dynamic> ? raw : const <String, dynamic>{};
    final id = _text(k['id']);
    final name = _text(k['name']);
    if (id == null) {
      problems.add('Eine Kategorie hat keine Kennung.');
      continue;
    }
    if (!categoryIds.add(id)) {
      problems.add('Kategorie "$id" kommt doppelt vor.');
      continue;
    }
    if (name == null) {
      problems.add('Kategorie "$id": Name fehlt.');
      continue;
    }
    categories.add(Category(id: id, name: name, position: categories.length));
  }

  final items = <Item>[];
  final itemIds = <String>{};
  for (final raw in itemsJson) {
    final a = raw is Map<String, dynamic> ? raw : const <String, dynamic>{};
    final id = _text(a['id']);
    if (id == null) {
      problems.add('Ein Artikel hat keine Kennung.');
      continue;
    }
    var ok = true;
    void fail(String message) {
      problems.add('Artikel "$id": $message');
      ok = false;
    }

    if (!itemIds.add(id)) {
      problems.add('Artikel "$id" kommt doppelt vor.');
      ok = false;
    }
    final name = _text(a['name']);
    if (name == null) fail('Name fehlt.');

    final price = a['preis_cent'];
    if (price == null) {
      fail('Preis fehlt.');
    } else if (price is! int) {
      fail('Preis muss eine ganze Zahl in Cent sein.');
    } else if (price < 0) {
      fail('Preis darf nicht negativ sein.');
    }

    final categoryId = _text(a['kategorie']);
    if (categoryId == null) {
      fail('Kategorie fehlt.');
    } else if (!categoryIds.contains(categoryId)) {
      fail('Kategorie "$categoryId" gibt es nicht.');
    }

    final rate = _rate(a['mwst']);
    if (a['mwst'] == null) {
      fail('Steuersatz fehlt.');
    } else if (rate == null) {
      fail('Steuersatz ${a['mwst']} ist nicht erlaubt. $_allowedRates');
    }

    final depositRaw = a['pfand_cent'];
    var deposit = 0;
    if (depositRaw != null) {
      if (depositRaw is! int) {
        fail('Pfand muss eine ganze Zahl in Cent sein.');
      } else if (depositRaw < 0) {
        fail('Pfand darf nicht negativ sein.');
      } else {
        deposit = depositRaw;
      }
    }

    final templateId = _text(a['auswahl']);
    if (templateId != null && !groupsJson.containsKey(templateId)) {
      fail('Auswahl "$templateId" gibt es nicht.');
    }

    final tags = <ItemTag>{};
    final tagRaw = a['kennzeichen'];
    final tagWords = tagRaw == null
        ? const []
        : (tagRaw is List ? tagRaw : [tagRaw]);
    for (final word in tagWords) {
      final tag = switch (word is String ? word.trim().toUpperCase() : null) {
        'VEGAN' => ItemTag.vegan,
        'SCHARF' => ItemTag.spicy,
        _ => null,
      };
      if (tag == null) {
        fail('Kennzeichen "$word" kennt die Kassa nicht.');
      } else {
        tags.add(tag);
      }
    }

    if (ok) {
      items.add(
        Item(
          id: id,
          name: name!,
          priceCents: price as int,
          categoryId: categoryId!,
          taxRate: rate!,
          depositCents: deposit,
          tags: tags,
          info: _text(a['info']),
          templateId: templateId,
          position: items.length,
        ),
      );
    }
  }

  final templates = <ModifierTemplate>[];
  for (final entry in groupsJson.entries) {
    final template = _parseTemplate(entry.key, entry.value, problems);
    if (template != null) templates.add(template);
  }

  final staffSeeds = <({String name, String pin, StaffRole role})>[];
  for (final raw in staffJson) {
    final m = raw is Map<String, dynamic> ? raw : const <String, dynamic>{};
    final name = _text(m['name']);
    if (name == null) {
      problems.add('Ein Mitarbeiter hat keinen Namen.');
      continue;
    }
    var ok = true;
    final pin = m['pin'];
    if (pin is! String || !RegExp(r'^[0-9]{4}$').hasMatch(pin)) {
      problems.add(
        'Mitarbeiter "$name": Die PIN muss aus genau vier Ziffern bestehen.',
      );
      ok = false;
    }
    final role = switch (m['rolle']) {
      'chef' => StaffRole.chef,
      'mitarbeiter' => StaffRole.staff,
      _ => null,
    };
    if (role == null) {
      problems.add(
        'Mitarbeiter "$name": Die Rolle muss "chef" oder "mitarbeiter" sein.',
      );
      ok = false;
    }
    if (ok && staffSeeds.any((s) => s.pin == pin)) {
      problems.add(
        'Mitarbeiter "$name": Die PIN ist in der Datei schon vergeben.',
      );
      ok = false;
    }
    if (ok) staffSeeds.add((name: name, pin: pin as String, role: role!));
  }

  if (problems.isNotEmpty) throw MenuImportException(problems);
  return Catalog(
    businessName: businessName!,
    categories: categories,
    items: items,
    templates: templates,
    staffSeeds: staffSeeds,
  );
}

String? _text(Object? value) {
  if (value is! String) return null;
  final t = value.trim();
  return t.isEmpty ? null : t;
}

TaxRate? _rate(Object? value) {
  if (value is! int) return null;
  for (final r in TaxRate.values) {
    if (r.percent == value) return r;
  }
  return null;
}

ModifierTemplate? _parseTemplate(
  String id,
  Object? raw,
  List<String> problems,
) {
  final before = problems.length;
  if (raw is! List) {
    problems.add('Auswahl "$id": Die Gruppen fehlen.');
    return null;
  }
  final groups = <ModifierGroup>[];
  for (var g = 0; g < raw.length; g++) {
    final gj = raw[g] is Map<String, dynamic>
        ? raw[g] as Map<String, dynamic>
        : const <String, dynamic>{};
    final gName = _text(gj['name']);
    if (gName == null) {
      problems.add('Auswahl "$id": Eine Gruppe hat keinen Namen.');
      continue;
    }
    final where = 'Auswahl "$id", Gruppe "$gName"';
    final min = gj['min'] ?? 0;
    final maxRaw = gj['max'];
    final optionsJson = gj['optionen'];
    if (min is! int ||
        min < 0 ||
        (maxRaw != null && (maxRaw is! int || maxRaw < 0))) {
      problems.add('$where: min und max müssen ganze Zahlen ab 0 sein.');
      continue;
    }
    if (optionsJson is! List) {
      problems.add('$where: Die Optionen fehlen.');
      continue;
    }
    final max = maxRaw as int?;
    var groupOk = true;
    if (max != null && min > max) {
      problems.add(
        '$where: mindestens $min und höchstens $max passt nicht zusammen.',
      );
      groupOk = false;
    }
    final options = <ModifierOption>[];
    for (var o = 0; o < optionsJson.length; o++) {
      final oj = optionsJson[o] is Map<String, dynamic>
          ? optionsJson[o] as Map<String, dynamic>
          : const <String, dynamic>{};
      final oName = _text(oj['name']);
      if (oName == null) {
        problems.add('$where: Eine Option hat keinen Namen.');
        groupOk = false;
        continue;
      }
      final surcharge = oj['aufpreis_cent'] ?? 0;
      if (surcharge is! int) {
        problems.add(
          '$where, Option "$oName": Aufpreis muss eine ganze Zahl in Cent sein.',
        );
        groupOk = false;
        continue;
      }
      TaxRate? rate;
      if (oj['mwst'] != null) {
        rate = _rate(oj['mwst']);
        if (rate == null) {
          problems.add(
            '$where, Option "$oName": Steuersatz ${oj['mwst']} ist nicht erlaubt. $_allowedRates',
          );
          groupOk = false;
          continue;
        }
      }
      final deposit = oj['pfand_cent'];
      if (deposit != null && (deposit is! int || deposit < 0)) {
        problems.add(
          '$where, Option "$oName": Pfand muss eine ganze Zahl ab 0 sein.',
        );
        groupOk = false;
        continue;
      }
      options.add(
        ModifierOption(
          id: '$id/$g/$o',
          name: oName,
          surchargeCents: surcharge,
          isDefault: oj['vorgabe'] == true,
          taxRate: rate,
          depositCents: deposit as int?,
        ),
      );
    }
    final defaults = options.where((o) => o.isDefault).length;
    if (max != null && defaults > max) {
      problems.add('$where: $defaults Vorgaben, aber höchstens $max wählbar.');
      groupOk = false;
    }
    if (groupOk) {
      groups.add(
        ModifierGroup(
          id: '$id/$g',
          name: gName,
          min: min,
          max: max,
          options: options,
        ),
      );
    }
  }
  if (problems.length > before) return null;
  return ModifierTemplate(id: id, name: id, groups: groups);
}
