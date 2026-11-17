import 'package:material_ui/material_ui.dart';

import '../../core/money.dart';
import '../../domain/catalog.dart';
import '../../ui/app_toggle.dart';
import '../../ui/pressable.dart';
import '../../ui/tokens.dart';
import 'item_row.dart';
import 'price_entry.dart';

/// Pfand, das der Schalter setzt.
const standardDepositCents = 25;

/// Die Spalte rechts (392 dp): Preis, Pfand, Vegan, Scharf, Steuersatz und die
/// Auswahl-Vorlage des gewählten Artikels. Mit "Preis ändern" wird sie zur
/// Preiseingabe. Schreiben tut der Aufrufer, [failed] zeigt den Hinweis.
class ItemDetail extends StatelessWidget {
  const ItemDetail({
    super.key,
    required this.item,
    required this.categoryName,
    required this.template,
    required this.editingPrice,
    required this.failed,
    required this.onEditPrice,
    required this.onCancelPrice,
    required this.onSavePrice,
    required this.onDeposit,
    required this.onTag,
  });

  final Item? item;
  final String categoryName;
  final ModifierTemplate? template;
  final bool editingPrice;
  final bool failed;
  final VoidCallback onEditPrice;
  final VoidCallback onCancelPrice;
  final ValueChanged<int> onSavePrice;
  final ValueChanged<int> onDeposit;
  final void Function(ItemTag tag, bool on) onTag;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final item = this.item;
    return Container(
      width: KassaTokens.receiptColumnWidth,
      decoration: BoxDecoration(
        color: c.card,
        border: Border(
          left: BorderSide(color: c.line, width: KassaTokens.borderThin),
        ),
      ),
      child: item == null
          ? const SizedBox.shrink()
          : editingPrice
          ? PriceEntry(
              header: _Header(item: item, categoryName: categoryName),
              currentCents: item.priceCents,
              failed: failed,
              onSave: onSavePrice,
              onCancel: onCancelPrice,
            )
          : _Normal(this, item),
    );
  }
}

class _Normal extends StatelessWidget {
  const _Normal(this.d, this.item);

  final ItemDetail d;
  final Item item;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final template = d.template;
    final hasDeposit = item.depositCents > 0;
    Widget row(Widget child) => Container(
      constraints: const BoxConstraints(minHeight: 56),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: c.line, width: KassaTokens.borderThin),
        ),
      ),
      child: child,
    );
    final labelStyle = text.bodyMedium!.copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w600,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            key: const Key('item-detail-scroll'),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(item: item, categoryName: d.categoryName),
                const SizedBox(height: KassaTokens.spaceXxl),
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                  decoration: BoxDecoration(
                    color: c.fill,
                    borderRadius: BorderRadius.circular(KassaTokens.radiusXxl),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Preis',
                              style: text.bodySmall!.copyWith(
                                fontSize: 14,
                                color: c.ink2,
                              ),
                            ),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                formatEuro(item.priceCents),
                                key: const Key('detail-price'),
                                maxLines: 1,
                                style: text.titleLarge!.copyWith(
                                  fontSize: 30,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: KassaTokens.spaceMd),
                      Pressable(
                        key: const Key('edit-price'),
                        onTap: d.onEditPrice,
                        child: Container(
                          height: 52,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: c.card,
                            borderRadius: BorderRadius.circular(
                              KassaTokens.radiusXl,
                            ),
                          ),
                          child: Text(
                            'Preis ändern',
                            maxLines: 1,
                            style: text.bodyMedium!.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: KassaTokens.spaceMd),
                row(
                  AppToggle(
                    key: const Key('toggle-deposit'),
                    label:
                        'Pfand ${formatEuro(hasDeposit ? item.depositCents : standardDepositCents)}',
                    value: hasDeposit,
                    onChanged: (on) =>
                        d.onDeposit(on ? standardDepositCents : 0),
                  ),
                ),
                row(
                  AppToggle(
                    key: const Key('toggle-vegan'),
                    label: 'Vegan',
                    value: item.tags.contains(ItemTag.vegan),
                    onChanged: (on) => d.onTag(ItemTag.vegan, on),
                  ),
                ),
                row(
                  AppToggle(
                    key: const Key('toggle-spicy'),
                    label: 'Scharf',
                    value: item.tags.contains(ItemTag.spicy),
                    onChanged: (on) => d.onTag(ItemTag.spicy, on),
                  ),
                ),
                row(
                  Row(
                    children: [
                      Expanded(child: Text('Steuersatz', style: labelStyle)),
                      Text(
                        '${item.taxRate.percent} %',
                        style: text.bodyMedium!.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                if (template != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Auswahl beim Bonieren', style: labelStyle),
                        const SizedBox(height: KassaTokens.spaceSm),
                        Text(
                          '${template.groups.map((g) => g.name).join(', ')}.',
                          style: text.bodySmall!.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: c.ink2,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (d.failed) const FailedHint(),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: c.line, width: KassaTokens.borderThin),
            ),
          ),
          child: Text(
            'Namen, Fotos und neue Artikel kommen aus der Speisekarten-Datei.',
            style: text.bodySmall!.copyWith(
              fontWeight: FontWeight.w400,
              color: c.ink2,
            ),
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.item, required this.categoryName});

  final Item item;
  final String categoryName;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        ItemPhoto(item: item, size: 88, radius: KassaTokens.radiusXxl),
        const SizedBox(width: KassaTokens.spaceXxl),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: text.headlineMedium,
              ),
              Text(
                categoryName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.bodySmall!.copyWith(fontSize: 15, color: c.ink2),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Hinweis, wenn eine Änderung nicht gespeichert werden konnte.
class FailedHint extends StatelessWidget {
  const FailedHint({super.key});

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Text(
        'Das hat nicht geklappt. Bitte nochmal versuchen.',
        key: const Key('write-failed'),
        style: Theme.of(context).textTheme.bodySmall!
            .copyWith(fontSize: 14, fontWeight: FontWeight.w700, color: c.red),
      ),
    );
  }
}
