import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/money.dart';
import '../../domain/catalog.dart';
import '../../l10n/generated/l10n.dart';
import '../../ui/hex_color.dart';
import '../../ui/menu_text.dart';
import '../../ui/pressable.dart';
import '../../ui/tokens.dart';

/// Artikeltaste: mit Bild (ca. 157 x 157) oder kompakt (Zeilenhöhe 90).
/// [quantity] ist die Menge dieses Artikels auf dem Bon (0: nicht darauf).
/// Ein Artikel, der nicht im Verkauf ist, ist ausgeschaltet. Name und Zusatz
/// stehen in der Bediensprache.
class ItemTile extends ConsumerWidget {
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

  /// Zusatz rechts unten: die Zusatzangabe des Artikels ([info], schon in der
  /// Bediensprache), sonst der Hinweis auf Pfand.
  static String? extraText(L10n l, Item item, String? info) =>
      info ?? (item.depositCents > 0 ? l.kassaPlusDeposit : null);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = KassaColors.of(context);
    final instant = MediaQuery.disableAnimationsOf(context);
    final selected = quantity > 0;
    final l = L10n.of(context);
    final menuText = ref.watch(menuTextProvider);
    final name = menuText(item.name);
    final info = item.info == null ? null : menuText(item.info!);
    final label = [
      name,
      if (item.inSale) formatEuro(item.priceCents) else l.kassaNotForSale,
      if (selected) l.kassaOnReceipt(quantity),
    ].join(l.uiListSeparator);
    final radius = showImage ? KassaTokens.radiusXxl : KassaTokens.radiusXl;
    final body = showImage
        ? _ImageBody(item: item, name: name, info: info)
        : _CompactBody(item: item, name: name, info: info);
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
              Positioned(
                top: 11,
                left: 11,
                child: _TagPill(tag: t, small: false),
              ),
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
        borderRadius: BorderRadius.circular(small ? KassaTokens.radiusXs : 6),
      ),
      child: Text(
        vegan ? L10n.of(context).kassaTagVegan : L10n.of(context).kassaTagSpicy,
        maxLines: 1,
        // Die Marke hat eine feste Höhe und wächst nicht mit der Schrift.
        textScaler: TextScaler.noScaling,
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
  const _ImageBody({
    required this.item,
    required this.name,
    required this.info,
  });

  final Item item;
  final String name;
  final String? info;

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
            // Bis das Foto gezeichnet ist, steht seine mittlere Farbe da.
            color: path == null
                ? c.accentSoft
                : colorFromHex(item.photoColor) ?? c.accentSoft,
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
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _TileName(
                    name,
                    maxLines: lines,
                    style: text.bodyLarge!.copyWith(
                      fontSize: 14.5,
                      height: 1.2,
                      color: c.ink,
                    ),
                  ),
                ),
                _PriceRow(item: item, info: info, tag: null),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CompactBody extends StatelessWidget {
  const _CompactBody({
    required this.item,
    required this.name,
    required this.info,
  });

  final Item item;
  final String name;
  final String? info;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final tags = _tags(item);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: _TileName(
            name,
            maxLines: 2,
            style: text.bodyMedium!.copyWith(
              fontSize: 15,
              height: 1.15,
              color: c.ink,
            ),
          ),
        ),
        _PriceRow(
          item: item,
          info: info,
          tag: tags.isEmpty ? null : tags.first,
        ),
      ],
    );
  }
}

/// Unterste Zeile der Taste: Preis, Marke (nur kompakt), rechts der Zusatz.
class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.item, required this.info, required this.tag});

  final Item item;
  final String? info;
  final ItemTag? tag;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final l = L10n.of(context);
    final extra = item.inSale
        ? ItemTile.extraText(l, item, info)
        : l.kassaNotForSale;
    // Preis und Marke behalten ihre Größe. Der Zusatz weicht zuerst: erst
    // gekürzt, dann ganz abgeschnitten.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
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
        Expanded(
          child: extra == null
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(left: KassaTokens.spaceSm),
                  child: ClipRect(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        extra,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: text.bodySmall!.copyWith(
                          fontSize: 12,
                          height: 1.0,
                          color: c.ink2,
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

/// Name auf der Taste, oben im Feld [maxLines] Zeilen in voller Größe. Passt
/// er so nicht ganz (lange Namen, andere Sprachen), wird die Schrift kleiner
/// und er darf so viele Zeilen nehmen, wie das Feld hoch ist: gekürzt wird
/// er erst, wenn er auch in der kleinsten Stufe nicht passt.
class _TileName extends StatelessWidget {
  const _TileName(this.name, {required this.maxLines, required this.style});

  final String name;
  final int maxLines;
  final TextStyle style;

  /// Stufen der Schrift, die volle Größe zuerst.
  static const _steps = [1.0, 0.9, 0.8];

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final locale = Localizations.maybeLocaleOf(context);
    return LayoutBuilder(
      builder: (context, box) {
        bool fits(TextStyle s, int? lines) {
          final painter = TextPainter(
            text: TextSpan(text: name, style: s),
            textDirection: direction,
            textScaler: scaler,
            locale: locale,
            maxLines: lines,
          )..layout(maxWidth: box.maxWidth);
          final ok =
              !painter.didExceedMaxLines && painter.height <= box.maxHeight;
          painter.dispose();
          return ok;
        }

        var shown = style;
        int? lines = maxLines;
        if (!fits(style, maxLines)) {
          final smaller = [
            for (final f in _steps.skip(1))
              style.copyWith(fontSize: style.fontSize! * f),
          ];
          final fitting = smaller.where((s) => fits(s, null)).firstOrNull;
          if (fitting != null) {
            shown = fitting;
            lines = null;
          } else {
            // Auch in der kleinsten Stufe zu lang: so viele Zeilen, wie
            // Platz haben, der Rest wird gekürzt.
            shown = smaller.last;
            final line = scaler.scale(shown.fontSize!) * (shown.height ?? 1);
            lines = (box.maxHeight / line).floor().clamp(1, 99);
          }
        }
        // Oben am Anfang der Zeile, wie zuvor in der gestreckten Spalte.
        return Align(
          alignment: AlignmentDirectional.topStart,
          child: Text(
            name,
            maxLines: lines,
            // Ellipse ohne Zeilengrenze hieße: nur eine Zeile.
            overflow: lines == null ? TextOverflow.clip : TextOverflow.ellipsis,
            style: shown,
          ),
        );
      },
    );
  }
}
