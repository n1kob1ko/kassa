// Zahlen für die Übersicht. Reines Dart.

enum StatsRange { today, days7, days30 }

/// Ein Balken: eine Stunde (heute) oder ein Kalendertag.
class Bucket {
  const Bucket({required this.label, required this.start, required this.cents});

  final String label;
  final DateTime start;
  final int cents;
}

class ItemStat {
  const ItemStat({
    required this.name,
    required this.quantity,
    required this.cents,
  });

  final String name;
  final int quantity;

  /// Warenwert ohne Pfand.
  final int cents;
}

class CategoryStat {
  const CategoryStat({
    required this.name,
    required this.cents,
    this.deposit = false,
  });

  final String name;
  final int cents;

  /// Die Zeile Pfand (keine Kategorie der Speisekarte). Heißt in den Daten
  /// immer "Pfand"; die Übersicht zeigt sie in der Bediensprache.
  final bool deposit;
}

class Overview {
  const Overview({
    required this.revenueCents,
    required this.previousRevenueCents,
    required this.receiptCount,
    required this.voidCount,
    required this.buckets,
    required this.cashCents,
    required this.cardCents,
    required this.topItems,
    required this.byCategory,
    this.voucherCents = 0,
  });

  /// Summe der Bons ohne verkaufte Gutscheine, ohne Trinkgeld.
  final int revenueCents;
  final int previousRevenueCents;

  /// Verkaufs-Bons minus Storno-Bons.
  final int receiptCount;

  /// Storno-Bons im Zeitraum.
  final int voidCount;
  final List<Bucket> buckets;

  /// Summe der Zahlungen bar, mit Karte und mit Gutschein, ohne Trinkgeld.
  /// Bar und Karte enthalten das Geld für verkaufte Gutscheine und die
  /// Auszahlung von Pfand (mit Minus).
  final int cashCents;
  final int cardCents;
  final int voucherCents;

  /// Höchstens fünf, nach Menge.
  final List<ItemStat> topItems;

  /// Absteigend nach Betrag, das Pfand als eigene Zeile am Ende.
  final List<CategoryStat> byCategory;
}
