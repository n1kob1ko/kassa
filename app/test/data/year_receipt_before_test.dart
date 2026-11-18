import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/domain/receipt.dart';

import '../support/rksv_rig.dart';
import '../support/sales.dart' show cart;

void main() {
  late RksvRig rig;

  setUp(() async {
    rig = await RksvRig.open();
    await rig.service.enableProbe(staff: rig.chef);
  });
  tearDown(() => rig.close());

  test('findet den Jahresbeleg direkt vor dem Verkauf, auch wenn die Uhr '
      'dazwischen 2 Sekunden weiterläuft', () async {
    final year = await rig.receipts.createSpecial(
      ReceiptKind.year,
      staff: rig.anna,
    );
    rig.clock.value = rig.clock.value.add(const Duration(seconds: 2));
    final sale = await rig.sell('s1', cart);
    expect(sale.number, year.number + 1);
    expect(sale.createdAt, isNot(year.createdAt));

    final found = await rig.receipts.yearReceiptBefore(sale);
    expect(found?.id, year.id);
    expect(found?.kind, ReceiptKind.year);
  });

  test('ein Jahreswechsel vor dem Verkauf: der fällige Jahresbeleg wird '
      'gefunden', () async {
    await rig.sell('s1', cart);
    rig.clock.value = DateTime(2027, 1, 2, 9);
    final sale = await rig.sell('s2', cart);
    final found = await rig.receipts.yearReceiptBefore(sale);
    expect(found?.kind, ReceiptKind.year);
    expect(found?.number, sale.number - 1);
  });

  test('null, wenn davor ein Monatsbeleg steht', () async {
    await rig.receipts.createSpecial(ReceiptKind.month, staff: rig.anna);
    final sale = await rig.sell('s1', cart);
    expect(await rig.receipts.yearReceiptBefore(sale), isNull);
  });

  test('null, wenn davor ein normaler Verkauf steht', () async {
    await rig.sell('s1', cart);
    final sale = await rig.sell('s2', cart);
    expect(await rig.receipts.yearReceiptBefore(sale), isNull);
  });

  test('null, wenn es davor keinen Bon gibt', () async {
    final start = await rig.receipts.byId(
      (await rig.db
              .customSelect('SELECT id FROM receipts WHERE number = 1')
              .getSingle())
          .read<String>('id'),
    );
    expect(start.number, 1);
    expect(await rig.receipts.yearReceiptBefore(start), isNull);
  });
}
