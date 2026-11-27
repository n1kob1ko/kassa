import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/core/app_language.dart';
import 'package:kassa/data/providers.dart';
import 'package:kassa/data/settings_repository.dart';
import 'package:kassa/data/translation_repository.dart';
import 'package:kassa/devices/device_providers.dart';
import 'package:kassa/devices/escpos.dart';
import 'package:kassa/devices/mono_image.dart';
import 'package:kassa/devices/printer.dart';
import 'package:kassa/domain/cart.dart';
import 'package:kassa/domain/catalog.dart';
import 'package:kassa/domain/kitchen_ticket.dart';
import 'package:kassa/domain/menu_dictionary.dart';
import 'package:kassa/domain/receipt_layout.dart';
import 'package:kassa/features/kassa/kitchen_service.dart';
import 'package:kassa/features/kassa/sale_service.dart';

import '../support/demo_fixtures.dart';
import '../support/sales.dart';

/// Ein winziges Bild statt eines gezeichneten Küchenbons.
final MonoImage _tinyImage = MonoImage(8, 2, Uint8List.fromList([0x81, 0x18]));

/// Transport, der mitschreibt; mit [hang] kommt `send` erst nach [release]
/// zurück.
class _Transport implements PrinterTransport {
  final sent = <Uint8List>[];
  final started = <Duration>[];

  /// Zahl der Zustandsfragen.
  int asked = 0;
  bool hang = false;
  final release = Completer<void>();

  @override
  void startCall(Duration limit) => started.add(limit);

  @override
  void abandon() {}

  @override
  Future<int?> status(List<int> request) async {
    asked++;
    return null;
  }

  @override
  Future<void> send(Uint8List bytes) async {
    if (hang) await release.future;
    sent.add(bytes);
  }
}

