// Der offene Bon: Auswahl von Optionen, Bon-Zeilen und Rabatte.
// Reines Dart, unveränderlich: jede Änderung liefert ein neues Objekt.

import 'package:uuid/uuid.dart';

import 'catalog.dart';
import 'discount.dart';

const int maxQuantity = 99;

/// Gewählte Optionen für einen Artikel einer Auswahl-Vorlage.
class Selection {
  const Selection._(this._template, this._chosenIds);

  /// Vorgabe-Optionen der Vorlage sind gewählt.
  factory Selection.defaults(ModifierTemplate template) =>
      Selection._(template, {
        for (final g in template.groups)
          for (final o in g.options)
            if (o.isDefault) o.id,
      });

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
  List<ModifierGroup> get missing => [
    for (final g in _template.groups)
      if (_countIn(g) < g.min) g,
  ];

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
    this.discount,
  });

  final String lineId;
  final Item item;
  final int quantity;
  final List<ModifierOption> options;

  /// Rabatt auf diese Zeile.
  final Discount? discount;

  int get unitPriceCents =>
      item.priceCents + options.fold(0, (sum, o) => sum + o.surchargeCents);

  int get unitDepositCents =>
      item.depositCents +
      options.fold(0, (sum, o) => sum + (o.depositCents ?? 0));

  /// Preis mal Menge, vor Rabatt.
  int get goodsCents => unitPriceCents * quantity;

  int get depositCents => unitDepositCents * quantity;

  /// Brutto-Warenwert je Steuersatz vor Rabatt, ohne Pfand. Eine Option mit
  /// eigenem Steuersatz zählt zu diesem Satz.
  Map<TaxRate, int> get listGrossByRate {
    final result = <TaxRate, int>{};
    void put(TaxRate rate, int cents) {
      if (cents == 0) return;
      result[rate] = (result[rate] ?? 0) + cents;
    }

    put(item.taxRate, item.priceCents * quantity);
    for (final o in options) {
      put(o.taxRate ?? item.taxRate, o.surchargeCents * quantity);
    }
    return result;
  }

  CartLine withQuantity(int q) => CartLine(
    lineId: lineId,
    item: item,
    quantity: q,
    options: options,
    discount: discount,
  );

  CartLine withDiscount(Discount? d) => CartLine(
    lineId: lineId,
    item: item,
    quantity: quantity,
    options: options,
    discount: d,
  );
}

/// Eine Zeile nach allen Rabatten. Pfand wird nie rabattiert.
class LinePricing {
  const LinePricing({
    required this.listCents,
    required this.ownDiscountCents,
    required this.shareCents,
    required this.depositCents,
    required this.grossByRate,
  });

  /// Preis mal Menge, vor Rabatt.
  final int listCents;

  /// Der Rabatt der Zeile selbst.
  final int ownDiscountCents;

  /// Der Anteil der Zeile am Bon-Rabatt.
  final int shareCents;

  final int depositCents;

  /// Nach allen Rabatten, ohne Pfand. Jeder Satz der Zeile vor Rabatt steht
  /// drin, auch wenn er durch den Rabatt 0 wird.
  final Map<TaxRate, int> grossByRate;

  int get discountCents => ownDiscountCents + shareCents;

  int get goodsCents => listCents - discountCents;
}

/// Der ganze Bon nach allen Rabatten.
class CartPricing {
  const CartPricing({
    required this.lines,
    required this.subtotalCents,
    required this.receiptDiscountCents,
  });

  final List<LinePricing> lines;

  /// Warenwert nach Zeilen-Rabatten, vor dem Bon-Rabatt.
  final int subtotalCents;

  final int receiptDiscountCents;

  int get discountCents => lines.fold(0, (s, l) => s + l.discountCents);

  int get goodsCents => lines.fold(0, (s, l) => s + l.goodsCents);

  int get depositCents => lines.fold(0, (s, l) => s + l.depositCents);

  int get totalCents => goodsCents + depositCents;

  /// Summe der Zeilen je Satz, ohne Pfand; Sätze mit Summe 0 fehlen.
  Map<TaxRate, int> get grossByRate {
    final result = <TaxRate, int>{};
    for (final l in lines) {
      for (final e in l.grossByRate.entries) {
        result[e.key] = (result[e.key] ?? 0) + e.value;
      }
    }
    result.removeWhere((_, cents) => cents == 0);
    return result;
  }
}

const _uuid = Uuid();

class Cart {
  const Cart._(this.lines, [this.discount]);

  const Cart.empty() : lines = const [], discount = null;

  final List<CartLine> lines;

  /// Rabatt auf den ganzen Bon. Ein leerer Bon hat keinen.
  final Discount? discount;

  /// Ein Bon aus [next] mit dem Bon-Rabatt dieses Bons; ein leerer Bon
  /// verliert ihn.
  Cart _withLines(List<CartLine> next) =>
      Cart._(next, next.isEmpty ? null : discount);

