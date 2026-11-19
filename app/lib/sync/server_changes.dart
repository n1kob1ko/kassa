// Übernimmt Speisekarte, Mitarbeiter und Betriebsdaten vom Server in die
// Datenbank des Tablets. Jeder Aufruf ist eine Transaktion: scheitert etwas,
// bleibt das Tablet genau wie vorher, auch der Cursor.
//
// Bons sind unveränderlich und tragen ihre eigenen Namen und Preise: nichts
// hier berührt sie. Kategorien und Artikel werden darum nie gelöscht, nur
// stillgelegt, alte Bons und Berichte verweisen auf sie.

import 'package:drift/drift.dart';

import '../data/catalog_repository.dart';
import '../data/database.dart';
import '../data/outbox_repository.dart';
import '../data/settings_repository.dart';
import '../domain/catalog.dart';
import '../domain/staff.dart';
import 'wire.dart';

class ServerChanges {
  ServerChanges(this._db);

  final KassaDatabase _db;

  /// Ob am Tablet schon ein Chef ist (Mitarbeiter mit PIN und der Rolle Chef).
  Future<bool> hasChef() async {
    final row =
        await (_db.select(_db.staffRows)
              ..where((t) => t.role.equals(StaffRole.chef.name))
              ..limit(1))
            .getSingleOrNull();
    return row != null;
  }

  /// Das erste Holen nach dem Koppeln: das Tablet hat danach genau den Stand
  /// aus [pages]. Was der Server nicht kennt, ist stillgelegt (Kategorien,
  /// Artikel) oder gelöscht (Vorlagen, Mitarbeiter). Der offene Bon ist leer.
  ///
  /// Die Seiten werden zuerst zusammengelegt (eine spätere Seite gewinnt),
  /// denn ein Artikel kann auf einer früheren Seite stehen als seine
  /// Kategorie, wenn sich die Kategorie später geändert hat.
  Future<void> replaceAll(
    List<PullResponse> pages, {
    required DateTime at,
  }) async {
    if (pages.isEmpty) throw ArgumentError.value(pages, 'pages', 'leer');
    final merged = _Changes.merge(pages);
    await _db.transaction(() async {
      await _db
          .update(_db.categoryRows)
          .write(const CategoryRowsCompanion(archived: Value(true)));
      await _db
          .update(_db.itemRows)
          .write(const ItemRowsCompanion(archived: Value(true)));
      await _db.delete(_db.modifierOptionRows).go();
      await _db.delete(_db.modifierGroupRows).go();
      await _db.delete(_db.modifierTemplateRows).go();
      await _db.delete(_db.staffRows).go();
      await _apply(merged);
      // Der Stand des Servers gilt, so wie es die Rückfrage beim Koppeln
      // sagt: Artikel-Änderungen, die noch warten, gehen nie nachträglich
      // hinauf. Bons und alles andere in der Liste bleiben.
      await OutboxRepository(_db).clearItemChanges();
      await SettingsRepository(_db).writeDraft(null);
      await _db
          .into(_db.syncStateRows)
          .insertOnConflictUpdate(
            SyncStateRowsCompanion(
              id: const Value(1),
              pullCursor: Value(pages.last.next),
              initialPullDone: const Value(true),
              lastPullAt: Value(at),
              lastError: const Value(null),
            ),
          );
    });
  }

