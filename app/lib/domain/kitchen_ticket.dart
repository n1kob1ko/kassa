// Aufbau des Küchenbons: aus einem gespeicherten Bon, dem Wörterbuch und der
// Küchensprache die Zeilen des Zettels. Reines Dart, ohne Flutter. Keine
// Preise, keine Summe. Gezeichnet und gedruckt wird er an anderer Stelle.

import '../core/app_language.dart';
import 'catalog.dart';
import 'menu_dictionary.dart';
import 'receipt.dart';

/// Wofür der Zettel gedruckt wird.
enum KitchenTicketKind { order, voided, copy, sample }

class KitchenLine {
  const KitchenLine({
    required this.quantity,
    required this.name,
    this.info,
    this.options = const [],
  });

  /// Immer positiv, auch beim Storno-Bon.
  final int quantity;
  final String name;
  final String? info;
  final List<String> options;
}

class KitchenTicket {
  const KitchenTicket({
    required this.language,
    required this.kind,
    required this.title,
    this.banner,
    required this.number,
    required this.time,
    required this.staffName,
    required this.lines,
  });

  final AppLanguage language;
  final KitchenTicketKind kind;

  /// "KÜCHE" in der Küchensprache.
  final String title;

  /// "STORNO", "KOPIE" oder "PROBE" in der Küchensprache, sonst `null`.
  final String? banner;
  final int number;
  final DateTime time;
  final String staffName;
  final List<KitchenLine> lines;
}

/// Die festen Texte des Zettels in der Küchensprache.
class KitchenTexts {
  const KitchenTexts({
    required this.title,
    required this.voided,
    required this.copy,
    required this.sample,
  });

  final String title;
  final String voided;
  final String copy;
  final String sample;
}

/// `null`, wenn der Bon kein Verkauf oder Storno ist oder keine Zeile für die
/// Küche hat. Ein Artikel, den [categoryOfItem] nicht kennt (gelöscht), zählt
/// als Küche.
KitchenTicket? buildKitchenTicket(
  Receipt receipt, {
  required AppLanguage language,
  required KitchenTexts texts,
  required MenuDictionary dictionary,
  required Map<String, String> categoryOfItem,
  required Set<String> skipCategories,
  bool copy = false,
  int? voidedNumber,
}) {
  final isVoid = receipt.kind == ReceiptKind.voided;
  if (receipt.kind != ReceiptKind.sale && !isVoid) return null;

  final lines = [
    for (final l in receipt.lines)
      if (!skipCategories.contains(categoryOfItem[l.itemId]))
        KitchenLine(
          quantity: l.quantity.abs(),
          name: dictionary.text(l.name, language),
          info: dictionary.textOrNull(l.info, language),
          options: [
            for (final o in l.options) dictionary.text(o.optionName, language),
          ],
        ),
  ];
  if (lines.isEmpty) return null;

  final kind = isVoid
      ? KitchenTicketKind.voided
      : copy
      ? KitchenTicketKind.copy
      : KitchenTicketKind.order;
  return KitchenTicket(
    language: language,
    kind: kind,
    title: texts.title,
    banner: switch (kind) {
      KitchenTicketKind.voided => texts.voided,
      KitchenTicketKind.copy => texts.copy,
      _ => null,
    },
    number: isVoid ? (voidedNumber ?? receipt.number) : receipt.number,
    time: receipt.createdAt,
    staffName: receipt.staffName,
    lines: lines,
  );
}

/// Beispiel-Küchenbon für die Vorschau und die Probe: die ersten drei aktiven
/// Artikel aus Kategorien für die Küche mit Anzahl 2, 1, 1; beim ersten bis zu
/// zwei Optionen seiner Vorlage (je Gruppe die vorgewählte, sonst die erste).
/// Gibt es keinen solchen Artikel, steht eine Zeile mit dem Probe-Text da.
KitchenTicket sampleKitchenTicket(
  Catalog catalog, {
  required AppLanguage language,
  required KitchenTexts texts,
  required MenuDictionary dictionary,
  required Set<String> skipCategories,
  required DateTime now,
}) {
  final items = [
    for (final i in catalog.items)
      if (i.inSale && !skipCategories.contains(i.categoryId)) i,
  ].take(3).toList();

  const quantities = [2, 1, 1];
  final lines = <KitchenLine>[];
  for (var n = 0; n < items.length; n++) {
    final item = items[n];
    final options = <String>[];
    final template = n == 0 ? catalog.templateOf(item) : null;
    if (template != null) {
      for (final group in template.groups) {
        if (options.length == 2) break;
        if (group.options.isEmpty) continue;
        final option = group.options.firstWhere(
          (o) => o.isDefault,
          orElse: () => group.options.first,
        );
        options.add(dictionary.text(option.name, language));
      }
    }
    lines.add(
      KitchenLine(
        quantity: quantities[n],
        name: dictionary.text(item.name, language),
        info: dictionary.textOrNull(item.info, language),
        options: options,
      ),
    );
  }
  if (lines.isEmpty) {
    lines.add(KitchenLine(quantity: 1, name: texts.sample));
  }
  return KitchenTicket(
    language: language,
    kind: KitchenTicketKind.sample,
    title: texts.title,
    banner: texts.sample,
    number: 128,
    time: now,
    staffName: texts.sample,
    lines: lines,
  );
}
