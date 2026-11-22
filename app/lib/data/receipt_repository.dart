// Speichert Bons unveränderlich. Korrekturen sind Storno-Bons.

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../core/clock.dart';
import '../domain/cart.dart';
import '../domain/catalog.dart';
import '../domain/pricing.dart';
import '../domain/receipt.dart';
import '../domain/staff.dart';
import '../rksv/core/rksv_code.dart';
import '../rksv/rksv_journal.dart';
import '../rksv/signature_unit.dart';
import 'database.dart';
import 'day_repository.dart';

class EmptyCartException implements Exception {
  const EmptyCartException();

  @override
  String toString() => 'EmptyCartException: Der Bon hat keine Zeilen.';
}

class InsufficientCashException implements Exception {
  const InsufficientCashException();

  @override
  String toString() =>
      'InsufficientCashException: Es wurde weniger gegeben als die Summe.';
}

class AlreadyVoidedException implements Exception {
  const AlreadyVoidedException();

  @override
  String toString() => 'AlreadyVoidedException: Der Bon ist schon storniert.';
}

class CannotVoidAVoidException implements Exception {
  const CannotVoidAVoidException();

  @override
  String toString() =>
      'CannotVoidAVoidException: Ein Storno-Bon kann nicht storniert werden.';
}

class CannotVoidSpecialException implements Exception {
  const CannotVoidSpecialException();

  @override
  String toString() =>
      'CannotVoidSpecialException: Ein Sonderbeleg kann nicht storniert '
      'werden.';
}

/// Der Bon gehört nicht zur laufenden Kette der Signatur: Sein Storno würde
/// den Umsatzzähler senken, ohne dass sein Verkauf darin steht.
class NotInCurrentChainException implements Exception {
  const NotInCurrentChainException();

  @override
  String toString() =>
      'NotInCurrentChainException: Der Bon gehört nicht zur laufenden Kette.';
}

class ReceiptRepository {
  ReceiptRepository(this._db, this._clock, this._days, {this._journal});

  final KassaDatabase _db;
  final Clock _clock;
  final DayRepository _days;

  /// Ohne Journal (in Tests) bekommt kein Bon einen Eintrag.
  final RksvJournal? _journal;

  /// Das Journal, mit dem die Bons ihre Einträge bekommen (null ohne).
  RksvJournal? get journal => _journal;

  /// Reihenfolge der fünf Beträge im Code.
  static const _codeRates = [
    TaxRate.normal,
    TaxRate.reduced1,
    TaxRate.reduced2,
    TaxRate.zero,
    TaxRate.special,
  ];

  /// Schließt einen Barverkauf ab. Die Id des Bons ist [saleId]: gibt es ihn
  /// schon, kommt der gespeicherte Bon zurück und nichts wird geschrieben.
  /// Im selben Schritt geht der Bon-Entwurf weg: ein Absturz direkt danach
  /// bietet denselben Verkauf nicht noch einmal an.
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