  /// Jedes spätere Holen: übernimmt eine Seite, die ab [since] für die Kassa
  /// [registerId] geholt wurde, und rückt den Cursor auf `page.next`.
  ///
  /// Gibt `false` zurück und schreibt nichts, wenn die Seite nicht mehr
  /// passt: das Tablet wurde inzwischen neu gekoppelt (andere Kassa, oder das
  /// erste Laden steht noch aus) oder ein anderer Lauf hat den Cursor schon
  /// bewegt.
  ///
  /// [markPulled] `false`: `lastPullAt` ("Zuletzt abgeglichen") bleibt, weil
  /// der Lauf nicht als Ganzes geklappt hat (das Senden blieb unvollständig).
  Future<bool> applyPage(
    PullResponse page, {
    required DateTime at,
    required int since,
    required String registerId,
    bool markPulled = true,
  }) async {
    return _db.transaction(() async {
      final state = await (_db.select(
        _db.syncStateRows,
      )..where((t) => t.id.equals(1))).getSingleOrNull();
      if (state == null ||
          !state.initialPullDone ||
          state.pullCursor != since ||
          state.registerId != registerId) {
        return false;
      }
      final changes = _Changes.merge([page]);
      await _holdCategoriesOf(changes);
      // Ein Feld, für das noch eine Änderung vom Tablet wartet, bleibt wie es
      // ist: der Server kennt die Änderung noch nicht.
      await _apply(
        changes,
        keep: await OutboxRepository(_db).pendingItemFields(),
      );
      await _db
          .into(_db.syncStateRows)
          .insertOnConflictUpdate(
            SyncStateRowsCompanion(
              id: const Value(1),
              pullCursor: Value(page.next),
              lastPullAt: markPulled ? Value(at) : const Value.absent(),
            ),
          );
      return true;
    });
  }

  /// Ein Artikel kann auf einer früheren Seite kommen als seine neue
  /// Kategorie (sie hat sich danach noch einmal geändert). Bis sie kommt,
  /// hält eine stillgelegte Kategorie mit ihrer Kennung den Platz, sonst
  /// bliebe der Abgleich an dieser Seite für immer hängen.
  Future<void> _holdCategoriesOf(_Changes c) async {
    final wanted = {for (final i in c.items.values) i.categoryId}
      ..removeAll(c.categories.keys);
    if (wanted.isEmpty) return;
    final known =
        await (_db.selectOnly(_db.categoryRows)
              ..addColumns([_db.categoryRows.id])
              ..where(_db.categoryRows.id.isIn(wanted)))
            .map((r) => r.read(_db.categoryRows.id)!)
            .get();
    for (final id in wanted.difference(known.toSet())) {
      await _db
          .into(_db.categoryRows)
          .insert(
            CategoryRowsCompanion.insert(
              id: id,
              name: id,
              position: 0,
              archived: const Value(true),
            ),
          );
    }
  }

