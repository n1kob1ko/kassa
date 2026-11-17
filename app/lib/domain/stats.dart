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
  const CategoryStat({required this.name, required this.cents});

  final String name;
  final int cents;
}

class Overview {
  const Overview({
    required this.revenueCents,
    required this.previousRevenueCents,
    required this.receiptCount,
    required this.buckets,
    required this.cashCents,
    required this.cardCents,
    required this.topItems,
    required this.byCategory,
  });

  final int revenueCents;
  final int previousRevenueCents;

  /// Verkaufs-Bons minus Storno-Bons.
  final int receiptCount;
  final List<Bucket> buckets;
  final int cashCents;
  final int cardCents;

  /// Höchstens fünf, nach Menge.
  final List<ItemStat> topItems;

  /// Absteigend nach Betrag, das Pfand als eigene Zeile am Ende.
  final List<CategoryStat> byCategory;
}
