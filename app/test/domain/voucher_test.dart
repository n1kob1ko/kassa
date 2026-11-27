import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/domain/voucher.dart';

void main() {
  final day = DateTime(2026, 11, 27, 12);

  VoucherMovement m(VoucherMovementKind kind, int cents, [String r = 'r1']) =>
      VoucherMovement(
        voucherId: 'v1',
        receiptId: r,
        kind: kind,
        amountCents: cents,
        createdAt: day,
      );

  Voucher voucher(List<VoucherMovement> movements) => Voucher(
    id: 'v1',
    code: '12345678',
    valueCents: 2500,
    createdAt: day,
    isTest: false,
    soldReceiptId: 'r1',
    movements: movements,
  );

  const sale = VoucherMovementKind.sale,
      redeem = VoucherMovementKind.redeem,
      voidSale = VoucherMovementKind.voidSale,
      voidRedeem = VoucherMovementKind.voidRedeem;

  test('Zustand: die Fälle aus shared/fixtures/vouchers/states.json', () {
    final cases =
        (jsonDecode(
              File('../shared/fixtures/vouchers/states.json')
                  .readAsStringSync(),
            ) as Map<String, dynamic>)['cases']
            as List<dynamic>;
    expect(cases.length, greaterThanOrEqualTo(8));
    const states = {
      'active': VoucherState.active,
      'empty': VoucherState.empty,
      'voided': VoucherState.voided,
      'overdrawn': VoucherState.overdrawn,
    };
    for (final c in cases.cast<Map<String, dynamic>>()) {
      final v = Voucher(
        id: 'v1',
        code: '12345678',
        valueCents: c['valueCents'] as int,
        createdAt: day,
        isTest: false,
        movements: [
          for (final (i, m)
              in (c['movements'] as List<dynamic>)
                  .cast<Map<String, dynamic>>()
                  .indexed)
            VoucherMovement(
              voucherId: 'v1',
              receiptId: 'r$i',
              kind: VoucherMovementKind.fromDb(m['kind'] as String),
              amountCents: m['amountCents'] as int,
              createdAt: day,
            ),
        ],
      );
      expect(
        (v.balanceCents, v.state),
        (c['balanceCents'] as int, states[c['state']]!),
        reason: c['name'] as String,
      );
    }
  });

  test('Guthaben und Zustand folgen aus den Bewegungen', () {
    final sold = voucher([m(sale, 2500)]);
    expect(
      (sold.balanceCents, sold.state, sold.untouched),
      (2500, VoucherState.active, true),
    );

    final part = voucher([m(sale, 2500), m(redeem, -965, 'r2')]);
    expect(
      (part.balanceCents, part.state, part.untouched),
      (1535, VoucherState.active, false),
    );

    final empty = voucher([
      m(sale, 2500),
      m(redeem, -965, 'r2'),
      m(redeem, -1535, 'r3'),
    ]);
    expect(
      (empty.balanceCents, empty.state, empty.untouched),
      (0, VoucherState.empty, false),
    );

    final voided = voucher([m(sale, 2500), m(voidSale, -2500, 'r4')]);
    expect(
      (voided.balanceCents, voided.state, voided.untouched),
      (0, VoucherState.voided, false),
    );

    final overdrawn = voucher([
      m(sale, 2500),
      m(redeem, -2500, 'r2'),
      m(redeem, -500, 'r3'),
    ]);
    expect(
      (overdrawn.balanceCents, overdrawn.state),
      (-500, VoucherState.overdrawn),
    );

    // Storniert, danach anderswo eingelöst: überzogen, nicht storniert.
    final voidedThenRedeemed = voucher([
      m(sale, 2500),
      m(redeem, -1000, 'r2'),
      m(voidSale, -2500, 'r4'),
    ]);
    expect(voidedThenRedeemed.state, VoucherState.overdrawn);

    // Storno einer Einlösung bringt das Guthaben zurück.
    final back = voucher([
      m(sale, 2500),
      m(redeem, -2500, 'r2'),
      m(voidRedeem, 2500, 'r5'),
    ]);
    expect(
      (back.balanceCents, back.state, back.untouched),
      (2500, VoucherState.active, false),
    );
  });

  test('Arten der Bewegungen heißen in der Datenbank sale, redeem, void_sale, '
      'void_redeem', () {
    final known = VoucherMovementKind.values.where(
      (k) => k != VoucherMovementKind.unknown,
    );
    expect(
      [for (final k in known) k.dbName],
      ['sale', 'redeem', 'void_sale', 'void_redeem'],
    );
    for (final k in known) {
      expect(VoucherMovementKind.fromDb(k.dbName), k);
    }
    // Eine Art einer späteren Version bricht nichts ab (Schlussprüfung A-I1).
    expect(VoucherMovementKind.fromDb('voidSale'), VoucherMovementKind.unknown);
    expect(VoucherMovementKind.fromDb('top_up'), VoucherMovementKind.unknown);
  });

  test('formatVoucherCode und isVoucherCode', () {
    expect(formatVoucherCode('12345678'), '1234 5678');
    expect(
      [
        isVoucherCode('12345678'),
        isVoucherCode('1234567'),
        isVoucherCode('1234 5678'),
        isVoucherCode('1234567a'),
      ],
      [true, false, false, false],
    );
    expect(isVoucherCode('123456789'), isFalse);
    expect(isVoucherCode('00000000'), isTrue);
  });

  test('mayVoidSale: nur mit dem Guthaben vom Verkauf und ohne Storno des '
      'Verkaufs', () {
    expect(voucher([m(sale, 2500)]).mayVoidSale, isTrue);
    expect(
      voucher([m(sale, 2500), m(redeem, -965, 'r2')]).mayVoidSale,
      isFalse,
    );
    // Die Einlösung ist selbst storniert: wieder wie vom Verkauf.
    expect(
      voucher([m(sale, 2500), m(redeem, -965, 'r2'), m(voidRedeem, 965, 'r3')])
          .mayVoidSale,
      isTrue,
    );
    expect(
      voucher([m(sale, 2500), m(voidSale, -2500, 'r2')]).mayVoidSale,
      isFalse,
    );
  });

  test(
    'usableVoucherBalance: Übung nur auf Übungs-Bon, echt nur auf echtem',
    () {
      final live = voucher([m(sale, 2500), m(redeem, -965, 'r2')]);
      final practice = Voucher(
        id: 'v2',
        code: '87654321',
        valueCents: 2000,
        createdAt: day,
        isTest: true,
        movements: [
          VoucherMovement(
            voucherId: 'v2',
            receiptId: 'r9',
            kind: sale,
            amountCents: 2000,
            createdAt: day,
          ),
        ],
      );
      expect(usableVoucherBalance(live, onTestReceipt: false), 1535);
      expect(usableVoucherBalance(live, onTestReceipt: true), 0);
      expect(usableVoucherBalance(practice, onTestReceipt: true), 2000);
      expect(usableVoucherBalance(practice, onTestReceipt: false), 0);
      expect(usableVoucherBalance(null, onTestReceipt: true), 0);
    },
  );

  test('voucherRedeemProblem: der erste Grund, sonst null', () {
    final ok = voucher([m(sale, 2500)]);
    expect(voucherRedeemProblem(ok, onTestReceipt: false), isNull);
    expect(
      voucherRedeemProblem(ok, onTestReceipt: false, chosenIds: ['v1']),
      VoucherRedeemProblem.alreadyOnReceipt,
    );
    expect(
      voucherRedeemProblem(ok, onTestReceipt: true),
      VoucherRedeemProblem.liveOnly,
    );
    expect(
      voucherRedeemProblem(
        voucher([m(sale, 2500), m(voidSale, -2500, 'r2')]),
        onTestReceipt: false,
      ),
      VoucherRedeemProblem.voided,
    );
    expect(
      voucherRedeemProblem(
        voucher([m(sale, 2500), m(redeem, -2500, 'r2')]),
        onTestReceipt: false,
      ),
      VoucherRedeemProblem.empty,
    );
    expect(
      voucherRedeemProblem(
        voucher([m(sale, 2500), m(redeem, -3000, 'r2')]),
        onTestReceipt: false,
      ),
      VoucherRedeemProblem.empty,
    );
    final practice = Voucher(
      id: 'v2',
      code: '87654321',
      valueCents: 2000,
      createdAt: day,
      isTest: true,
      movements: const [],
    );
    expect(
      voucherRedeemProblem(practice, onTestReceipt: false),
      VoucherRedeemProblem.testOnly,
    );
  });
}
