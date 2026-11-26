import 'package:material_ui/material_ui.dart';

import '../../domain/catalog.dart';
import '../../l10n/generated/l10n.dart';
import '../../ui/segmented.dart';
import '../../ui/tokens.dart';
import 'item_tile.dart';

/// Wie viele Spalten bei dieser Breite der Rasterfläche: Richtwert
/// Spaltenbreite 157, Abstand 10. 692 - 32 dp ergeben genau 4.
int itemGridColumns(double width) {
  const target = 157.0;
  final n = ((width + KassaTokens.gridGap) / (target + KassaTokens.gridGap))
      .floor();
  return n < 1 ? 1 : n;
}

/// Die Artikelfläche: Titelzeile mit dem Umschalter "Mit Bildern" / "Kompakt"
/// und darunter das Raster der Artikeltasten.
class ItemArea extends StatelessWidget {
  const ItemArea({
    super.key,
    required this.title,
    required this.items,
    required this.quantities,
    required this.showImages,
    required this.onShowImages,
    required this.onItem,
  });

  final String title;
  final List<Item> items;

  /// Menge je Artikel-Id auf dem Bon.
  final Map<String, int> quantities;
  final bool showImages;
  final ValueChanged<bool> onShowImages;
  final ValueChanged<Item> onItem;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final l = L10n.of(context);
    final rowHeight = showImages
        ? KassaTokens.gridRowHeightImage
        : KassaTokens.gridRowHeightCompact;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 56,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LayoutBuilder(
              builder: (context, box) => Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 11),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              key: const Key('area-title'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.headlineMedium,
                            ),
                          ),
                          // Auf schmaler Fläche hat die Anzahl keinen Platz.
                          if (box.maxWidth >= 520) ...[
                            const SizedBox(width: KassaTokens.spaceLg),
                            Text(
                              l.kassaItemCount(items.length),
                              maxLines: 1,
                              style: text.bodySmall!.copyWith(
                                fontSize: 14,
                                color: c.ink2,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: KassaTokens.spaceLg),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Segmented<bool>(
                      segments: [
                        (true, l.kassaWithImages),
                        (false, l.kassaCompact),
                      ],
                      // In jeder Sprache dieselben Schlüssel.
                      keyFor: (images) => Key(
                        images ? 'segment-Mit Bildern' : 'segment-Kompakt',
                      ),
                      selected: showImages,
                      onSelected: onShowImages,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) {
              final columns = itemGridColumns(box.maxWidth - 32);
              return GridView.builder(
                key: const Key('item-grid'),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: KassaTokens.gridGap,
                  crossAxisSpacing: KassaTokens.gridGap,
                  mainAxisExtent: rowHeight,
                ),
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final item = items[i];
                  return ItemTile(
                    key: Key('item-${item.id}'),
                    item: item,
                    quantity: quantities[item.id] ?? 0,
                    showImage: showImages,
                    onTap: () => onItem(item),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
