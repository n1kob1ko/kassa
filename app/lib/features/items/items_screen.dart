import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/providers.dart';
import '../../domain/catalog.dart';
import '../../ui/tokens.dart';
import '../kassa/category_rail.dart';
import 'item_detail.dart';
import 'item_row.dart';

/// Der Bereich Artikel (nur Chef): Kategorien links, die Artikel der Kategorie
/// in der Mitte, der gewählte Artikel rechts in der festen Spalte. Jede
/// Änderung wird sofort geschrieben, die Ansicht folgt dem Katalog. Namen,
/// Fotos und neue Artikel gibt es hier nicht.
class ItemsScreen extends ConsumerStatefulWidget {
  const ItemsScreen({super.key});

  @override
  ConsumerState<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends ConsumerState<ItemsScreen> {
  String? _categoryId;
  String? _itemId;
  bool _editingPrice = false;
  bool _failed = false;

  void _selectCategory(String id) => setState(() {
    _categoryId = id;
    _itemId = null;
    _editingPrice = false;
    _failed = false;
  });

  void _selectItem(String id) => setState(() {
    _itemId = id;
    _editingPrice = false;
    _failed = false;
  });

  /// Schreibt die Änderung. Bei einem Fehler bleibt der alte Wert stehen und
  /// die Detailspalte zeigt den Hinweis. Antwort: ob es geklappt hat.
  Future<bool> _update(
    String id, {
    int? priceCents,
    bool? inSale,
    bool? favorite,
    int? depositCents,
    Set<ItemTag>? tags,
  }) async {
    try {
      await ref
          .read(catalogRepositoryProvider)
          .updateItem(
            id,
            priceCents: priceCents,
            inSale: inSale,
            favorite: favorite,
            depositCents: depositCents,
            tags: tags,
          );
      if (mounted) setState(() => _failed = false);
      return true;
    } catch (_) {
      if (mounted) setState(() => _failed = true);
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final catalog = ref.watch(catalogStreamProvider).value;
    if (catalog == null) return ColoredBox(color: c.ground);

    final entries = [
      for (final k in catalog.categories)
        CategoryEntry(
          id: k.id,
          name: k.name,
          count: catalog.items.where((i) => i.categoryId == k.id).length,
        ),
    ];
    final category =
        catalog.categories.where((k) => k.id == _categoryId).firstOrNull ??
        catalog.categories.firstOrNull;
    final items = [
      for (final i in catalog.items)
        if (i.categoryId == category?.id) i,
    ];
    final selected =
        items.where((i) => i.id == _itemId).firstOrNull ?? items.firstOrNull;

    final radius = BorderRadius.circular(KassaTokens.radiusCard);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CategoryRail(
          entries: entries,
          selectedId: category?.id,
          onSelected: _selectCategory,
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: KassaTokens.receiptHeaderHeight,
                  child: Row(
                    children: [
                      Text('Artikel', style: text.headlineMedium),
                      const SizedBox(width: KassaTokens.spaceLg),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            '${category?.name ?? ''}, ${items.length} Artikel',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.labelLarge!.copyWith(
                              fontWeight: FontWeight.w600,
                              color: c.ink2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: c.card,
                      borderRadius: radius,
                      border: Border.all(
                        color: c.line,
                        width: KassaTokens.borderThin,
                      ),
                      boxShadow: c.cardShadow,
                    ),
                    child: ClipRRect(
                      borderRadius: radius,
                      child: Column(
                        children: [
                          const ItemListHeader(),
                          Expanded(
                            child: ListView.builder(
                              key: const Key('item-list'),
                              itemCount: items.length,
                              itemBuilder: (context, i) {
                                final item = items[i];
                                return ItemRow(
                                  key: ValueKey(item.id),
                                  item: item,
                                  template: catalog.templateOf(item),
                                  selected: item.id == selected?.id,
                                  onSelect: () => _selectItem(item.id),
                                  onFavorite: (v) =>
                                      _update(item.id, favorite: v),
                                  onInSale: (v) => _update(item.id, inSale: v),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        ItemDetail(
          key: ValueKey(selected?.id),
          item: selected,
          categoryName: category?.name ?? '',
          template: selected == null ? null : catalog.templateOf(selected),
          editingPrice: _editingPrice,
          failed: _failed,
          onEditPrice: () => setState(() => _editingPrice = true),
          onCancelPrice: () => setState(() => _editingPrice = false),
          onSavePrice: (cents) async {
            final ok = await _update(selected!.id, priceCents: cents);
            if (ok && mounted) setState(() => _editingPrice = false);
          },
          onDeposit: (cents) => _update(selected!.id, depositCents: cents),
          onTag: (tag, on) => _update(
            selected!.id,
            tags: {
              for (final t in selected.tags)
                if (t != tag) t,
              if (on) tag,
            },
          ),
        ),
      ],
    );
  }
}
