import 'dart:io';

import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/money.dart';
import '../../domain/catalog.dart';
import '../../ui/app_toggle.dart';
import '../../ui/pressable.dart';
import '../../ui/tokens.dart';

/// Breiten der Spalten in Kopf und Zeilen der Artikelliste.
const _priceWidth = 84.0;
const _starWidth = 56.0;
const _toggleWidth = 72.0;
const _rowHeight = 64.0;
const _sidePadding = 16.0;

/// Foto des Artikels oder, ohne Foto, der Platzhalter auf `accentSoft`.
class ItemPhoto extends StatelessWidget {
  const ItemPhoto({
    super.key,
    required this.item,
    required this.size,
    required this.radius,
  });

  final Item item;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final placeholder = Center(
      child: Opacity(
        opacity: 0.55,
        child: Icon(
          LucideIcons.utensils,
          size: size * 0.45,
          color: c.accentInk,
        ),
      ),
    );
    final path = item.photoPath;
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.accentSoft,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: path == null
          ? placeholder
          : Image.file(
              File(path),
              fit: BoxFit.cover,
              cacheWidth: 200,
              errorBuilder: (_, _, _) => placeholder,
            ),
    );
  }
}

/// Die Marken VEGAN und SCHARF hinter dem Namen.
class ItemTagPills extends StatelessWidget {
  const ItemTagPills(this.item, {super.key});

  final Item item;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    Widget pill(String label, Color bg, Color fg) => Container(
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        maxLines: 1,
        // Die Marke hat eine feste Höhe und wächst nicht mit der Schrift.
        textScaler: TextScaler.noScaling,
        style: Theme.of(context).textTheme.labelSmall!
            .copyWith(height: 1.0, color: fg),
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (item.tags.contains(ItemTag.vegan))
          pill('VEGAN', c.veganBg, c.veganFg),
        if (item.tags.contains(ItemTag.vegan) &&
            item.tags.contains(ItemTag.spicy))
          const SizedBox(width: 4),
        if (item.tags.contains(ItemTag.spicy))
          pill('SCHARF', c.spicyBg, c.spicyFg),
      ],
    );
  }
}

/// Zweite Zeile einer Zeile: nicht im Verkauf, sonst Vorlage, Pfand, Zusatz.
String? itemSecondLine(Item item, ModifierTemplate? template) {
  if (!item.inSale) return 'Nicht im Verkauf';
  if (template != null) return 'Mit Auswahl';
  if (item.depositCents > 0) {
    return 'plus ${formatEuro(item.depositCents)} Pfand';
  }
  return item.info;
}

/// Kopf der Liste: Artikel, Preis, Favorit, Im Verkauf (12,5 dp 700, `ink2`).
class ItemListHeader extends StatelessWidget {
  const ItemListHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final style = Theme.of(context).textTheme.bodySmall!
        .copyWith(fontSize: 12.5, fontWeight: FontWeight.w700, color: c.ink2);
    Widget cell(String label, double width, Alignment alignment) => SizedBox(
      width: width,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: alignment,
        child: Text(label, maxLines: 1, style: style),
      ),
    );
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: _sidePadding),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: c.line, width: KassaTokens.borderThin),
        ),
      ),
      child: Row(
        children: [
          Expanded(child: Text('Artikel', style: style)),
          cell('Preis', _priceWidth, Alignment.centerRight),
          cell('Favorit', _starWidth, Alignment.center),
          cell('Im Verkauf', _toggleWidth, Alignment.center),
        ],
      ),
    );
  }
}

/// Eine Zeile der Artikelliste. Die Fläche mit Bild, Name und Preis wählt den
/// Artikel (`row-<id>`), Stern (`fav-<id>`) und Schalter (`insale-<id>`)
/// schreiben sofort.
class ItemRow extends StatelessWidget {
  const ItemRow({
    super.key,
    required this.item,
    required this.template,
    required this.selected,
    required this.onSelect,
    required this.onFavorite,
    required this.onInSale,
  });

