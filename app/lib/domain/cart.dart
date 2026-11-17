// Der offene Bon: Auswahl von Optionen und Bon-Zeilen.
// Reines Dart, unveränderlich: jede Änderung liefert ein neues Objekt.

import 'package:uuid/uuid.dart';

import 'catalog.dart';

const int maxQuantity = 99;

/// Gewählte Optionen für einen Artikel einer Auswahl-Vorlage.
class Selection {
  const Selection._(this._template, this._chosenIds);

  /// Vorgabe-Optionen der Vorlage sind gewählt.
  factory Selection.defaults(ModifierTemplate template) => Selection._(
        template,
        {
          for (final g in template.groups)
            for (final o in g.options)
              if (o.isDefault) o.id,
        },
      );

  final ModifierTemplate _template;
  final Set<String> _chosenIds;

  Selection toggle(ModifierGroup group, ModifierOption option) {
    final ids = {..._chosenIds};
    final max = group.max;
    if (ids.contains(option.id)) {
      // Pflichtgruppe mit genau einer Wahl: Antippen lässt die Wahl stehen.
      if (max == 1 && group.min >= 1) return this;
      ids.remove(option.id);
    } else if (max == 1) {
      ids.removeAll(group.options.map((o) => o.id));
      ids.add(option.id);
    } else {
      final count = group.options.where((o) => ids.contains(o.id)).length;
      if (max != null && count >= max) return this;
      ids.add(option.id);
    }
    return Selection._(_template, ids);
  }

  bool isChosen(ModifierOption o) => _chosenIds.contains(o.id);

  int _countIn(ModifierGroup g) => g.options.where(isChosen).length;

  bool get isComplete => _template.groups.every((g) => _countIn(g) >= g.min);

  /// Gruppen, in denen noch Optionen fehlen.
  List<ModifierGroup> get missing =>
      [for (final g in _template.groups) if (_countIn(g) < g.min) g];

  /// Nach Gruppe, dann nach Stelle in der Gruppe geordnet.
  List<ModifierOption> get chosen => [
        for (final g in _template.groups)
          for (final o in g.options)
            if (isChosen(o)) o,
      ];

  int get surchargeCents => chosen.fold(0, (sum, o) => sum + o.surchargeCents);
}

class CartLine {
  const CartLine({
    required this.lineId,
    required this.item,
    required this.quantity,
    this.options = const [],
  });

  final String lineId;
  final Item item;
  final int quantity;
  final List<ModifierOption> options;

  int get unitPriceCents =>
      item.priceCents + options.fold(0, (sum, o) => sum + o.surchargeCents);

  int get unitDepositCents =>
      item.depositCents + options.fold(0, (sum, o) => sum + (o.depositCents ?? 0));

  int get goodsCents => unitPriceCents * quantity;

  int get depositCents => unitDepositCents * quantity;

  CartLine withQuantity(int q) =>
      CartLine(lineId: lineId, item: item, quantity: q, options: options);
}

const _uuid = Uuid();

class Cart {
  const Cart._(this.lines);

  const Cart.empty() : lines = const [];

  final List<CartLine> lines;

  Cart add(Item item, {List<ModifierOption> options = const [], String? lineId}) {
    if (item.templateId == null && options.isEmpty) {
      final i = lines.indexWhere((l) => l.item.id == item.id && l.options.isEmpty);
      if (i >= 0) {
        final next = [...lines];
        next[i] = next[i].withQuantity(_cap(next[i].quantity + 1));
        return Cart._(next);
      }
    }
    return Cart._([
      ...lines,
      CartLine(
        lineId: lineId ?? _uuid.v4(),
        item: item,
        quantity: 1,
        options: List.unmodifiable(options),
      ),
    ]);
  }

  Cart setQuantity(String lineId, int quantity) {
    if (quantity <= 0) return remove(lineId);
    return Cart._([
      for (final l in lines) l.lineId == lineId ? l.withQuantity(_cap(quantity)) : l,
    ]);
  }

  Cart remove(String lineId) =>
      Cart._([for (final l in lines) if (l.lineId != lineId) l]);

  int get goodsCents => lines.fold(0, (sum, l) => sum + l.goodsCents);

  int get depositCents => lines.fold(0, (sum, l) => sum + l.depositCents);

  int get totalCents => goodsCents + depositCents;

  bool get isEmpty => lines.isEmpty;

  Map<String, dynamic> toJson() => {
        'lines': [
          for (final l in lines)
            {
              'lineId': l.lineId,
              'itemId': l.item.id,
              'quantity': l.quantity,
              'optionIds': [for (final o in l.options) o.id],
            },
        ],
      };

  /// Der Bon gegen einen (geänderten) Katalog neu aufgelöst: Zeilenkennung,
  /// Menge und Options-Ids bleiben, Artikel und Optionen kommen aus [catalog].
  /// Es gelten dieselben Regeln wie in [fromJson], zum Beispiel fallen Zeilen
  /// weg, die es nicht mehr gibt.
  Cart rebind(Catalog catalog) => fromJson(toJson(), catalog);

  /// Zeilen, deren Artikel oder Option es im Katalog nicht mehr gibt, mit
  /// Menge unter 1, mit falschen Typen oder mit doppelter Kennung fallen weg.
  /// Das Lesen wirft nie wegen des Inhalts.
  static Cart fromJson(Map<String, dynamic> json, Catalog catalog) {
    final rawLines = json['lines'];
    if (rawLines is! List) return const Cart.empty();
    final lines = <CartLine>[];
    final seen = <String>{};
    for (final raw in rawLines) {
      if (raw is! Map) continue;
      final lineId = raw['lineId'];
      final itemId = raw['itemId'];
      final quantity = raw['quantity'];
      final optionIds = raw['optionIds'] ?? const [];
      if (lineId is! String || itemId is! String || quantity is! int) continue;
      if (quantity < 1 || optionIds is! List || seen.contains(lineId)) continue;
      final Item item;
      try {
        item = catalog.item(itemId);
      } on StateError {
        continue;
      }
      final known = {
        for (final g in catalog.templateOf(item)?.groups ?? const <ModifierGroup>[])
          for (final o in g.options) o.id: o,
      };
      final options = <ModifierOption>[];
      var ok = true;
      for (final id in optionIds) {
        final o = id is String ? known[id] : null;
        if (o == null) {
          ok = false;
          break;
        }
        options.add(o);
      }
      if (!ok) continue;
      seen.add(lineId);
      lines.add(CartLine(
        lineId: lineId,
        item: item,
        quantity: _cap(quantity),
        options: options,
      ));
    }
    return Cart._(lines);
  }
}

int _cap(int q) => q > maxQuantity ? maxQuantity : q;