  /// Kategorien und Vorlagen vor Artikeln, damit jeder Artikel seine
  /// Kategorie schon vorfindet.
  ///
  /// [keep]: Artikel und die Felder, die nicht überschrieben werden (siehe
  /// `OutboxRepository.pendingItemFields`). Ein Artikel, den es am Tablet noch
  /// nicht gibt, wird immer ganz geschrieben.
  Future<void> _apply(
    _Changes c, {
    Map<String, Set<String>> keep = const {},
  }) async {
    final business = c.business;
    if (business != null) {
      await _db
          .into(_db.businessRows)
          .insertOnConflictUpdate(
            BusinessRowsCompanion.insert(
              id: const Value(1),
              name: business.name,
              addressLines: Value(business.addressLines.join('\n')),
              vatId: Value(business.vatId),
              receiptFooter: Value(business.receiptFooter),
            ),
          );
    }
    for (final k in c.categories.values) {
      await _db
          .into(_db.categoryRows)
          .insertOnConflictUpdate(
            CategoryRowsCompanion.insert(
              id: k.id,
              name: k.name,
              position: k.position,
              archived: Value(k.archived),
            ),
          );
    }
    for (final t in c.templates.values) {
      await _deleteTemplate(t.id, keepRow: !t.archived);
      if (!t.archived) await _writeTemplate(t);
    }
    final known = keep.isEmpty
        ? const <String>{}
        : {
            for (final r
                in await (_db.selectOnly(_db.itemRows)
                      ..addColumns([_db.itemRows.id])
                      ..where(_db.itemRows.id.isIn(keep.keys)))
                    .get())
              r.read(_db.itemRows.id)!,
          };
    for (final i in c.items.values) {
      // photoPath fehlt absichtlich: das Foto gehört dem Tablet.
      final held = known.contains(i.id) ? keep[i.id]! : const <String>{};
      if (held.isNotEmpty) {
        await (_db.update(_db.itemRows)..where((t) => t.id.equals(i.id))).write(
          ItemRowsCompanion(
            name: Value(i.name),
            priceCents: held.contains('priceCents')
                ? const Value.absent()
                : Value(i.priceCents),
            categoryId: Value(i.categoryId),
            taxPercent: Value(i.taxRate.percent),
            depositCents: held.contains('depositCents')
                ? const Value.absent()
                : Value(i.depositCents),
            tags: held.contains('tags')
                ? const Value.absent()
                : Value(encodeItemTags(i.tags)),
            info: Value(i.info),
            templateId: Value(i.templateId),
            favorite: held.contains('favorite')
                ? const Value.absent()
                : Value(i.favorite),
            inSale: held.contains('inSale')
                ? const Value.absent()
                : Value(i.inSale),
            position: Value(i.position),
            archived: Value(i.archived),
          ),
        );
        continue;
      }
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
              favorite: Value(i.favorite),
              inSale: Value(i.inSale),
              position: i.position,
              archived: Value(i.archived),
            ),
          );
    }
    for (final s in c.staff.values) {
      if (s.archived) {
        await (_db.delete(_db.staffRows)..where((t) => t.id.equals(s.id))).go();
        continue;
      }
      await _db
          .into(_db.staffRows)
          .insertOnConflictUpdate(
            StaffRowsCompanion.insert(
              id: s.id,
              name: s.name,
              role: s.role.name,
              pinSalt: s.pinSalt,
              pinHash: s.pinHash,
            ),
          );
    }
  }

  /// Löscht die Gruppen und Optionen der Vorlage [id], ohne [keepRow] auch
  /// die Vorlage selbst.
  Future<void> _deleteTemplate(String id, {required bool keepRow}) async {
    final groups = _db.selectOnly(_db.modifierGroupRows)
      ..addColumns([_db.modifierGroupRows.id])
      ..where(_db.modifierGroupRows.templateId.equals(id));
    await (_db.delete(
      _db.modifierOptionRows,
    )..where((t) => t.groupId.isInQuery(groups))).go();
    await (_db.delete(
      _db.modifierGroupRows,
    )..where((t) => t.templateId.equals(id))).go();
    if (!keepRow) {
      await (_db.delete(
        _db.modifierTemplateRows,
      )..where((t) => t.id.equals(id))).go();
    }
  }

  /// Schreibt die Vorlage samt Gruppen und Optionen. Eine bekannte Vorlage
  /// behält ihren Platz, eine neue kommt ans Ende.
  Future<void> _writeTemplate(WireTemplate t) async {
    final existing = await (_db.select(
      _db.modifierTemplateRows,
    )..where((r) => r.id.equals(t.id))).getSingleOrNull();
    final int position;
    if (existing != null) {
      position = existing.position;
    } else {
      final max = _db.modifierTemplateRows.position.max();
      final last = await (_db.selectOnly(
        _db.modifierTemplateRows,
      )..addColumns([max])).map((r) => r.read(max)).getSingle();
      position = last == null ? 0 : last + 1;
    }
    await _db
        .into(_db.modifierTemplateRows)
        .insertOnConflictUpdate(
          ModifierTemplateRowsCompanion.insert(
            id: t.id,
            name: t.name,
            position: position,
          ),
        );
    for (var g = 0; g < t.groups.length; g++) {
      final ModifierGroup group = t.groups[g];
      await _db
          .into(_db.modifierGroupRows)
          .insert(
            ModifierGroupRowsCompanion.insert(
              id: group.id,
              templateId: t.id,
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
}

/// Der Inhalt einer oder mehrerer Seiten, je Kennung die letzte Fassung. Eine
/// Kennung behält den Platz ihres ersten Auftretens.
class _Changes {
  _Changes._();

  factory _Changes.merge(List<PullResponse> pages) {
    final c = _Changes._();
    for (final p in pages) {
      c.business = p.business ?? c.business;
      for (final k in p.categories) {
        c.categories[k.id] = k;
      }
      for (final t in p.templates) {
        c.templates[t.id] = t;
      }
      for (final i in p.items) {
        c.items[i.id] = i;
      }
      for (final s in p.staff) {
        c.staff[s.id] = s;
      }
    }
    return c;
  }

  BusinessInfo? business;
  final categories = <String, WireCategory>{};
  final templates = <String, WireTemplate>{};
  final items = <String, WireItem>{};
  final staff = <String, WireStaff>{};
}