void main() {
  late TestShop shop;
  late ProviderContainer container;
  late List<KitchenTicket> rendered;
  late Map<String, _Transport> transports;

  final raster = encodeRasterTicket(_tinyImage);

  setUp(() async {
    shop = await TestShop.open();
    rendered = [];
    transports = {
      '192.168.0.50': _Transport(), // Bondrucker
      '192.168.0.60': _Transport(), // Küchendrucker
    };
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(shop.db),
        clockProvider.overrideWithValue(shop.clock),
        transportFactoryProvider.overrideWithValue(
          (settings) => transports[settings.printerAddress],
        ),
        kitchenImageRendererProvider.overrideWithValue((
          ticket, {
          required widthDots,
        }) async {
          rendered.add(ticket);
          return _tinyImage;
        }),
      ],
    );
    // Die Drucker folgen den Strömen der Einstellungen und der Speisekarte.
    container.listen(receiptPrinterProvider, (_, _) {});
    container.listen(kitchenPrinterProvider, (_, _) {});
  });
  tearDown(() async {
    container.dispose();
    await shop.close();
  });

  _Transport receiptT() => transports['192.168.0.50']!;
  _Transport kitchenT() => transports['192.168.0.60']!;

  Future<void> configure(
    KitchenMode mode, {
    PrinterKind kitchenKind = PrinterKind.network,
    Set<String> skip = const {},
  }) async {
    final repo = container.read(settingsRepositoryProvider);
    await repo.save(
      (await repo.current()).copyWith(
        printerKind: PrinterKind.network,
        printerAddress: '192.168.0.50',
        cashDrawerEnabled: false,
        kitchenMode: mode,
        kitchenPrinterKind: kitchenKind,
        kitchenPrinterAddress: kitchenKind == PrinterKind.none
            ? null
            : '192.168.0.60',
        kitchenSkipCategories: skip,
      ),
    );
    for (var i = 0; i < 100; i++) {
      final now = container.read(settingsStreamProvider).value;
      final catalog = container.read(catalogStreamProvider).value;
      if (now?.kitchenMode == mode &&
          now?.kitchenPrinterKind == kitchenKind &&
          now?.printerKind == PrinterKind.network &&
          catalog != null) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    fail('Einstellungen kamen nicht an');
  }

  Future<SaleResult> sell([String id = 's1']) => container
      .read(saleServiceProvider)
      .completeCash(saleId: id, cart: cart, givenCents: 2000, staff: shop.anna);

  group('kitchenPrinterProvider', () {
    test('aus: null', () async {
      await configure(KitchenMode.off);
      expect(container.read(kitchenPrinterProvider), isNull);
    });

    test('am Bondrucker: dieselbe Instanz wie der Bondrucker', () async {
      await configure(KitchenMode.receiptPrinter);
      expect(
        container.read(kitchenPrinterProvider),
        same(container.read(receiptPrinterProvider)),
      );
    });

    test('ein Verkauf (Entwurf des Bons in den Einstellungen) gibt keinen '
        'neuen Drucker und damit keine neue Warteschlange', () async {
      await configure(KitchenMode.kitchenPrinter);
      final receipt = container.read(receiptPrinterProvider);
      final kitchen = container.read(kitchenPrinterProvider);
      await container.read(settingsRepositoryProvider).writeDraft('{}');
      await (await sell()).print;
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(
        container.read(settingsStreamProvider).value?.kitchenMode,
        KitchenMode.kitchenPrinter,
      );
      expect(container.read(receiptPrinterProvider), same(receipt));
      expect(container.read(kitchenPrinterProvider), same(kitchen));
    });

    test('am Küchendrucker: ein eigener Drucker', () async {
      await configure(KitchenMode.kitchenPrinter);
      final p = container.read(kitchenPrinterProvider);
      expect(p, isNotNull);
      expect(p, isNot(same(container.read(receiptPrinterProvider))));
    });

    test(
      'am Küchendrucker ohne Adresse: notSetUp, nicht der Bondrucker',
      () async {
        await configure(
          KitchenMode.kitchenPrinter,
          kitchenKind: PrinterKind.none,
        );
        final p = container.read(kitchenPrinterProvider)!;
        final o = await p.printRaster(() async => raster);
        expect(o.problem, PrintProblem.notSetUp);
        expect(receiptT().sent, isEmpty);
      },
    );
  });

  group('ein Drucker, eine Warteschlange', () {
    test('am Küchendrucker mit derselben Adresse wie der Bondrucker: '
        'dieselbe Instanz', () async {
      await configure(KitchenMode.kitchenPrinter);
      final repo = container.read(settingsRepositoryProvider);
      await repo.save(
        (await repo.current()).copyWith(
          kitchenPrinterAddress: ' 192.168.0.50 ',
        ),
      );
      await _until(
        () =>
            container
                .read(settingsStreamProvider)
                .value
                ?.kitchenPrinterAddress ==
            ' 192.168.0.50 ',
      );
      expect(
        container.read(kitchenPrinterProvider),
        same(container.read(receiptPrinterProvider)),
      );
      // Bon und Küchenbon gehen nacheinander hinaus, nie gleichzeitig.
      receiptT().hang = true;
      final r = await sell();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      receiptT().release.complete();
      expect((await r.print).ok, isTrue);
      expect((await r.kitchen)!.ok, isTrue);
      expect(receiptT().sent, [
        encodeEscPos(layoutReceipt(r.receipt, catalog.business)),
        raster,
      ]);
    });

    test('gleiche Adresse, andere Art: eigener Drucker', () async {
      await configure(KitchenMode.kitchenPrinter);
      final repo = container.read(settingsRepositoryProvider);
      await repo.save(
        (await repo.current()).copyWith(
          kitchenPrinterKind: PrinterKind.bluetooth,
          kitchenPrinterAddress: '192.168.0.50',
        ),
      );
      await _until(
        () =>
            container.read(settingsStreamProvider).value?.kitchenPrinterKind ==
            PrinterKind.bluetooth,
      );
      expect(
        container.read(kitchenPrinterProvider),
        isNot(same(container.read(receiptPrinterProvider))),
      );
    });

    test('ändert sich die Adresse wirklich, kommt ein neuer Drucker, und der '
        'nächste Auftrag geht an den neuen Transport', () async {
      transports['192.168.0.70'] = _Transport();
      await configure(KitchenMode.kitchenPrinter);
      final before = container.read(kitchenPrinterProvider);
      final repo = container.read(settingsRepositoryProvider);
      await repo.save(
        (await repo.current()).copyWith(kitchenPrinterAddress: '192.168.0.70'),
      );
      await _until(
        () =>
            container
                .read(settingsStreamProvider)
                .value
                ?.kitchenPrinterAddress ==
            '192.168.0.70',
      );
      final after = container.read(kitchenPrinterProvider)!;
      expect(after, isNot(same(before)));
      expect((await after.printRaster(() async => raster)).ok, isTrue);
      expect(transports['192.168.0.70']!.sent, [raster]);
      expect(kitchenT().sent, isEmpty);

      // Ebenso der Bondrucker.
      final receiptBefore = container.read(receiptPrinterProvider);
      await repo.save(
        (await repo.current()).copyWith(printerAddress: '192.168.0.70'),
      );
      await _until(
        () =>
            container.read(settingsStreamProvider).value?.printerAddress ==
            '192.168.0.70',
      );
      final receiptAfter = container.read(receiptPrinterProvider);
      expect(receiptAfter, isNot(same(receiptBefore)));
      await receiptAfter.testPrint();
      expect(transports['192.168.0.70']!.sent, hasLength(2));
      expect(receiptT().sent, isEmpty);
    });

    test(
      'ändert sich der Ort des Küchenbons, kommt der passende Drucker',
      () async {
        await configure(KitchenMode.kitchenPrinter);
        final own = container.read(kitchenPrinterProvider);
        await configure(KitchenMode.receiptPrinter);
        final shared = container.read(kitchenPrinterProvider);
        expect(shared, isNot(same(own)));
        expect(shared, same(container.read(receiptPrinterProvider)));
        expect((await shared!.printRaster(() async => raster)).ok, isTrue);
        expect(receiptT().sent, [raster]);
        expect(kitchenT().sent, isEmpty);
      },
    );
  });

  group('Fehler beim Einreihen', () {
    test('Drucker nicht zu lesen und Wörterbuch scheitert: unreachable, '
        'kein unbehandelter Fehler', () async {
      container.dispose();
      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(shop.db),
          clockProvider.overrideWithValue(shop.clock),
          transportFactoryProvider.overrideWithValue(
            (settings) => transports[settings.printerAddress],
          ),
          translationRepositoryProvider.overrideWithValue(
            _BrokenTranslations(shop.db),
          ),
          kitchenPrinterProvider.overrideWith(
            (ref) => throw StateError('Drucker'),
          ),
        ],
      );
      container.listen(settingsStreamProvider, (_, _) {});
      container.listen(catalogStreamProvider, (_, _) {});
      await configure(KitchenMode.kitchenPrinter);
      final r = await sell();
      final o = await container
          .read(kitchenServiceProvider)
          .printFor(r.receipt);
      expect(o?.problem, PrintProblem.unreachable);
      // Das Wörterbuch scheitert erst danach; niemand wartet mehr darauf.
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
  });

  group('am Transport', () {
    test('am Bondrucker, zwei schnelle Verkäufe: Bon A, Küche A, Bon B, '
        'Küche B', () async {
      await configure(KitchenMode.receiptPrinter);
      receiptT().hang = true; // der erste Bon steckt noch im Drucker
      // Zwei Verkäufe hintereinander, ohne auf einen Druck zu warten.
      final ra = await sell('s1');
      final rb = await sell('s2');
      await Future<void>.delayed(const Duration(milliseconds: 30));
      receiptT().release.complete();
      expect((await ra.print).ok, isTrue);
      expect((await rb.print).ok, isTrue);
      expect((await ra.kitchen)!.ok, isTrue);
      expect((await rb.kitchen)!.ok, isTrue);
      expect(receiptT().sent, [
        encodeEscPos(layoutReceipt(ra.receipt, catalog.business)),
        raster,
        encodeEscPos(layoutReceipt(rb.receipt, catalog.business)),
        raster,
      ]);
    });

    test('am Bondrucker, nichts für die Küche: kitchen null, kein Zettel, '
        'keine Frage an den Drucker', () async {
      await configure(KitchenMode.receiptPrinter, skip: {cola.categoryId});
      final r = await container
          .read(saleServiceProvider)
          .completeCash(
            saleId: 's1',
            cart: const Cart.empty().add(cola),
            givenCents: 2000,
            staff: shop.anna,
          );
      expect((await r.print).ok, isTrue);
      expect(await r.kitchen, isNull);
      // Die Warteschlange ist danach leer: ein weiterer Bon kommt durch.
      await container.read(receiptPrinterProvider).testPrint();
      expect(receiptT().sent, [
        encodeEscPos(layoutReceipt(r.receipt, catalog.business)),
        isNot(raster),
      ]);
      expect(receiptT().asked, 2); // Bon und Testdruck, nicht der Küchenbon
      expect(rendered, isEmpty);
    });

    test('am Bondrucker, nur freie Beträge: kitchen null, kein Zettel, keine '
        'Frage an den Drucker', () async {
      await configure(KitchenMode.receiptPrinter);
      final r = await container
          .read(saleServiceProvider)
          .completeCash(
            saleId: 's1',
            cart: const Cart.empty()
                .addOpenAmount(amountCents: 1250, rate: TaxRate.normal)
                .addOpenAmount(amountCents: 300, rate: TaxRate.reduced1),
            givenCents: 2000,
            staff: shop.anna,
          );
      expect((await r.print).ok, isTrue);
      expect(await r.kitchen, isNull);
      await container.read(receiptPrinterProvider).testPrint();
      expect(receiptT().sent, [
        encodeEscPos(layoutReceipt(r.receipt, catalog.business)),
        isNot(raster),
      ]);
      expect(receiptT().asked, 2); // Bon und Testdruck, nicht der Küchenbon
      expect(rendered, isEmpty);
    });

    test('am Bondrucker: Kundenbon, dann Raster, je eigener Auftrag', () async {
      await configure(KitchenMode.receiptPrinter);
      final r = await sell();
      expect((await r.print).ok, isTrue);
      expect((await r.kitchen)!.ok, isTrue);
      expect(receiptT().sent, [
        encodeEscPos(layoutReceipt(r.receipt, catalog.business)),
        raster,
      ]);
      expect(receiptT().started, [printCallLimit, rasterCallLimit]);
      expect(kitchenT().sent, isEmpty);
    });

    test('am Küchendrucker: Raster an den Küchendrucker, Bon an den '
        'Bondrucker', () async {
      await configure(KitchenMode.kitchenPrinter);
      final r = await sell();
      expect((await r.print).ok, isTrue);
      expect((await r.kitchen)!.ok, isTrue);
      expect(receiptT().sent, [
        encodeEscPos(layoutReceipt(r.receipt, catalog.business)),
      ]);
      expect(kitchenT().sent, [raster]);
      expect(kitchenT().started, [rasterCallLimit]);
    });

    test(
      'Küchendrucker hängt: der Bon des nächsten Verkaufs kommt sofort',
      () async {
        await configure(KitchenMode.kitchenPrinter);
        kitchenT().hang = true;
        final first = await sell('s1');
        expect((await first.print).ok, isTrue);
        final second = await sell('s2');
        expect((await second.print).ok, isTrue);
        expect(receiptT().sent, hasLength(2));
        kitchenT().release.complete();
        expect((await first.kitchen)!.ok, isTrue);
        expect((await second.kitchen)!.ok, isTrue);
        expect(kitchenT().sent, [raster, raster]);
      },
    );
  });

  group('printFor', () {
    test('aus: null, nichts gezeichnet', () async {
      await configure(KitchenMode.off);
      final r = await sell();
      await r.print;
      final o = await container
          .read(kitchenServiceProvider)
          .printFor(r.receipt);
      expect(o, isNull);
      expect(rendered, isEmpty);
    });

    test('copy: true druckt den Vermerk KOPIE', () async {
      await configure(KitchenMode.kitchenPrinter);
      final r = await sell();
      await r.kitchen;
      rendered.clear();
      final o = await container
          .read(kitchenServiceProvider)
          .printFor(r.receipt, copy: true);
      expect(o!.ok, isTrue);
      expect(rendered.single.kind, KitchenTicketKind.copy);
      expect(rendered.single.banner, 'KOPIE');
      expect(rendered.single.number, r.receipt.number);
      expect(kitchenT().sent, [raster, raster]);
    });

    test(
      'ein inzwischen stillgelegter Artikel zählt mit seiner Kategorie',
      () async {
        await configure(
          KitchenMode.kitchenPrinter,
          skip: {cola.categoryId, huhnBowl.categoryId},
        );
        final r = await sell();
        expect(await r.kitchen, isNull);
        // Huhn Bowl wird stillgelegt: der Bon nennt sie weiter.
        await shop.catalogRepo.importCatalog(
          Catalog(
            business: catalog.business,
            categories: catalog.categories,
            items: [
              for (final i in catalog.items)
                if (i.id != huhnBowl.id) i,
            ],
            templates: catalog.templates,
          ),
        );
        final o = await container
            .read(kitchenServiceProvider)
            .printFor(r.receipt, copy: true);
        expect(o, isNull);
        expect(rendered, isEmpty);
      },
    );

    test('nichts davon landet in der Datenbank', () async {
      await configure(KitchenMode.kitchenPrinter);
      final r = await sell();
      await r.kitchen;
      final before = await _dump(shop);
      await container.read(kitchenServiceProvider).printFor(r.receipt);
      expect(await _dump(shop), before);
    });
  });

  group('printSample', () {
    test('druckt den Beispiel-Küchenbon am gewählten Drucker', () async {
      await configure(KitchenMode.kitchenPrinter);
      final o = await container.read(kitchenServiceProvider).printSample();
      expect(o.ok, isTrue);
      expect(rendered.single.kind, KitchenTicketKind.sample);
      expect(rendered.single.banner, 'PROBE');
      expect(rendered.single.lines, isNotEmpty);
      expect(kitchenT().sent, [raster]);
      expect(receiptT().sent, isEmpty);
    });

    test('aus: notSetUp, nichts gedruckt', () async {
      await configure(KitchenMode.off);
      final o = await container.read(kitchenServiceProvider).printSample();
      expect(o.problem, PrintProblem.notSetUp);
      expect(rendered, isEmpty);
    });

    test('Zeichnen wirft: unreachable', () async {
      container.dispose();
      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(shop.db),
          clockProvider.overrideWithValue(shop.clock),
          transportFactoryProvider.overrideWithValue(
            (settings) => transports[settings.printerAddress],
          ),
          kitchenImageRendererProvider.overrideWithValue(
            (ticket, {required widthDots}) async => throw StateError('x'),
          ),
        ],
      );
      container.listen(kitchenPrinterProvider, (_, _) {});
      await configure(KitchenMode.kitchenPrinter);
      final o = await container.read(kitchenServiceProvider).printSample();
      expect(o.problem, PrintProblem.unreachable);
      expect(kitchenT().sent, isEmpty);
    });
  });
}

/// Wartet, bis [done] wahr ist (die Ströme der Einstellungen sind
/// asynchron).
Future<void> _until(bool Function() done) async {
  for (var i = 0; i < 100; i++) {
    if (done()) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail('Bedingung kam nicht');
}

/// Ein Wörterbuch, das beim Lesen scheitert.
class _BrokenTranslations extends TranslationRepository {
  _BrokenTranslations(super.db);

  @override
  Future<MenuDictionary> current() async {
    await Future<void>.delayed(const Duration(milliseconds: 5));
    throw StateError('Wörterbuch');
  }
}

/// Inhalt der Tabellen, die ein Druck verändern könnte.
Future<Map<String, List<Map<String, Object?>>>> _dump(TestShop shop) async => {
  for (final t in [
    'receipts',
    'receipt_lines',
    'settings',
    'translations',
    'outbox',
    'reports',
  ])
    t: [
      for (final row in await shop.db.customSelect('SELECT * FROM $t').get())
        row.data,
    ],
};
