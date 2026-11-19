// Speichert den Katalog (Speisekarte) in der Datenbank.

import 'package:drift/drift.dart';

import '../core/clock.dart';
import '../domain/catalog.dart';
import '../domain/wire_file.dart';
import 'database.dart';
import 'outbox_repository.dart';

class CatalogRepository {
  CatalogRepository(this._db, {this._clock = const SystemClock()});

  final KassaDatabase _db;
  final Clock _clock;

  /// Spielt [c] ein. Läuft in einer Transaktion: scheitert etwas, bleibt der
  /// alte Stand. Favorit und Im-Verkauf bestehender Artikel bleiben erhalten,
  /// alles andere kommt aus der Datei. Artikel, die in der Datei fehlen,
  /// werden stillgelegt, nicht gelöscht. Mitarbeiter legt der Import nicht an.
  Future<void> importCatalog(Catalog c) async {
    final categoryIds = {for (final k in c.categories) k.id};
    for (final item in c.items) {
      if (!categoryIds.contains(item.categoryId)) {
        throw StateError(
          'Artikel "${item.id}": Kategorie "${item.categoryId}" gibt es nicht.',
        );
      }
    }
    await _db.transaction(() async {
      // Die Betriebsdaten kommen alle aus der Datei und ersetzen den alten Stand.
      await _db
          .into(_db.businessRows)
          .insertOnConflictUpdate(
            BusinessRowsCompanion.insert(
              id: const Value(1),
              name: c.business.name,
              addressLines: Value(c.business.addressLines.join('\n')),
              vatId: Value(c.business.vatId),
              receiptFooter: Value(c.business.receiptFooter),
            ),
          );

      // Kategorien
      for (final k in c.categories) {
        await _db
            .into(_db.categoryRows)
            .insertOnConflictUpdate(
              CategoryRowsCompanion.insert(
                id: k.id,
                name: k.name,
                position: k.position,
                archived: const Value(false),
              ),
            );
      }
      await (_db.update(_db.categoryRows)
            ..where((t) => t.id.isNotIn(categoryIds)))
          .write(const CategoryRowsCompanion(archived: Value(true)));

      // Vorlagen werden ersetzt.
      await _db.delete(_db.modifierOptionRows).go();
      await _db.delete(_db.modifierGroupRows).go();
      await _db.delete(_db.modifierTemplateRows).go();
      for (var t = 0; t < c.templates.length; t++) {
        final template = c.templates[t];
        await _db
            .into(_db.modifierTemplateRows)
            .insert(
              ModifierTemplateRowsCompanion.insert(
                id: template.id,
                name: template.name,
                position: t,
              ),
            );
        for (var g = 0; g < template.groups.length; g++) {
          final group = template.groups[g];
          await _db
              .into(_db.modifierGroupRows)
              .insert(
                ModifierGroupRowsCompanion.insert(
                  id: group.id,
                  templateId: template.id,
                  name: group.name,
                  minCount: group.min,
                  maxCount: Value(group.max),
                  position: g,
                ),
              );
          for (var o = 0; o < group.options.length; o++) {
            final option = group.options[o];
            await _db
                .into(_db.modifierOptionRows)
                .insert(
                  ModifierOptionRowsCompanion.insert(
                    id: option.id,
                    groupId: group.id,
                    name: option.name,
                    surchargeCents: Value(option.surchargeCents),
                    isDefault: Value(option.isDefault),
                    taxPercent: Value(option.taxRate?.percent),
                    depositCents: Value(option.depositCents),
                    position: o,
                  ),
                );
          }
        }
      }

      // Artikel
      final existing = {
        for (final r in await _db.select(_db.itemRows).get()) r.id: r,
      };
      final itemIds = <String>{};
      for (final i in c.items) {
        itemIds.add(i.id);
        final old = existing[i.id];
        await _db
            .into(_db.itemRows)
            .insertOnConflictUpdate(
              ItemRowsCompanion.insert(
                id: i.id,
                name: i.name,
                priceCents: i.priceCents,
                categoryId: i.categoryId,
                taxPercent: i.taxRate.percent,
                depositCents: Value(i.depositCents),
                tags: Value(encodeItemTags(i.tags)),
                info: Value(i.info),
                templateId: Value(i.templateId),
                favorite: Value(old?.favorite ?? i.favorite),
                inSale: Value(old?.inSale ?? i.inSale),
                photoPath: Value(i.photoPath),
                position: i.position,
                archived: const Value(false),
              ),
            );
      }
      await (_db.update(_db.itemRows)..where((t) => t.id.isNotIn(itemIds)))
          .write(const ItemRowsCompanion(archived: Value(true)));
    });
  }

  Stream<Catalog?> watch() {
    final Set<TableInfo> tables = {
      _db.businessRows,
      _db.categoryRows,
      _db.itemRows,
      _db.modifierTemplateRows,
      _db.modifierGroupRows,
      _db.modifierOptionRows,
    };
    return _watch(tables);
  }

  Stream<Catalog?> _watch(Set<TableInfo> tables) async* {
    yield await current();
    await for (final _ in _db.tableUpdates(
      TableUpdateQuery.onAllTables(tables),
    )) {
      yield await current();
    }
  }

