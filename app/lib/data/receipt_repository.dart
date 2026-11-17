// Speichert Bons unveränderlich. Korrekturen sind Storno-Bons.

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../core/clock.dart';
import '../domain/cart.dart';
import '../domain/catalog.dart';
import '../domain/pricing.dart';
import '../domain/receipt.dart';
import '../domain/staff.dart';
import 'database.dart';

class EmptyCartException implements Exception {
  const EmptyCartException();

  @override
  String toString() => 'EmptyCartException: Der Bon hat keine Zeilen.';
}

class InsufficientCashException implements Exception {
  const InsufficientCashException();

  @override
  String toString() => 'InsufficientCashException: Es wurde weniger gegeben als die Summe.';
}

class AlreadyVoidedException implements Exception {
  const AlreadyVoidedException();

  @override
  String toString() => 'AlreadyVoidedException: Der Bon ist schon storniert.';
}

class CannotVoidAVoidException implements Exception {
  const CannotVoidAVoidException();

  @override
  String toString() => 'CannotVoidAVoidException: Ein Storno-Bon kann nicht storniert werden.';
}

class ReceiptRepository {
  ReceiptRepository(this._db, this._clock);

  final KassaDatabase _db;
  final Clock _clock;

  /// Schließt einen Barverkauf ab. Die Id des Bons ist [saleId]: gibt es ihn
  /// schon, kommt der gespeicherte Bon zurück und nichts wird geschrieben.
  Future<Receipt> finalizeCashSale({
    required String saleId,
    required Cart cart,
    required int givenCents,
    required Staff staff,
  }) {
    return _db.transaction(() async {
      final existing = await _find(saleId);
      if (existing != null) return existing;
      if (cart.isEmpty) throw const EmptyCartException();
      if (givenCents < cart.totalCents) throw const InsufficientCashException();

      final groupNames = await _groupNamesOf(cart);
      final lines = [
        for (var i = 0; i < cart.lines.length; i++)
          ReceiptLine(
            position: i,
            itemId: cart.lines[i].item.id,
            name: cart.lines[i].item.name,
            info: cart.lines[i].item.info,
            unitPriceCents: cart.lines[i].unitPriceCents,
            quantity: cart.lines[i].quantity,
            unitDepositCents: cart.lines[i].unitDepositCents,
            options: [
              for (final o in cart.lines[i].options)
                ReceiptLineOption(
                  groupName: groupNames[o.id] ?? '',
                  optionName: o.name,
                  surchargeCents: o.surchargeCents,
                ),
            ],
            grossByRate: grossByRateOfLine(cart.lines[i]),
          ),
      ];
      return _write(
        id: saleId,
        kind: ReceiptKind.sale,
        staff: staff,
        lines: lines,
        goodsCents: cart.goodsCents,
        depositCents: cart.depositCents,
        totalCents: cart.totalCents,
        payment: Payment(
          kind: PaymentKind.cash,
          amountCents: cart.totalCents,
          givenCents: givenCents,
          changeCents: givenCents - cart.totalCents,
        ),
      );
    });
  }

  /// Storniert einen Bon durch einen neuen Storno-Bon mit negativen Beträgen.
  /// Die Rolle der Person prüft der Aufrufer, nicht das Repository.
  Future<Receipt> voidReceipt(String receiptId, {required Staff staff}) {
    return _db.transaction(() async {
      final original = await byId(receiptId);
      if (original.kind == ReceiptKind.voided) {
        throw const CannotVoidAVoidException();
      }
      if (original.isVoided) throw const AlreadyVoidedException();
      return _write(
        id: const Uuid().v4(),
        kind: ReceiptKind.voided,
        voidsReceiptId: original.id,
        staff: staff,
        lines: [
          for (final l in original.lines)
            ReceiptLine(
              position: l.position,
              itemId: l.itemId,
              name: l.name,
              info: l.info,
              unitPriceCents: l.unitPriceCents,
              quantity: -l.quantity,
              unitDepositCents: l.unitDepositCents,
              options: l.options,
              grossByRate: {for (final e in l.grossByRate.entries) e.key: -e.value},
            ),
        ],
        goodsCents: -original.goodsCents,
        depositCents: -original.depositCents,
        totalCents: -original.totalCents,
        payment: Payment(
          kind: original.payment.kind,
          amountCents: -original.totalCents,
          givenCents: 0,
          changeCents: 0,
        ),
      );
    });
  }

