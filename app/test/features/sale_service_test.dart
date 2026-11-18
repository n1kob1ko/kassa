import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/data/providers.dart';
import 'package:kassa/data/settings_repository.dart';
import 'package:kassa/devices/device_providers.dart';
import 'package:kassa/devices/printer.dart';
import 'package:kassa/domain/receipt.dart';
import 'package:kassa/features/kassa/sale_service.dart';

import '../support/fake_devices.dart';
import '../support/sales.dart';

void main() {
  late TestShop shop;
  late FakePrinter printer;
  late ProviderContainer container;
  late SaleService service;

  Future<void> configure({
    PrinterKind kind = PrinterKind.network,
    bool drawer = true,
  }) async {
    final repo = container.read(settingsRepositoryProvider);
    await repo.save(
      (await repo.current()).copyWith(
        printerKind: kind,
        printerAddress: kind == PrinterKind.none ? null : '192.168.0.50',
        cashDrawerEnabled: drawer,
      ),
    );
  }

  setUp(() async {
    shop = await TestShop.open();
    printer = FakePrinter();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(shop.db),
        clockProvider.overrideWithValue(shop.clock),
        receiptPrinterProvider.overrideWithValue(printer),
      ],
    );
    service = container.read(saleServiceProvider);
  });
  tearDown(() async {
    container.dispose();
    await shop.close();
  });

  Future<SaleResult> sell([String id = 's1']) => service.completeCash(
    saleId: id,
    cart: cart,
    givenCents: 2000,
    staff: shop.anna,
  );

  test('Bar mit Lade: erst Lade, dann Bon', () async {
    await configure();
    final r = await sell();
    expect((await r.print).ok, isTrue);
    expect(printer.log, ['drawer', 'print:s1']);
  });

  test('Lade ausgeschaltet: nur Bon', () async {
    await configure(drawer: false);
    final r = await sell();
    expect((await r.print).ok, isTrue);
    expect(printer.log, ['print:s1']);
  });

  test('ohne Drucker: Bon gespeichert, print ergibt notSetUp, nichts '
      'geschickt', () async {
    await configure(kind: PrinterKind.none);
    final r = await sell();
    expect((await r.print).problem, PrintProblem.notSetUp);
    expect(printer.log, isEmpty);
    expect(await shop.count('receipts'), 1);
  });

  test('Drucker scheitert: der Bon ist trotzdem da, genau einmal', () async {
    await configure();
    printer.next = const PrintOutcome.failed(PrintProblem.unreachable);
    final r = await sell();
    expect((await r.print).ok, isFalse);
    expect(await shop.count('receipts'), 1);
    expect(r.receipt.number, 1);
  });

  test('Drucker hängt: completeCash kommt sofort zurück', () async {
    await configure();
    printer.hold = Completer<void>();
    final r = await sell(); // kein Warten auf den Drucker
    var done = false;
    unawaited(r.print.then((_) => done = true));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(done, isFalse);
    expect(await shop.count('receipts'), 1);
    printer.hold!.complete();
    expect((await r.print).ok, isTrue);
  });

  test('zweimal dieselbe saleId: ein Bon, ein Druck', () async {
    await configure();
    final a = await sell();
    final b = await sell();
    await a.print;
    await b.print;
    expect(b.receipt.id, a.receipt.id);
    expect(await shop.count('receipts'), 1);
    expect(printer.printed, ['s1']);
    expect(printer.log.where((e) => e == 'drawer'), hasLength(1));
  });

  test('Storno druckt den Storno-Bon und öffnet die Lade nicht', () async {
    await configure();
    final sale = await shop.sell('s1');
    final r = await service.voidReceipt(sale.id, staff: shop.chef);
    expect(r.receipt.kind, ReceiptKind.voided);
    expect((await r.print).ok, isTrue);
    expect(printer.log, ['print:${r.receipt.id}']);
  });

  test('reprint druckt den Bon noch einmal, ohne Lade', () async {
    await configure();
    final sale = await shop.sell('s1');
    expect((await service.reprint(sale)).ok, isTrue);
    expect(printer.log, ['print:s1']);
  });

  test('reprint ohne Drucker: notSetUp', () async {
    await configure(kind: PrinterKind.none);
    final sale = await shop.sell('s1');
    expect((await service.reprint(sale)).problem, PrintProblem.notSetUp);
    expect(printer.log, isEmpty);
  });
}