  final Item item;
  final ModifierTemplate? template;
  final bool selected;
  final VoidCallback onSelect;
  final ValueChanged<bool> onFavorite;
  final ValueChanged<bool> onInSale;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final ink = item.inSale ? c.ink : c.ink2;
    final second = itemSecondLine(item, template);
    return Container(
      height: _rowHeight,
      padding: const EdgeInsets.symmetric(horizontal: _sidePadding),
      decoration: BoxDecoration(
        color: selected ? c.accentSoft : null,
        border: Border(
          bottom: BorderSide(color: c.line, width: KassaTokens.borderThin),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Pressable(
              key: Key('row-${item.id}'),
              onTap: onSelect,
              child: LayoutBuilder(
                builder: (context, box) {
                  // Auf dem kleinsten Tablet bleibt für den Namen sonst fast
                  // nichts: dann entfallen Bild und Marken (sie stehen im Detail).
                  final narrow = box.maxWidth < _priceWidth + 150;
                  return SizedBox(
                    height: _rowHeight,
                    child: Row(
                      children: [
                        if (!narrow) ...[
                          ItemPhoto(
                            item: item,
                            size: 44,
                            radius: KassaTokens.radiusLg,
                          ),
                          const SizedBox(width: KassaTokens.spaceXl),
                        ],
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      item.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: text.bodyMedium!.copyWith(
                                        color: ink,
                                      ),
                                    ),
                                  ),
                                  if (item.tags.isNotEmpty && !narrow) ...[
                                    const SizedBox(width: KassaTokens.spaceMd),
                                    Flexible(
                                      flex: 0,
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: ItemTagPills(item),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              if (second != null)
                                Text(
                                  second,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: text.bodySmall!.copyWith(
                                    color: c.ink2,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: _priceWidth,
                          child: Text(
                            formatEuro(item.priceCents),
                            maxLines: 1,
                            textAlign: TextAlign.right,
                            style: text.titleMedium!.copyWith(color: ink),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          SizedBox(
            width: _starWidth,
            child: Center(
              child: Pressable(
                key: Key('fav-${item.id}'),
                onTap: () => onFavorite(!item.favorite),
                minTapSize: const Size(KassaTokens.minTap, KassaTokens.minTap),
                semanticLabel: item.favorite
                    ? '${item.name} aus den Favoriten nehmen'
                    : '${item.name} zu den Favoriten',
                child: SizedBox(
                  width: KassaTokens.minTap,
                  height: KassaTokens.minTap,
                  child: Center(
                    child: CustomPaint(
                      size: const Size(24, 24),
                      painter: _StarPainter(
                        filled: item.favorite,
                        color: item.favorite ? c.accent : c.ink2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            key: Key('insale-${item.id}'),
            width: _toggleWidth,
            child: Semantics(
              toggled: item.inSale,
              label: '${item.name} im Verkauf',
              excludeSemantics: true,
              onTap: () => onInSale(!item.inSale),
              child: AppToggle(
                value: item.inSale,
                onChanged: onInSale,
                label: '',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Der Stern aus den Lucide-Symbolen: gefüllt für Favorit, sonst nur Linie.
class _StarPainter extends CustomPainter {
  const _StarPainter({required this.filled, required this.color});

  final bool filled;
  final Color color;

  static const _points = [
    Offset(12, 2),
    Offset(15.09, 8.26),
    Offset(22, 9.27),
    Offset(17, 14.14),
    Offset(18.18, 21.02),
    Offset(12, 17.77),
    Offset(5.82, 21.02),
    Offset(7, 14.14),
    Offset(2, 9.27),
    Offset(8.91, 8.26),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 24;
    final path = Path()..moveTo(_points[0].dx * k, _points[0].dy * k);
    for (final p in _points.skip(1)) {
      path.lineTo(p.dx * k, p.dy * k);
    }
    path.close();
    final paint = Paint()
      ..color = color
      ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = 2 * k
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, paint);
    if (filled) {
      canvas.drawPath(path, paint..style = PaintingStyle.stroke);
    }
  }

  @override
  bool shouldRepaint(_StarPainter old) =>
      old.filled != filled || old.color != color;
}
