import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/money.dart';
import '../../domain/cart.dart';
import '../../domain/catalog.dart';
import '../../l10n/generated/l10n.dart';
import '../../ui/ltr.dart';
import '../../ui/menu_text.dart';
import '../../ui/pressable.dart';
import '../../ui/primary_button.dart';
import '../../ui/tokens.dart';

/// "Zusammenstellen": steht in der Mitte anstelle der Artikel. Eine Karte je
/// Auswahlgruppe, unten "Abbrechen" und "Auf den Bon". Solange eine Pflicht-
/// gruppe fehlt, ist die Taste ausgeschaltet und nennt sie. Namen von Artikel,
/// Gruppen und Optionen stehen in der Bediensprache.
class ModifierPanel extends ConsumerStatefulWidget {
  const ModifierPanel({
    super.key,
    required this.item,
    required this.template,
    required this.onCancel,
    required this.onAdd,
  });

  final Item item;
  final ModifierTemplate template;
  final VoidCallback onCancel;
  final ValueChanged<List<ModifierOption>> onAdd;

  @override
  ConsumerState<ModifierPanel> createState() => _ModifierPanelState();
}

class _ModifierPanelState extends ConsumerState<ModifierPanel> {
  late Selection _selection = Selection.defaults(widget.template);

  void _toggle(ModifierGroup g, ModifierOption o) =>
      setState(() => _selection = _selection.toggle(g, o));

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final l = L10n.of(context);
    final menuText = ref.watch(menuTextProvider);
    final missing = _selection.missing;
    final price = widget.item.priceCents + _selection.surchargeCents;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 64,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // Lange Namen (andere Sprachen): kleiner und in zwei Zeilen.
                Expanded(
                  child: FittingName(
                    menuText(widget.item.name),
                    maxLines: 1,
                    alignment: AlignmentDirectional.centerStart,
                    style: text.headlineMedium!,
                  ),
                ),
                const SizedBox(width: KassaTokens.spaceXxl),
                Ltr(
                  child: Text(
                    formatEuro(price),
                    key: const Key('builder-price'),
                    style: text.headlineMedium!.copyWith(color: c.accentInk),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            key: const Key('builder-groups'),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            itemCount: widget.template.groups.length,
            separatorBuilder: (_, _) =>
                const SizedBox(height: KassaTokens.spaceMd),
            itemBuilder: (context, i) {
              final g = widget.template.groups[i];
              return _GroupCard(
                group: g,
                selection: _selection,
                onToggle: (o) => _toggle(g, o),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: c.card,
            border: Border(
              top: BorderSide(color: c.line, width: KassaTokens.borderThin),
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 180,
                child: PrimaryButton(
                  key: const Key('cancel-build'),
                  label: l.kassaCancel,
                  filled: false,
                  height: 68,
                  onPressed: widget.onCancel,
                ),
              ),
              const SizedBox(width: KassaTokens.spaceLg),
              Expanded(
                child: PrimaryButton(
                  key: const Key('add-to-cart'),
                  label: missing.isEmpty
                      ? l.kassaAddToReceipt
                      : l.kassaStillToChoose(
                          missing
                              .map((g) => menuText(g.name))
                              .join(l.uiListSeparator),
                        ),
                  muted: missing.isNotEmpty,
                  height: 68,
                  onPressed: missing.isEmpty
                      ? () => widget.onAdd(_selection.chosen)
                      : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GroupCard extends ConsumerWidget {
  const _GroupCard({
    required this.group,
    required this.selection,
    required this.onToggle,
  });

  final ModifierGroup group;
  final Selection selection;
  final ValueChanged<ModifierOption> onToggle;

  String _hint(L10n l) {
    final max = group.max;
    if (max == 1) return group.min >= 1 ? l.kassaPickOne : l.kassaAtMostOne;
    if (max == null) return group.min >= 1 ? l.kassaAtLeast(group.min) : '';
    return l.kassaUpTo(max);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final l = L10n.of(context);
    final count = group.options.where(selection.isChosen).length;
    final short = count < group.min;
    final status = short
        ? l.kassaPleaseChoose
        : (group.max != 1 && count > 0 ? l.kassaChosenCount(count) : '');
    final hint = _hint(l);
    return Container(
      key: Key('group-${group.id}'),
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 10),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(KassaTokens.radiusXxl),
        border: Border.all(color: c.line, width: KassaTokens.borderThin),
        boxShadow: c.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 36),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          ref.watch(menuTextProvider)(group.name),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleMedium,
                        ),
                      ),
                      if (hint.isNotEmpty) ...[
                        const SizedBox(width: KassaTokens.spaceLg),
                        Flexible(
                          child: Text(
                            hint,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.bodySmall!.copyWith(color: c.ink2),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (status.isNotEmpty)
                  Text(
                    status,
                    key: Key('status-${group.id}'),
                    maxLines: 1,
                    style: text.bodySmall!.copyWith(
                      fontWeight: FontWeight.w800,
                      color: short ? c.red : c.ink2,
                    ),
                  ),
              ],
            ),
          ),
          LayoutBuilder(
            builder: (context, box) {
              // Richtwert: eine Option ist etwa 150 dp breit.
              final maxCols = ((box.maxWidth + 8) / 158).floor().clamp(1, 6);
              // Gleich lange Reihen: 5 Optionen bei höchstens 4 sind 3 + 2.
              final rowCount = (group.options.length / maxCols).ceil();
              final cols = rowCount == 0
                  ? 1
                  : (group.options.length / rowCount).ceil();
              final rows = <Widget>[];
              for (var i = 0; i < group.options.length; i += cols) {
                final chunk = group.options.skip(i).take(cols).toList();
                if (rows.isNotEmpty) {
                  rows.add(const SizedBox(height: KassaTokens.spaceMd));
                }
                rows.add(
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var j = 0; j < cols; j++) ...[
                          if (j > 0) const SizedBox(width: KassaTokens.spaceMd),
                          Expanded(
                            child: j < chunk.length
                                ? _OptionButton(
                                    option: chunk[j],
                                    chosen: selection.isChosen(chunk[j]),
                                    showSurcharge: true,
                                    onTap: () => onToggle(chunk[j]),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }
              return Column(children: rows);
            },
          ),
        ],
      ),
    );
  }
}

class _OptionButton extends ConsumerWidget {
  const _OptionButton({
    required this.option,
    required this.chosen,
    required this.showSurcharge,
    required this.onTap,
  });

  final ModifierOption option;
  final bool chosen;
  final bool showSurcharge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final instant = MediaQuery.disableAnimationsOf(context);
    final fg = chosen ? c.accentInk : c.ink;
    final surcharge = option.surchargeCents;
    final name = ref.watch(menuTextProvider)(option.name);
    return Pressable(
      key: Key('opt-${option.id}'),
      onTap: onTap,
      semanticLabel: chosen ? L10n.of(context).kassaOptionChosen(name) : name,
      child: AnimatedContainer(
        duration: instant ? Duration.zero : KassaTokens.motionFast,
        curve: Curves.linear,
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: chosen ? c.accentSoft : c.card,
          borderRadius: BorderRadius.circular(KassaTokens.radiusLg),
          border: Border.all(
            color: chosen ? c.accent : c.line,
            width: KassaTokens.borderButton,
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 14),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: text.labelLarge!.copyWith(height: 1.12, color: fg),
                    ),
                    if (surcharge != 0 && showSurcharge)
                      Ltr(
                        child: Text(
                          '${surcharge > 0 ? '+' : ''}${formatEuro(surcharge)}',
                          style: text.bodySmall!.copyWith(
                            fontSize: 12.5,
                            color: fg.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (chosen)
              PositionedDirectional(
                top: 0,
                end: -6,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: c.accent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(LucideIcons.check, size: 11, color: c.onAccent),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
