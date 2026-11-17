// Katalog der Kassa: Kategorien, Artikel, Auswahl-Vorlagen.
// Reines Dart, ohne Flutter und ohne Datenbank.

import 'staff.dart';

enum TaxRate {
  normal(20),
  reduced1(10),
  reduced2(13),
  zero(0),
  special(19);

  const TaxRate(this.percent);

  final int percent;

  /// Wirft [ArgumentError], wenn der Satz nicht erlaubt ist.
  static TaxRate fromPercent(int p) {
    for (final rate in values) {
      if (rate.percent == p) return rate;
    }
    throw ArgumentError.value(p, 'p', 'Steuersatz nicht erlaubt');
  }
}

enum ItemTag { vegan, spicy }

class Category {
  const Category({required this.id, required this.name, required this.position});

  final String id;
  final String name;
  final int position;
}

class Item {
  const Item({
    required this.id,
    required this.name,
    required this.priceCents,
    required this.categoryId,
    required this.taxRate,
    this.depositCents = 0,
    this.tags = const {},
    this.info,
    this.templateId,
    this.favorite = false,
    this.inSale = true,
    this.photoPath,
    required this.position,
  });

  final String id;
  final String name;
  final int priceCents;
  final String categoryId;
  final TaxRate taxRate;
  final int depositCents;
  final Set<ItemTag> tags;
  final String? info;
  final String? templateId;
  final bool favorite;
  final bool inSale;
  final String? photoPath;
  final int position;

  /// Kopie mit geänderten Feldern. Ein Feld auf `null` zurückzusetzen geht
  /// damit nicht.
  Item copyWith({
    String? name,
    int? priceCents,
    String? categoryId,
    TaxRate? taxRate,
    int? depositCents,
    Set<ItemTag>? tags,
    String? info,
    String? templateId,
    bool? favorite,
    bool? inSale,
    String? photoPath,
    int? position,
  }) =>
      Item(
        id: id,
        name: name ?? this.name,
        priceCents: priceCents ?? this.priceCents,
        categoryId: categoryId ?? this.categoryId,
        taxRate: taxRate ?? this.taxRate,
        depositCents: depositCents ?? this.depositCents,
        tags: tags ?? this.tags,
        info: info ?? this.info,
        templateId: templateId ?? this.templateId,
        favorite: favorite ?? this.favorite,
        inSale: inSale ?? this.inSale,
        photoPath: photoPath ?? this.photoPath,
        position: position ?? this.position,
      );
}

class ModifierOption {
  const ModifierOption({
    required this.id,
    required this.name,
    this.surchargeCents = 0,
    this.isDefault = false,
    this.taxRate,
    this.depositCents,
  });

  final String id;
  final String name;
  final int surchargeCents;
  final bool isDefault;

  /// Eigener Steuersatz der Option, sonst gilt der des Artikels.
  final TaxRate? taxRate;

  /// Eigenes Pfand der Option, sonst keines.
  final int? depositCents;
}

class ModifierGroup {
  const ModifierGroup({
    required this.id,
    required this.name,
    required this.min,
    required this.max,
    required this.options,
  });

  final String id;
  final String name;
  final int min;

  /// `null` heißt ohne Grenze.
  final int? max;
  final List<ModifierOption> options;
}

class ModifierTemplate {
  const ModifierTemplate({required this.id, required this.name, required this.groups});

  final String id;
  final String name;
  final List<ModifierGroup> groups;
}

class Catalog {
  const Catalog({
    required this.businessName,
    required this.categories,
    required this.items,
    required this.templates,
    this.staffSeeds = const [],
  });

  final String businessName;
  final List<Category> categories;
  final List<Item> items;
  final List<ModifierTemplate> templates;
  final List<({String name, String pin, StaffRole role})> staffSeeds;

  /// Wirft [StateError], wenn es den Artikel nicht gibt.
  Item item(String id) => items.firstWhere(
        (i) => i.id == id,
        orElse: () => throw StateError('Artikel "$id" gibt es nicht.'),
      );

  ModifierTemplate? templateOf(Item item) {
    final id = item.templateId;
    if (id == null) return null;
    for (final t in templates) {
      if (t.id == id) return t;
    }
    return null;
  }
}
