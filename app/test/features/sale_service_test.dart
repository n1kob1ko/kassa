import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/data/card_payment_repository.dart';
import 'package:kassa/data/providers.dart';
import 'package:kassa/data/settings_repository.dart';
import 'package:kassa/devices/card_terminal.dart';
import 'package:kassa/devices/device_providers.dart';
import 'package:kassa/devices/printer.dart';
import 'package:kassa/domain/cart.dart';
import 'package:kassa/domain/catalog.dart';
import 'package:kassa/domain/receipt.dart';
import 'package:kassa/features/kassa/cart_controller.dart';
import 'package:kassa/features/kassa/sale_service.dart';

import '../support/fake_devices.dart';
import '../support/demo_fixtures.dart';
import '../support/sales.dart';

void main() {
  late TestShop shop;
  late FakePrinter printer;
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
    terminal = FakeCardTerminal();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(shop.db),
        clockProvider.overrideWithValue(shop.clock),
        receiptPrinterProvider.overrideWithValue(printer),
        cardTerminalProvider.overrideWithValue(terminal),
      ],
    );
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
      final p = o.sale.receipt.payment;
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
      expect(o.message, 'Die Karte wurde abgelehnt.');
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
      expect(r.receipt.payment.kind, PaymentKind.card);
      expect(r.receipt.payment.providerTxCode, isNull);
      expect(r.receipt.payment.provider, 'sumup');
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

    test('CardFailed.message: alle Texte', () {
      String m(CardFailure f, [String? d]) => CardFailed(f, detail: d).message;
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
}
