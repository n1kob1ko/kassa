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
    expect(
      [for (final k in VoucherMovementKind.values) k.dbName],
      ['sale', 'redeem', 'void_sale', 'void_redeem'],
    );
    for (final k in VoucherMovementKind.values) {
      expect(VoucherMovementKind.fromDb(k.dbName), k);
    }
    expect(() => VoucherMovementKind.fromDb('voidSale'), throwsArgumentError);
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
}