      final saved = await _write(
        id: saleId,
        kind: ReceiptKind.sale,
        staff: staff,
        lines: await _linesOf(cart),
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
      await (_db.update(_db.settingsRows)..where((t) => t.id.equals(1))).write(
        const SettingsRowsCompanion(receiptDraft: Value(null)),
      );
      return saved;
    });
  }

  /// Schließt einen Kartenverkauf ab, nachdem das Terminal bezahlt gemeldet
  /// hat. Bon, Zahlung, Entwurf und offene Zahlung ändern sich in einem
  /// Schritt. Gibt es den Bon zu [saleId] schon, kommt er zurück; die offene
  /// Zahlung mit dieser Id geht trotzdem weg.
  Future<Receipt> finalizeCardSale({
    required String saleId,
    required Cart cart,
    required Staff staff,
    required String provider,
    String? txCode,
    String? cardScheme,
    String? cardLast4,
  }) {
    return _db.transaction(() async {
      final existing = await _find(saleId);
      if (existing == null && cart.isEmpty) throw const EmptyCartException();
      final saved =
          existing ??
          await _write(
            id: saleId,
            kind: ReceiptKind.sale,
            staff: staff,
            lines: await _linesOf(cart),
            goodsCents: cart.goodsCents,
            depositCents: cart.depositCents,
            totalCents: cart.totalCents,
            payment: Payment(
              kind: PaymentKind.card,
              amountCents: cart.totalCents,
              givenCents: 0,
              changeCents: 0,
              provider: provider,
              providerTxCode: txCode,
              cardScheme: cardScheme,
              cardLast4: cardLast4,
            ),
          );
      await (_db.delete(
        _db.pendingCardPaymentRows,
      )..where((t) => t.id.equals(saleId))).go();
      if (existing == null) {
        await (_db.update(_db.settingsRows)..where((t) => t.id.equals(1)))
            .write(const SettingsRowsCompanion(receiptDraft: Value(null)));
      }
      return saved;
    });
  }

  Future<List<ReceiptLine>> _linesOf(Cart cart) async {
    final groupNames = await _groupNamesOf(cart);
    return [
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
  }

  /// Storniert einen Bon durch einen neuen Storno-Bon mit negativen Beträgen.
  /// Die Rolle der Person prüft der Aufrufer, nicht das Repository. Läuft die
  /// Signatur, geht das nur für Bons ihrer laufenden Kette
  /// ([NotInCurrentChainException]).
  Future<Receipt> voidReceipt(String receiptId, {required Staff staff}) {
    return _db.transaction(() async {
      final original = await byId(receiptId);
      if (original.kind == ReceiptKind.voided) {
        throw const CannotVoidAVoidException();
      }
      if (original.kind.isSpecial) throw const CannotVoidSpecialException();
      if (original.isVoided) throw const AlreadyVoidedException();
      final payment =
          original.payment ??
          (throw StateError('Bon "${original.id}" hat keine Zahlung.'));
      final journal = _journal;
      if (journal != null && !await journal.mayVoid(original.id)) {
        throw const NotInCurrentChainException();
      }
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
              grossByRate: {
                for (final e in l.grossByRate.entries) e.key: -e.value,
              },
            ),
        ],
        goodsCents: -original.goodsCents,
        depositCents: -original.depositCents,
        totalCents: -original.totalCents,
        payment: Payment(
          kind: payment.kind,
          amountCents: -original.totalCents,
          givenCents: 0,
          changeCents: 0,
          provider: payment.provider,
          providerTxCode: payment.providerTxCode,
          cardScheme: payment.cardScheme,
          cardLast4: payment.cardLast4,
        ),
      );
    });
  }

  /// Schreibt einen Sonderbeleg der Art [kind] (Betrag 0, ohne Zeilen, ohne
  /// Zahlung, ohne Tag) mit seinem Eintrag im Protokoll. Start-, Null- und
  /// Schlussbeleg löst der Chef aus; Monats-, Jahres- und Sammelbeleg
  /// entstehen von selbst vor einem Verkauf. Vor einem Null- oder
  /// Schlussbeleg steht, was fällig ist, wie vor einem Verkauf. Mit
  /// [mustSign] wirft jeder Fehler der Signatur ([SignatureFailure]) und
  /// jeder andere, und nichts bleibt stehen. Ohne laufende Signatur:
  /// [StateError].
  Future<Receipt> createSpecial(
    ReceiptKind kind, {
    required Staff staff,
    bool mustSign = false,
  }) {
    return _db.transaction(() async {
      if (!kind.isSpecial) {
        throw ArgumentError.value(kind, 'kind', 'Kein Sonderbeleg');
      }
      final journal = _journal;
      if (journal == null || !await journal.isActive()) {
        throw StateError('Sonderbelege gibt es nur mit Signatur.');
      }
      final signatureDown =
          (kind == ReceiptKind.zero || kind == ReceiptKind.closing) &&
          await _writeDue(journal, staff);
      return _writeSpecial(
        journal,
        kind,
        staff: staff,
        mustSign: mustSign,
        trySign: !signatureDown,
      );
    });
  }

  /// "Nochmal prüfen": Läuft ein Ausfall, versucht dies den Sammelbeleg.
  /// true, wenn er geschrieben ist und der Ausfall damit endet; false ohne
  /// Ausfall oder wenn die Signatur noch nicht geht (dann ist nichts
  /// geschrieben).
  Future<bool> retryCollective({required Staff staff}) {
    return _db.transaction(() async {
      final journal = _journal;
      if (journal == null ||
          await journal.dueBefore(_clock.now()) != ReceiptKind.collective) {
        return false;
      }
      return _tryCollective(journal, staff);
    });
  }

  /// Der Jahresbeleg, der direkt vor [sale] steht (Nummer `sale.number - 1`,
  /// Art `year`), sonst `null`. Ein fälliger Jahresbeleg entsteht im selben
  /// Schritt direkt vor dem Bon, der ihn auslöst; die Zeit wird nicht
  /// verglichen.
  Future<Receipt?> yearReceiptBefore(Receipt sale) async {
    final row =
        await (_db.select(_db.receiptRows)..where(
              (t) =>
                  t.number.equals(sale.number - 1) &
                  t.kind.equals(ReceiptKind.year.name),
            ))
            .getSingleOrNull();
    if (row == null) return null;
    return (await _hydrate([row])).single;
  }

  /// Der Bon mit dieser Id, oder `null`.
  Future<Receipt?> find(String id) => _find(id);

  /// Wirft [StateError], wenn es den Bon nicht gibt.
  Future<Receipt> byId(String id) async {
    final r = await _find(id);
    if (r == null) throw StateError('Bon "$id" gibt es nicht.');
    return r;
  }

  /// Die Bons eines Tages und die Sonderbelege ohne Tag, die ab seinem Beginn
  /// bis zum Beginn des nächsten Tages entstanden sind (beim ersten Tag auch
  /// alle davor, beim neuesten alle danach). Nach Nummer aufsteigend.
  Stream<List<Receipt>> watchDay(String businessDayId) {
    final query = _db.customSelect(
      'SELECT r.* FROM receipts r, '
      '(SELECT opened_at FROM business_days WHERE id = ?1) d '
      'WHERE r.business_day_id = ?1 '
      'OR (r.business_day_id IS NULL '
      'AND (r.created_at >= d.opened_at OR NOT EXISTS '
      '(SELECT 1 FROM business_days p WHERE p.opened_at < d.opened_at)) '
      'AND (r.created_at < (SELECT MIN(n.opened_at) FROM business_days n '
      'WHERE n.opened_at > d.opened_at) OR NOT EXISTS '
      '(SELECT 1 FROM business_days n WHERE n.opened_at > d.opened_at))) '
      'ORDER BY r.number',
      variables: [Variable.withString(businessDayId)],
      readsFrom: {_db.receiptRows, _db.businessDayRows, _db.rksvEntryRows},
    );
    return query
        .watch()
        .map((rows) => [for (final r in rows) _db.receiptRows.map(r.data)])
        .asyncMap(_hydrate);
  }

  Future<Receipt?> _find(String id) async {
    final row = await (_db.select(
      _db.receiptRows,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return null;
    return (await _hydrate([row])).single;
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
    final journal = _journal;
    final signing = journal != null && await journal.isActive();
    List<int>? sums;
    var signatureDown = false;
    if (signing) {
      sums = _codeSumsOf(lines, depositCents);
      if (sums.fold<int>(0, (a, b) => a + b) != totalCents) {
        throw StateError(
          'Die Beträge je Satz ergeben nicht die Summe des Bons $id.',
        );
      }
      signatureDown = await _writeDue(journal, staff);
    }
    final dayId = (await _days.openOrCreateDay()).id;
    final number = await _nextNumber();
    final createdAt = _clock.now();
    await _db
        .into(_db.receiptRows)
        .insert(
          ReceiptRowsCompanion.insert(
            id: id,
            number: number,
            createdAt: createdAt,
            staffId: staff.id,
            staffName: staff.name,
            businessDayId: Value(dayId),
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
            provider: Value(payment.provider),
            providerTxCode: Value(payment.providerTxCode),
            cardScheme: Value(payment.cardScheme),
            cardLast4: Value(payment.cardLast4),
          ),
        );
    if (signing) {
      await _record(
        journal,
        receiptId: id,
        number: number,
        createdAt: createdAt,
        kind: kind,
        sumsCents: sums!,
        trySign: !signatureDown,
      );
    }
    return byId(id);
  }

  Future<int> _nextNumber() async {
    final maxNumber = _db.receiptRows.number.max();
    final highest = await (_db.selectOnly(
      _db.receiptRows,
    )..addColumns([maxNumber])).map((r) => r.read(maxNumber)).getSingle();
    return (highest ?? 0) + 1;
  }

  /// Die fünf Beträge des Codes: Summen der Zeilen je Satz, das Pfand zählt
  /// zu Null.
  static List<int> _codeSumsOf(List<ReceiptLine> lines, int depositCents) => [
    for (final rate in _codeRates)
      lines.fold<int>(0, (sum, l) => sum + (l.grossByRate[rate] ?? 0)) +
          (rate == TaxRate.zero ? depositCents : 0),
  ];

  /// Schreibt, was vor einem Verkauf oder Storno fällig ist. Höchstens zwei
  /// Runden: Auf einen Sammelbeleg kann ein Monats- oder Jahresbeleg folgen.
  /// Ein gescheiterter Sammelbeleg und ein Monats- oder Jahresbeleg mit
  /// Ausfall-Vermerk beenden die Runden. true, wenn die
  /// Signatur eben nicht ging: Der Bon danach fragt sie dann nicht noch
  /// einmal.
  Future<bool> _writeDue(RksvJournal journal, Staff staff) async {
    for (var round = 0; round < 2; round++) {
      final due = await journal.dueBefore(_clock.now());
      if (due == null) return false;
      if (due != ReceiptKind.collective) {
        await _writeSpecial(journal, due, staff: staff);
        // Kam der Monats- oder Jahresbeleg mit Ausfall-Vermerk, hat die
        // Signatur eben nicht geantwortet: kein Sammelbeleg mehr, und der
        // Bon danach fragt sie nicht noch einmal. Der nächste Bon schreibt
        // Sammelbeleg und signierten Monatsbeleg (R10).
        if (await journal.dueBefore(_clock.now()) == ReceiptKind.collective) {
          return true;
        }
      } else if (!await _tryCollective(journal, staff)) {
        return true;
      }
    }
    return false;
  }

  /// Der Sammelbeleg in einer eigenen Transaktion; scheitert seine Signatur,
  /// wird nur er zurückgerollt, der Ausfall dauert an, und es kommt false.
  Future<bool> _tryCollective(RksvJournal journal, Staff staff) async {
    try {
      await _db.transaction(
        () => _writeSpecial(
          journal,
          ReceiptKind.collective,
          staff: staff,
          mustSign: true,
        ),
      );
      return true;
    } on SignatureFailure catch (e) {
      // Nach dem Zurückrollen: Bei Ketten mit Karte nennt der Ausfall den
      // Grund dieses Versuchs (B1).
      await journal.noteFailedAttempt(e.reason);
      return false;
    } on Object {
      // Unerwartet (K9): Der Sammelbeleg ist zurückgerollt, die Probe
      // endet, der Verkauf läuft weiter. Außerhalb der Probe weiterwerfen:
      // Im echten Betrieb kommt hier nur noch ein Fehler der Datenbank (oder
      // des AES-Schlüssels) an, jeder der Einheit ist SignatureFailure (Q6).
      if (!await journal.endProbeAfterError()) rethrow;
      return false;
    }
  }

  Future<Receipt> _writeSpecial(
    RksvJournal journal,
    ReceiptKind kind, {
    required Staff staff,
    bool mustSign = false,
    bool trySign = true,
  }) async {
    final id = const Uuid().v4();
    final number = await _nextNumber();
    final createdAt = _clock.now();
    await _db
        .into(_db.receiptRows)
        .insert(
          ReceiptRowsCompanion.insert(
            id: id,
            number: number,
            createdAt: createdAt,
            staffId: staff.id,
            staffName: staff.name,
            businessDayId: const Value(null),
            kind: kind.name,
            goodsCents: 0,
            depositCents: 0,
            totalCents: 0,
          ),
        );
    const zero = [0, 0, 0, 0, 0];
    if (mustSign) {
      await journal.record(
        receiptId: id,
        number: number,
        createdAt: createdAt,
        kind: kind,
        sumsCents: zero,
        mustSign: true,
      );
    } else {
      await _record(
        journal,
        receiptId: id,
        number: number,
        createdAt: createdAt,
        kind: kind,
        sumsCents: zero,
        trySign: trySign,
      );
    }
    return byId(id);
  }

  /// Der Eintrag im Protokoll, in einer inneren Transaktion. Scheitert dabei
  /// etwas Unerwartetes und läuft die Probe, wird nur der Eintrag
  /// zurückgerollt und die Probe endet (K9): Der Bon bleibt gespeichert.
  /// Sonst rollt der Fehler den ganzen Bon zurück. Im echten Betrieb macht
  /// das Journal aus jedem Fehler der Einheit einen Ausfall (Q6); hier kommt
  /// dann nur noch ein Fehler der Datenbank (oder des AES-Schlüssels) an.
  Future<void> _record(
    RksvJournal journal, {
    required String receiptId,
    required int number,
    required DateTime createdAt,
    required ReceiptKind kind,
    required List<int> sumsCents,
    bool trySign = true,
  }) async {
    try {
      await _db.transaction(
        () => journal.record(
          receiptId: receiptId,
          number: number,
          createdAt: createdAt,
          kind: kind,
          sumsCents: sumsCents,
          trySign: trySign,
        ),
      );
    } on Object {
      if (!await journal.endProbeAfterError()) rethrow;
    }
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
        r.readTable(_db.modifierOptionRows).id: r
            .readTable(_db.modifierGroupRows)
            .name,
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
    // Einmal nach Bon gruppieren, statt je Bon alle Zeilen zu filtern.
    final linesOf = <String, List<ReceiptLineRow>>{};
    for (final l in lineRows) {
      (linesOf[l.receiptId] ??= []).add(l);
    }
    final optionsOf = <(String, int), List<ReceiptLineOptionRow>>{};
    for (final o in optionRows) {
      (optionsOf[(o.receiptId, o.linePosition)] ??= []).add(o);
    }
    final payments = {
      for (final p in await (_db.select(
        _db.paymentRows,
      )..where((t) => t.receiptId.isIn(ids))).get())
        p.receiptId: p,
    };
    final stamps = <String, RksvStamp>{};
    for (final j in await (_db.select(_db.rksvEntryRows).join([
      innerJoin(
        _db.rksvChainRows,
        _db.rksvChainRows.chain.equalsExp(_db.rksvEntryRows.chain),
      ),
    ])..where(_db.rksvEntryRows.receiptId.isIn(ids))).get()) {
      final entry = j.readTable(_db.rksvEntryRows);
      final chain = j.readTable(_db.rksvChainRows);
      final String text;
      try {
        text = qrText(entry.jws);
      } on FormatException {
        // Ein kaputter Eintrag soll die Liste der Bons nicht sperren: Der Bon
        // kommt ohne Angaben der Signatur.
        continue;
      }
      stamps[entry.receiptId] = RksvStamp(
        cashBoxId: chain.cashBoxId,
        qrText: text,
        damaged: entry.damaged,
        probe: chain.mode == 'probe',
      );
    }
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
            for (final l in linesOf[r.id] ?? const <ReceiptLineRow>[])
              ReceiptLine(
                position: l.position,
                itemId: l.itemId,
                name: l.name,
                info: l.info,
                unitPriceCents: l.unitPriceCents,
                quantity: l.quantity,
                unitDepositCents: l.unitDepositCents,
                options: [
                  for (final o
                      in optionsOf[(r.id, l.position)] ??
                          const <ReceiptLineOptionRow>[])
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
          // Sonderbelege haben keine Zahlung.
          payment: switch (payments[r.id]) {
            null => null,
            final p => Payment(
              kind: PaymentKind.values.byName(p.kind),
              amountCents: p.amountCents,
              givenCents: p.givenCents,
              changeCents: p.changeCents,
              provider: p.provider,
              providerTxCode: p.providerTxCode,
              cardScheme: p.cardScheme,
              cardLast4: p.cardLast4,
            ),
          },
          rksv: stamps[r.id],
          goodsCents: r.goodsCents,
          depositCents: r.depositCents,
          totalCents: r.totalCents,
        ),
    ];
  }
}
