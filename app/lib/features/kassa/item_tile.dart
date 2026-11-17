import 'dart:io';

import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/money.dart';
import '../../domain/catalog.dart';
import '../../ui/pressable.dart';
import '../../ui/tokens.dart';

/// Artikeltaste: mit Bild (ca. 157 x 157) oder kompakt (Zeilenhöhe 90).
/// [quantity] ist die Menge dieses Artikels auf dem Bon (0: nicht darauf).
/// Ein Artikel, der nicht im Verkauf ist, ist ausgeschaltet.
class ItemTile extends StatelessWidget {
  const ItemTile({
    super.key,
    required this.item,
    required this.quantity,
    required this.showImage,
    required this.onTap,
  });

  final Item item;
  final int quantity;
  final bool showImage;
  final VoidCallback onTap;

  static String? extraText(Item item) =>
      item.info ?? (item.depositCents > 0 ? '+ Pfand' : null);

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final instant = MediaQuery.disableAnimationsOf(context);
    final selected = quantity > 0;
    final label = [
      item.name,
      if (item.inSale) formatEuro(item.priceCents) else 'Nicht im Verkauf',
      if (selected) '$quantity auf dem Bon',
    ].join(', ');
    final radius = showImage ? KassaTokens.radiusXxl : KassaTokens.radiusXl;
    final body = showImage
        ? _ImageBody(item: item, selected: selected)
        : _CompactBody(item: item);
    return Pressable(
      onTap: item.inSale ? onTap : null,
      semanticLabel: label,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: AnimatedContainer(
              duration: instant ? Duration.zero : KassaTokens.motionFast,
              curve: Curves.linear,
              padding: showImage
                  ? const EdgeInsets.all(6)
                  : const EdgeInsets.fromLTRB(12, 11, 12, 10),
              decoration: BoxDecoration(
                color: c.card,
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(
                  color: selected ? c.accent : c.line,
                  width: KassaTokens.borderButton,
                ),
                boxShadow: c.cardShadow,
              ),
              child: body,
            ),
          ),
          if (showImage)
            for (final t in _tags(item).take(1))
              Positioned(top: 11, left: 11, child: _TagPill(tag: t, small: false)),
          if (selected)
            Positioned(
              top: showImage ? 11 : -7,
              right: showImage ? 11 : -7,
              child: _QuantityBadge(
                quantity: quantity,
                ring: showImage ? c.card : c.ground,
              ),
            ),
        ],
      ),
    );
  }
}

List<ItemTag> _tags(Item item) => [
  for (final t in ItemTag.values)
    if (item.tags.contains(t)) t,
];

class _QuantityBadge extends StatelessWidget {
  const _QuantityBadge({required this.quantity, required this.ring});

  final int quantity;
  final Color ring;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    return Container(
      key: const Key('quantity-badge'),
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.accent,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: ring, spreadRadius: 2)],
      ),
      child: Text(
        '$quantity',
        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          height: 1.0,
          color: c.onAccent,
        ),
      ),
    );
  }
}

class _TagPill extends StatelessWidget {
  const _TagPill({required this.tag, required this.small});

  final ItemTag tag;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final vegan = tag == ItemTag.vegan;
    return Container(
      height: small ? 18 : 20,
      padding: EdgeInsets.symmetric(horizontal: small ? 6 : 7),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: vegan ? c.veganBg : c.spicyBg,
        borderRadius: BorderRadius.circular(
          small ? KassaTokens.radiusXs : 6,
        ),
      ),
      child: Text(
        vegan ? 'VEGAN' : 'SCHARF',
        maxLines: 1,
        style: Theme.of(context).textTheme.labelSmall!.copyWith(
          fontSize: small ? 10 : 10.5,
          height: 1.0,
          color: vegan ? c.veganFg : c.spicyFg,
        ),
      ),
    );
  }
}

class _ImageBody extends StatelessWidget {
  const _ImageBody({required this.item, required this.selected});

  final Item item;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    // Bei großer Schrift passt nur eine Zeile Name über den Preis.
    final lines = MediaQuery.textScalerOf(context).scale(10) > 11.5 ? 1 : 2;
    final placeholder = Center(
      child: Opacity(
        opacity: 0.55,
        child: Icon(LucideIcons.utensils, size: 30, color: c.accentInk),
      ),
    );
    final path = item.photoPath;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 80,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: c.accentSoft,
            borderRadius: BorderRadius.circular(11),
          ),
          child: path == null
              ? placeholder
              : Image.file(
                  File(path),
                  fit: BoxFit.cover,
                  cacheWidth: 400,
                  errorBuilder: (_, _, _) => placeholder,
                ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 6, 6, 1),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  item.name,
                  maxLines: lines,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyLarge!.copyWith(
                    fontSize: 14.5,
                    height: 1.2,
                    color: c.ink,
                  ),
                ),
                _PriceRow(item: item, tag: null),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CompactBody extends StatelessWidget {
  const _CompactBody({required this.item});

  final Item item;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final tags = _tags(item);
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          item.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: text.bodyMedium!.copyWith(
            fontSize: 15,
            height: 1.15,
            color: c.ink,
          ),
        ),
        _PriceRow(item: item, tag: tags.isEmpty ? null : tags.first),
      ],
    );
  }
}

/// Unterste Zeile der Taste: Preis, Marke (nur kompakt), rechts der Zusatz.
class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.item, required this.tag});

  final Item item;
  final ItemTag? tag;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final extra = item.inSale ? ItemTile.extraText(item) : 'Nicht im Verkauf';
    return LayoutBuilder(
      builder: (context, box) => Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Preis und Marke schrumpfen eher, als dass sie überlaufen.
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (item.inSale)
                    Text(
                      formatEuro(item.priceCents),
                      maxLines: 1,
                      style: text.titleMedium!.copyWith(
                        fontSize: 15,
                        height: 1.0,
                        color: c.accentInk,
                      ),
                    ),
                  if (tag != null && item.inSale) ...[
                    const SizedBox(width: KassaTokens.spaceSm),
                    _TagPill(tag: tag!, small: true),
                  ],
                ],
              ),
            ),
          ),
          if (extra != null) const SizedBox(width: KassaTokens.spaceSm),
          if (extra != null)
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: box.maxWidth * 0.5),
              child: Text(
                extra,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: text.bodySmall!.copyWith(
                  fontSize: 12,
                  height: 1.0,
                  color: c.ink2,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
