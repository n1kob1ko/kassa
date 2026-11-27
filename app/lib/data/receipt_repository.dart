// Speichert Bons unveränderlich. Korrekturen sind Storno-Bons.

import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../core/clock.dart';
import '../domain/cart.dart';
import '../domain/catalog.dart';
import '../domain/discount.dart';
import '../domain/receipt.dart';
import '../domain/receipt_rules.dart';
import '../domain/staff.dart';
import '../domain/voucher.dart';
import '../rksv/core/rksv_code.dart';
import '../rksv/rksv_journal.dart';
import '../rksv/signature_unit.dart';
import 'database.dart';
import 'day_repository.dart';
import 'voucher_repository.dart';

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

/// Das Guthaben des Gutscheins [voucherId] reicht nicht mehr für seine
/// Zahlung. [balanceCents] ist das Guthaben, das an diesem Bon gilt (0 für
/// einen Übungs-Gutschein auf einem echten Bon und umgekehrt).
class VoucherBalanceException implements Exception {
  const VoucherBalanceException(this.voucherId, this.balanceCents);

  final String voucherId;
  final int balanceCents;

  @override
  String toString() =>
      'VoucherBalanceException: Der Gutschein $voucherId hat nur noch '
      '$balanceCents Cent.';
}

/// Storno eines Bons, auf dem ein Gutschein verkauft wurde, der schon
/// eingelöst ist.
class VoucherSaleRedeemedException implements Exception {
  const VoucherSaleRedeemedException();

  @override
  String toString() =>
      'VoucherSaleRedeemedException: Der Gutschein wurde schon eingelöst.';
}

/// Bar oder Karte, obwohl die Gutscheine schon alles bezahlen. Ein falscher
/// Bon für diesen Aufruf, darum ein [ArgumentError].
class NothingDueException extends ArgumentError {
  NothingDueException() : super('Es ist nichts mehr zu zahlen.', 'cart');

  @override
  String toString() => 'NothingDueException: Es ist nichts mehr zu zahlen.';
}

/// Ein Gutschein, der mit dem Bon entsteht.
typedef _NewVoucher = ({
  String id,
  String code,
  int valueCents,
  int linePosition,
  bool isTest,
});

class ReceiptRepository {
  /// [random] zieht den Schlüssel der öffentlichen Seite und die Codes der
  /// Gutscheine; ohne ist es [Random.secure].
  ReceiptRepository(
    this._db,
    this._clock,
    this._days, {
    this._journal,
    Random? random,
  }) : _random = random ?? Random.secure();

  final KassaDatabase _db;
  final Clock _clock;
  final DayRepository _days;
  final Random _random;
  late final VoucherRepository _vouchers = VoucherRepository(_db);

  /// Ohne Journal (in Tests) bekommt kein Bon einen Eintrag.
  final RksvJournal? _journal;

  /// Das Journal, mit dem die Bons ihre Einträge bekommen (null ohne).
  RksvJournal? get journal => _journal;

  /// Schließt einen Barverkauf ab. Die Id des Bons ist [saleId]: gibt es ihn
  /// schon, kommt der gespeicherte Bon zurück und nichts wird geschrieben.
  /// Im selben Schritt geht der Bon-Entwurf weg: ein Absturz direkt danach
  /// bietet denselben Verkauf nicht noch einmal an.
  ///
  /// Bar bezahlt wird, was nach den gewählten Gutscheinen offen ist
  /// (`cart.pricing.dueCents`); die Gutschein-Zahlungen stehen davor. Ist
  /// nichts offen, aber es gibt Gutschein-Zahlungen: [NothingDueException]
  /// (dafür ist [finalizeVoucherSale]). Ein Bon unter 0 ist eine Auszahlung
  /// ([finalizePayout]): hier [ArgumentError].
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
      final pricing = cart.pricing;
      if (pricing.totalCents < 0) {
        throw ArgumentError.value(
          pricing.totalCents,
          'cart',
          'Ein Bon unter 0 ist eine Auszahlung',
        );
      }
      final due = pricing.dueCents;
      if (due == 0 && pricing.voucherUses.isNotEmpty) {
        throw NothingDueException();
      }
      if (givenCents < due) throw const InsufficientCashException();

