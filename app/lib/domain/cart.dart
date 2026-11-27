// Der offene Bon: Auswahl von Optionen, Bon-Zeilen und Rabatte.
// Reines Dart, unveränderlich: jede Änderung liefert ein neues Objekt.

import 'package:uuid/uuid.dart';

import 'catalog.dart';
import 'discount.dart';

const int maxQuantity = 99;

/// Der höchste freie Betrag: 9.999,99 €.
const openAmountMaxCents = 999999;

/// Die Sätze für einen freien Betrag: 20, 10, 13 und 0 %.
const openAmountRates = [
  TaxRate.normal,
  TaxRate.reduced1,
  TaxRate.reduced2,
  TaxRate.zero,
];

const _openAmountPrefix = 'open-amount-';

/// Die Kennung des Artikels eines freien Betrags, etwa `open-amount-20`.
String openAmountItemId(TaxRate rate) => '$_openAmountPrefix${rate.percent}';

/// Ob [itemId] die Kennung eines freien Betrags ist.
bool isOpenAmountItemId(String itemId) => itemId.startsWith(_openAmountPrefix);

/// So steht ein freier Betrag am Bon, immer deutsch: "Diverses 20 %".
String openAmountName(TaxRate rate) => 'Diverses ${rate.percent} %';

/// Der Artikel eines freien Betrags: entsteht im Code, nie im Katalog.
Item _openAmountItem(int cents, TaxRate rate) => Item(
  id: openAmountItemId(rate),
  name: openAmountName(rate),
  priceCents: cents,
  categoryId: '',
  taxRate: rate,
  position: 0,
);

bool _isOpenAmountCents(Object? cents) =>
    cents is int && cents >= 1 && cents <= openAmountMaxCents;

const _depositReturnPrefix = 'deposit-return-';

/// Die Kennung des Artikels "Pfand zurück" für [depositCents], etwa
/// `deposit-return-25`.
String depositReturnItemId(int depositCents) =>
    '$_depositReturnPrefix$depositCents';

/// Ob [itemId] die Kennung einer Zeile "Pfand zurück" ist.
bool isDepositReturnItemId(String itemId) =>
    itemId.startsWith(_depositReturnPrefix);

/// So steht eine Zeile "Pfand zurück" am Bon, immer deutsch.
const depositReturnName = 'Pfand zurück';

/// Der Artikel "Pfand zurück": Preis 0, Pfand -[depositCents], Satz 0.
/// Entsteht im Code, nie im Katalog.
Item _depositReturnItem(int depositCents) => Item(
  id: depositReturnItemId(depositCents),
  name: depositReturnName,
  priceCents: 0,
  categoryId: '',
  taxRate: TaxRate.zero,
  depositCents: -depositCents,
  position: 0,
);

/// Die Kennung des Artikels einer Gutschein-Zeile (ein verkaufter Gutschein).
const voucherSaleItemId = 'voucher-sale';

/// Ob [itemId] die Kennung einer Gutschein-Zeile ist.
bool isVoucherSaleItemId(String itemId) => itemId == voucherSaleItemId;

/// So steht eine Gutschein-Zeile am Bon, immer deutsch.
const voucherSaleName = 'Gutschein';

/// Der kleinste Wert eines Gutscheins: 1,00 €.
const voucherMinCents = 100;

/// Der größte Wert eines Gutscheins: 500,00 €.
const voucherMaxCents = 50000;

/// Die Tasten für den Wert eines Gutscheins: 10, 20, 25 und 50 €.
const voucherPresetCents = [1000, 2000, 2500, 5000];

bool _isVoucherCents(Object? cents) =>
    cents is int && cents >= voucherMinCents && cents <= voucherMaxCents;

/// Der Artikel einer Gutschein-Zeile: Preis [valueCents], Satz 0. Entsteht im
/// Code, nie im Katalog.
Item _voucherSaleItem(int valueCents) => Item(
  id: voucherSaleItemId,
  name: voucherSaleName,
  priceCents: valueCents,
  categoryId: '',
  taxRate: TaxRate.zero,
  position: 0,
);

