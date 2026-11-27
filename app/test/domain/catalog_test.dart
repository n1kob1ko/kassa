// Die Pfand-Beträge der Speisekarte: je Betrag eine Reihe im Blatt "Pfand
// zurück".

import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/domain/catalog.dart';

import '../support/demo_fixtures.dart';
import '../support/sales.dart';

const _business = BusinessInfo(name: 'Beispiel-Imbiss');

Item _item(
  String id, {
  int depositCents = 0,
  bool inSale = true,
  String? templateId,
}) => Item(
  id: id,
  name: id,
  priceCents: 300,
  categoryId: 'k',
  taxRate: TaxRate.normal,
  depositCents: depositCents,
  inSale: inSale,
  templateId: templateId,
  position: 0,
);

/// Eine Vorlage "Gefäß" mit einer Option ohne und einer mit [depositCents].
ModifierTemplate _template(String id, int depositCents) => ModifierTemplate(
  id: id,
  name: 'Gefäß',
  groups: [
    ModifierGroup(
      id: '$id/0',
      name: 'Gefäß',
      min: 1,
      max: 1,
      options: [
        ModifierOption(id: '$id/0/0', name: 'Glas', isDefault: true),
        ModifierOption(
          id: '$id/0/1',
          name: 'Flasche',
          depositCents: depositCents,
        ),
      ],
    ),
  ],
);

Catalog _catalogOf(
  List<Item> items, [
  List<ModifierTemplate> templates = const [],
]) => Catalog(
  business: _business,
  categories: const [Category(id: 'k', name: 'Karte', position: 0)],
  items: items,
  templates: templates,
);

void main() {
  test('depositAmounts: Beträge von Artikeln und Auswahlen, ohne Doppelte, '
      'aufsteigend; archivierte und nicht verkaufte zählen nicht', () async {
    // Beispiel-Karte: drei Getränke mit je 0,25 € Pfand.
    expect(depositAmounts(catalog), [25]);

    final becher100 = _item('becher', depositCents: 100);
    final flasche25Option = _item('saft', templateId: 'gefaess');
    final withBoth = _catalogOf(
      [becher100, flasche25Option, _item('cola', depositCents: 25)],
      [_template('gefaess', 25)],
    );
    expect(depositAmounts(withBoth), [25, 100]);

    final catalogWithoutDeposit = _catalogOf([_item('pommes')]);
    expect(depositAmounts(catalogWithoutDeposit), isEmpty);

    // Nicht im Verkauf: weder der Artikel noch die Optionen seiner Vorlage.
    expect(
      depositAmounts(
        _catalogOf(
          [
            _item('becher', depositCents: 100, inSale: false),
            _item('saft', templateId: 'gefaess', inSale: false),
          ],
          [_template('gefaess', 25)],
        ),
      ),
      isEmpty,
    );
    // Eine Vorlage, die kein Artikel im Verkauf nutzt, zählt nicht.
    expect(
      depositAmounts(_catalogOf([_item('pommes')], [_template('gefaess', 50)])),
      isEmpty,
    );

    // Archiviert: eine neue Speisekarte ohne die Getränke archiviert sie,
    // die Karte der Kassa kennt dann kein Pfand mehr.
    final shop = await TestShop.open();
    addTearDown(shop.close);
    await shop.catalogRepo.importCatalog(
      Catalog(
        business: catalog.business,
        categories: catalog.categories,
        items: [
          for (final i in catalog.items)
            if (i.depositCents == 0) i,
        ],
        templates: catalog.templates,
      ),
    );
    final current = (await shop.catalogRepo.current())!;
    expect(current.items.any((i) => i.id == 'cola'), isFalse);
    expect(depositAmounts(current), isEmpty);
  });
}