  /// Wirft [StateError], wenn es den Bon nicht gibt.
  Future<Receipt> byId(String id) async {
    final r = await _find(id);
    if (r == null) throw StateError('Bon "$id" gibt es nicht.');
    return r;
  }

  /// Die Bons eines Tages, nach Nummer aufsteigend.
  Stream<List<Receipt>> watchDay(String businessDayId) {
    final query = _db.select(_db.receiptRows)
      ..where((t) => t.businessDayId.equals(businessDayId))
      ..orderBy([(t) => OrderingTerm.asc(t.number)]);
    return query.watch().asyncMap(_hydrate);
  }

  Future<Receipt?> _find(String id) async {
    final row = await (_db.select(
      _db.receiptRows,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return null;
    return (await _hydrate([row])).single;
  }

  /// Der offene Tag, sonst ein neuer.
  Future<String> _openDayId() async {
    final open = await (_db.select(
      _db.businessDayRows,
    )..where((t) => t.closedAt.isNull())).getSingleOrNull();
    if (open != null) return open.id;
    final id = const Uuid().v4();
    await _db
        .into(_db.businessDayRows)
        .insert(BusinessDayRowsCompanion.insert(id: id, openedAt: _clock.now()));
    return id;
  }

  Future<Receipt> _write({
    required String id,
    required ReceiptKind kind,
    String? voidsReceiptId,
    required Staff staff,
    required List<ReceiptLine> lines,
    required int goodsCents,
    required int depositCents,
    required int totalCents,
    required Payment payment,
  }) async {
    final dayId = await _openDayId();
    final maxNumber = _db.receiptRows.number.max();
    final highest = await (_db.selectOnly(
      _db.receiptRows,
    )..addColumns([maxNumber])).map((r) => r.read(maxNumber)).getSingle();
    await _db
        .into(_db.receiptRows)
        .insert(
          ReceiptRowsCompanion.insert(
            id: id,
            number: (highest ?? 0) + 1,
            createdAt: _clock.now(),
            staffId: staff.id,
            staffName: staff.name,
            businessDayId: dayId,
            kind: kind.name,
            voidsReceiptId: Value(voidsReceiptId),
            goodsCents: goodsCents,
            depositCents: depositCents,
            totalCents: totalCents,
          ),
        );
    for (final l in lines) {
      int gross(TaxRate r) => l.grossByRate[r] ?? 0;
      await _db
          .into(_db.receiptLineRows)
          .insert(
            ReceiptLineRowsCompanion.insert(
              receiptId: id,
              position: l.position,
              itemId: l.itemId,
              name: l.name,
              info: Value(l.info),
              unitPriceCents: l.unitPriceCents,
              quantity: l.quantity,
              unitDepositCents: l.unitDepositCents,
              gross20Cents: Value(gross(TaxRate.normal)),
              gross10Cents: Value(gross(TaxRate.reduced1)),
              gross13Cents: Value(gross(TaxRate.reduced2)),
              gross0Cents: Value(gross(TaxRate.zero)),
              gross19Cents: Value(gross(TaxRate.special)),
            ),
          );
      for (var i = 0; i < l.options.length; i++) {
        final o = l.options[i];
        await _db
            .into(_db.receiptLineOptionRows)
            .insert(
              ReceiptLineOptionRowsCompanion.insert(
                receiptId: id,
                linePosition: l.position,
                position: i,
                groupName: o.groupName,
                optionName: o.optionName,
                surchargeCents: o.surchargeCents,
              ),
            );
      }
    }
    await _db
        .into(_db.paymentRows)
        .insert(
          PaymentRowsCompanion.insert(
            receiptId: id,
            kind: payment.kind.name,
            amountCents: payment.amountCents,
            givenCents: payment.givenCents,
            changeCents: payment.changeCents,
          ),
        );
    return byId(id);
  }

  /// Gruppenname je Options-Id, aus dem Katalog der Datenbank.
  Future<Map<String, String>> _groupNamesOf(Cart cart) async {
    final ids = {
      for (final l in cart.lines)
        for (final o in l.options) o.id,
    };
    if (ids.isEmpty) return {};
    final query = _db.select(_db.modifierOptionRows).join([
      innerJoin(
        _db.modifierGroupRows,
        _db.modifierGroupRows.id.equalsExp(_db.modifierOptionRows.groupId),
      ),
    ])..where(_db.modifierOptionRows.id.isIn(ids));
    return {
      for (final r in await query.get())
        r.readTable(_db.modifierOptionRows).id: r.readTable(_db.modifierGroupRows).name,
    };
  }

  Future<List<Receipt>> _hydrate(List<ReceiptRow> rows) async {
    if (rows.isEmpty) return const [];
    final ids = [for (final r in rows) r.id];
    final lineRows =
        await (_db.select(_db.receiptLineRows)
              ..where((t) => t.receiptId.isIn(ids))
              ..orderBy([(t) => OrderingTerm.asc(t.position)]))
            .get();
    final optionRows =
        await (_db.select(_db.receiptLineOptionRows)
              ..where((t) => t.receiptId.isIn(ids))
              ..orderBy([(t) => OrderingTerm.asc(t.position)]))
            .get();
    final payments = {
      for (final p in await (_db.select(
        _db.paymentRows,
      )..where((t) => t.receiptId.isIn(ids))).get())
        p.receiptId: p,
    };
    final voidedBy = {
      for (final v in await (_db.select(
        _db.receiptRows,
      )..where((t) => t.voidsReceiptId.isIn(ids))).get())
        v.voidsReceiptId!: v.id,
    };
    return [
      for (final r in rows)
        Receipt(
          id: r.id,
          number: r.number,
          createdAt: r.createdAt,
          staffId: r.staffId,
          staffName: r.staffName,
          businessDayId: r.businessDayId,
          kind: ReceiptKind.values.byName(r.kind),
          voidsReceiptId: r.voidsReceiptId,
          voidedByReceiptId: voidedBy[r.id],
          lines: [
            for (final l in lineRows.where((l) => l.receiptId == r.id))
              ReceiptLine(
                position: l.position,
                itemId: l.itemId,
                name: l.name,
                info: l.info,
                unitPriceCents: l.unitPriceCents,
                quantity: l.quantity,
                unitDepositCents: l.unitDepositCents,
                options: [
                  for (final o in optionRows.where(
                    (o) => o.receiptId == r.id && o.linePosition == l.position,
                  ))
                    ReceiptLineOption(
                      groupName: o.groupName,
                      optionName: o.optionName,
                      surchargeCents: o.surchargeCents,
                    ),
                ],
                grossByRate: {
                  for (final e in {
                    TaxRate.normal: l.gross20Cents,
                    TaxRate.reduced1: l.gross10Cents,
                    TaxRate.reduced2: l.gross13Cents,
                    TaxRate.zero: l.gross0Cents,
                    TaxRate.special: l.gross19Cents,
                  }.entries)
                    if (e.value != 0) e.key: e.value,
                },
              ),
          ],
          payment: () {
            final p = payments[r.id]!;
            return Payment(
              kind: PaymentKind.values.byName(p.kind),
              amountCents: p.amountCents,
              givenCents: p.givenCents,
              changeCents: p.changeCents,
            );
          }(),
          goodsCents: r.goodsCents,
          depositCents: r.depositCents,
          totalCents: r.totalCents,
        ),
    ];
  }
}