/// Ob [itemId] für Zeilen vergeben ist, die im Code entstehen (freier Betrag,
/// Pfand zurück, Gutschein). Eine Speisekarte darf solche Kennungen nicht
/// haben, und auf den Küchenbon kommen diese Zeilen nie.
bool isReservedItemId(String itemId) =>
    isOpenAmountItemId(itemId) ||
    isDepositReturnItemId(itemId) ||
    isVoucherSaleItemId(itemId);

/// Ein Gutschein, der am offenen Bon zum Bezahlen gewählt ist. Abgebucht wird
/// erst beim Abschließen.
class AppliedVoucher {
  const AppliedVoucher({
    required this.voucherId,
    required this.code,
    required this.balanceCents,
  });

  final String voucherId;

  /// Der Code aus 8 Ziffern, nur zum Tippen.
  final String code;

  /// Das Guthaben, als der Gutschein gewählt (oder zuletzt gelesen) wurde.
  final int balanceCents;
}

/// Was ein gewählter Gutschein von diesem Bon deckt.
class VoucherUse {
  const VoucherUse({
    required this.voucherId,
    required this.code,
    required this.amountCents,
    required this.balanceAfterCents,
  });

  final String voucherId;
  final String code;

  /// Über 0, höchstens das Guthaben.
  final int amountCents;

