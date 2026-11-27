import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Variable;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/core/app_language.dart';
import 'package:kassa/data/card_payment_repository.dart';
import 'package:kassa/data/database.dart';
import 'package:kassa/data/providers.dart';
import 'package:kassa/data/receipt_repository.dart';
import 'package:kassa/data/settings_repository.dart';
import 'package:kassa/devices/card_terminal.dart';
import 'package:kassa/devices/device_providers.dart';
import 'package:kassa/devices/escpos.dart';
import 'package:kassa/devices/mono_image.dart';
import 'package:kassa/devices/printer.dart';
import 'package:kassa/domain/cart.dart';
import 'package:kassa/domain/catalog.dart';
import 'package:kassa/domain/discount.dart';
import 'package:kassa/domain/kitchen_ticket.dart';
import 'package:kassa/domain/receipt.dart';
import 'package:kassa/domain/staff.dart';
import 'package:kassa/features/kassa/cart_controller.dart';
import 'package:kassa/features/kassa/sale_service.dart';

import '../support/fake_devices.dart';
import '../support/demo_fixtures.dart';
import '../support/sales.dart';

void main() {
  late TestShop shop;
  late FakePrinter printer;
  late FakePrinter kitchen;
  late List<(KitchenTicket, int)> rendered;
  late FakeCardTerminal terminal;
  late CardPaymentRepository cardPayments;
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
    kitchen = FakePrinter();
    rendered = [];
    terminal = FakeCardTerminal();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(shop.db),
        clockProvider.overrideWithValue(shop.clock),
        receiptPrinterProvider.overrideWithValue(printer),
        // Wie der echte Provider: am Bondrucker dieselbe Instanz, sonst
        // ein eigener Drucker.
        kitchenPrinterProvider.overrideWith(
          (ref) =>
              switch (ref.watch(settingsStreamProvider).value?.kitchenMode) {
                KitchenMode.receiptPrinter => printer,
                KitchenMode.kitchenPrinter => kitchen,
                _ => null,
              },
        ),
        kitchenImageRendererProvider.overrideWithValue((
          ticket, {
          required widthDots,
        }) async {
          rendered.add((ticket, widthDots));
          return _tinyImage;
        }),
        cardTerminalProvider.overrideWithValue(terminal),
      ],
    );
    // Hält den Strom der Einstellungen offen, damit der Küchendrucker ihnen
    // folgt.
    container.listen(settingsStreamProvider, (_, _) {});
    service = container.read(saleServiceProvider);
    cardPayments = container.read(cardPaymentRepositoryProvider);
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

  test('Bar mit Lade: Lade und Bon in einem Druckauftrag', () async {
    await configure();
    final r = await sell();
    expect((await r.print).ok, isTrue);
    expect(printer.log, ['print+drawer:s1']);
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
    expect(printer.log, ['print+drawer:s1']);
  });

  group('Küchenbon', () {
    Future<void> configureKitchen(
      KitchenMode mode, {
      PrinterKind kind = PrinterKind.network,
      Set<String> skip = const {},
      AppLanguage language = AppLanguage.de,
    }) async {
      final repo = container.read(settingsRepositoryProvider);
      await repo.save(
        (await repo.current()).copyWith(
          kitchenMode: mode,
          kitchenLanguage: language,
          kitchenPrinterKind: kind,
          kitchenPrinterAddress: kind == PrinterKind.none
              ? null
              : '192.168.0.60',
          kitchenPrinterColumns: 32,
          kitchenSkipCategories: skip,
        ),
      );
      // Der Strom der Einstellungen hat die Änderung gebracht.
      for (var i = 0; i < 100; i++) {
        final now = container.read(settingsStreamProvider).value;
        if (now?.kitchenMode == mode && now?.kitchenLanguage == language) {
          return;
        }
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      fail('Einstellungen kamen nicht an');
    }

    final raster = encodeRasterTicket(_tinyImage);

    test('aus: der Küchendrucker wird nie gerufen, kitchen ist null', () async {
      await configure();
      await configureKitchen(KitchenMode.off);
      final r = await sell();
      expect((await r.print).ok, isTrue);
      expect(await r.kitchen, isNull);
      expect(printer.log, ['print+drawer:s1']);
      expect(kitchen.log, isEmpty);
      expect(rendered, isEmpty);
    });

    test('am Bondrucker: erst der Kundenbon, dann das Raster', () async {
      await configure();
      await configureKitchen(KitchenMode.receiptPrinter);
      final r = await sell();
      expect((await r.print).ok, isTrue);
      expect((await r.kitchen)!.ok, isTrue);
      expect(printer.log, ['print+drawer:s1', 'raster']);
      expect(printer.rasters, [raster]);
      expect(kitchen.log, isEmpty);
      final (ticket, width) = rendered.single;
      expect(width, 48 * 12); // Papier des Bondruckers
      expect(ticket.kind, KitchenTicketKind.order);
      expect(ticket.number, r.receipt.number);
      expect(ticket.title, 'KÜCHE');
      expect(ticket.banner, isNull);
      // Ohne Wörterbuch die Namen des Bons.
      expect(
        [for (final l in ticket.lines) l.name],
        [for (final l in r.receipt.lines) l.name],
      );
      expect(ticket.lines, hasLength(2));
    });

    test('am Bondrucker: der Küchenbon wartet auf den Kundenbon', () async {
      await configure();
      await configureKitchen(KitchenMode.receiptPrinter);
      printer.hold = Completer<void>();
      final r = await sell();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(printer.log, ['print+drawer:s1']);
      printer.hold!.complete();
      expect((await r.kitchen)!.ok, isTrue);
      expect(printer.log, ['print+drawer:s1', 'raster']);
    });

    test('am Küchendrucker: Raster dorthin, Bon an den Bondrucker, beide '
        'gleichzeitig', () async {
      await configure();
      await configureKitchen(KitchenMode.kitchenPrinter);
      printer.hold = Completer<void>(); // Bondrucker hängt
      final r = await sell();
      expect((await r.kitchen)!.ok, isTrue);
      expect(kitchen.log, ['raster']);
      expect(kitchen.rasters, [raster]);
      expect(rendered.single.$2, 32 * 12); // Papier des Küchendruckers
      printer.hold!.complete();
      expect((await r.print).ok, isTrue);
      expect(printer.log, ['print+drawer:s1']);
    });

    test('Küchendrucker hängt: der Kundenbon kommt trotzdem', () async {
      await configure();
      await configureKitchen(KitchenMode.kitchenPrinter);
      kitchen.hold = Completer<void>();
      final r = await sell();
      expect((await r.print).ok, isTrue);
      var kitchenDone = false;
      unawaited(r.kitchen.then((_) => kitchenDone = true));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(kitchenDone, isFalse);
      // Der nächste Verkauf druckt seinen Bon, der Küchendrucker hängt noch.
      final next = await sell('s2');
      expect((await next.print).ok, isTrue);
      kitchen.hold!.complete();
      expect((await r.kitchen)!.ok, isTrue);
      expect((await next.kitchen)!.ok, isTrue);
    });

    test('Küchendrucker wirft: Verkauf gespeichert, print ok, kitchen '
        'gescheitert', () async {
      await configure();
      await configureKitchen(KitchenMode.kitchenPrinter);
      kitchen.rasterError = StateError('kaputt');
      final r = await sell();
      expect(await shop.count('receipts'), 1);
      expect(r.receipt.number, 1);
      expect((await r.print).ok, isTrue);
      expect((await r.kitchen)!.problem, PrintProblem.unreachable);
    });

    test('Zeichnen wirft: kitchen gescheitert, der Bon ist gedruckt', () async {
      container.dispose();
      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(shop.db),
          clockProvider.overrideWithValue(shop.clock),
          receiptPrinterProvider.overrideWithValue(printer),
          kitchenPrinterProvider.overrideWithValue(printer),
          kitchenImageRendererProvider.overrideWithValue(
            (ticket, {required widthDots}) async => throw StateError('x'),
          ),
        ],
      );
      service = container.read(saleServiceProvider);
      container.listen(settingsStreamProvider, (_, _) {});
      await configure();
      await configureKitchen(KitchenMode.receiptPrinter);
      final r = await sell();
      expect((await r.print).ok, isTrue);
      expect((await r.kitchen)!.problem, PrintProblem.unreachable);
      expect(printer.log, ['print+drawer:s1', 'raster']);
    });

    test('Bondrucker scheitert, Küchendrucker druckt', () async {
      await configure();
      await configureKitchen(KitchenMode.kitchenPrinter);
      printer.next = const PrintOutcome.failed(PrintProblem.paperOut);
      final r = await sell();
      expect((await r.print).problem, PrintProblem.paperOut);
      expect((await r.kitchen)!.ok, isTrue);
      expect(kitchen.rasters, [raster]);
    });

    test('am Küchendrucker, aber keiner eingerichtet: notSetUp', () async {
      await configure();
      await configureKitchen(
        KitchenMode.kitchenPrinter,
        kind: PrinterKind.none,
      );
      final r = await sell();
      expect((await r.print).ok, isTrue);
      expect((await r.kitchen)!.problem, PrintProblem.notSetUp);
      expect(kitchen.log, isEmpty);
    });

    test('nur Getränke: kitchen ist null, nichts gedruckt', () async {
      await configure();
      await configureKitchen(
        KitchenMode.kitchenPrinter,
        skip: {cola.categoryId},
      );
      final r = await service.completeCash(
        saleId: 's1',
        cart: const Cart.empty().add(cola).add(leitungswasser),
        givenCents: 2000,
        staff: shop.anna,
      );
      expect((await r.print).ok, isTrue);
      expect(await r.kitchen, isNull);
      expect(kitchen.log, isEmpty);
      expect(rendered, isEmpty);
    });

    test(
      'Getränke abgeschaltet: nur die Speisen stehen am Küchenbon',
      () async {
        await configure();
        await configureKitchen(
          KitchenMode.kitchenPrinter,
          skip: {cola.categoryId},
        );
        final r = await sell();
        expect((await r.kitchen)!.ok, isTrue);
        final ticket = rendered.single.$1;
        expect([for (final l in ticket.lines) l.name], ['Huhn Bowl']);
        expect(ticket.lines.single.options, ['XXL', 'Nudeln']);
      },
    );

    test('in der Küchensprache, unabhängig von der Bediensprache', () async {
      await configure();
      await configureKitchen(
        KitchenMode.kitchenPrinter,
        language: AppLanguage.tr,
      );
      final r = await sell();
      await r.kitchen;
      expect(rendered.single.$1.language, AppLanguage.tr);
      expect(rendered.single.$1.title, 'MUTFAK');
    });

    test('Storno: Küchenbon mit STORNO und der Nummer des Bons', () async {
      await configure();
      await configureKitchen(KitchenMode.kitchenPrinter);
      final sale = await sell();
      await sale.kitchen;
      rendered.clear();
      final v = await service.voidReceipt(sale.receipt.id, staff: shop.chef);
      expect((await v.print).ok, isTrue);
      expect((await v.kitchen)!.ok, isTrue);
      final ticket = rendered.single.$1;
      expect(ticket.kind, KitchenTicketKind.voided);
      expect(ticket.banner, 'STORNO');
      expect(ticket.number, sale.receipt.number);
      expect([for (final l in ticket.lines) l.quantity], [2, 1]);
      expect(kitchen.log, ['raster', 'raster']);
    });

    test(
      'Storno am Bondrucker: erst der Storno-Bon, dann das Raster',
      () async {
        await configure();
        final sale = await sell();
        await sale.print;
        await configureKitchen(KitchenMode.receiptPrinter);
        printer.log.clear();
        final v = await service.voidReceipt(sale.receipt.id, staff: shop.chef);
        expect((await v.kitchen)!.ok, isTrue);
        expect(printer.log, ['print:${v.receipt.id}', 'raster']);
      },
    );

    test('Storno nur mit Zeilen, die nicht in die Küche gehen: kitchen ist '
        'null, nichts gedruckt', () async {
      await configure();
      await configureKitchen(
        KitchenMode.receiptPrinter,
        skip: {cola.categoryId, huhnBowl.categoryId},
      );
      final sale = await sell();
      expect(await sale.kitchen, isNull);
      final v = await service.voidReceipt(sale.receipt.id, staff: shop.chef);
      expect((await v.print).ok, isTrue);
      expect(await v.kitchen, isNull);
      expect(rendered, isEmpty);
      expect(printer.rasters, isEmpty);
      expect(kitchen.log, isEmpty);
    });

    test('Storno mit aus: kitchen ist null', () async {
      await configure();
      final sale = await sell();
      final v = await service.voidReceipt(sale.receipt.id, staff: shop.chef);
      expect(await v.kitchen, isNull);
      expect(printer.log.where((e) => e == 'raster'), isEmpty);
    });

    test('zweimal dieselbe saleId: ein Küchenbon', () async {
      await configure();
      await configureKitchen(KitchenMode.kitchenPrinter);
      final a = await sell();
      final b = await sell();
      await a.kitchen;
      await b.kitchen;
      expect(kitchen.log, ['raster']);
    });

    test('Kartenzahlung: Küchenbon nach dem Bon', () async {
      await configure();
      await configureKitchen(KitchenMode.receiptPrinter);
      final o = await service.payByCard(
        paymentId: 'p1',
        cart: cart,
        staff: shop.anna,
      );
      final sale = (o as CardSaleDone).sale;
      expect((await sale.kitchen)!.ok, isTrue);
      expect(printer.log, ['print:p1', 'raster']);
    });
  });

  group('Nochmal drucken nach dem Verkauf', () {
    test(
      'Lade ging nicht auf: Nochmal drucken öffnet sie mit dem Bon',
      () async {
        await configure();
        printer.next = const PrintOutcome.failed(PrintProblem.timeout);
        final r = await sell();
        expect((await r.print).drawerSent, isFalse);
        printer.next = const PrintOutcome.ok();
        expect((await service.printAgain(r.receipt)).ok, isTrue);
        expect(printer.log, ['print+drawer:s1', 'print+drawer:s1']);
        // Jetzt ist sie aufgegangen: ein weiteres Mal ohne Lade.
        await service.printAgain(r.receipt);
        expect(printer.log.last, 'print:s1');
      },
    );

    test(
      'Lade ging auf, nur der Bon fehlt: Nochmal drucken ohne Lade',
      () async {
        await configure();
        printer
          ..next = const PrintOutcome.failed(PrintProblem.paperOut)
          ..kickGoesOut = true;
        final r = await sell();
        expect((await r.print).drawerSent, isTrue);
        printer.next = const PrintOutcome.ok();
        await service.printAgain(r.receipt);
        expect(printer.log, ['print+drawer:s1', 'print:s1']);
      },
    );

    test(
      'Bon gedruckt, nur die Lade fehlt: nur die Lade, kein zweiter Bon',
      () async {
        await configure();
        printer.kickGoesOut = false;
        final r = await sell();
        final first = await r.print;
        expect((first.ok, first.drawerSent), (true, false));
        expect((await service.printAgain(r.receipt)).ok, isTrue);
        expect(printer.log, ['print+drawer:s1', 'drawer']);
      },
    );

    test('Lade inzwischen ausgeschaltet: Nochmal drucken ohne Lade', () async {
      await configure();
      printer.next = const PrintOutcome.failed(PrintProblem.unreachable);
      final r = await sell();
      await r.print;
      await configure(drawer: false);
      printer.next = const PrintOutcome.ok();
      await service.printAgain(r.receipt);
      expect(printer.log, ['print+drawer:s1', 'print:s1']);
    });

    test('Kartenzahlung: Nochmal drucken nie mit Lade', () async {
      await configure();
      container.read(cartProvider.notifier).restore(cart);
      printer.next = const PrintOutcome.failed(PrintProblem.unreachable);
      final o = await service.payByCard(
        paymentId: 'p1',
        cart: cart,
        staff: shop.anna,
      ) as CardSaleDone;
      await o.sale.print;
      printer.next = const PrintOutcome.ok();
      await service.printAgain(o.sale.receipt);
      expect(printer.log, ['print:p1', 'print:p1']);
      expect(await shop.count('receipts'), 1);
    });

    test('Drucken im Bon-Detail (reprint) öffnet die Lade nie, auch wenn sie '
        'beim Verkauf nicht aufging', () async {
      await configure();
      printer.next = const PrintOutcome.failed(PrintProblem.timeout);
      final r = await sell();
      await r.print;
      printer.next = const PrintOutcome.ok();
      await service.reprint(r.receipt);
      expect(printer.log, ['print+drawer:s1', 'print:s1']);
    });
  });

  test('Storno druckt den Storno-Bon und öffnet die Lade nicht', () async {
    await configure();
    final sale = await shop.sell('s1');
    final r = await service.voidReceipt(sale.id, staff: shop.chef);
    expect(r.receipt.kind, ReceiptKind.voided);
    expect((await r.print).ok, isTrue);
    expect(printer.log, ['print:${r.receipt.id}']);
  });

  group('completeFree', () {
    final free = const Cart.empty()
        .add(teigtaschen)
        .setReceiptDiscount(
          const Discount.percent(100, DiscountReason.invitation),
        );

    test('completeFree: Bon gespeichert, der Druckauftrag öffnet die Lade '
        'nicht', () async {
      await configure();
      final r = await service.completeFree(
        saleId: 'f1',
        cart: free,
        staff: shop.anna,
      );
      expect((await r.print).ok, isTrue);
      expect(printer.log.single, startsWith('print:'));
      expect(printer.log, ['print:f1']);
      final p = r.receipt.payments.single;
      expect(
        (
          r.receipt.totalCents,
          p.kind,
          p.amountCents,
          p.givenCents,
          p.changeCents,
        ),
        (0, PaymentKind.cash, 0, 0, 0),
      );
      expect(await shop.count('receipts'), 1);
    });

    test('completeFree mit Summe über 0: ArgumentError, nichts '
        'gespeichert', () async {
      await configure();
      // Mit Pfand ist die Summe das Pfand, auch bei 100 % Rabatt.
      final withDeposit = const Cart.empty()
          .add(cola)
          .setReceiptDiscount(
            const Discount.percent(100, DiscountReason.invitation),
          );
      for (final c in [cart, withDeposit]) {
        await expectLater(
          service.completeFree(saleId: 'f1', cart: c, staff: shop.anna),
          throwsArgumentError,
        );
      }
      expect(await shop.count('receipts'), 0);
      expect(printer.log, isEmpty);
    });
  });

  group('completePayout', () {
    /// Der Küchenbon am Bondrucker, wie in der Gruppe "Küchenbon".
    Future<void> kitchenAtReceiptPrinter() async {
      final repo = container.read(settingsRepositoryProvider);
      await repo.save(
        (await repo.current()).copyWith(
          kitchenMode: KitchenMode.receiptPrinter,
        ),
      );
      for (var i = 0; i < 100; i++) {
        final now = container.read(settingsStreamProvider).value;
        if (now?.kitchenMode == KitchenMode.receiptPrinter) return;
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      fail('Einstellungen kamen nicht an');
    }

    // Teigtaschen 6,50 € und 99 × 0,25 € zurück: −18,25 €.
    final withGoods = const Cart.empty()
        .add(teigtaschen)
        .setDepositReturn(depositCents: 25, quantity: 99);
    final onlyReturn = const Cart.empty().setDepositReturn(
      depositCents: 25,
      quantity: 3,
    );

    test('completePayout druckt den Bon, öffnet die Lade und druckt den '
        'Küchenbon, wenn Ware dabei ist', () async {
      await configure();
      await kitchenAtReceiptPrinter();
      final r = await service.completePayout(
        saleId: 'p1',
        cart: withGoods,
        staff: shop.anna,
      );
      expect((await r.print).ok, isTrue);
      expect((await r.kitchen)!.ok, isTrue);
      expect(printer.log, ['print+drawer:p1', 'raster']);
      expect(
        [for (final l in rendered.single.$1.lines) l.name],
        ['Teigtaschen'],
      );
      final p = r.receipt.payments.single;
      expect(
        (
          r.receipt.totalCents,
          p.kind,
          p.amountCents,
          p.givenCents,
          p.changeCents,
        ),
        (-1825, PaymentKind.cash, -1825, 0, 0),
      );
      // Ein zweiter Aufruf mit derselben Id druckt nicht noch einmal.
      final again = await service.completePayout(
        saleId: 'p1',
        cart: withGoods,
        staff: shop.anna,
      );
      await again.print;
      expect(printer.log, ['print+drawer:p1', 'raster']);
      expect(await shop.count('receipts'), 1);
    });

    test('nur Pfand zurück: kein Küchenbon; Lade ausgeschaltet: nur der '
        'Bon', () async {
      await configure(drawer: false);
      await kitchenAtReceiptPrinter();
      final r = await service.completePayout(
        saleId: 'p2',
        cart: onlyReturn,
        staff: shop.anna,
      );
      expect((await r.print).ok, isTrue);
      expect(await r.kitchen, isNull);
      expect(printer.log, ['print:p2']);
      expect(rendered, isEmpty);
    });

    test('Summe 0 oder darüber: ArgumentError, nichts gespeichert, nichts '
        'gedruckt', () async {
      await configure();
      for (final c in [cart, const Cart.empty().add(teigtaschen)]) {
        await expectLater(
          service.completePayout(saleId: 'p3', cart: c, staff: shop.anna),
          throwsArgumentError,
        );
      }
      expect(await shop.count('receipts'), 0);
      expect(printer.log, isEmpty);
    });
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

  group('Karte', () {
    Future<CardSaleOutcome> pay([String id = 'p1']) =>
        service.payByCard(paymentId: id, cart: cart, staff: shop.anna);

    /// Legt den Bon auf die Kassa, wie in der Oberfläche.
    void putOnRegister() => container.read(cartProvider.notifier).restore(cart);

    test('bezahlt: ein Bon mit Kartenzahlung, offene Zahlung weg, Entwurf '
        'weg, gedruckt ohne Lade', () async {
      await configure();
      putOnRegister();
      terminal.next = const CardPaid(
        txCode: 'TX1',
        cardScheme: 'MASTERCARD',
        cardLast4: '1234',
      );
      final o = await pay() as CardSaleDone;
      expect((await o.sale.print).ok, isTrue);
      final p = o.sale.receipt.payments.single;
      expect(p.kind, PaymentKind.card);
      expect(
        (p.provider, p.providerTxCode, p.cardScheme, p.cardLast4),
        ('sumup', 'TX1', 'MASTERCARD', '1234'),
      );
      expect(o.sale.receipt.id, 'p1');
      expect(await cardPayments.pending(), isEmpty);
      expect(printer.log, ['print:p1']);
      expect(terminal.payments.single.amountCents, 1820);
      expect(terminal.payments.single.paymentId, 'p1');
      expect(terminal.payments.single.title, 'Bon Beispiel-Imbiss');
      expect(await shop.count('receipts'), 1);
      expect(await shop.receipts.byId('p1'), isNotNull);
      expect(container.read(cartProvider).isEmpty, isTrue);
      expect(
        await container.read(settingsRepositoryProvider).readDraft(),
        isNull,
      );
    });

    test('abgelehnt: kein Bon, keine offene Zahlung, Meldung', () async {
      await configure();
      putOnRegister();
      terminal.next = const CardFailed(CardFailure.declined);
      final o = await pay() as CardSaleFailed;
      expect(o.message, 'Die Kartenzahlung wurde nicht abgeschlossen.');
      expect(await shop.count('receipts'), 0);
      expect(await cardPayments.pending(), isEmpty);
      expect(printer.log, isEmpty);
      expect(container.read(cartProvider).isEmpty, isFalse);
    });

    test('unklar: kein Bon, offene Zahlung bleibt als unklar', () async {
      putOnRegister();
      terminal.next = const CardUnknown();
      final o = await pay() as CardSaleUnclear;
      expect(o.paymentId, 'p1');
      expect(await shop.count('receipts'), 0);
      final p = (await cardPayments.pending()).single;
      expect((p.id, p.unknown, p.amountCents), ('p1', true, 1820));
      expect((p.staffId, p.staffName), (shop.anna.id, 'Anna'));
      expect(container.read(cartProvider).isEmpty, isTrue);
    });

    test('pay wirft: wie unklar', () async {
      putOnRegister();
      terminal.next = () async => throw StateError('Verbindung weg');
      final o = await pay() as CardSaleUnclear;
      expect(o.paymentId, 'p1');
      expect(await shop.count('receipts'), 0);
      expect((await cardPayments.pending()).single.unknown, isTrue);
      expect(container.read(cartProvider).isEmpty, isTrue);
    });

    test('die offene Zahlung steht in der Datenbank, bevor das Terminal '
        'gerufen wird', () async {
      var seen = false;
      terminal.next = () async {
        final p = (await cardPayments.pending()).single;
        expect((p.id, p.unknown), ('p1', false));
        seen = true;
        return const CardFailed(CardFailure.cancelled);
      };
      await pay();
      expect(seen, isTrue);
    });

    test('unter 1,00 € oder leer: kein Aufruf des Terminals', () async {
      final cheap = const Cart.empty().add(leitungswasser);
      final low = await service.payByCard(
        paymentId: 'p1',
        cart: cheap,
        staff: shop.anna,
      );
      expect(low, isA<CardSaleFailed>());
      final empty = await service.payByCard(
        paymentId: 'p2',
        cart: const Cart.empty(),
        staff: shop.anna,
      );
      expect(empty, isA<CardSaleFailed>());
      expect(terminal.payments, isEmpty);
      expect(await cardPayments.pending(), isEmpty);
      expect(container.read(activeCardPaymentProvider), isNull);
    });

    test('payByCard mit Bar-Teil 10,00 und Trinkgeld 0,80: Terminal bucht '
        '9,00', () async {
      putOnRegister();
      var seen = false;
      terminal.next = () async {
        final p = (await cardPayments.pending()).single;
        expect((p.amountCents, p.cashPartCents, p.tipCents), (900, 1000, 80));
        seen = true;
        return const CardPaid(txCode: 'TX1');
      };
      final o = await service.payByCard(
        paymentId: 'p1',
        cart: cart,
        staff: shop.anna,
        cashPartCents: 1000,
        tipCents: 80,
      ) as CardSaleDone;
      expect(seen, isTrue);
      expect(terminal.payments.single.amountCents, 900);
      final payments = o.sale.receipt.payments;
      expect(
        [for (final p in payments) (p.kind, p.amountCents, p.tipCents)],
        [(PaymentKind.cash, 1000, 0), (PaymentKind.card, 820, 80)],
      );
      expect(payments.last.tipStaffName, 'Anna');
      expect(o.sale.receipt.totalCents, 1820);
      expect(await cardPayments.pending(), isEmpty);
    });

    test(
      'Rest unter dem Kleinstbetrag: belowMinimum, nichts geschrieben',
      () async {
        final o = await service.payByCard(
          paymentId: 'p1',
          cart: cart,
          staff: shop.anna,
          cashPartCents: 1750,
          tipCents: 500,
        ) as CardSaleFailed;
        expect(o.problem, CardSaleProblem.belowMinimum);
        expect(o.minimumCents, 100);
        expect(terminal.payments, isEmpty);
        expect(await cardPayments.pending(), isEmpty);
        expect(await shop.count('receipts'), 0);
        expect(container.read(activeCardPaymentProvider), isNull);
      },
    );

    test('negativer Bar-Teil oder negatives Trinkgeld: nicht gestartet, '
        'nichts geschrieben', () async {
      for (final (cashPart, tip) in [(-1, 0), (0, -1)]) {
        final o = await service.payByCard(
          paymentId: 'p1',
          cart: cart,
          staff: shop.anna,
          cashPartCents: cashPart,
          tipCents: tip,
        ) as CardSaleFailed;
        expect(o.problem, CardSaleProblem.notStarted);
      }
      expect(terminal.payments, isEmpty);
      expect(await cardPayments.pending(), isEmpty);
    });

    test('Bar-Teil gleich der Summe oder darüber: nicht gestartet, nichts '
        'geschrieben, auch bei einem Terminal ohne Kleinstbetrag', () async {
      terminal.minimum = 0;
      for (final cashPart in [cart.totalCents, cart.totalCents + 1]) {
        final o = await service.payByCard(
          paymentId: 'p1',
          cart: cart,
          staff: shop.anna,
          cashPartCents: cashPart,
          tipCents: 50,
        ) as CardSaleFailed;
        expect(o.problem, CardSaleProblem.notStarted, reason: '$cashPart');
      }
      expect(terminal.payments, isEmpty);
      expect(await cardPayments.pending(), isEmpty);
      expect(await shop.count('receipts'), 0);
      expect(container.read(activeCardPaymentProvider), isNull);
    });

    test('unklar mit Bar-Teil und Trinkgeld bestätigen: der Bon trägt beide, '
        'das Trinkgeld für die Person der Zahlung', () async {
      putOnRegister();
      terminal.next = const CardUnknown();
      await service.payByCard(
        paymentId: 'p1',
        cart: cart,
        staff: shop.anna,
        cashPartCents: 1000,
        tipCents: 80,
      );
      final p = (await cardPayments.pending()).single;
      expect((p.amountCents, p.cashPartCents, p.tipCents), (900, 1000, 80));
      final catalog = (await container.read(catalogProvider.future))!;
      final r = await service.confirmUnclear(p, catalog: catalog);
      expect(
        [
          for (final x in r.receipt.payments)
            (x.kind, x.amountCents, x.tipCents, x.tipStaffName),
        ],
        [
          (PaymentKind.cash, 1000, 0, null),
          (PaymentKind.card, 820, 80, 'Anna'),
        ],
      );
      expect(await cardPayments.pending(), isEmpty);
    });

    test('mit Bar-Teil und Lade: Lade und Bon in einem Druckauftrag; Lade '
        'aus: nur der Bon', () async {
      await configure();
      putOnRegister();
      final o = await service.payByCard(
        paymentId: 'p1',
        cart: cart,
        staff: shop.anna,
        cashPartCents: 1000,
      ) as CardSaleDone;
      expect((await o.sale.print).ok, isTrue);
      expect(printer.log, ['print+drawer:p1']);

      await configure(drawer: false);
      putOnRegister();
      final o2 = await service.payByCard(
        paymentId: 'p2',
        cart: cart,
        staff: shop.anna,
        cashPartCents: 1000,
      ) as CardSaleDone;
      await o2.sale.print;
      expect(printer.log, ['print+drawer:p1', 'print:p2']);
    });

    test('mit Bar-Teil, die Lade ging nicht auf: Nochmal drucken holt sie '
        'nach', () async {
      await configure();
      putOnRegister();
      printer.next = const PrintOutcome.failed(PrintProblem.unreachable);
      final o = await service.payByCard(
        paymentId: 'p1',
        cart: cart,
        staff: shop.anna,
        cashPartCents: 1000,
      ) as CardSaleDone;
      await o.sale.print;
      printer.next = const PrintOutcome.ok();
      await service.printAgain(o.sale.receipt);
      expect(printer.log, ['print+drawer:p1', 'print+drawer:p1']);
    });

    test(
      'unklar mit Bar-Teil bestätigen: die Lade geht mit dem Bon auf',
      () async {
        await configure();
        putOnRegister();
        terminal.next = const CardUnknown();
        await service.payByCard(
          paymentId: 'p1',
          cart: cart,
          staff: shop.anna,
          cashPartCents: 1000,
        );
        final p = (await cardPayments.pending()).single;
        final catalog = (await container.read(catalogProvider.future))!;
        final r = await service.confirmUnclear(p, catalog: catalog);
        await r.print;
        expect(printer.log, ['print+drawer:p1']);
      },
    );

    test('terminalAmountCents: Summe ohne Bar-Teil, mit Trinkgeld', () {
      expect(
        terminalAmountCents(totalCents: 1820, cashPartCents: 0, tipCents: 0),
        1820,
      );
      expect(
        terminalAmountCents(
          totalCents: 1820,
          cashPartCents: 1000,
          tipCents: 80,
        ),
        900,
      );
    });

    test('cartOfPending prüft den Betrag mit Bar-Teil und Trinkgeld', () async {
      final catalog = (await container.read(catalogProvider.future))!;
      PendingCardPayment pending(int amount, int cashPart, int tip) =>
          PendingCardPayment(
            id: 'p1',
            cartJson: jsonEncode(cart.toJson()),
            amountCents: amount,
            staffId: shop.anna.id,
            staffName: 'Anna',
            startedAt: shop.clock.now(),
            unknown: true,
            cashPartCents: cashPart,
            tipCents: tip,
          );
      expect(
        SaleService.cartOfPending(pending(900, 1000, 80), catalog),
        isNotNull,
      );
      expect(
        SaleService.cartOfPending(pending(1820, 0, 0), catalog),
        isNotNull,
      );
      expect(SaleService.cartOfPending(pending(1820, 0, 80), catalog), isNull);
      expect(
        SaleService.cartOfPending(pending(1820, 1000, 0), catalog),
        isNull,
      );
    });

    test('zweiter Aufruf während einer laufenden Zahlung: abgewiesen, ein '
        'Aufruf am Terminal', () async {
      putOnRegister();
      terminal.hang = Completer<CardPaymentResult>();
      final first = pay('p1');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final second = await pay('p2') as CardSaleFailed;
      expect(second.message, 'Es läuft schon eine Kartenzahlung.');
      expect(terminal.payments.map((p) => p.paymentId), ['p1']);
      expect((await cardPayments.pending()).map((p) => p.id), ['p1']);
      terminal.hang!.complete(const CardPaid(txCode: 'TX1'));
      expect(await first, isA<CardSaleDone>());
    });

    test('unklar bestätigen: Bon als Karte ohne Beleg-Code, offene Zahlung '
        'weg', () async {
      await configure();
      putOnRegister();
      terminal.next = const CardUnknown();
      await pay();
      final p = (await cardPayments.pending()).single;
      final catalog = (await container.read(catalogProvider.future))!;
      final r = await service.confirmUnclear(p, catalog: catalog);
      expect(r.receipt.id, 'p1');
      expect(r.receipt.payments.single.kind, PaymentKind.card);
      expect(r.receipt.payments.single.providerTxCode, isNull);
      expect(r.receipt.payments.single.provider, 'sumup');
      expect(r.receipt.totalCents, 1820);
      expect(r.receipt.staffName, 'Anna');
      expect(await cardPayments.pending(), isEmpty);
      expect((await r.print).ok, isTrue);
      expect(printer.log, ['print:p1']);
    });

    test('unklar bestätigen, Bon nicht mehr lesbar: Ausnahme, offene Zahlung '
        'bleibt', () async {
      putOnRegister();
      terminal.next = const CardUnknown();
      await pay();
      final p = (await cardPayments.pending()).single;
      final broken = PendingCardPayment(
        id: p.id,
        cartJson: 'kaputt',
        amountCents: p.amountCents,
        staffId: p.staffId,
        staffName: p.staffName,
        startedAt: p.startedAt,
        unknown: true,
      );
      final catalog = (await container.read(catalogProvider.future))!;
      await expectLater(
        service.confirmUnclear(broken, catalog: catalog),
        throwsA(isA<UnreadableCardPaymentException>()),
      );
      expect(await cardPayments.pending(), hasLength(1));
      expect(await shop.count('receipts'), 0);
    });

    test('unklar verwerfen: kein Bon, offene Zahlung weg, Bon wieder '
        'eingesetzt', () async {
      putOnRegister();
      terminal.next = const CardUnknown();
      await pay();
      expect(container.read(cartProvider).isEmpty, isTrue);
      final p = (await cardPayments.pending()).single;
      await service.discardUnclear(p);
      expect(await cardPayments.pending(), isEmpty);
      expect(await shop.count('receipts'), 0);
      expect(container.read(cartProvider).totalCents, cart.totalCents);
    });

    group('unklare Zahlung nach einem Absturz', () {
      /// Die offene Zahlung, wie ein Absturz sie hinterlässt: `started`, und
      /// der Entwurf hat den Bon wieder auf die Kassa gebracht.
      Future<PendingCardPayment> crashed({bool onRegister = true}) async {
        if (onRegister) putOnRegister();
        await cardPayments.begin(paymentId: 'p1', cart: cart, staff: shop.anna);
        return (await cardPayments.pending()).single;
      }

      Future<Catalog> catalogOf() async {
        final c = await container.read(catalogProvider.future);
        return c!;
      }

      test('bestätigen mit demselben Bon auf der Kassa: Bon geschrieben, '
          'Kassa leer, Entwurf weg', () async {
        await configure();
        final p = await crashed();
        final r = await service.confirmUnclear(p, catalog: await catalogOf());
        expect(r.receipt.id, 'p1');
        expect(await shop.count('receipts'), 1);
        expect(await cardPayments.pending(), isEmpty);
        expect(container.read(cartProvider).isEmpty, isTrue);
        expect(
          await container.read(settingsRepositoryProvider).readDraft(),
          isNull,
        );
      });

      test('bestätigen nach einer Änderung der Speisekarte, die die Summe '
          'lässt: derselbe Bon auf der Kassa wird trotzdem geleert', () async {
        await configure();
        putOnRegister();
        await cardPayments.begin(paymentId: 'p1', cart: cart, staff: shop.anna);
        // Eine Zeile, deren Artikel es nicht mehr gibt (z. B. ein Artikel um
        // 0,00 €): sie zählt nicht zur Summe und fällt beim Lesen weg.
        final stored = cart.toJson();
        final withGone = {
          ...stored,
          'lines': [
            ...(stored['lines'] as List),
            {
              'lineId': 'weg',
              'itemId': 'gibt-es-nicht-mehr',
              'quantity': 1,
              'optionIds': <String>[],
            },
          ],
        };
        await shop.db.customUpdate(
          'UPDATE pending_card_payments SET cart_json = ? WHERE id = ?',
          variables: [
            Variable.withString(jsonEncode(withGone)),
            Variable.withString('p1'),
          ],
        );
        final p = (await cardPayments.pending()).single;
        expect(p.cartJson, isNot(jsonEncode(cart.toJson())));
        // Der Entwurf hat den Bon so zurückgebracht, wie die Kassa ihn liest.
        final catalog = await catalogOf();
        container
            .read(cartProvider.notifier)
            .restore(Cart.fromJson(withGone, catalog));
        await service.confirmUnclear(p, catalog: catalog);
        expect(await shop.count('receipts'), 1);
        expect(container.read(cartProvider).isEmpty, isTrue);
      });

      test('bestätigen mit anderem Inhalt auf der Kassa: der bleibt '
          'stehen', () async {
        await configure();
        final p = await crashed(onRegister: false);
        container.read(cartProvider.notifier).restore(cartCard);
        await service.confirmUnclear(p, catalog: await catalogOf());
        expect(await shop.count('receipts'), 1);
        expect(container.read(cartProvider).toJson(), cartCard.toJson());
        expect(
          await container.read(settingsRepositoryProvider).readDraft(),
          isNotNull,
        );
      });

      test(
        'bestätigen nach CardUnknown (Kassa schon leer): bleibt leer',
        () async {
          await configure();
          putOnRegister();
          terminal.next = const CardUnknown();
          await pay();
          expect(container.read(cartProvider).isEmpty, isTrue);
          final p = (await cardPayments.pending()).single;
          await service.confirmUnclear(p, catalog: await catalogOf());
          expect(await shop.count('receipts'), 1);
          expect(container.read(cartProvider).isEmpty, isTrue);
        },
      );

      test('verwerfen mit demselben Bon auf der Kassa: nichts doppelt, keine '
          'offene Zahlung, kein Bon', () async {
        final p = await crashed();
        await service.discardUnclear(p);
        expect(await cardPayments.pending(), isEmpty);
        expect(await shop.count('receipts'), 0);
        expect(container.read(cartProvider).toJson(), cart.toJson());
        expect(container.read(cartProvider).totalCents, 1820);
      });

      test('verwerfen mit anderem Inhalt auf der Kassa: der bleibt, nichts '
          'wird ersetzt', () async {
        final p = await crashed(onRegister: false);
        container.read(cartProvider.notifier).restore(cartCard);
        await service.discardUnclear(p);
        expect(await cardPayments.pending(), isEmpty);
        expect(container.read(cartProvider).toJson(), cartCard.toJson());
      });

      test('bestätigen einer Zahlung, die gerade am Terminal läuft: wirft, '
          'nichts geschrieben', () async {
        putOnRegister();
        terminal.hang = Completer<CardPaymentResult>();
        final running = pay('p1');
        await Future<void>.delayed(const Duration(milliseconds: 20));
        final p = (await cardPayments.pending()).single;
        expect((p.id, p.unknown), ('p1', false));
        expect(container.read(activeCardPaymentProvider), 'p1');
        await expectLater(
          service.confirmUnclear(p, catalog: await catalogOf()),
          throwsA(isA<CardPaymentRunningException>()),
        );
        await expectLater(
          service.discardUnclear(p),
          throwsA(isA<CardPaymentRunningException>()),
        );
        expect(await shop.count('receipts'), 0);
        expect(await cardPayments.pending(), hasLength(1));
        expect(container.read(cartProvider).isEmpty, isFalse);
        terminal.hang!.complete(const CardPaid(txCode: 'TX1'));
        expect(await running, isA<CardSaleDone>());
        expect(await shop.count('receipts'), 1);
      });

      test('Zahlung schon weg (Bon oder verworfen): bestätigen und verwerfen '
          'schreiben nichts', () async {
        final p = await crashed(onRegister: false);
        await cardPayments.discard('p1');
        await expectLater(
          service.confirmUnclear(p, catalog: await catalogOf()),
          throwsA(isA<CardPaymentGoneException>()),
        );
        await expectLater(
          service.discardUnclear(p),
          throwsA(isA<CardPaymentGoneException>()),
        );
        expect(await shop.count('receipts'), 0);
        expect(
          await container.read(settingsRepositoryProvider).readDraft(),
          isNull,
        );
      });
    });

    test('dieselbe paymentId zweimal bezahlt gemeldet: ein Bon', () async {
      await configure();
      final a = await pay() as CardSaleDone;
      final b = await pay() as CardSaleDone;
      await a.sale.print;
      await b.sale.print;
      expect(b.sale.receipt.id, a.sale.receipt.id);
      expect(await shop.count('receipts'), 1);
      expect(printer.printed, ['p1']);
      expect(terminal.payments, hasLength(1));
      expect(await cardPayments.pending(), isEmpty);
    });

    test('Id mit unklarer offener Zahlung: unklar, kein Aufruf des Terminals, '
        'Zeile unverändert', () async {
      putOnRegister();
      terminal.next = const CardUnknown();
      await pay();
      final before = (await cardPayments.pending()).single;
      final other = const Cart.empty().add(teigtaschen).add(cola);
      final o = await service.payByCard(
        paymentId: 'p1',
        cart: other,
        staff: shop.anna,
      ) as CardSaleUnclear;
      expect(o.paymentId, 'p1');
      expect(terminal.payments, hasLength(1));
      final after = (await cardPayments.pending()).single;
      expect(after.unknown, isTrue);
      expect(after.cartJson, before.cartJson);
      expect(after.amountCents, 1820);
      expect(container.read(activeCardPaymentProvider), isNull);
    });

    test('Id mit liegengebliebener Zahlung (gestartet): unklar, kein Aufruf '
        'des Terminals, Zeile danach unklar', () async {
      putOnRegister();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await cardPayments.begin(paymentId: 'p1', cart: cart, staff: shop.anna);
      final o = await pay() as CardSaleUnclear;
      expect(o.paymentId, 'p1');
      expect(terminal.payments, isEmpty);
      final row = (await cardPayments.pending()).single;
      expect((row.unknown, row.amountCents), (true, 1820));
      expect(await shop.count('receipts'), 0);
    });

    test(
      'activeCardPaymentProvider: sichtbar während pay, danach null',
      () async {
        final seen = <String?>[];
        terminal.next = () async {
          seen.add(container.read(activeCardPaymentProvider));
          return const CardPaid(txCode: 'TX1');
        };
        expect(container.read(activeCardPaymentProvider), isNull);
        await pay('a');
        expect(container.read(activeCardPaymentProvider), isNull);

        terminal.next = () async {
          seen.add(container.read(activeCardPaymentProvider));
          return const CardFailed(CardFailure.other);
        };
        await pay('b');
        expect(container.read(activeCardPaymentProvider), isNull);

        terminal.next = () async {
          seen.add(container.read(activeCardPaymentProvider));
          return const CardUnknown();
        };
        await pay('c');
        expect(container.read(activeCardPaymentProvider), isNull);

        terminal.next = () async {
          seen.add(container.read(activeCardPaymentProvider));
          throw StateError('weg');
        };
        await pay('d');
        expect(container.read(activeCardPaymentProvider), isNull);
        expect(seen, ['a', 'b', 'c', 'd']);
      },
    );

    group('payByCard wirft nie', () {
      late _FailingCardPayments failing;
      late ProviderContainer c;
      late SaleService s;

      setUp(() {
        failing = _FailingCardPayments(shop.db, shop.clock);
        c = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(shop.db),
            clockProvider.overrideWithValue(shop.clock),
            receiptPrinterProvider.overrideWithValue(printer),
            cardTerminalProvider.overrideWithValue(terminal),
            cardPaymentRepositoryProvider.overrideWithValue(failing),
          ],
        );
        s = c.read(saleServiceProvider);
        c.read(cartProvider.notifier).restore(cart);
      });
      tearDown(() => c.dispose());

      Future<CardSaleOutcome> payNow() =>
          s.payByCard(paymentId: 'p1', cart: cart, staff: shop.anna);

      test('unklar und markUnknown scheitert: unklar, Kassa leer, die offene '
          'Zahlung bleibt', () async {
        failing.failMarkUnknown = true;
        terminal.next = const CardUnknown();
        final o = await payNow();
        expect(o, isA<CardSaleUnclear>());
        expect(c.read(cartProvider).isEmpty, isTrue);
        expect((await failing.pending()).single.id, 'p1');
        expect(c.read(activeCardPaymentProvider), isNull);
      });

      test('pay wirft und markUnknown scheitert: unklar', () async {
        failing.failMarkUnknown = true;
        terminal.next = () async => throw StateError('weg');
        expect(await payNow(), isA<CardSaleUnclear>());
        expect(c.read(cartProvider).isEmpty, isTrue);
        expect(await failing.pending(), hasLength(1));
      });

      test('bezahlt, Bon nicht gespeichert und markUnknown scheitert: '
          'unklar', () async {
        failing.failMarkUnknown = true;
        terminal.next = const CardPaid(txCode: 'TX1');
        final receipts = _FailingReceipts(shop.db, shop.clock, shop.days);
        c.dispose();
        c = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(shop.db),
            clockProvider.overrideWithValue(shop.clock),
            receiptPrinterProvider.overrideWithValue(printer),
            cardTerminalProvider.overrideWithValue(terminal),
            cardPaymentRepositoryProvider.overrideWithValue(failing),
            receiptRepositoryProvider.overrideWithValue(receipts),
          ],
        );
        s = c.read(saleServiceProvider);
        c.read(cartProvider.notifier).restore(cart);
        final o = await payNow();
        expect(o, isA<CardSaleUnclear>());
        expect(c.read(cartProvider).isEmpty, isTrue);
        expect(await failing.pending(), hasLength(1));
      });

      test('abgelehnt und discard scheitert: gescheitert mit der Meldung, '
          'der Bon bleibt auf der Kassa', () async {
        failing.failDiscard = true;
        terminal.next = const CardFailed(CardFailure.declined);
        final o = await payNow();
        expect(o, isA<CardSaleFailed>());
        expect(
          (o as CardSaleFailed).message,
          'Die Kartenzahlung wurde nicht abgeschlossen.',
        );
        expect(c.read(cartProvider).isEmpty, isFalse);
        expect(c.read(activeCardPaymentProvider), isNull);
      });
    });

    test('CardFailed.message: alle Texte', () {
      String m(CardFailure f, [String? d]) => CardFailed(f, detail: d).message;
      expect(
        m(CardFailure.declined),
        'Die Kartenzahlung wurde nicht abgeschlossen.',
      );
      expect(m(CardFailure.cancelled), 'Kartenzahlung abgebrochen.');
      expect(
        m(CardFailure.noInternet),
        'Kein Internet. Kartenzahlung geht gerade nicht.',
      );
      expect(
        m(CardFailure.notLoggedIn),
        'SumUp ist nicht angemeldet. Bitte in den Einstellungen anmelden.',
      );
      expect(
        m(CardFailure.noReader),
        'Kein Kartenleser verbunden. Bitte in den Einstellungen verbinden.',
      );
      expect(
        m(CardFailure.permission),
        'Kassa braucht die Erlaubnis für Bluetooth und Standort.',
      );
      expect(m(CardFailure.other), 'Die Kartenzahlung hat nicht geklappt.');
      expect(
        m(CardFailure.other, 'Code 7'),
        'Die Kartenzahlung hat nicht geklappt. (Code 7)',
      );
    });
  });

  group('Gutschein', () {
    final voucherCart = const Cart.empty()
        .addVoucherSale(valueCents: 2500)
        .add(cola)
        .addVoucherSale(valueCents: 1000);

    Future<SaleResult> sellVouchers([String id = 'g1']) => service.completeCash(
      saleId: id,
      cart: voucherCart,
      givenCents: 3815,
      staff: shop.anna,
    );

    test('ohne verkauften Gutschein ist voucherPrints leer', () async {
      await configure(drawer: false);
      final r = await sell();
      expect((await r.print).ok, isTrue);
      expect(await r.voucherPrints, isEmpty);
      expect(printer.log, ['print:s1']);
    });

    test('nach dem Kundenbon je Gutschein ein Abschnitt, in der Reihenfolge '
        'der Zeilen', () async {
      await configure(drawer: false);
      final r = await sellVouchers();
      final outcomes = await r.voucherPrints;
      expect([for (final o in outcomes) o.ok], [true, true]);
      final sold = r.receipt.soldVouchers;
      expect(printer.log, [
        'print:g1',
        'voucher:${sold[0].voucherId}',
        'voucher:${sold[1].voucherId}',
      ]);
      expect(
        [for (final s in printer.voucherSlips) s.voucher.valueCents],
        [2500, 1000],
      );
      expect(
        [for (final s in printer.voucherSlips) s.soldAt],
        [r.receipt.createdAt, r.receipt.createdAt],
      );
      // Ohne laufende Signatur sind es Übungs-Gutscheine.
      expect([for (final s in printer.voucherSlips) s.isTest], [true, true]);
    });

    test('der Abschnitt wartet auf den Kundenbon', () async {
      await configure(drawer: false);
      final hold = printer.hold = Completer<void>();
      final r = await sellVouchers();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(printer.log, ['print:g1']);
      printer.hold = null;
      hold.complete();
      expect(await r.voucherPrints, hasLength(2));
      expect(printer.log, hasLength(3));
    });

    test('Kundenbon gescheitert: kein Abschnitt von selbst', () async {
      await configure(drawer: false);
      printer.next = const PrintOutcome.failed(PrintProblem.paperOut);
      final r = await sellVouchers();
      expect((await r.print).ok, isFalse);
      expect(await r.voucherPrints, isEmpty);
      expect(printer.log, ['print:g1']);
    });

    test(
      'ohne Drucker: nichts gedruckt, printVoucher ergibt notSetUp',
      () async {
        await configure(kind: PrinterKind.none);
        final r = await sellVouchers();
        expect(await r.voucherPrints, isEmpty);
        final o = await service.printVoucher(
          r.receipt,
          r.receipt.soldVouchers.first,
        );
        expect(o.problem, PrintProblem.notSetUp);
        expect(printer.log, isEmpty);
      },
    );

    test('zweimal dieselbe saleId: die Abschnitte nur einmal', () async {
      await configure(drawer: false);
      final a = await sellVouchers();
      await a.voucherPrints;
      final b = await sellVouchers();
      expect(await b.voucherPrints, hasLength(2));
      expect(printer.log, hasLength(3));
    });

    test('printVoucher druckt nur den Abschnitt, mit dem Ergebnis des '
        'Druckers', () async {
      await configure(drawer: false);
      final r = await sellVouchers();
      await r.voucherPrints;
      printer.log.clear();
      printer.voucherSlips.clear();
      printer.next = const PrintOutcome.failed(PrintProblem.coverOpen);
      final second = r.receipt.soldVouchers[1];
      final o = await service.printVoucher(r.receipt, second);
      expect(o.problem, PrintProblem.coverOpen);
      expect(printer.log, ['voucher:${second.voucherId}']);
      expect(printer.voucherSlips.single.voucher.code, second.code);
    });

    test('Küchenbon am Bondrucker: Kundenbon, Küchenbon, dann die '
        'Abschnitte', () async {
      await configure(drawer: false);
      final repo = container.read(settingsRepositoryProvider);
      await repo.save(
        (await repo.current()).copyWith(
          kitchenMode: KitchenMode.receiptPrinter,
        ),
      );
      for (var i = 0; i < 100; i++) {
        if (container.read(settingsStreamProvider).value?.kitchenMode ==
            KitchenMode.receiptPrinter) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      final r = await sellVouchers();
      await r.kitchen;
      await r.voucherPrints;
      expect(printer.printedJobs.map((p) => p.kind), [
        'receipt',
        'raster',
        'voucher',
        'voucher',
      ]);
      // Auf den Küchenbon kommt nur die Cola, nie eine Gutschein-Zeile.
      expect([for (final l in rendered.single.$1.lines) l.name], [cola.name]);
    });
  });

  group('Gutschein einlösen (Task 11)', () {
    Future<void> drain(String voucherId, int cents) => shop.db
        .into(shop.db.voucherMovementRows)
        .insert(
          VoucherMovementRowsCompanion.insert(
            voucherId: voucherId,
            receiptId: 'andere-kassa',
            kind: 'redeem',
            amountCents: -cents,
            createdAt: shop.clock.now(),
          ),
        );

    test('completeVoucher: nur Gutschein-Zahlungen, Kundenbon ohne Lade',
        () async {
      await configure();
      final v = await sellVoucher(shop, 2500);
      printer.log.clear();
      final r = await service.completeVoucher(
        saleId: 'e1',
        cart: cartCard.applyVoucher(applied(v)),
        staff: shop.anna,
      );
      expect((await r.print).ok, isTrue);
      expect(printer.log, ['print:e1']);
      expect(
        [for (final p in r.receipt.payments) (p.kind, p.amountCents)],
        [(PaymentKind.voucher, 965)],
      );
    });

    test('payByCard: Guthaben reicht nicht mehr, VoucherBalanceException '
        'vor offener Zahlung und Terminal', () async {
      final v = await sellVoucher(shop, 500);
      final paying = cartCard.applyVoucher(applied(v));
      await drain(v.id, 315);
      await expectLater(
        service.payByCard(paymentId: 'k1', cart: paying, staff: shop.anna),
        throwsA(
          isA<VoucherBalanceException>().having(
            (e) => e.balanceCents,
            'balanceCents',
            185,
          ),
        ),
      );
      expect(terminal.payments, isEmpty);
      expect(await cardPayments.pending(), isEmpty);
      expect(container.read(activeCardPaymentProvider), isNull);
      expect(await shop.receipts.find('k1'), isNull);
    });

    test('payByCard nach Gutschein: offene Zahlung mit Gutschein vor dem '
        'Terminal, das Terminal bucht den Rest; belastet entsteht der Bon '
        'auch bei überzogenem Gutschein', () async {
      final v = await sellVoucher(shop, 500);
      final paying = cartCard.applyVoucher(applied(v));
      List<PendingCardPayment>? seen;
      terminal.next = () async {
        seen = await cardPayments.pending();
        await drain(v.id, 500);
        return const CardPaid(txCode: 'TX9');
      };
      final out = await service.payByCard(
        paymentId: 'k2',
        cart: paying,
        staff: shop.anna,
        tipCents: 35,
      );
      expect(out, isA<CardSaleDone>());
      expect(terminal.payments.single.amountCents, 500);
      expect(seen!.single.amountCents, 500);
      expect(seen!.single.cartJson, contains(v.id));
      final r = (out as CardSaleDone).sale.receipt;
      expect(
        [
          for (final p in r.payments)
            (p.kind, p.amountCents, p.tipCents, p.voucherBalanceAfterCents),
        ],
        [(PaymentKind.voucher, 500, 0, -500), (PaymentKind.card, 465, 35, null)],
      );
      expect(await cardPayments.pending(), isEmpty);
    });

    test('payByCard, wenn die Gutscheine alles bezahlen: nie zum Terminal, '
        'auch ohne Kleinstbetrag', () async {
      terminal.minimum = 0;
      final v = await sellVoucher(shop, 2500);
      final out = await service.payByCard(
        paymentId: 'k3',
        cart: cartCard.applyVoucher(applied(v)),
        staff: shop.anna,
      );
      expect(
        (out as CardSaleFailed).problem,
        CardSaleProblem.notStarted,
      );
      expect(terminal.payments, isEmpty);
      expect(await cardPayments.pending(), isEmpty);
    });

    test('unklare Zahlung mit Gutschein-Zeile bestätigt: der Abschnitt des '
        'Gutscheins wird gedruckt', () async {
      await configure(drawer: false);
      final selling = const Cart.empty()
          .add(cola)
          .addVoucherSale(valueCents: 2000);
      await cardPayments.begin(
        paymentId: 'u1',
        cart: selling,
        staff: shop.anna,
      );
      await cardPayments.markUnknown('u1');
      final r = await service.confirmUnclear(
        (await cardPayments.pending()).single,
        catalog: catalog,
      );
      expect(r.receipt.soldVouchers, hasLength(1));
      expect([for (final o in await r.voucherPrints) o.ok], [true]);
      expect(printer.printedJobs.map((p) => p.kind), ['receipt', 'voucher']);
    });
  });

  group('Belegerteilung und Kundenbon (Task 15)', () {
    Future<List<Map<String, Object?>>> deliveries() async => [
      for (final r in await shop.db
          .customSelect(
            'SELECT receipt_id, kind FROM receipt_deliveries '
            'ORDER BY receipt_id, kind',
          )
          .get())
        r.data,
    ];

    test('effectiveReceiptMode: ohne Kopplung immer "Immer drucken"', () {
      for (final mode in ReceiptMode.values) {
        final s = RegisterSettings(receiptMode: mode);
        expect(effectiveReceiptMode(s, paired: true), mode);
        expect(
          effectiveReceiptMode(s, paired: false),
          ReceiptMode.alwaysPrint,
        );
      }
    });

    test('"gedruckt" erst nach einem Druck ohne Fehler, einmal je Bon; auch '
        'Nochmal drucken, Drucken aus "Bons" und die Rechnung', () async {
      await configure();
      printer.next = const PrintOutcome.failed(PrintProblem.unreachable);
      final r = await sell('s1');
      expect((await r.print).ok, isFalse);
      expect(r.autoPrinted, isTrue);
      expect(await r.fallback.toList(), [ReceiptFallback.none]);
      expect(await deliveries(), isEmpty);

      printer.next = const PrintOutcome.ok();
      expect((await service.printAgain(r.receipt)).ok, isTrue);
      expect(await deliveries(), [
        {'receipt_id': 's1', 'kind': 'printed'},
      ]);
      expect((await service.reprint(r.receipt)).ok, isTrue);
      expect(await deliveries(), hasLength(1));

      // Aus "Bons" nachgedruckt: der erste Druck ohne Fehler zählt.
      final s2 = await shop.sell('s2');
      expect((await service.reprint(s2)).ok, isTrue);
      // Als Rechnung gedruckt.
      final s3 = await shop.sell('s3');
      final recipient = await container
          .read(customerRepositoryProvider)
          .setRecipient(
            receiptId: s3.id,
            name: 'Muster GmbH',
            addressLine1: 'Musterweg 1',
            addressLine2: '1010 Wien',
            staff: shop.chef,
          );
      expect((await service.printInvoice(s3, recipient)).ok, isTrue);
      expect(await deliveries(), [
        {'receipt_id': 's1', 'kind': 'printed'},
        {'receipt_id': 's2', 'kind': 'printed'},
        {'receipt_id': 's3', 'kind': 'printed'},
      ]);
      expect(
        [
          for (final r in await shop.db
              .customSelect(
                "SELECT ref FROM outbox WHERE kind = 'delivery' ORDER BY id",
              )
              .get())
            r.read<String>('ref'),
        ],
        ['s1/printed', 's2/printed', 's3/printed'],
      );
    });

    test('ein Sonderbeleg zählt nicht als Belegerteilung', () async {
      await configure();
      await shop.insertSpecialReceipt('start', 1, ReceiptKind.start);
      final start = (await shop.receipts.find('start'))!;
      expect((await service.reprint(start)).ok, isTrue);
      expect(printer.printed, ['start']);
      expect(await deliveries(), isEmpty);
    });

    test('ohne Server: ein digitaler Wert druckt wie "Immer drucken", ohne '
        'Uhr', () async {
      await configure();
      final repo = container.read(settingsRepositoryProvider);
      await repo.save(
        (await repo.current()).copyWith(
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
      final r = await sell('s1');
      expect(r.autoPrinted, isTrue);
      expect(r.receiptMode, ReceiptMode.alwaysPrint);
      expect((await r.print).ok, isTrue);
      expect(printer.log, ['print+drawer:s1']);
      expect(await r.fallback.toList(), [ReceiptFallback.none]);
    });
  });

}

/// Offene Zahlungen, deren Schreiben scheitern kann.
class _FailingCardPayments extends CardPaymentRepository {
  _FailingCardPayments(super.db, super.clock);

  bool failMarkUnknown = false;
  bool failDiscard = false;

  @override
  Future<void> markUnknown(String paymentId) async {
    if (failMarkUnknown) throw StateError('Datenbank voll');
    return super.markUnknown(paymentId);
  }

  @override
  Future<void> discard(String paymentId) async {
    if (failDiscard) throw StateError('Datenbank voll');
    return super.discard(paymentId);
  }
}

/// Bons, deren Abschluss als Kartenzahlung scheitert.
class _FailingReceipts extends ReceiptRepository {
  _FailingReceipts(super.db, super.clock, super.days);

  @override
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
  }) async => throw StateError('Datenbank voll');
}

/// Ein winziges Bild statt eines gezeichneten Küchenbons (Zeichnen braucht
/// `dart:ui` und echte Zeit).
final MonoImage _tinyImage = MonoImage(8, 2, Uint8List.fromList([0x81, 0x18]));