  Cart add(
    Item item, {
    List<ModifierOption> options = const [],
    String? lineId,
  }) {
    if (item.templateId == null && options.isEmpty) {
      final i = lines.indexWhere(
        (l) => l.item.id == item.id && l.options.isEmpty,
      );
      if (i >= 0) {
        final next = [...lines];
        next[i] = next[i].withQuantity(_cap(next[i].quantity + 1));
        return _withLines(next);
      }
    }
    return _withLines([
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
    return _withLines([
      for (final l in lines)
        l.lineId == lineId ? l.withQuantity(_cap(quantity)) : l,
    ]);
  }

  Cart remove(String lineId) => _withLines([
    for (final l in lines)
      if (l.lineId != lineId) l,
  ]);

  /// Setzt den Rabatt der Zeile [lineId]; null nimmt ihn weg.
  Cart setLineDiscount(String lineId, Discount? discount) => _withLines([
    for (final l in lines) l.lineId == lineId ? l.withDiscount(discount) : l,
  ]);

  /// Setzt den Rabatt auf den ganzen Bon; null nimmt ihn weg. Ein leerer Bon
  /// bekommt keinen.
  Cart setReceiptDiscount(Discount? discount) =>
      Cart._(lines, lines.isEmpty ? null : discount);

  /// Der Bon nach allen Rabatten (Spec 5.4). Bei jedem Aufruf neu gerechnet,
  /// immer gleich für denselben Bon.
  CartPricing get pricing {
    // 1. Der eigene Rabatt jeder Zeile.
    final list = [for (final l in lines) l.goodsCents];
    final own = [
      for (var i = 0; i < lines.length; i++)
        lines[i].discount?.of(list[i]) ?? 0,
    ];
    final after = [for (var i = 0; i < lines.length; i++) list[i] - own[i]];
    // 2. Der Bon-Rabatt vom Warenwert nach Zeilen-Rabatten.
    final subtotal = after.fold(0, (s, c) => s + c);
    final receipt = discount?.of(subtotal) ?? 0;
    // 3. Auf die Zeilen verteilt.
    final share = allocate(receipt, [for (final a in after) a < 0 ? 0 : a]);
    // 4. Der Rabatt jeder Zeile auf ihre Steuersätze verteilt.
    return CartPricing(
      lines: [
        for (var i = 0; i < lines.length; i++)
          LinePricing(
            listCents: list[i],
            ownDiscountCents: own[i],
            shareCents: share[i],
            depositCents: lines[i].depositCents,
            grossByRate: _afterDiscount(
              lines[i].listGrossByRate,
              own[i] + share[i],
            ),
          ),
      ],
      subtotalCents: subtotal,
      receiptDiscountCents: receipt,
    );
  }

  /// Warenwert nach Rabatt, ohne Pfand.
  int get goodsCents => pricing.goodsCents;

  int get depositCents => lines.fold(0, (sum, l) => sum + l.depositCents);

  /// Warenwert nach Rabatt plus Pfand.
  int get totalCents => pricing.totalCents;

  bool get isEmpty => lines.isEmpty;

  Map<String, dynamic> toJson() => {
    'lines': [
      for (final l in lines)
        {
          'lineId': l.lineId,
          'itemId': l.item.id,
          'quantity': l.quantity,
          'optionIds': [for (final o in l.options) o.id],
          if (l.discount != null) 'discount': l.discount!.toJson(),
        },
    ],
    if (discount != null) 'discount': discount!.toJson(),
  };

  /// Der Bon gegen einen (geänderten) Katalog neu aufgelöst: Zeilenkennung,
  /// Menge, Options-Ids und Rabatte bleiben, Artikel und Optionen kommen aus
  /// [catalog].
  /// Es gelten dieselben Regeln wie in [fromJson], zum Beispiel fallen Zeilen
  /// weg, die es nicht mehr gibt.
  Cart rebind(Catalog catalog) => fromJson(toJson(), catalog);

  /// Zeilen, deren Artikel oder Option es im Katalog nicht mehr gibt, mit
  /// Menge unter 1, mit falschen Typen oder mit doppelter Kennung fallen weg.
  /// Ein unlesbarer Rabatt fällt weg, die Zeile bleibt. Ein Entwurf ohne
  /// Rabatte (aus 1.10.0) wird gelesen wie bisher. Das Lesen wirft nie wegen
  /// des Inhalts.
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
        for (final g
            in catalog.templateOf(item)?.groups ?? const <ModifierGroup>[])
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
      lines.add(
        CartLine(
          lineId: lineId,
          item: item,
          quantity: _cap(quantity),
          options: options,
          discount: Discount.fromJson(raw['discount']),
        ),
      );
    }
    return Cart._(
      lines,
      lines.isEmpty ? null : Discount.fromJson(json['discount']),
    );
  }
}

int _cap(int q) => q > maxQuantity ? maxQuantity : q;

/// Zieht [discountCents] von den Beträgen je Satz ab, verteilt nach den
/// Beträgen über 0, in der Reihenfolge von [TaxRate.values]. Alle Sätze aus
/// [gross] bleiben drin, in ihrer Reihenfolge.
Map<TaxRate, int> _afterDiscount(Map<TaxRate, int> gross, int discountCents) {
  final rates = [
    for (final r in TaxRate.values)
      if (gross.containsKey(r)) r,
  ];
  final cut = allocate(discountCents, [
    for (final r in rates) gross[r]! < 0 ? 0 : gross[r]!,
  ]);
  final cutOf = {for (var i = 0; i < rates.length; i++) rates[i]: cut[i]};
  return {for (final e in gross.entries) e.key: e.value - cutOf[e.key]!};
}