  Future<Catalog?> current() async {
    final business = await (_db.select(
      _db.businessRows,
    )..where((t) => t.id.equals(1))).getSingleOrNull();
    if (business == null) return null;

    final categories =
        await (_db.select(_db.categoryRows)
              ..where((t) => t.archived.equals(false))
              ..orderBy([(t) => OrderingTerm.asc(t.position)]))
            .get();
    final items =
        await (_db.select(_db.itemRows)
              ..where((t) => t.archived.equals(false))
              ..orderBy([(t) => OrderingTerm.asc(t.position)]))
            .get();
    final templates = await (_db.select(
      _db.modifierTemplateRows,
    )..orderBy([(t) => OrderingTerm.asc(t.position)])).get();
    final groups = await (_db.select(
      _db.modifierGroupRows,
    )..orderBy([(t) => OrderingTerm.asc(t.position)])).get();
    final options = await (_db.select(
      _db.modifierOptionRows,
    )..orderBy([(t) => OrderingTerm.asc(t.position)])).get();

    return Catalog(
      business: BusinessInfo(
        name: business.name,
        addressLines: [
          for (final l in business.addressLines.split('\n'))
            if (l.isNotEmpty) l,
        ],
        vatId: business.vatId,
        receiptFooter: business.receiptFooter,
        logo: business.logoFileId == null
            ? null
            : WireFile(
                id: business.logoFileId!,
                color: business.logoColor ?? '',
              ),
        logoPath: business.logoPath,
      ),
      categories: [
        for (final k in categories)
          Category(id: k.id, name: k.name, position: k.position),
      ],
      items: [
        for (final r in items)
          Item(
            id: r.id,
            name: r.name,
            priceCents: r.priceCents,
            categoryId: r.categoryId,
            taxRate: TaxRate.fromPercent(r.taxPercent),
            depositCents: r.depositCents,
            tags: _decodeTags(r.tags),
            info: r.info,
            templateId: r.templateId,
            favorite: r.favorite,
            inSale: r.inSale,
            photoPath: r.photoPath,
            photoColor: r.photoColor,
            position: r.position,
          ),
      ],
      templates: [
        for (final t in templates)
          ModifierTemplate(
            id: t.id,
            name: t.name,
            groups: [
              for (final g in groups.where((g) => g.templateId == t.id))
                ModifierGroup(
                  id: g.id,
                  name: g.name,
                  min: g.minCount,
                  max: g.maxCount,
                  options: [
                    for (final o in options.where((o) => o.groupId == g.id))
                      ModifierOption(
                        id: o.id,
                        name: o.name,
                        surchargeCents: o.surchargeCents,
                        isDefault: o.isDefault,
                        taxRate: o.taxPercent == null
                            ? null
                            : TaxRate.fromPercent(o.taxPercent!),
                        depositCents: o.depositCents,
                      ),
                  ],
                ),
            ],
          ),
      ],
    );
  }

  /// Ändert nur die angegebenen Felder. Wirft [StateError], wenn es den
  /// Artikel nicht gibt.
  ///
  /// An einem gekoppelten Tablet (die Kassa hat einen Platz beim Server)
  /// entsteht in derselben Transaktion pro Feld, dessen Wert sich wirklich
  /// ändert, ein Eintrag "noch zu senden" mit Wert und Zeitpunkt. Ein Wert,
  /// der schon gilt, schreibt nichts. Das Pfand ist immer eine Zahl (ohne
  /// Pfand 0), die Kennzeichen gehen als Liste in der gespeicherten
  /// Reihenfolge (nach Namen sortiert).
  Future<void> updateItem(
    String itemId, {
    int? priceCents,
    bool? inSale,
    bool? favorite,
    int? depositCents,
    Set<ItemTag>? tags,
  }) => _db.transaction(() async {
    final old = await (_db.select(
      _db.itemRows,
    )..where((t) => t.id.equals(itemId))).getSingleOrNull();
    if (old == null) throw StateError('Artikel "$itemId" gibt es nicht.');
    final newTags = tags == null ? null : encodeItemTags(tags);

    await (_db.update(_db.itemRows)..where((t) => t.id.equals(itemId))).write(
      ItemRowsCompanion(
        priceCents: Value.absentIfNull(priceCents),
        inSale: Value.absentIfNull(inSale),
        favorite: Value.absentIfNull(favorite),
        depositCents: Value.absentIfNull(depositCents),
        tags: Value.absentIfNull(newTags),
      ),
    );

    final state = await (_db.select(
      _db.syncStateRows,
    )..where((t) => t.id.equals(1))).getSingleOrNull();
    if (state?.registerId == null) return;

    final changes = <String, Object>{
      if (priceCents != null && priceCents != old.priceCents)
        'priceCents': priceCents,
      if (inSale != null && inSale != old.inSale) 'inSale': inSale,
      if (favorite != null && favorite != old.favorite) 'favorite': favorite,
      if (depositCents != null && depositCents != old.depositCents)
        'depositCents': depositCents,
      if (newTags != null && newTags != old.tags)
        'tags': [
          for (final n in newTags.split(','))
            if (n.isNotEmpty) n,
        ],
    };
    final outbox = OutboxRepository(_db);
    final at = _clock.now();
    for (final e in changes.entries) {
      await outbox.addItemChange(
        itemId: itemId,
        field: e.key,
        value: e.value,
        changedAt: at,
      );
    }
  });
}

/// Die Kennzeichen eines Artikels, wie die Spalte `tags` sie hält.
String encodeItemTags(Set<ItemTag> tags) =>
    (tags.map((t) => t.name).toList()..sort()).join(',');

Set<ItemTag> _decodeTags(String s) => {
  for (final n in s.split(','))
    if (n.isNotEmpty) ItemTag.values.byName(n),
};