  /// Das Guthaben nach diesem Bon.
  final int balanceAfterCents;
}

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
    this.isOpenAmount = false,
    this.isDepositReturn = false,
    this.isVoucherSale = false,
  });

  final String lineId;
  final Item item;
  final int quantity;
  final List<ModifierOption> options;

  /// Rabatt auf diese Zeile.
  final Discount? discount;

  /// Ein freier Betrag: der Artikel entsteht im Code, nicht im Katalog.
  final bool isOpenAmount;

  /// Eine Zeile "Pfand zurück": Preis 0, Pfand unter 0, höchstens eine je
  /// Betrag.
  final bool isDepositReturn;

  /// Eine Gutschein-Zeile: ein verkaufter Gutschein, Menge 1, nie Rabatt.
  final bool isVoucherSale;

  /// Zeilen, die nie Rabatt bekommen.
  bool get _takesNoDiscount => isDepositReturn || isVoucherSale;

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
    isOpenAmount: isOpenAmount,
    isDepositReturn: isDepositReturn,
    isVoucherSale: isVoucherSale,
  );

  CartLine withDiscount(Discount? d) => CartLine(
    lineId: lineId,
    item: item,
    quantity: quantity,
    options: options,
    discount: d,
    isOpenAmount: isOpenAmount,
    isDepositReturn: isDepositReturn,
    isVoucherSale: isVoucherSale,
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
    this.voucherSaleCents = 0,
    this.voucherUses = const [],
  });

  final List<LinePricing> lines;

  /// Warenwert nach Zeilen-Rabatten, vor dem Bon-Rabatt. Die Gutschein-Zeilen
  /// stehen drin; der Bon-Rabatt rechnet aber ohne sie.
  final int subtotalCents;

  final int receiptDiscountCents;

  /// Summe der Gutschein-Zeilen (verkaufte Gutscheine). Steht im Warenwert.
  final int voucherSaleCents;

  /// Wovon der Bon-Rabatt rechnet und woran er gekappt wird: die
  /// Zwischensumme ohne die Gutschein-Zeilen.
  int get discountBaseCents => _discountBase(subtotalCents, voucherSaleCents);

  static int _discountBase(int subtotalCents, int voucherSaleCents) =>
      subtotalCents - voucherSaleCents;

  /// Was die gewählten Gutscheine decken, in ihrer Reihenfolge; ein
  /// Gutschein, der nichts deckt, fehlt.
  final List<VoucherUse> voucherUses;

  /// Was die gewählten Gutscheine zusammen decken.
  int get voucherCents => voucherUses.fold(0, (s, u) => s + u.amountCents);

  /// Noch zu zahlen: die Summe des Bons ohne das, was Gutscheine decken.
  int get dueCents => totalCents - voucherCents;

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
  const Cart._(this.lines, [this.discount, this.vouchers = const []]);

  const Cart.empty() : lines = const [], discount = null, vouchers = const [];

  final List<CartLine> lines;

  /// Rabatt auf den ganzen Bon. Ein leerer Bon hat keinen.
  final Discount? discount;

  /// Die zum Bezahlen gewählten Gutscheine, in der Reihenfolge des Einlösens.
  /// Ein leerer Bon und ein Bon mit Gutschein-Zeile haben keine.
  final List<AppliedVoucher> vouchers;

  /// Ein Bon aus [next] mit dem Bon-Rabatt und den Gutscheinen dieses Bons;
  /// ein leerer Bon verliert beides.
  Cart _withLines(List<CartLine> next) =>
      next.isEmpty ? Cart._(next) : Cart._(next, discount, vouchers);

  Cart _withVouchers(List<AppliedVoucher> next) =>
      Cart._(lines, discount, List.unmodifiable(next));

  CartLine? _line(String lineId) {
    for (final l in lines) {
      if (l.lineId == lineId) return l;
    }
    return null;
  }

  Cart add(
    Item item, {
    List<ModifierOption> options = const [],
    String? lineId,
  }) {
    if (item.templateId == null && options.isEmpty) {
      final i = lines.indexWhere(
        (l) =>
            l.item.id == item.id &&
            l.options.isEmpty &&
            !l.isOpenAmount &&
            !l._takesNoDiscount,
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

  /// Ein freier Betrag als neue Zeile mit Menge 1; zwei freie Beträge
  /// verschmelzen nie. Wirft [ArgumentError] bei einem Betrag unter 1 Cent
  /// oder über [openAmountMaxCents] und bei einem Satz außerhalb von
  /// [openAmountRates].
  Cart addOpenAmount({
    required int amountCents,
    required TaxRate rate,
    String? lineId,
  }) {
    if (!_isOpenAmountCents(amountCents)) {
      throw ArgumentError.value(amountCents, 'amountCents');
    }
    if (!openAmountRates.contains(rate)) {
      throw ArgumentError.value(rate, 'rate');
    }
    return _withLines([
      ...lines,
      CartLine(
        lineId: lineId ?? _uuid.v4(),
        item: _openAmountItem(amountCents, rate),
        quantity: 1,
        isOpenAmount: true,
      ),
    ]);
  }

  /// Die Zeile "Pfand zurück" für [depositCents] mit [quantity]; höchstens
  /// eine Zeile je Betrag. Gibt es sie schon, ändert sich nur die Menge, an
  /// ihrer Stelle. Menge 0 nimmt sie weg. Wirft [ArgumentError] bei einem
  /// Betrag unter 1 Cent oder einer Menge außerhalb 0 bis [maxQuantity].
  Cart setDepositReturn({required int depositCents, required int quantity}) {
    if (depositCents < 1) {
      throw ArgumentError.value(depositCents, 'depositCents');
    }
    if (quantity < 0 || quantity > maxQuantity) {
      throw ArgumentError.value(quantity, 'quantity');
    }
    final id = depositReturnItemId(depositCents);
    final i = lines.indexWhere((l) => l.isDepositReturn && l.item.id == id);
    if (quantity == 0) return i < 0 ? this : remove(lines[i].lineId);
    if (i >= 0) return setQuantity(lines[i].lineId, quantity);
    return _withLines([
      ...lines,
      CartLine(
        lineId: _uuid.v4(),
        item: _depositReturnItem(depositCents),
        quantity: quantity,
        isDepositReturn: true,
      ),
    ]);
  }

  /// Die Menge der Zeile "Pfand zurück" für [depositCents]; 0 ohne Zeile.
  int depositReturnQuantity(int depositCents) {
    final id = depositReturnItemId(depositCents);
    for (final l in lines) {
      if (l.isDepositReturn && l.item.id == id) return l.quantity;
    }
    return 0;
  }

  /// Ein verkaufter Gutschein als neue Zeile mit Menge 1; zwei verschmelzen
  /// nie. Wirft [ArgumentError] bei einem Wert außerhalb [voucherMinCents]
  /// bis [voucherMaxCents] und [StateError], wenn Gutscheine zum Bezahlen
  /// gewählt sind.
  Cart addVoucherSale({required int valueCents, String? lineId}) {
    if (vouchers.isNotEmpty) {
      throw StateError('Der Bon wird mit einem Gutschein bezahlt.');
    }
    if (!_isVoucherCents(valueCents)) {
      throw ArgumentError.value(valueCents, 'valueCents');
    }
    return _withLines([
      ...lines,
      CartLine(
        lineId: lineId ?? _uuid.v4(),
        item: _voucherSaleItem(valueCents),
        quantity: 1,
        isVoucherSale: true,
      ),
    ]);
  }

  /// Ob auf dem Bon ein Gutschein verkauft wird.
  bool get hasVoucherSale => lines.any((l) => l.isVoucherSale);

  /// Wählt [voucher] zum Bezahlen, nach den schon gewählten. Wirft
  /// [StateError] bei einem leeren Bon, bei einem Bon mit Gutschein-Zeile und
  /// wenn derselbe Gutschein schon gewählt ist.
  Cart applyVoucher(AppliedVoucher voucher) {
    if (lines.isEmpty) throw StateError('Der Bon ist leer.');
    if (hasVoucherSale) {
      throw StateError('Auf dem Bon wird ein Gutschein verkauft.');
    }
    if (vouchers.any((v) => v.voucherId == voucher.voucherId)) {
      throw StateError('Der Gutschein ist schon gewählt.');
    }
    return _withVouchers([...vouchers, voucher]);
  }

  /// Nimmt den gewählten Gutschein [voucherId] weg.
  Cart removeVoucher(String voucherId) => _withVouchers([
    for (final v in vouchers)
      if (v.voucherId != voucherId) v,
  ]);

  /// Der gewählte Gutschein [voucherId] mit neuem Guthaben, an seiner Stelle.
  Cart withVoucherBalance(String voucherId, int balanceCents) => _withVouchers([
    for (final v in vouchers)
      v.voucherId == voucherId
          ? AppliedVoucher(
              voucherId: v.voucherId,
              code: v.code,
              balanceCents: balanceCents,
            )
          : v,
  ]);

  /// Menge 0 oder darunter nimmt die Zeile weg. Wirft [ArgumentError] bei
  /// einer Gutschein-Zeile und einer Menge über 1.
  Cart setQuantity(String lineId, int quantity) {
    if (quantity <= 0) return remove(lineId);
    if (quantity > 1 && (_line(lineId)?.isVoucherSale ?? false)) {
      throw ArgumentError.value(quantity, 'quantity', 'Gutschein-Zeile');
    }
    return _withLines([
      for (final l in lines)
        l.lineId == lineId ? l.withQuantity(_cap(quantity)) : l,
    ]);
  }

  Cart remove(String lineId) => _withLines([
    for (final l in lines)
      if (l.lineId != lineId) l,
  ]);

  /// Setzt den Rabatt der Zeile [lineId]; null nimmt ihn weg. Wirft
  /// [ArgumentError] bei einem Rabatt auf "Pfand zurück" oder eine
  /// Gutschein-Zeile.
  Cart setLineDiscount(String lineId, Discount? discount) {
    if (discount != null && (_line(lineId)?._takesNoDiscount ?? false)) {
      throw ArgumentError.value(lineId, 'lineId', 'Zeile ohne Rabatt');
    }
    return _withLines([
      for (final l in lines) l.lineId == lineId ? l.withDiscount(discount) : l,
    ]);
  }

  /// Setzt den Rabatt auf den ganzen Bon; null nimmt ihn weg. Ein leerer Bon
  /// bekommt keinen.
  Cart setReceiptDiscount(Discount? discount) =>
      Cart._(lines, lines.isEmpty ? null : discount, vouchers);

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
    // 2. Der Bon-Rabatt vom Warenwert nach Zeilen-Rabatten, ohne die
    // Gutschein-Zeilen.
    final subtotal = after.fold(0, (s, c) => s + c);
    var voucherSale = 0;
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].isVoucherSale) voucherSale += after[i];
    }
    final receipt =
        discount?.of(CartPricing._discountBase(subtotal, voucherSale)) ?? 0;
    // 3. Auf die Zeilen verteilt, nie auf Gutschein-Zeilen ("Pfand zurück"
    // hat Warenwert 0).
    final share = allocate(receipt, [
      for (var i = 0; i < lines.length; i++)
        lines[i].isVoucherSale || after[i] < 0 ? 0 : after[i],
    ]);
    // 4. Was die gewählten Gutscheine decken, der Reihe nach.
    var rest = subtotal - receipt + depositCents;
    final uses = <VoucherUse>[];
    for (final v in vouchers) {
      if (rest <= 0) break;
      final balance = v.balanceCents < 0 ? 0 : v.balanceCents;
      final amount = balance < rest ? balance : rest;
      if (amount == 0) continue;
      uses.add(
        VoucherUse(
          voucherId: v.voucherId,
          code: v.code,
          amountCents: amount,
          balanceAfterCents: v.balanceCents - amount,
        ),
      );
      rest -= amount;
    }
    // 5. Der Rabatt jeder Zeile auf ihre Steuersätze verteilt.
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
      voucherSaleCents: voucherSale,
      voucherUses: List.unmodifiable(uses),
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
          if (l.isOpenAmount)
            'open': {
              'cents': l.item.priceCents,
              'taxPercent': l.item.taxRate.percent,
            },
          if (l.isDepositReturn)
            'depositReturn': {'cents': -l.item.depositCents},
          if (l.isVoucherSale) 'voucherSale': {'cents': l.item.priceCents},
        },
    ],
    if (discount != null) 'discount': discount!.toJson(),
    if (vouchers.isNotEmpty)
      'vouchers': [
        for (final v in vouchers)
          {'id': v.voucherId, 'code': v.code, 'balanceCents': v.balanceCents},
      ],
  };

  /// Der Bon gegen einen (geänderten) Katalog neu aufgelöst: Zeilenkennung,
  /// Menge, Options-Ids und Rabatte bleiben, Artikel und Optionen kommen aus
  /// [catalog]. Freie Beträge, "Pfand zurück", Gutschein-Zeilen und gewählte
  /// Gutscheine fragen den Katalog nicht und bleiben.
  /// Es gelten dieselben Regeln wie in [fromJson], zum Beispiel fallen Zeilen
  /// weg, die es nicht mehr gibt.
  Cart rebind(Catalog catalog) => fromJson(toJson(), catalog);

  /// Zeilen, deren Artikel oder Option es im Katalog nicht mehr gibt, mit
  /// Menge unter 1, mit falschen Typen oder mit doppelter Kennung fallen weg.
  /// Ein unlesbarer Rabatt fällt weg, die Zeile bleibt. Eine Zeile mit `open`
  /// ist ein freier Betrag und entsteht ohne den Katalog; ist `open`
  /// unlesbar, außerhalb der Grenzen oder passt nicht zur Kennung, fällt nur
  /// diese Zeile weg. Ebenso entstehen Zeilen mit `depositReturn` ("Pfand
  /// zurück", höchstens eine je Betrag) und `voucherSale` (Gutschein, Menge
  /// 1) ohne den Katalog; unlesbar oder außerhalb der Grenzen fällt die Zeile
  /// weg, ein Rabatt daran fällt weg. Unlesbare gewählte Gutscheine fallen
  /// einzeln weg, alle bei einem leeren Bon oder einem Bon mit Gutschein-Zeile.
  /// Ein Entwurf ohne Rabatte und freie Beträge (aus 1.10.0) oder ohne die
  /// Dinge aus Stufe 1b (aus 1.11.0) wird gelesen wie bisher. Das Lesen wirft
  /// nie wegen des Inhalts.
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
      if (raw.containsKey('open')) {
        final item = _openAmountItemOf(raw['open'], itemId);
        if (item == null || optionIds.isNotEmpty) continue;
        seen.add(lineId);
        lines.add(
          CartLine(
            lineId: lineId,
            item: item,
            quantity: _cap(quantity),
            discount: Discount.fromJson(raw['discount']),
            isOpenAmount: true,
          ),
        );
        continue;
      }
      if (raw.containsKey('depositReturn')) {
        final item = _depositReturnItemOf(raw['depositReturn'], itemId);
        if (item == null || optionIds.isNotEmpty) continue;
        if (lines.any((l) => l.isDepositReturn && l.item.id == itemId)) {
          continue;
        }
        seen.add(lineId);
        lines.add(
          CartLine(
            lineId: lineId,
            item: item,
            quantity: _cap(quantity),
            isDepositReturn: true,
          ),
        );
        continue;
      }
      if (raw.containsKey('voucherSale')) {
        final cents = raw['voucherSale'] is Map
            ? (raw['voucherSale'] as Map)['cents']
            : null;
        if (!_isVoucherCents(cents) || !isVoucherSaleItemId(itemId)) continue;
        if (quantity != 1 || optionIds.isNotEmpty) continue;
        seen.add(lineId);
        lines.add(
          CartLine(
            lineId: lineId,
            item: _voucherSaleItem(cents as int),
            quantity: 1,
            isVoucherSale: true,
          ),
        );
        continue;
      }
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
    if (lines.isEmpty) return const Cart.empty();
    return Cart._(
      lines,
      Discount.fromJson(json['discount']),
      lines.any((l) => l.isVoucherSale)
          ? const []
          : _vouchersOf(json['vouchers']),
    );
  }
}