      final saved = await _writeSale(
        id: saleId,
        cart: cart,
        staff: staff,
        after: (position) => [
          Payment(
            position: position,
            kind: PaymentKind.cash,
            amountCents: due,
            givenCents: givenCents,
            changeCents: givenCents - due,
          ),
        ],
      );
      await _clearDraft();
      return saved;
    });
  }

  /// Schließt einen Bon ab, den die gewählten Gutscheine ganz bezahlen: nur
  /// Gutschein-Zahlungen, keine Bar-Zahlung. Es muss
  /// `cart.pricing.dueCents == 0` und `cart.pricing.voucherCents > 0` gelten,
  /// sonst [ArgumentError]. Sonst wie [finalizeCashSale].
  Future<Receipt> finalizeVoucherSale({
    required String saleId,
    required Cart cart,
    required Staff staff,
  }) {
    return _db.transaction(() async {
      final existing = await _find(saleId);
      if (existing != null) return existing;
      final pricing = cart.pricing;
      if (pricing.dueCents != 0 || pricing.voucherCents <= 0) {
        throw ArgumentError.value(
          pricing.dueCents,
          'cart',
          'Die Gutscheine bezahlen den Bon nicht ganz',
        );
      }
      final saved = await _writeSale(
        id: saleId,
        cart: cart,
        staff: staff,
        after: (_) => const [],
      );
      await _clearDraft();
      return saved;
    });
  }

  /// Schließt einen Bon unter 0 ab (etwa nur "Pfand zurück"): eine
  /// Bar-Zahlung über die Summe, gegeben 0, kein Rückgeld. Nur bei
  /// `cart.totalCents < 0`, sonst [ArgumentError]. Sonst wie
  /// [finalizeCashSale].
  Future<Receipt> finalizePayout({
    required String saleId,
    required Cart cart,
    required Staff staff,
  }) {
    return _db.transaction(() async {
      final existing = await _find(saleId);
      if (existing != null) return existing;
      final total = cart.pricing.totalCents;
      if (total >= 0) {
        throw ArgumentError.value(total, 'cart', 'Der Bon liegt nicht unter 0');
      }
      final saved = await _writeSale(
        id: saleId,
        cart: cart,
        staff: staff,
        after: (position) => [
          Payment(
            position: position,
            kind: PaymentKind.cash,
            amountCents: total,
            givenCents: 0,
            changeCents: 0,
          ),
        ],
      );
      await _clearDraft();
      return saved;
    });
  }

  Future<void> _clearDraft() =>
      (_db.update(_db.settingsRows)..where((t) => t.id.equals(1))).write(
        const SettingsRowsCompanion(receiptDraft: Value(null)),
      );

  /// Schließt einen Kartenverkauf ab, nachdem das Terminal bezahlt gemeldet
  /// hat. Bon, Zahlung, Entwurf und offene Zahlung ändern sich in einem
  /// Schritt. Gibt es den Bon zu [saleId] schon, kommt er zurück; die offene
  /// Zahlung mit dieser Id geht trotzdem weg.
  ///
  /// Vorn stehen die Gutschein-Zahlungen; bezahlt wird, was danach offen
  /// ist (`dueCents`). Mit [cashPartCents] über 0 ist der Rest gemischt
  /// bezahlt: zuerst bar über den Bar-Teil (gegeben gleich Bar-Teil, kein
  /// Rückgeld), dann mit Karte über den Rest. Die Karte trägt [tipCents]; das
  /// Trinkgeld gehört [staff]. Es muss `0 <= cashPartCents < dueCents` und
  /// `tipCents >= 0` gelten, sonst [ArgumentError].
  ///
  /// Mit [allowOverdraw] (die Karte hat schon bezahlt) entsteht der Bon
  /// auch, wenn ein Gutschein dabei unter 0 fällt. Bezahlen die Gutscheine
  /// schon alles: [NothingDueException].
  Future<Receipt> finalizeCardSale({
    required String saleId,
    required Cart cart,
    required Staff staff,
    required String provider,
    String? txCode,
    String? cardScheme,
    String? cardLast4,
    int cashPartCents = 0,
    int tipCents = 0,
    bool allowOverdraw = false,
  }) {
    return _db.transaction(() async {
      final existing = await _find(saleId);
      if (existing == null && cart.isEmpty) throw const EmptyCartException();
      final pricing = cart.pricing;
      final due = pricing.dueCents;
      if (existing == null) {
        // Eine Karte über 0 gibt es nicht: die Gutscheine bezahlen alles.
        if (due == 0 && pricing.voucherUses.isNotEmpty) {
          throw NothingDueException();
        }
        if (cashPartCents < 0 || cashPartCents >= due) {
          throw ArgumentError.value(
            cashPartCents,
            'cashPartCents',
            'Der Bar-Teil muss zwischen 0 und der Summe liegen',
          );
        }
        if (tipCents < 0) {
          throw ArgumentError.value(
            tipCents,
            'tipCents',
            'Das Trinkgeld darf nicht negativ sein',
          );
        }
      }
      final saved =
          existing ??
          await _writeSale(
            id: saleId,
            cart: cart,
            staff: staff,
            allowOverdraw: allowOverdraw,
            after: (position) => [
              if (cashPartCents > 0)
                Payment(
                  position: position,
                  kind: PaymentKind.cash,
                  amountCents: cashPartCents,
                  givenCents: cashPartCents,
                  changeCents: 0,
                ),
              Payment(
                position: cashPartCents > 0 ? position + 1 : position,
                kind: PaymentKind.card,
                amountCents: due - cashPartCents,
                givenCents: 0,
                changeCents: 0,
                tipCents: tipCents,
                tipStaffId: tipCents > 0 ? staff.id : null,
                tipStaffName: tipCents > 0 ? staff.name : null,
                provider: provider,
                providerTxCode: txCode,
                cardScheme: cardScheme,
                cardLast4: cardLast4,
              ),
            ],
          );
      await (_db.delete(
        _db.pendingCardPaymentRows,
      )..where((t) => t.id.equals(saleId))).go();
      if (existing == null) await _clearDraft();
      return saved;
    });
  }

  /// Schreibt den Verkauf [cart]: zuerst eine Gutschein-Zahlung je
  /// [VoucherUse], dann die Zahlungen aus [after] (es bekommt die Stelle der
  /// ersten). Jede Gutschein-Zeile bekommt einen neuen Gutschein.
  Future<Receipt> _writeSale({
    required String id,
    required Cart cart,
    required Staff staff,
    required List<Payment> Function(int position) after,
    bool allowOverdraw = false,
  }) async {
    final pricing = cart.pricing;
    final isTest = await _isTestReceipt();
    final voucherPayments = await _voucherPayments(
      pricing.voucherUses,
      isTest: isTest,
      allowOverdraw: allowOverdraw,
    );
    final (lines, newVouchers) = await _withNewVouchers(
      await _linesOf(cart),
      isTest: isTest,
    );
    return _write(
      id: id,
      kind: ReceiptKind.sale,
      staff: staff,
      lines: lines,
      goodsCents: cart.goodsCents,
      depositCents: cart.depositCents,
      totalCents: cart.totalCents,
      discountCents: pricing.discountCents,
      discount: _receiptDiscountOf(cart),
      payments: [...voucherPayments, ...after(voucherPayments.length)],
      newVouchers: newVouchers,
    );
  }

  /// Ob der Bon, der jetzt entstünde, ein Übungs-Bon ist (für die Prüfung
  /// eines Gutscheins vor dem Einlösen).
  Future<bool> isTestReceiptNow() => _isTestReceipt();

  /// Prüft vor einer Kartenzahlung jedes Guthaben der gewählten Gutscheine
  /// von [cart] nach derselben Regel wie das Abschließen: reicht eines
  /// nicht, [VoucherBalanceException]. Schreibt nichts.
  Future<void> checkVoucherBalances(Cart cart) async {
    final uses = cart.pricing.voucherUses;
    if (uses.isEmpty) return;
    await _voucherPayments(
      uses,
      isTest: await _isTestReceipt(),
      allowOverdraw: false,
    );
  }

  /// Ob der Bon, der jetzt entsteht, ein Übungs-Bon ist: nach der Kette, in
  /// die sein Eintrag kommt ([isTestChainMode]).
  Future<bool> _isTestReceipt() async {
    final journal = _journal;
    if (journal == null || !await journal.isActive()) {
      return isTestChainMode(null);
    }
    final row = await _db
        .customSelect(
          'SELECT c.mode FROM rksv_state s '
          'JOIN rksv_chains c ON c.chain = s.chain WHERE s.id = 1',
        )
        .getSingleOrNull();
    return isTestChainMode(row?.read<String>('mode'));
  }

  /// Eine Zahlung je [VoucherUse], ab Stelle 0. Das Guthaben kommt aus den
  /// Bewegungen, nicht aus dem Bon. Ein Übungs-Gutschein gilt nur auf einem
  /// Übungs-Bon, ein echter nur auf einem echten (sonst Guthaben 0). Reicht
  /// das Guthaben nicht: [VoucherBalanceException], außer mit
  /// [allowOverdraw].
  Future<List<Payment>> _voucherPayments(
    List<VoucherUse> uses, {
    required bool isTest,
    required bool allowOverdraw,
  }) async {
    final payments = <Payment>[];
    for (final use in uses) {
      final voucher = await _vouchers.byId(use.voucherId);
      if (voucher == null) throw VoucherBalanceException(use.voucherId, 0);
      final balance = voucher.balanceCents;
      final usable = usableVoucherBalance(voucher, onTestReceipt: isTest);
      if (usable < use.amountCents && !allowOverdraw) {
        throw VoucherBalanceException(voucher.id, usable);
      }
      payments.add(
        Payment(
          position: payments.length,
          kind: PaymentKind.voucher,
          amountCents: use.amountCents,
          givenCents: use.amountCents,
          changeCents: 0,
          voucherId: voucher.id,
          voucherCode: voucher.code,
          voucherBalanceAfterCents: balance - use.amountCents,
        ),
      );
    }
    return payments;
  }

  /// Je Gutschein-Zeile ein neuer Gutschein mit freiem Code; die Zeile trägt
  /// danach den Code als `info`.
  Future<(List<ReceiptLine>, List<_NewVoucher>)> _withNewVouchers(
    List<ReceiptLine> lines, {
    required bool isTest,
  }) async {
    final created = <_NewVoucher>[];
    final out = <ReceiptLine>[];
    for (final l in lines) {
      if (!isVoucherSaleItemId(l.itemId)) {
        out.add(l);
        continue;
      }
      if (l.quantity != 1) {
        throw StateError('Eine Gutschein-Zeile hat immer die Menge 1.');
      }
      final code = await _freeCode({for (final v in created) v.code});
      created.add((
        id: const Uuid().v4(),
        code: code,
        valueCents: l.unitPriceCents,
        linePosition: l.position,
        isTest: isTest,
      ));
      out.add(
        ReceiptLine(
          position: l.position,
          itemId: l.itemId,
          name: l.name,
          info: 'Code ${formatVoucherCode(code)}',
          unitPriceCents: l.unitPriceCents,
          quantity: l.quantity,
          unitDepositCents: l.unitDepositCents,
          options: l.options,
          grossByRate: l.grossByRate,
          discountCents: l.discountCents,
          discount: l.discount,
        ),
      );
    }
    return (out, created);
  }

  /// 8 zufällige Ziffern, die noch kein Gutschein hat (auch keiner aus
  /// [taken], die mit diesem Bon entstehen).
  Future<String> _freeCode(Set<String> taken) async {
    while (true) {
      final code = [for (var i = 0; i < 8; i++) _random.nextInt(10)].join();
      if (taken.contains(code)) continue;
      final used =
          await (_db.select(_db.voucherRows)
                ..where((t) => t.code.equals(code))
                ..limit(1))
              .getSingleOrNull();
      if (used == null) return code;
    }
  }

  /// Schlüssel der öffentlichen Seite: 16 zufällige Bytes, base64url ohne
  /// `=` (22 Zeichen).
  String _newPublicToken() => base64Url
      .encode([for (var i = 0; i < 16; i++) _random.nextInt(256)])
      .replaceAll('=', '');

  /// Die Zeilen des Bons aus [Cart.pricing]: Beträge je Satz nach Rabatt,
  /// der Rabatt der Zeile und ihr eigener Rabatt. Der Einzelpreis bleibt der
  /// Preis vor Rabatt.
  Future<List<ReceiptLine>> _linesOf(Cart cart) async {
    final groupNames = await _groupNamesOf(cart);
    final pricing = cart.pricing;
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
          grossByRate: pricing.lines[i].grossByRate,
          discountCents: pricing.lines[i].discountCents,
          discount: _discountOf(
            cart.lines[i].discount,
            pricing.lines[i].ownDiscountCents,
          ),
        ),
    ];
  }

  /// Der Bon-Rabatt von [cart] mit seinem Betrag, sonst `null`.
  static ReceiptDiscount? _receiptDiscountOf(Cart cart) =>
      _discountOf(cart.discount, cart.pricing.receiptDiscountCents);

  static ReceiptDiscount? _discountOf(Discount? d, int amountCents) => d == null
      ? null
      : ReceiptDiscount(
          percent: d.percent,
          amountCents: amountCents,
          reason: d.reason.name,
        );

  /// Derselbe Rabatt mit negativem Betrag, für den Storno.
  static ReceiptDiscount? _negated(ReceiptDiscount? d) => d == null
      ? null
      : ReceiptDiscount(
          percent: d.percent,
          amountCents: -d.amountCents,
          reason: d.reason,
        );

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
      if (original.payments.isEmpty) {
        throw StateError('Bon "${original.id}" hat keine Zahlung.');
      }
      final journal = _journal;
      if (journal != null && !await journal.mayVoid(original.id)) {
        throw const NotInCurrentChainException();
      }
      final sold = await _vouchers.soldOn(original.id);
      if (!sold.every((v) => v.mayVoidSale)) {
        throw const VoucherSaleRedeemedException();
      }
      // Jede Zahlung gespiegelt. Das Trinkgeld bleibt bei der Person, die
      // kassiert hat, nicht bei der, die storniert (Spec 5.4a). Ein
      // Gutschein bekommt seinen Betrag zurück.
      final payments = <Payment>[];
      for (final p in original.payments) {
        final voucherId = p.voucherId;
        payments.add(
          Payment(
            position: p.position,
            kind: p.kind,
            amountCents: -p.amountCents,
            givenCents: 0,
            changeCents: 0,
            tipCents: -p.tipCents,
            tipStaffId: p.tipStaffId,
            tipStaffName: p.tipStaffName,
            provider: p.provider,
            providerTxCode: p.providerTxCode,
            cardScheme: p.cardScheme,
            cardLast4: p.cardLast4,
            voucherId: voucherId,
            voucherCode: p.voucherCode,
            voucherBalanceAfterCents: voucherId == null
                ? null
                : await _vouchers.balanceOf(voucherId) + p.amountCents,
          ),
        );
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
              discountCents: -l.discountCents,
              discount: _negated(l.discount),
            ),
        ],
        goodsCents: -original.goodsCents,
        depositCents: -original.depositCents,
        totalCents: -original.totalCents,
        discountCents: -original.discountCents,
        discount: _negated(original.discount),
        payments: payments,
        voidedVouchers: sold,
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
    int discountCents = 0,
    ReceiptDiscount? discount,
    required List<Payment> payments,
    List<_NewVoucher> newVouchers = const [],
    List<Voucher> voidedVouchers = const [],
  }) async {
    final isVoid = kind == ReceiptKind.voided;
    final tipCents = payments.fold<int>(0, (sum, p) => sum + p.tipCents);
    final sums = codeSums(
      lineGross: [for (final l in lines) l.grossByRate],
      depositCents: depositCents,
      tipCents: tipCents,
    );
    final journal = _journal;
    final signing = journal != null && await journal.isActive();
    // Mit laufender Signatur wie bisher zuerst diese Prüfung: Kein Bon geht
    // ins Protokoll, dessen Beträge nicht Summe plus Trinkgeld ergeben.
    if (signing &&
        sums.fold<int>(0, (a, b) => a + b) != totalCents + tipCents) {
      throw StateError(
        'Die Beträge je Satz ergeben nicht die Summe des Bons $id.',
      );
    }
    checkReceiptRules(
      goodsCents: goodsCents,
      depositCents: depositCents,
      totalCents: totalCents,
      discountCents: discountCents,
      lines: lines,
      payments: payments,
      isVoid: isVoid,
    );
    var signatureDown = false;
    if (signing) signatureDown = await _writeDue(journal, staff);
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
            tipCents: Value(tipCents),
            discountCents: Value(discountCents),
            discountPercent: Value(discount?.percent),
            discountAmountCents: Value(discount?.amountCents ?? 0),
            discountReason: Value(discount?.reason),
            publicToken: Value(_newPublicToken()),
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
              discountCents: Value(l.discountCents),
              ownDiscountPercent: Value(l.discount?.percent),
              ownDiscountCents: Value(l.discount?.amountCents ?? 0),
              ownDiscountReason: Value(l.discount?.reason),
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
    for (final payment in payments) {
      await _db
          .into(_db.paymentRows)
          .insert(
            PaymentRowsCompanion.insert(
              receiptId: id,
              position: Value(payment.position),
              kind: payment.kind.name,
              amountCents: payment.amountCents,
              givenCents: payment.givenCents,
              changeCents: payment.changeCents,
              tipCents: Value(payment.tipCents),
              tipStaffId: Value(payment.tipStaffId),
              tipStaffName: Value(payment.tipStaffName),
              provider: Value(payment.provider),
              providerTxCode: Value(payment.providerTxCode),
              cardScheme: Value(payment.cardScheme),
              cardLast4: Value(payment.cardLast4),
              voucherId: Value(payment.voucherId),
              voucherCode: Value(payment.voucherCode),
              voucherBalanceAfterCents: Value(payment.voucherBalanceAfterCents),
            ),
          );
    }
    await _writeVoucherMovements(
      receiptId: id,
      createdAt: createdAt,
      isVoid: isVoid,
      payments: payments,
      newVouchers: newVouchers,
      voidedVouchers: voidedVouchers,
    );
    if (signing) {
      await _record(
        journal,
        receiptId: id,
        number: number,
        createdAt: createdAt,
        kind: kind,
        sumsCents: sums,
        trySign: !signatureDown,
      );
    }
    return byId(id);
  }

  /// Neue Gutscheine mit ihrer Bewegung `sale`, je Gutschein-Zahlung
  /// `redeem` (beim Storno `void_redeem`) und je stornierten Verkauf
  /// `void_sale`, alle zum Bon [receiptId].
  Future<void> _writeVoucherMovements({
    required String receiptId,
    required DateTime createdAt,
    required bool isVoid,
    required List<Payment> payments,
    required List<_NewVoucher> newVouchers,
    required List<Voucher> voidedVouchers,
  }) async {
    Future<void> move(String voucherId, VoucherMovementKind kind, int cents) =>
        _db
            .into(_db.voucherMovementRows)
            .insert(
              VoucherMovementRowsCompanion.insert(
                voucherId: voucherId,
                receiptId: receiptId,
                kind: kind.dbName,
                amountCents: cents,
                createdAt: createdAt,
              ),
            );
    for (final v in newVouchers) {
      await _db
          .into(_db.voucherRows)
          .insert(
            VoucherRowsCompanion.insert(
              id: v.id,
              code: v.code,
              valueCents: v.valueCents,
              createdAt: createdAt,
              soldReceiptId: Value(receiptId),
              soldLinePosition: Value(v.linePosition),
              isTest: v.isTest,
            ),
          );
      await move(v.id, VoucherMovementKind.sale, v.valueCents);
    }
    for (final p in payments) {
      if (p.kind != PaymentKind.voucher) continue;
      await move(
        p.voucherId!,
        isVoid ? VoucherMovementKind.voidRedeem : VoucherMovementKind.redeem,
        -p.amountCents,
      );
    }
    for (final v in voidedVouchers) {
      await move(v.id, VoucherMovementKind.voidSale, -v.valueCents);
    }
  }

  Future<int> _nextNumber() async {
    final maxNumber = _db.receiptRows.number.max();
    final highest = await (_db.selectOnly(
      _db.receiptRows,
    )..addColumns([maxNumber])).map((r) => r.read(maxNumber)).getSingle();
    return (highest ?? 0) + 1;
  }

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
    final paymentsOf = <String, List<PaymentRow>>{};
    for (final p
        in await (_db.select(_db.paymentRows)
              ..where((t) => t.receiptId.isIn(ids))
              ..orderBy([(t) => OrderingTerm.asc(t.position)]))
            .get()) {
      (paymentsOf[p.receiptId] ??= []).add(p);
    }
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
    // Die Gutscheine eines Verkaufs; ein Storno-Bon zeigt die seines
    // Verkaufs mit negativem Wert.
    final saleOf = {
      for (final r in rows)
        r.id: r.kind == ReceiptKind.voided.name ? r.voidsReceiptId : r.id,
    };
    final soldOf = <String, List<VoucherRow>>{};
    for (final v
        in await (_db.select(_db.voucherRows)
              ..where(
                (t) =>
                    t.soldReceiptId.isIn(saleOf.values.nonNulls) &
                    t.soldLinePosition.isNotNull(),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.soldLinePosition)]))
            .get()) {
      (soldOf[v.soldReceiptId!] ??= []).add(v);
    }
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
                discountCents: l.discountCents,
                discount: l.ownDiscountReason == null
                    ? null
                    : ReceiptDiscount(
                        percent: l.ownDiscountPercent,
                        amountCents: l.ownDiscountCents,
                        reason: l.ownDiscountReason!,
                      ),
              ),
          ],
          // Sonderbelege haben keine Zahlung.
          payments: [
            for (final p in paymentsOf[r.id] ?? const <PaymentRow>[])
              Payment(
                position: p.position,
                kind: PaymentKind.values.byName(p.kind),
                amountCents: p.amountCents,
                givenCents: p.givenCents,
                changeCents: p.changeCents,
                tipCents: p.tipCents,
                tipStaffId: p.tipStaffId,
                tipStaffName: p.tipStaffName,
                provider: p.provider,
                providerTxCode: p.providerTxCode,
                cardScheme: p.cardScheme,
                cardLast4: p.cardLast4,
                voucherId: p.voucherId,
                voucherCode: p.voucherCode,
                voucherBalanceAfterCents: p.voucherBalanceAfterCents,
              ),
          ],
          soldVouchers: [
            for (final v in soldOf[saleOf[r.id]] ?? const <VoucherRow>[])
              SoldVoucher(
                voucherId: v.id,
                code: v.code,
                valueCents: r.kind == ReceiptKind.voided.name
                    ? -v.valueCents
                    : v.valueCents,
                linePosition: v.soldLinePosition!,
              ),
          ],
          publicToken: r.publicToken,
          rksv: stamps[r.id],
          goodsCents: r.goodsCents,
          depositCents: r.depositCents,
          totalCents: r.totalCents,
          discountCents: r.discountCents,
          discount: r.discountReason == null
              ? null
              : ReceiptDiscount(
                  percent: r.discountPercent,
                  amountCents: r.discountAmountCents,
                  reason: r.discountReason!,
                ),
        ),
    ];
  }
}
