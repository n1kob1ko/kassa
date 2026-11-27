import 'package:drift/drift.dart' show Variable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/app_sync_providers.dart' show hasServerProvider;
import 'package:kassa/core/app_language.dart';
import 'package:kassa/data/providers.dart';
import 'package:kassa/data/settings_repository.dart';
import 'package:kassa/devices/device_providers.dart';
import 'package:kassa/devices/printer.dart';
import 'package:kassa/domain/customer.dart';
import 'package:kassa/domain/receipt.dart';
import 'package:kassa/features/kassa/sale_service.dart';

import '../support/fake_devices.dart';
import '../support/rksv_rig.dart';
import '../support/sales.dart' show cart;

/// Druckt wie [FakePrinter], aber der Jahresbeleg scheitert (oder wirft).
class _YearFails extends FakePrinter {
  _YearFails({this.throws = false});

  final bool throws;

  @override
  Future<PrintOutcome> printReceipt(
    Receipt receipt, {
    bool openDrawer = false,
    ReceiptRecipient? recipient,
  }) async {
    if (receipt.kind == ReceiptKind.year) {
      log.add('failed:${receipt.id}');
      if (throws) throw StateError('Papier aus');
      return const PrintOutcome.failed(PrintProblem.unreachable);
    }
    return super.printReceipt(receipt, openDrawer: openDrawer);
  }
}

void main() {
  late RksvRig rig;
  late ProviderContainer container;
  late SaleService service;

  Future<void> setUpWith(FakePrinter printer) async {
    rig = await RksvRig.open();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(rig.db),
        clockProvider.overrideWithValue(rig.clock),
        receiptRepositoryProvider.overrideWithValue(rig.receipts),
        receiptPrinterProvider.overrideWithValue(printer),
      ],
    );
    await container
        .read(settingsRepositoryProvider)
        .save(
          const RegisterSettings(
            printerKind: PrinterKind.network,
            printerAddress: '192.168.0.50',
          ),
        );
    await rig.service.enableProbe(staff: rig.chef);
    service = container.read(saleServiceProvider);
  }

  tearDown(() async {
    container.dispose();
    await rig.close();
  });

  Future<SaleResult> sell(String id) => service.completeCash(
    saleId: id,
    cart: cart,
    givenCents: cart.totalCents,
    staff: rig.anna,
  );

  Future<String> idOf(ReceiptKind kind) async =>
      (await rig.db
              .customSelect(
                'SELECT id FROM receipts WHERE kind = ?',
                variables: [Variable.withString(kind.name)],
              )
              .getSingle())
          .read<String>('id');

  test('Jahresbeleg vor dem Verkaufsbon, Monatsbeleg nicht', () async {
    final printer = FakePrinter();
    await setUpWith(printer);

    // Monatswechsel: der Monatsbeleg entsteht, gedruckt wird nur der Bon.
    rig.clock.value = DateTime(2026, 12, 2, 9);
    final december = await sell('s1');
    expect((await december.print).ok, isTrue);
    expect(printer.log, ['print+drawer:s1']);
    expect(await rig.receipts.yearReceiptBefore(december.receipt), isNull);

    // Jahreswechsel: zuerst der Jahresbeleg, dann der Bon mit der Lade.
    printer.log.clear();
    rig.clock.value = DateTime(2027, 1, 2, 9);
    final january = await sell('s2');
    expect((await january.print).ok, isTrue);
    final year = await idOf(ReceiptKind.year);
    expect(printer.log, ['print:$year', 'print+drawer:s2']);

    // Nochmal drucken aus den Bons: nur der Bon, nie der Jahresbeleg.
    printer.log.clear();
    await service.reprint(january.receipt);
    expect(printer.log, ['print:s2']);
  });

  for (final throws in [false, true]) {
    test(
      'Druck des Jahresbelegs ${throws ? 'wirft' : 'scheitert'}: der Bon '
      'des Verkaufs wird trotzdem gedruckt, der Verkauf steht einmal',
      () async {
        final printer = _YearFails(throws: throws);
        await setUpWith(printer);
        rig.clock.value = DateTime(2027, 1, 2, 9);
        final r = await sell('s1');
        expect((await r.print).ok, isTrue);
        final year = await idOf(ReceiptKind.year);
        expect(printer.log, ['failed:$year', 'print+drawer:s1']);
        expect(
          await rig.db
              .customSelect(
                "SELECT COUNT(*) AS n FROM receipts WHERE kind = 'sale'",
              )
              .map((row) => row.read<int>('n'))
              .getSingle(),
          1,
        );
      },
    );
  }

  test('"Digital, Druck auf Wunsch": der Jahresbeleg druckt beim Abschließen '
      'wie immer, der Kundenbon erst mit "Bon drucken"', () async {
    final printer = FakePrinter();
    rig = await RksvRig.open();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(rig.db),
        clockProvider.overrideWithValue(rig.clock),
        receiptRepositoryProvider.overrideWithValue(rig.receipts),
        receiptPrinterProvider.overrideWithValue(printer),
        hasServerProvider.overrideWithValue(true),
      ],
    );
    await container
        .read(settingsRepositoryProvider)
        .save(
          const RegisterSettings(
            printerKind: PrinterKind.network,
            printerAddress: '192.168.0.50',
            receiptMode: ReceiptMode.digitalOnRequest,
          ),
        );
    await container
        .read(syncStateRepositoryProvider)
        .saveRegister(
          registerId: 'kassa-1',
          registerName: 'Kassa 1',
          businessId: 'betrieb-1',
        );
    await rig.service.enableProbe(staff: rig.chef);
    service = container.read(saleServiceProvider);

    rig.clock.value = DateTime(2027, 1, 2, 9);
    final january = await sell('s2');
    expect(january.autoPrinted, isFalse);
    final year = await idOf(ReceiptKind.year);
    await pumpEventQueue();
    expect(printer.log, ['drawer', 'print:$year']);
    expect((await service.printNow(january.receipt)).ok, isTrue);
    expect((await january.print).ok, isTrue);
    expect(printer.log, ['drawer', 'print:$year', 'print:s2']);
  });
}