/// Die gewählten Gutscheine aus dem Feld `vouchers` eines Entwurfs; unlesbare
/// und doppelte fallen weg.
List<AppliedVoucher> _vouchersOf(Object? raw) {
  if (raw is! List) return const [];
  final result = <AppliedVoucher>[];
  for (final v in raw) {
    if (v is! Map) continue;
    final id = v['id'];
    final code = v['code'];
    final balance = v['balanceCents'];
    if (id is! String || code is! String || balance is! int) continue;
    if (result.any((r) => r.voucherId == id)) continue;
    result.add(
      AppliedVoucher(voucherId: id, code: code, balanceCents: balance),
    );
  }
  return List.unmodifiable(result);
}

/// Der Artikel "Pfand zurück" aus dem Feld `depositReturn` eines Entwurfs;
/// null, wenn es unlesbar ist, der Betrag unter 1 Cent liegt oder nicht zu
/// [itemId] passt.
Item? _depositReturnItemOf(Object? raw, String itemId) {
  if (raw is! Map) return null;
  final cents = raw['cents'];
  if (cents is! int || cents < 1) return null;
  if (depositReturnItemId(cents) != itemId) return null;
  return _depositReturnItem(cents);
}

int _cap(int q) => q > maxQuantity ? maxQuantity : q;

/// Der Artikel des freien Betrags aus dem Feld `open` eines Entwurfs; null,
/// wenn es unlesbar ist, außerhalb der Grenzen liegt oder nicht zu [itemId]
/// passt.
Item? _openAmountItemOf(Object? open, String itemId) {
  if (open is! Map) return null;
  final cents = open['cents'];
  final percent = open['taxPercent'];
  if (!_isOpenAmountCents(cents) || percent is! int) return null;
  for (final rate in openAmountRates) {
    if (rate.percent == percent) {
      if (openAmountItemId(rate) != itemId) return null;
      return _openAmountItem(cents as int, rate);
    }
  }
  return null;
}

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
