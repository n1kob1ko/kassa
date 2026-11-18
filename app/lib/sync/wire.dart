// Nachrichtenformen zwischen Kassa und Server (Teil C1).
// Reines Dart, ohne Flutter: auch das Werkzeug `tool/menu_fixture.dart` nutzt es.

import '../domain/catalog.dart';
import '../domain/staff.dart';

/// Die Speisekarte in der Form der Nachrichten ohne `archived`, `favorite`
/// und `inSale`. Das ist auch die Form, die der Server beim Lesen der
/// Speisekarten-Datei erzeugt.
Map<String, Object?> catalogToWire(Catalog c) => {
  'business': {
    'name': c.business.name,
    'addressLines': c.business.addressLines,
    'vatId': c.business.vatId,
    'receiptFooter': c.business.receiptFooter,
  },
  'categories': [
    for (final k in c.categories)
      {'id': k.id, 'name': k.name, 'position': k.position},
  ],
  'items': [
    for (final i in c.items)
      {
        'id': i.id,
        'name': i.name,
        'priceCents': i.priceCents,
        'categoryId': i.categoryId,
        'taxPercent': i.taxRate.percent,
        'depositCents': i.depositCents,
        'tags': [for (final t in i.tags) t.name],
        'info': i.info,
        'templateId': i.templateId,
        'position': i.position,
      },
  ],
  'templates': [
    for (final t in c.templates)
      {
        'id': t.id,
        'name': t.name,
        'groups': [
          for (final g in t.groups)
            {
              'id': g.id,
              'name': g.name,
              'min': g.min,
              'max': g.max,
              'options': [
                for (final o in g.options)
                  {
                    'id': o.id,
                    'name': o.name,
                    'surchargeCents': o.surchargeCents,
                    'isDefault': o.isDefault,
                    'taxPercent': o.taxRate?.percent,
                    'depositCents': o.depositCents,
                  },
              ],
            },
        ],
      },
  ],
  'staffSeeds': [
    for (final s in c.staffSeeds)
      {
        'name': s.name,
        'pin': s.pin,
        'role': s.role == StaffRole.chef ? 'chef' : 'staff',
      },
  ],
};
