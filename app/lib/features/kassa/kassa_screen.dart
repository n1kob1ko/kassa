import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/providers.dart';
import '../../data/settings_repository.dart';
import '../../domain/catalog.dart';
import '../../ui/tokens.dart';
import 'cart_controller.dart';
import 'cart_panel.dart';
import 'category_rail.dart';
import 'item_grid.dart';
import 'modifier_panel.dart';

const _favoritesId = 'favorites';

/// Der Kassenbildschirm: Kategorien links, Artikel (oder das Zusammenstellen)
/// in der Mitte, der offene Bon rechts. [onPayCash] wird mit "Bar" gerufen.
class KassaScreen extends ConsumerStatefulWidget {
  const KassaScreen({super.key, required this.onPayCash});

  final VoidCallback onPayCash;

  @override
  ConsumerState<KassaScreen> createState() => _KassaScreenState();
}

class _KassaScreenState extends ConsumerState<KassaScreen> {
  String? _categoryId;
  Item? _building;

  /// Was die Person eben getippt hat, bis die Datenbank es bestätigt: so
  /// wechselt die Ansicht im selben Bild.
  bool? _imagesOverride;

  void _selectCategory(String id) => setState(() {
    _categoryId = id;
    _building = null;
  });

  void _setImages(bool value) {
    setState(() => _imagesOverride = value);
    final repo = ref.read(settingsRepositoryProvider);
    repo
        .current()
        .then((s) => repo.save(s.copyWith(showImages: value)))
        .catchError((Object _) {});
  }

  void _tapItem(Catalog catalog, Item item) {
    if (catalog.templateOf(item) != null) {
      setState(() => _building = item);
    } else {
      ref.read(cartProvider.notifier).add(item);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    ref.listen(settingsStreamProvider, (_, next) {
      if (next.value?.showImages == _imagesOverride) _imagesOverride = null;
    });
    final catalog = ref.watch(catalogStreamProvider).value;
    final stored = ref.watch(settingsStreamProvider).value ??
        const RegisterSettings();
    final showImages = _imagesOverride ?? stored.showImages;
    final cart = ref.watch(cartProvider);
    final cartCtl = ref.read(cartProvider.notifier);
    if (catalog == null) return ColoredBox(color: c.ground);

    final favorites = [for (final i in catalog.items) if (i.favorite) i];
    final entries = [
      if (favorites.isNotEmpty)
        CategoryEntry(
          id: _favoritesId,
          name: 'Favoriten',
          count: favorites.length,
          isFavorites: true,
        ),
      for (final k in catalog.categories)
        CategoryEntry(
          id: k.id,
          name: k.name,
          count: catalog.items.where((i) => i.categoryId == k.id).length,
        ),
    ];
    final selected = entries.any((e) => e.id == _categoryId)
        ? _categoryId
        : (entries.isEmpty ? null : entries.first.id);
    final entry = entries.where((e) => e.id == selected).firstOrNull;
    final items = selected == _favoritesId
        ? favorites
        : [for (final i in catalog.items) if (i.categoryId == selected) i];
    final quantities = <String, int>{};
    for (final l in cart.lines) {
      quantities[l.item.id] = (quantities[l.item.id] ?? 0) + l.quantity;
    }
    final building = _building;
    final template = building == null ? null : catalog.templateOf(building);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CategoryRail(
          entries: entries,
          selectedId: selected,
          onSelected: _selectCategory,
        ),
        Expanded(
          child: building != null && template != null
              ? ModifierPanel(
                  key: Key('builder-${building.id}'),
                  item: building,
                  template: template,
                  onCancel: () => setState(() => _building = null),
                  onAdd: (options) {
                    cartCtl.add(building, options: options);
                    setState(() => _building = null);
                  },
                )
              : ItemArea(
                  title: entry?.name ?? '',
                  items: items,
                  quantities: quantities,
                  showImages: showImages,
                  onShowImages: _setImages,
                  onItem: (item) => _tapItem(catalog, item),
                ),
        ),
        CartPanel(onPayCash: widget.onPayCash, canPay: building == null),
      ],
    );
  }
}
