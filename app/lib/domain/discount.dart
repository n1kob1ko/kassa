// Rabatt: in Prozent oder als Betrag, mit einem Grund. Reines Dart, kennt den
// Bon nicht. Alle Rechnungen mit ganzen Cent, damit jedes Gerät auf den Cent
// gleich rechnet (Spec 5.4).

enum DiscountReason { regular, staff, complaint, promotion, invitation }

/// 'regular' Stammgast, 'staff' Mitarbeiter, 'complaint' Reklamation,
/// 'promotion' Aktion, 'invitation' Einladung; ein unbekannter Name kommt
/// zurück, wie er ist. Deutsch, für Bon und Berichte.
String discountReasonLabel(String name) => switch (name) {
  'regular' => 'Stammgast',
  'staff' => 'Mitarbeiter',
  'complaint' => 'Reklamation',
  'promotion' => 'Aktion',
  'invitation' => 'Einladung',
  _ => name,
};

/// Die Prozent-Stufen, die die Kassa zum Antippen anbietet.
const discountPercents = [5, 10, 15, 20, 50, 100];

class Discount {
  /// [percent] von 1 bis 100.
  const Discount.percent(int this.percent, this.reason)
    : amountCents = 0,
      assert(percent >= 1 && percent <= 100);

  /// [amountCents] über 0.
  const Discount.amount(this.amountCents, this.reason)
    : percent = null,
      assert(amountCents > 0);

  final int? percent;
  final int amountCents;
  final DiscountReason reason;

  /// Der Rabatt in Cent von [baseCents]: Prozent kaufmännisch gerundet, ein
  /// Betrag höchstens so groß wie der Wert. Auf einen Wert bis 0 gibt es
  /// keinen Rabatt.
  int of(int baseCents) {
    if (baseCents <= 0) return 0;
    final p = percent;
    if (p != null) return (baseCents * p + 50) ~/ 100;
    return amountCents < baseCents ? amountCents : baseCents;
  }

  /// Gleich, wenn Prozent, Betrag und Grund gleich sind.
  @override
  bool operator ==(Object other) =>
      other is Discount &&
      other.percent == percent &&
      other.amountCents == amountCents &&
      other.reason == reason;

  @override
  int get hashCode => Object.hash(percent, amountCents, reason);

  @override
  String toString() => percent != null
      ? 'Discount($percent %, ${reason.name})'
      : 'Discount($amountCents Cent, ${reason.name})';

  Map<String, dynamic> toJson() => {
    if (percent != null) 'percent': percent else 'amountCents': amountCents,
    'reason': reason.name,
  };

  /// Alles Unlesbare ergibt null: kein Objekt, falscher Typ, unbekannter
  /// Grund, Prozent außerhalb 1 bis 100, Betrag bis 0, weder oder beides.
  static Discount? fromJson(Object? json) {
    if (json is! Map) return null;
    final reasonName = json['reason'];
    if (reasonName is! String) return null;
    DiscountReason? reason;
    for (final r in DiscountReason.values) {
      if (r.name == reasonName) reason = r;
    }
    if (reason == null) return null;
    final percent = json['percent'];
    final amount = json['amountCents'];
    if (percent != null && amount != null) return null;
    if (percent is int && percent >= 1 && percent <= 100) {
      return Discount.percent(percent, reason);
    }
    if (amount is int && amount > 0) return Discount.amount(amount, reason);
    return null;
  }
}

/// Verteilt [amountCents] im Verhältnis von [weights] auf Cent genau: jede
/// Stelle bekommt den abgerundeten Anteil, die übrigen Cent gehen je einer an
/// die Stellen mit dem größten Rest, bei gleichem Rest an die frühere Stelle.
/// [ArgumentError] bei einem Betrag unter 0, einem Gewicht unter 0 oder einem
/// Betrag über der Summe der Gewichte.
List<int> allocate(int amountCents, List<int> weights) {
  if (amountCents < 0) {
    throw ArgumentError.value(amountCents, 'amountCents', 'unter 0');
  }
  if (weights.any((w) => w < 0)) {
    throw ArgumentError.value(weights, 'weights', 'ein Gewicht unter 0');
  }
  final total = weights.fold(0, (s, w) => s + w);
  if (amountCents > total) {
    throw ArgumentError.value(amountCents, 'amountCents', 'über $total');
  }
  if (amountCents == 0) return List.filled(weights.length, 0);
  final shares = [for (final w in weights) amountCents * w ~/ total];
  final rests = [for (final w in weights) amountCents * w % total];
  var left = amountCents - shares.fold(0, (s, c) => s + c);
  // Stabil sortiert: bei gleichem Rest bleibt die frühere Stelle vorn.
  final order = [for (var i = 0; i < weights.length; i++) i];
  _stableSortDescending(order, rests);
  for (final i in order) {
    if (left == 0) break;
    shares[i]++;
    left--;
  }
  return shares;
}

/// Ordnet [order] nach [keys] absteigend; Gleichstand behält die Reihenfolge.
void _stableSortDescending(List<int> order, List<int> keys) {
  // Einfügesortieren ist stabil; die Listen sind kurz (Zeilen, Steuersätze).
  for (var i = 1; i < order.length; i++) {
    final v = order[i];
    var j = i - 1;
    while (j >= 0 && keys[order[j]] < keys[v]) {
      order[j + 1] = order[j];
      j--;
    }
    order[j + 1] = v;
  }
}
