import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/generated/l10n.dart';
import '../../ui/menu_text.dart';
import '../../ui/pressable.dart';
import '../../ui/tokens.dart';

/// Eine Zeile der Kategorie-Spalte.
class CategoryEntry {
  const CategoryEntry({
    required this.id,
    required this.name,
    required this.count,
    this.isFavorites = false,
  });

  /// Schlüssel der Taste ist `cat-<id>`.
  final String id;

  /// Name aus der Speisekarte (angezeigt in der Bediensprache), bei den
  /// Favoriten schon der Text der App.
  final String name;
  final int count;
  final bool isFavorites;
}

/// Kategorie-Spalte, 196 dp breit: "Favoriten" (wenn es welche gibt) und die
/// Kategorien des Katalogs, mit Anzahl der Artikel. Lange Listen scrollen.
class CategoryRail extends StatelessWidget {
  const CategoryRail({
    super.key,
    required this.entries,
    required this.selectedId,
    required this.onSelected,
  });

  final List<CategoryEntry> entries;
  final String? selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: KassaTokens.categoryColumnWidth,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 12, 0, 12),
        itemCount: entries.length,
        separatorBuilder: (_, _) => const SizedBox(height: KassaTokens.spaceSm),
        itemBuilder: (context, i) {
          final e = entries[i];
          return _CategoryButton(
            key: Key('cat-${e.id}'),
            entry: e,
            active: e.id == selectedId,
            onTap: () => onSelected(e.id),
          );
        },
      ),
    );
  }
}

class _CategoryButton extends ConsumerWidget {
  const _CategoryButton({
    super.key,
    required this.entry,
    required this.active,
    required this.onTap,
  });

  final CategoryEntry entry;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final instant = MediaQuery.disableAnimationsOf(context);
    final name = entry.isFavorites
        ? entry.name
        : ref.watch(menuTextProvider)(entry.name);
    return Pressable(
      onTap: onTap,
      semanticLabel: L10n.of(
        context,
      ).kassaCategoryLabel(name, L10n.of(context).kassaItemCount(entry.count)),
      child: AnimatedContainer(
        duration: instant ? Duration.zero : KassaTokens.motionFast,
        curve: Curves.linear,
        height: KassaTokens.categoryButtonHeight,
        padding: EdgeInsets.only(left: entry.isFavorites ? 8 : 12, right: 10),
        decoration: BoxDecoration(
          color: active ? c.accentSoft : c.card,
          borderRadius: BorderRadius.circular(KassaTokens.radiusXl),
          border: Border.all(
            color: active ? c.accent : c.line,
            width: KassaTokens.borderButton,
          ),
          boxShadow: c.cardShadow,
        ),
        child: Row(
          children: [
            if (entry.isFavorites) ...[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: c.accentSoft,
                  borderRadius: BorderRadius.circular(KassaTokens.radiusMd),
                ),
                child: Icon(LucideIcons.star, size: 20, color: c.accentInk),
              ),
              const SizedBox(width: KassaTokens.spaceLg),
            ],
            Expanded(
              child: Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: text.bodyLarge!.copyWith(
                  fontSize: 14.5,
                  height: 1.12,
                  color: active ? c.accentInk : c.ink,
                ),
              ),
            ),
            const SizedBox(width: KassaTokens.spaceLg),
            Text(
              '${entry.count}',
              style: text.labelMedium!.copyWith(
                fontWeight: FontWeight.w700,
                color: c.ink2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
