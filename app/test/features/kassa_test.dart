import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/core/app_language.dart';
import 'package:kassa/data/database.dart';
import 'package:kassa/data/sync_state_repository.dart';
import 'package:kassa/data/providers.dart';
import 'package:kassa/devices/printer.dart';
import 'package:kassa/domain/cart.dart';
import 'package:kassa/domain/catalog.dart';
import 'package:kassa/domain/discount.dart';
import 'package:kassa/features/kassa/cart_controller.dart';
import 'package:kassa/features/kassa/kassa_screen.dart';
import 'package:kassa/features/kassa/kitchen_service.dart';
import 'package:kassa/features/login/session.dart';
import 'package:kassa/rksv/online/online_providers.dart';
import 'package:kassa/rksv/rksv_secrets.dart';
import 'package:kassa/rksv/rksv_state.dart';
import 'package:kassa/ui/pressable.dart';
import 'package:kassa/ui/primary_button.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../support/cash_pump.dart' show queryRows;
import '../support/demo_fixtures.dart';
import '../support/fake_server.dart';
import '../support/files_pump.dart';
import '../support/fake_atrust.dart';
import '../support/fake_devices.dart';
import '../support/kassa_pump.dart';
import '../support/pump.dart';
import '../support/signature_pump.dart';

Finder _text(String s) => find.text(s);

String _total(WidgetTester t) => textOf(t, const Key('cart-total'));

PrimaryButton _button(WidgetTester t, String key) =>
    t.widget<PrimaryButton>(find.byKey(Key(key)));

int _columns(WidgetTester t) {
  final grid = t.widget<GridView>(find.byKey(const Key('item-grid')));
  return (grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
      .crossAxisCount;
}

Future<void> _openBowl(WidgetTester t) async {
  await t.tap(find.byKey(const Key('item-huhn-bowl')));
  await t.pump();
}

/// Wählt Größe und Basis und legt die Bowl auf den Bon.
Future<void> _addBowl(
  WidgetTester t, {
  String size = 'bowl/0/1',
  String base = 'bowl/1/0',
}) async {
  await _openBowl(t);
  await t.tap(find.byKey(Key('opt-$base')));
  await t.tap(find.byKey(Key('opt-$size')));
  await t.pump();
  await t.tap(find.byKey(const Key('add-to-cart')));
  await t.pump();
}

const _login = 'PUT /Session/u123456789';
const _liveLogin = 'PUT /Session/u-beispiel';

/// Zählt, wie oft der AES-Schlüssel gelesen wird.
class _CountingSecrets extends MemoryRksvSecrets {
  int aesReads = 0;

  @override
  Future<Uint8List?> aesKey(int chain) {
    aesReads++;
    return super.aesKey(chain);
  }
}

/// Die App geht in den Hintergrund und kommt wieder nach vorn.
Future<void> _resume(WidgetTester t) async {
  t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await t.pumpAndSettle();
}

/// Signatur-Attrappen und [fake] als A-Trust; [onRead] zählt, wie oft die
/// Verbindung zu A-Trust gebaut wird.
List<Override> _online(
  FakeAtrust fake,
  MemoryRksvSecrets secrets, [
  void Function()? onRead,
]) => [
  ...signatureOverrides(secrets: secrets),
  atrustHttpClientProvider.overrideWith((ref) {
    onRead?.call();
    return fake.client;
  }),
];

void main() {
  offenerBonTests();
  testWidgets('Tipp auf Artikel legt ihn auf den Bon, Pfand steht getrennt', (
    t,
  ) async {
    await pumpKassa(t);
    await t.tap(find.byKey(const Key('cat-getraenke')));
    await t.pump();
    await t.tap(find.byKey(const Key('item-cola')));
    await t.tap(find.byKey(const Key('item-cola')));
    await t.pump();
    final line = cartOf(t).lines.single;
    final row = find.byKey(Key('line-${line.lineId}'));
    expect(
      find.descendant(of: row, matching: _text('Cola 0,33 l')),
      findsOneWidget,
    );
    expect(textOf(t, Key('qty-${line.lineId}')), '2');
    expect(find.descendant(of: row, matching: _text('5,80 €')), findsOneWidget);
    expect(textOf(t, const Key('cart-deposit')), 'davon Pfand 0,50 €');
    expect(_text('Pfand'), findsNothing);
    // Das Pfand steht unter der Summe.
    expect(
      t.getTopLeft(find.byKey(const Key('cart-deposit'))).dy,
      greaterThan(t.getTopLeft(find.byKey(const Key('cart-total'))).dy),
    );
    expect(_total(t), '6,30 €');
    expect(textOf(t, const Key('cart-count')), '2 Artikel');
  });

  testWidgets(
    'Artikel mit Auswahl: "Auf den Bon" erst, wenn die Pflichtgruppen gewählt sind',
    (t) async {
      await pumpKassa(t);
      await _openBowl(t);
      expect(_button(t, 'add-to-cart').onPressed, isNull);
      expect(_button(t, 'add-to-cart').label, 'Noch wählen: Basis');
      expect(_text('Noch wählen: Basis'), findsOneWidget);
      expect(_text('Bitte wählen'), findsOneWidget);
      // Der Bon bleibt, solange zusammengestellt wird, und Bar ist gesperrt.
      expect(cartOf(t).isEmpty, isTrue);
      await t.tap(find.byKey(const Key('opt-bowl/1/0')));
      await t.tap(find.byKey(const Key('opt-bowl/0/1')));
      await t.pump();
      expect(_button(t, 'add-to-cart').label, 'Auf den Bon');
      expect(_button(t, 'add-to-cart').onPressed, isNotNull);
      expect(_text('Bitte wählen'), findsNothing);
      await t.tap(find.byKey(const Key('add-to-cart')));
      await t.pump();
      expect(_total(t), '11,90 €');
      expect(_text('XXL, Reis'), findsOneWidget);
      // Das Zusammenstellen ist zu, das Raster wieder da.
      expect(find.byKey(const Key('item-grid')), findsOneWidget);
      expect(find.byKey(const Key('add-to-cart')), findsNothing);
    },
  );

  testWidgets('Abbrechen im Zusammenstellen legt nichts auf den Bon', (
    t,
  ) async {
    await pumpKassa(t);
    await _openBowl(t);
    await t.tap(find.byKey(const Key('opt-bowl/1/0')));
    await t.pump();
    await t.tap(find.byKey(const Key('cancel-build')));
    await t.pump();
    expect(cartOf(t).isEmpty, isTrue);
    expect(_total(t), '0,00 €');
    expect(find.byKey(const Key('add-to-cart')), findsNothing);
    expect(find.byKey(const Key('item-huhn-bowl')), findsOneWidget);
    expect(await draftOf(t), isNull);
  });

  testWidgets(
    'derselbe einfache Artikel gibt eine Zeile, zwei Bowls mit anderer Auswahl zwei',
    (t) async {
      await pumpKassa(t);
      await t.tap(find.byKey(const Key('cat-snacks')));
      await t.pump();
      await t.tap(find.byKey(const Key('item-pommes')));
      await t.tap(find.byKey(const Key('item-pommes')));
      await t.pump();
      expect(cartOf(t).lines, hasLength(1));
      expect(cartOf(t).lines.single.quantity, 2);
      await t.tap(find.byKey(const Key('cat-bowls')));
      await t.pump();
      await _addBowl(t, size: 'bowl/0/1', base: 'bowl/1/0');
      await _addBowl(t, size: 'bowl/0/0', base: 'bowl/1/1');
      final lines = cartOf(t).lines;
      expect(lines.map((l) => l.item.id), ['pommes', 'huhn-bowl', 'huhn-bowl']);
      expect(lines[1].options.map((o) => o.id), contains('bowl/0/1'));
      expect(lines[2].options.map((o) => o.id), contains('bowl/1/1'));
      expect(find.byKey(Key('line-${lines[1].lineId}')), findsOneWidget);
      expect(find.byKey(Key('line-${lines[2].lineId}')), findsOneWidget);
    },
  );

  testWidgets(
    'Minus bei Menge 1 entfernt die Zeile, Plus erhöht Menge und Summe',
    (t) async {
      await pumpKassaWith(t, ['teigtaschen']);
      final id = cartOf(t).lines.single.lineId;
      expect(_total(t), '6,50 €');
      await t.tap(find.byKey(Key('qty-plus-$id')));
      await t.pump();
      expect(textOf(t, Key('qty-$id')), '2');
      expect(_total(t), '13,00 €');
      await t.tap(find.byKey(Key('qty-minus-$id')));
      await t.pump();
      expect(textOf(t, Key('qty-$id')), '1');
      await t.tap(find.byKey(Key('qty-minus-$id')));
      await t.pump();
      expect(find.byKey(Key('line-$id')), findsNothing);
      expect(cartOf(t).isEmpty, isTrue);
      expect(_text('Noch nichts boniert'), findsOneWidget);
      expect(_total(t), '0,00 €');
    },
  );

  testWidgets('ohne Pfand gibt es keine Pfandzeile, nur die Steuer', (t) async {
    await pumpKassaWith(t, ['pommes']);
    expect(find.byKey(const Key('cart-deposit')), findsNothing);
    expect(find.textContaining('MwSt'), findsOneWidget);
  });

  for (final (size, scale) in [
    (const Size(1280, 800), 1.0),
    (const Size(960, 600), 1.3),
  ]) {
    testWidgets(
      'kompakte Tasten: jeder Preis hat dieselbe Größe ($size, Schrift $scale)',
      (t) async {
        await pumpKassaWith(t, ['teigtaschen'], size: size, textScale: scale);
        double sizeOf(String id, String price) {
          final text = find.descendant(
            of: find.byKey(Key('item-$id')),
            matching: _text(price),
          );
          final box = t.renderObject<RenderBox>(text);
          // Gezeichnete Höhe der Schrift: FittedBox würde sie verkleinern.
          final fitted = find.ancestor(
            of: text,
            matching: find.byType(FittedBox),
          );
          expect(fitted, findsNothing, reason: 'Preis wird nicht skaliert');
          return box.size.height;
        }

        final a = sizeOf('teigtaschen', '6,50 €');
        final b = sizeOf('fruehlingsrollen', '4,90 €');
        final c = sizeOf('pommes', '3,90 €');
        expect(b, a);
        expect(c, a);
        expect(t.takeException(), isNull);
      },
    );
  }

  testWidgets('Bon leeren lässt sich rückgängig machen', (t) async {
    await pumpKassaWith(t, ['cola', 'teigtaschen']);
    expect(_total(t), '9,65 €');
    await t.tap(find.byKey(const Key('clear-cart')));
    await t.pump();
    expect(_total(t), '0,00 €');
    expect(_text('Bon geleert'), findsOneWidget);
    expect(_text('Noch nichts boniert'), findsOneWidget);
    await t.tap(_text('Rückgängig'));
    await t.pump();
    expect(_total(t), '9,65 €');
    expect(_text('Bon geleert'), findsNothing);
  });

  testWidgets(
    'Preis geändert bei offenem Bon: Zeile, Summe, nächster Tipp und Bon gelten neu',
    (t) async {
      await pumpKassaWith(t, ['cola']);
      expect(_total(t), '3,15 €');
      await containerOf(t)
          .read(catalogRepositoryProvider)
          .updateItem('cola', priceCents: 320);
      await t.pump();
      await t.pump();
      final id = cartOf(t).lines.single.lineId;
      expect(cartOf(t).lines.single.unitPriceCents, 320);
      expect(_total(t), '3,45 €');
      await t.tap(find.byKey(const Key('item-cola')));
      await t.pump();
      expect(textOf(t, Key('qty-$id')), '2');
      expect(_total(t), '6,90 €');
      expect(
        (await containerOf(t).read(settingsRepositoryProvider).readDraft())!,
        contains('"quantity":2'),
      );
      await t.tap(find.byKey(const Key('pay-cash')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('finish-sale')));
      await t.pumpAndSettle();
      final rows = await containerOf(t)
          .read(databaseProvider)
          .customSelect(
            'SELECT unit_price_cents AS p, quantity AS q FROM receipt_lines',
          )
          .get();
      expect([for (final r in rows) (r.data['p'], r.data['q'])], [(320, 2)]);
    },
  );

  testWidgets(
    'Speisekarte neu eingespielt ohne Artikel: seine Zeile fällt vom offenen Bon',
    (t) async {
      await pumpKassaWith(t, ['cola', 'teigtaschen']);
      expect(cartOf(t).lines, hasLength(2));
      final without = Catalog(
        business: catalog.business,
        categories: catalog.categories,
        items: [
          for (final i in catalog.items)
            if (i.id != 'cola') i,
        ],
        templates: catalog.templates,
      );
      await containerOf(t)
          .read(catalogRepositoryProvider)
          .importCatalog(without);
      await t.pump();
      await t.pump();
      await t.pump();
      expect(cartOf(t).lines.map((l) => l.item.id), ['teigtaschen']);
      expect(_total(t), '6,50 €');
      expect(await draftOf(t), isNot(contains('cola')));
    },
  );

  testWidgets(
    'Bon leeren, dann etwas boniert: Hinweis weg, nur der neue Artikel bleibt',
    (t) async {
      await pumpKassaWith(t, ['cola', 'teigtaschen']);
      await t.tap(find.byKey(const Key('clear-cart')));
      await t.pump();
      expect(_text('Bon geleert'), findsOneWidget);
      await tapItem(t, 'pommes');
      await t.pump();
      expect(_text('Bon geleert'), findsNothing);
      expect(_text('Rückgängig'), findsNothing);
      expect(cartOf(t).lines.map((l) => l.item.id), ['pommes']);
    },
  );

  testWidgets('restore ersetzt nie einen Bon, auf dem etwas liegt', (t) async {
    await pumpKassaWith(t, ['teigtaschen']);
    final old = const Cart.empty().add(cola);
    containerOf(t).read(cartProvider.notifier).restore(old);
    await t.pump();
    expect(cartOf(t).lines.map((l) => l.item.id), ['teigtaschen']);
    expect(_total(t), '6,50 €');
  });

  testWidgets(
    'leerer Bon: Bar und Karte sind gesperrt, mit Artikel gehen beide',
    (t) async {
      await pumpKassa(t);
      expect(_text('Noch nichts boniert'), findsOneWidget);
      expect(
        _text(
          'Tippe links auf einen Artikel. Jeder Tipp legt ihn einmal auf den Bon.',
        ),
        findsOneWidget,
      );
      expect(_button(t, 'pay-cash').onPressed, isNull);
      expect(_button(t, 'pay-card').onPressed, isNull);
      expect(_text('kommt später'), findsNothing);
      await t.tap(find.byKey(const Key('cat-snacks')));
      await t.pump();
      await t.tap(find.byKey(const Key('item-pommes')));
      await t.pump();
      expect(_button(t, 'pay-cash').onPressed, isNotNull);
      expect(_button(t, 'pay-card').onPressed, isNotNull);
      expect(t.getSize(find.byKey(const Key('pay-cash'))).height, 80);
      expect(t.getSize(find.byKey(const Key('pay-card'))).height, 80);
    },
  );

  testWidgets('Bar öffnet das Bezahlen, aber nur mit Artikeln auf dem Bon', (
    t,
  ) async {
    await pumpApp(t, const KassaScreen(), overrides: await memoryOverrides());
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('pay-cash')));
    await t.pump();
    expect(find.byKey(const Key('finish-sale')), findsNothing);
    await t.tap(find.byKey(const Key('cat-snacks')));
    await t.pump();
    await t.tap(find.byKey(const Key('item-teigtaschen')));
    await t.pump();
    await t.tap(find.byKey(const Key('pay-cash')));
    await t.pump();
    expect(find.byKey(const Key('finish-sale')), findsOneWidget);
  });

  testWidgets(
    'Artikel, die nicht im Verkauf sind, lassen sich nicht antippen',
    (t) async {
      await pumpKassa(t);
      await containerOf(t)
          .read(catalogRepositoryProvider)
          .updateItem('cola', inSale: false);
      await t.pump();
      await t.pump();
      await t.tap(find.byKey(const Key('cat-getraenke')));
      await t.pump();
      expect(
        find.descendant(
          of: find.byKey(const Key('item-cola')),
          matching: _text('Nicht im Verkauf'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('item-cola')),
          matching: _text('2,90 €'),
        ),
        findsNothing,
      );
      await t.tap(find.byKey(const Key('item-cola')));
      await t.pump();
      expect(cartOf(t).isEmpty, isTrue);
      // Ein anderer Artikel derselben Kategorie geht weiter.
      await t.tap(find.byKey(const Key('item-eistee')));
      await t.pump();
      expect(cartOf(t).lines.single.item.id, 'eistee');
    },
  );

  testWidgets(
    'ohne Favoriten gibt es keine Kategorie "Favoriten", die erste ist gewählt',
    (t) async {
      await pumpKassa(t);
      expect(find.byKey(const Key('cat-favorites')), findsNothing);
      expect(_text('Favoriten'), findsNothing);
      expect(textOf(t, const Key('area-title')), 'Bowls');
      expect(find.byKey(const Key('item-huhn-bowl')), findsOneWidget);
      expect(find.byKey(const Key('item-cola')), findsNothing);
    },
  );

  testWidgets(
    'mit Favorit: "Favoriten" steht zuerst und ist gewählt, mit Anzahl',
    (t) async {
      await pumpKassa(t);
      await containerOf(t)
          .read(catalogRepositoryProvider)
          .updateItem('cola', favorite: true);
      await t.pump();
      await t.pump();
      expect(find.byKey(const Key('cat-favorites')), findsOneWidget);
      expect(
        t.getTopLeft(find.byKey(const Key('cat-favorites'))).dy,
        lessThan(t.getTopLeft(find.byKey(const Key('cat-bowls'))).dy),
      );
      expect(textOf(t, const Key('area-title')), 'Favoriten');
      expect(find.byKey(const Key('item-cola')), findsOneWidget);
      expect(find.byKey(const Key('item-huhn-bowl')), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const Key('cat-favorites')),
          matching: _text('1'),
        ),
        findsOneWidget,
      );
      // Die Anzahl der Kategorien steht in ihrer Taste.
      expect(
        find.descendant(
          of: find.byKey(const Key('cat-bowls')),
          matching: _text('4'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('der offene Bon ist nach einem Neustart wieder da', (t) async {
    await pumpKassaWith(t, ['cola']);
    await t.pump();
    expect(await draftOf(t), isNotNull);
    await pumpKassa(t, sameDatabase: true);
    await t.pump();
    expect(_total(t), '3,15 €');
    expect(cartOf(t).lines.single.item.id, 'cola');
  });

  testWidgets(
    'Rabatte stehen im Entwurf und sind nach einem Neustart wieder da',
    (t) async {
      await pumpKassaWith(t, ['cola']);
      final cart = containerOf(t).read(cartProvider.notifier);
      final id = cartOf(t).lines.single.lineId;
      cart.setLineDiscount(
        id,
        const Discount.percent(10, DiscountReason.regular),
      );
      cart.setReceiptDiscount(const Discount.amount(100, DiscountReason.staff));
      await t.pump();
      expect(await draftOf(t), contains('"discount"'));
      await pumpKassa(t, sameDatabase: true);
      await t.pump();
      expect(cartOf(t).lines.single.discount?.toJson(), {
        'percent': 10,
        'reason': 'regular',
      });
      expect(cartOf(t).discount?.toJson(), {
        'amountCents': 100,
        'reason': 'staff',
      });
      expect(cartOf(t).totalCents, 290 - 29 - 100 + 25);
    },
  );

  testWidgets('Abmelden und Anmelden lässt den Bon stehen', (t) async {
    await pumpKassaWith(t, ['cola', 'pommes']);
    await t.tap(find.byKey(const Key('staff')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('cart-total')), findsNothing);
    expect(containerOf(t).read(sessionProvider), isNull);
    await typePin(t, '4711');
    await t.pumpAndSettle();
    expect(_total(t), '7,05 €');
  });

  for (final (name, draft) in [
    ('kaputtes JSON', '{kaputt'),
    ('Liste statt Objekt', '[1, 2]'),
    (
      'falsche Typen',
      '{"lines": [{"lineId": 1, "itemId": "cola", "quantity": "x"}]}',
    ),
    ('lines ist keine Liste', '{"lines": 5}'),
    (
      'Menge 0',
      '{"lines": [{"lineId": "a", "itemId": "cola", "quantity": 0, "optionIds": []}]}',
    ),
  ]) {
    testWidgets(
      'unlesbarer Entwurf ($name): leerer Bon, kein Fehler, Entwurf gelöscht',
      (t) async {
        final overrides = await memoryOverrides();
        final c = ProviderContainer(overrides: overrides);
        await c.read(settingsRepositoryProvider).writeDraft(draft);
        c.dispose();
        await pumpKassa(t, overrides: overrides);
        await t.pump();
        await t.pump();
        expect(t.takeException(), isNull);
        expect(_total(t), '0,00 €');
        expect(_text('Noch nichts boniert'), findsOneWidget);
        expect(await draftOf(t), isNull);
        // Und die Kassa nimmt weiter Artikel an.
        await tapItem(t, 'pommes');
        expect(_total(t), '3,90 €');
      },
    );
  }

  testWidgets(
    'der Schalter "Mit Bildern" wechselt die Tasten und bleibt nach dem Neustart',
    (t) async {
      await pumpKassa(t);
      // Vorgabe: kompakt, 90 dp hohe Tasten, kein Platzhalter-Bild.
      expect(t.getSize(find.byKey(const Key('item-huhn-bowl'))).height, 90);
      expect(find.byIcon(LucideIcons.utensils), findsNothing);
      await t.tap(find.byKey(const Key('segment-Mit Bildern')));
      await t.pump();
      expect(t.getSize(find.byKey(const Key('item-huhn-bowl'))).height, 157);
      expect(find.byIcon(LucideIcons.utensils), findsWidgets);
      await t.pump();
      await t.pump();
      expect(
        (await containerOf(
          t,
        ).read(settingsRepositoryProvider).current()).showImages,
        isTrue,
      );

      await pumpKassa(t, sameDatabase: true);
      expect(t.getSize(find.byKey(const Key('item-huhn-bowl'))).height, 157);
      await t.tap(find.byKey(const Key('segment-Kompakt')));
      await t.pump();
      expect(t.getSize(find.byKey(const Key('item-huhn-bowl'))).height, 90);
    },
  );

  testWidgets('kaputte Bilddatei: Taste ohne Bild, kein Fehler', (t) async {
    await pumpKassa(t);
    await t.tap(find.byKey(const Key('segment-Mit Bildern')));
    await t.pump();
    // Eine Datei, die kein Bild ist, und ein Pfad, hinter dem nichts liegt.
    await putPhoto(t, 'huhn-bowl', bytes: Uint8List.fromList([1, 2, 3, 4]));
    final db = containerOf(t).read(databaseProvider);
    await (db.update(db.itemRows)..where((r) => r.id.equals('cola'))).write(
      const ItemRowsCompanion(photoPath: Value('/gibt/es/nicht.webp')),
    );
    final bowl = find.byKey(const Key('item-huhn-bowl'));
    await settleImages(
      t,
      until: () => find
          .descendant(of: bowl, matching: find.byIcon(LucideIcons.utensils))
          .evaluate()
          .isNotEmpty,
    );

    expect(t.takeException(), isNull);
    // Beide Tasten stehen mit Platzhalter da, Name und Preis sind lesbar.
    expect(find.byKey(const Key('item-huhn-bowl')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('item-huhn-bowl')),
        matching: find.byIcon(LucideIcons.utensils),
      ),
      findsOneWidget,
    );
    expect(find.text('Huhn Bowl'), findsWidgets);
    // Die Kassa bleibt benutzbar.
    await tapItem(t, 'cola');
    expect(t.takeException(), isNull);
    expect(find.byKey(const Key('cart-total')), findsOneWidget);
  });

  testWidgets('ganzes Foto: die Taste zeigt es, ohne den Platzhalter', (
    t,
  ) async {
    await pumpKassa(t);
    await t.tap(find.byKey(const Key('segment-Mit Bildern')));
    await t.pump();
    await putPhoto(t, 'huhn-bowl');
    final raw = find.descendant(
      of: find.byKey(const Key('item-huhn-bowl')),
      matching: find.byType(RawImage),
    );
    // Gezeichnet ist es, sobald das Bild entschlüsselt ist.
    await settleImages(
      t,
      until: () =>
          raw.evaluate().isNotEmpty && t.widget<RawImage>(raw).image != null,
    );
    expect(t.widget<RawImage>(raw).image, isNotNull);

    expect(t.takeException(), isNull);
    expect(raw, findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('item-huhn-bowl')),
        matching: find.byIcon(LucideIcons.utensils),
      ),
      findsNothing,
    );
  });

  testWidgets('Spalten: 4 bei 1280 x 800, weniger bei 960 x 600', (t) async {
    await pumpKassa(t);
    expect(_columns(t), 4);
    // Mit 692 dp Mitte und 16 dp Rand wird die Taste etwa 157 breit.
    expect(
      t.getSize(find.byKey(const Key('item-huhn-bowl'))).width,
      closeTo(157.5, 0.1),
    );
    expect(t.getSize(find.byKey(const Key('cat-bowls'))).width, 184);
    await pumpKassa(t, size: const Size(960, 600));
    expect(_columns(t), lessThan(4));
    expect(_columns(t), greaterThanOrEqualTo(1));
    expect(t.takeException(), isNull);
    await pumpKassa(t, size: const Size(1600, 900));
    expect(_columns(t), greaterThan(4));
  });

  testWidgets('lange Namen und 99 Stück laufen nicht über', (t) async {
    await pumpKassa(t, size: const Size(960, 600), textScale: 1.3);
    final long = 'Ein sehr langer Artikelname für den Test ${'x' * 20} Ende';
    expect(long.length, greaterThanOrEqualTo(60));
    final changed = Catalog(
      business: catalog.business,
      categories: catalog.categories,
      templates: catalog.templates,
      items: [
        for (final i in catalog.items)
          i.id == 'pommes' || i.id == 'huhn-bowl' ? i.copyWith(name: long) : i,
      ],
    );
    await containerOf(t).read(catalogRepositoryProvider).importCatalog(changed);
    await t.pump();
    await t.pump();
    await t.tap(find.byKey(const Key('cat-snacks')));
    await t.pump();
    await t.tap(find.byKey(const Key('item-pommes')));
    await t.pump();
    final id = cartOf(t).lines.single.lineId;
    containerOf(t).read(cartProvider.notifier).setQuantity(id, 99);
    await t.pump();
    expect(textOf(t, Key('qty-$id')), '99');
    expect(t.takeException(), isNull);
    // Dasselbe mit Bildern, im Zusammenstellen und mit Pfand-Zeile.
    await t.tap(find.byKey(const Key('segment-Mit Bildern')));
    await t.pump();
    expect(t.takeException(), isNull);
    await t.tap(find.byKey(const Key('cat-getraenke')));
    await t.pump();
    await t.tap(find.byKey(const Key('item-cola')));
    await t.pump();
    expect(t.takeException(), isNull);
    await t.tap(find.byKey(const Key('cat-bowls')));
    await t.pump();
    await _openBowl(t);
    expect(t.takeException(), isNull);
  });

  Future<void> expectTapTargets(WidgetTester t) async {
    final small = <String>[];
    for (final e in find.byType(Pressable).evaluate()) {
      final box = e.renderObject! as RenderBox;
      final size = box.size;
      final shorter = size.width < size.height ? size.width : size.height;
      if (shorter < 47.99) small.add('${e.widget.key ?? e.widget} $size');
    }
    expect(small, isEmpty);
  }

  testWidgets(
    'jede Tippfläche ist mindestens 48 dp (Raster, Bon, Zusammenstellen)',
    (t) async {
      await pumpKassaWith(t, ['cola', 'teigtaschen']);
      expect(find.byType(Pressable), findsWidgets);
      await expectTapTargets(t);
      await t.tap(find.byKey(const Key('segment-Mit Bildern')));
      await t.pump();
      await expectTapTargets(t);
      await t.tap(find.byKey(const Key('clear-cart')));
      await t.pump();
      await expectTapTargets(t);
      await t.tap(find.byKey(const Key('cat-bowls')));
      await t.pump();
      await _openBowl(t);
      await expectTapTargets(t);
      await t.tap(find.byKey(const Key('opt-bowl/1/0')));
      await t.pump();
      await expectTapTargets(t);
      await t.tap(find.byKey(const Key('cancel-build')));
      await t.pump(const Duration(seconds: 8));
    },
  );

  testWidgets('kleiner Bildschirm mit großer Schrift: kein Überlauf', (
    t,
  ) async {
    await pumpKassaWith(
      t,
      ['cola', 'pommes'],
      size: const Size(960, 600),
      textScale: 1.3,
    );
    await t.tap(find.byKey(const Key('cat-bowls')));
    await t.pump();
    await _addBowl(t);
    expect(t.takeException(), isNull);
    expect(_text('XXL, Reis'), findsOneWidget);
  });

  group('Anmelden im Voraus', () {
    testWidgets('Start der Kassa mit Online-Probe: eine Anmeldung', (t) async {
      final fake = FakeAtrust();
      await pumpKassa(
        t,
        overrides: [
          ...await memoryOverrides(),
          ..._online(fake, MemoryRksvSecrets()),
        ],
      );
      expect(fake.requests, isEmpty);
      await seedProbe(t, unit: RksvUnit.atrustTest);
      // Wechselt der Stand bei offener Kassa, meldet sie sich nicht an.
      expect(fake.requests, isEmpty);

      await pumpKassa(t, sameDatabase: true);
      expect(fake.requests, [_login]);
      expect(t.takeException(), isNull);
    });

    testWidgets('zurück nach vorn mit Online-Probe: eine Anmeldung, danach '
        'keine, solange die Sitzung gilt', (t) async {
      final fake = FakeAtrust();
      await pumpKassa(
        t,
        overrides: [
          ...await memoryOverrides(),
          ..._online(fake, MemoryRksvSecrets()),
        ],
      );
      await seedProbe(t, unit: RksvUnit.atrustTest);
      expect(fake.requests, isEmpty);

      await _resume(t);
      expect(fake.requests, [_login]);
      await _resume(t);
      expect(fake.requests, [_login]);
    });

    testWidgets('ohne Online-Probe: keine Anfrage, keine Verbindung', (
      t,
    ) async {
      final fake = FakeAtrust();
      var reads = 0;
      await pumpKassa(
        t,
        overrides: [
          ...await memoryOverrides(),
          ..._online(fake, MemoryRksvSecrets(), () => reads++),
        ],
      );
      await _resume(t);
      await seedProbe(t);
      await _resume(t);
      await pumpKassa(t, sameDatabase: true);
      await _resume(t);
      expect(fake.requests, isEmpty);
      expect(reads, 0);
    });

    testWidgets('beendete Online-Probe: keine Anfrage, keine Verbindung', (
      t,
    ) async {
      final fake = FakeAtrust();
      var reads = 0;
      await pumpKassa(
        t,
        overrides: [
          ...await memoryOverrides(),
          ..._online(fake, MemoryRksvSecrets(), () => reads++),
        ],
      );
      await seedProbe(t, unit: RksvUnit.atrustTest, ended: true);
      await pumpKassa(t, sameDatabase: true);
      await _resume(t);
      expect(fake.requests, isEmpty);
      expect(reads, 0);
    });

    testWidgets('abgelehnt: weder beim Start noch beim Zurückkommen eine '
        'Anfrage', (t) async {
      final fake = FakeAtrust();
      final secrets = MemoryRksvSecrets();
      await secrets.writeAtrustRejected(true);
      await pumpKassa(
        t,
        overrides: [...await memoryOverrides(), ..._online(fake, secrets)],
      );
      await seedProbe(t, unit: RksvUnit.atrustTest);
      await pumpKassa(t, sameDatabase: true);
      await _resume(t);
      expect(fake.requests, isEmpty);
    });

    testWidgets('lehnt A-Trust beim Zurückkommen ab: der Hinweis sagt es '
        'sofort, danach keine Anfrage mehr', (t) async {
      final fake = FakeAtrust()..loginStatus = 403;
      final secrets = MemoryRksvSecrets();
      await pumpKassa(
        t,
        overrides: [...await memoryOverrides(), ..._online(fake, secrets)],
      );
      await seedProbe(
        t,
        unit: RksvUnit.atrustTest,
        outageSince: DateTime(2026, 11, 17, 13, 5),
        outageReason: 'Kein Internet.',
      );
      expect(find.byKey(const Key('rksv-retry')), findsOneWidget);

      await _resume(t);
      expect(fake.requests, [_login]);
      expect(
        find.text(
          'A-Trust hat die Zugangsdaten abgelehnt. Bitte den Chef holen.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('rksv-retry')), findsNothing);
      expect(await secrets.atrustRejected(), isTrue);

      await _resume(t);
      await pumpKassa(t, sameDatabase: true);
      expect(fake.requests, [_login]);
    });

    testWidgets('Start und Zurückkommen in Betrieb: eine Anmeldung am echten '
        'System, keine am Testsystem; den AES-Schlüssel liest die Kassa '
        'einmal (Q17)', (t) async {
      final fake = FakeAtrust();
      final secrets = _CountingSecrets();
      await secrets.writeAtrustCredentials(exampleLiveCredentials);
      await secrets.writeAesKey(1, Uint8List(32));
      await pumpKassa(
        t,
        overrides: [...await memoryOverrides(), ..._online(fake, secrets)],
      );
      expect(fake.requests, isEmpty);
      await seedLive(t);
      // Wechselt der Stand bei offener Kassa, meldet sie sich nicht an.
      expect(fake.requests, isEmpty);
      expect(secrets.aesReads, 0);

      await pumpKassa(t, sameDatabase: true);
      expect(fake.requests, [_liveLogin]);
      expect(secrets.aesReads, 1);
      await _resume(t);
      expect(fake.requests, [_liveLogin]);
      // Der Schlüssel liegt im Speicher, er wird nicht noch einmal gelesen.
      expect(secrets.aesReads, 1);
      expect(t.takeException(), isNull);
    });

    testWidgets('in Betrieb und abgelehnt: weder beim Start noch beim '
        'Zurückkommen eine Anfrage', (t) async {
      final fake = FakeAtrust();
      final secrets = MemoryRksvSecrets();
      await secrets.writeAtrustCredentials(exampleLiveCredentials);
      await secrets.writeAtrustRejected(true, live: true);
      await pumpKassa(
        t,
        overrides: [...await memoryOverrides(), ..._online(fake, secrets)],
      );
      await seedLive(t);
      await pumpKassa(t, sameDatabase: true);
      await _resume(t);
      expect(fake.requests, isEmpty);
    });

    testWidgets('außer Betrieb: keine Anfrage, kein Schlüssel gelesen', (
      t,
    ) async {
      final fake = FakeAtrust();
      final secrets = _CountingSecrets();
      await secrets.writeAtrustCredentials(exampleLiveCredentials);
      await pumpKassa(
        t,
        overrides: [...await memoryOverrides(), ..._online(fake, secrets)],
      );
      await seedLive(t, decommissioned: true);
      await pumpKassa(t, sameDatabase: true);
      await _resume(t);
      expect(fake.requests, isEmpty);
      expect(secrets.aesReads, 0);
    });

    testWidgets('hängt der geschützte Speicher in Betrieb, steht die Kassa '
        'trotzdem da', (t) async {
      final fake = FakeAtrust();
      final secrets = MemoryRksvSecrets();
      await pumpKassa(
        t,
        overrides: [...await memoryOverrides(), ..._online(fake, secrets)],
      );
      await seedLive(t);
      secrets.hangReads = true;
      await pumpKassa(t, sameDatabase: true);
      await _resume(t);
      expect(find.byKey(const Key('area-kassa')), findsOneWidget);
      expect(
        find.byKey(Key('cat-${catalog.item('cola').categoryId}')),
        findsOneWidget,
      );
      expect(t.takeException(), isNull);
      expect(fake.requests, isEmpty);
    });

    testWidgets('geschützter Speicher nicht lesbar: kein Fehler, kein Satz, '
        'keine Anfrage', (t) async {
      final fake = FakeAtrust();
      final secrets = MemoryRksvSecrets();
      await pumpKassa(
        t,
        overrides: [...await memoryOverrides(), ..._online(fake, secrets)],
      );
      await seedProbe(t, unit: RksvUnit.atrustTest);
      secrets.failReads = true;
      await pumpKassa(t, sameDatabase: true);
      await _resume(t);
      expect(t.takeException(), isNull);
      expect(fake.requests, isEmpty);
      expect(find.textContaining('Speicher'), findsNothing);
      expect(find.byKey(const Key('rksv-outage')), findsNothing);
    });
  });

  kuechenbonNachDemVerkaufTests();
}

/// "Verkauf fertig" mit dem Küchenbon: Hinweis nur, wenn er gescheitert ist.
void kuechenbonNachDemVerkaufTests() {
  Future<FakeKitchenService> sellWithKitchen(
    WidgetTester t,
    PrintOutcome? outcome, {
    Completer<void>? hold,
  }) async {
    final kitchen = FakeKitchenService()
      ..next = outcome
      ..hold = hold;
    await pumpKassa(
      t,
      overrides: [
        ...await memoryOverrides(),
        kitchenServiceProvider.overrideWithValue(kitchen),
      ],
    );
    final repo = containerOf(t).read(settingsRepositoryProvider);
    await repo.save(
      (await repo.current()).copyWith(kitchenMode: KitchenMode.kitchenPrinter),
    );
    await t.pumpAndSettle();
    await tapItem(t, 'cola');
    await t.tap(find.byKey(const Key('pay-cash')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('finish-sale')));
    await t.pumpAndSettle();
    return kitchen;
  }

  testWidgets('Küchenbon gescheitert: Zeile, Meldung und Taste; nachdrucken '
      'klappt', (t) async {
    final kitchen = await sellWithKitchen(
      t,
      const PrintOutcome.failed(PrintProblem.paperOut),
    );
    expect(kitchen.calls, ['for:1']);
    expect(_text('Küchenbon nicht gedruckt'), findsOneWidget);
    expect(_text('Drucker nicht bereit. Das Papier ist leer.'), findsOneWidget);
    expect(find.byKey(const Key('kitchen-reprint')), findsOneWidget);
    expect(
      t.getSize(find.byKey(const Key('kitchen-reprint'))).height,
      greaterThanOrEqualTo(48),
    );

    kitchen.next = const PrintOutcome.ok();
    final hold = kitchen.hold = Completer<void>();
    await t.tap(find.byKey(const Key('kitchen-reprint')));
    await t.pump();
    expect(_text('Küchenbon wird gedruckt …'), findsOneWidget);
    // Ein zweiter Tipp druckt nicht noch einmal.
    await t.tap(find.byKey(const Key('kitchen-reprint')), warnIfMissed: false);
    await t.pump();
    expect(kitchen.calls, ['for:1', 'for:1']);
    kitchen.hold = null;
    hold.complete();
    await t.pumpAndSettle();
    expect(_text('Küchenbon gedruckt.'), findsOneWidget);
    expect(_text('Küchenbon nicht gedruckt'), findsNothing);
    expect(find.byKey(const Key('kitchen-reprint')), findsNothing);
  });

  testWidgets('nachdrucken scheitert wieder: Meldung des Druckers bleibt', (
    t,
  ) async {
    final kitchen = await sellWithKitchen(
      t,
      const PrintOutcome.failed(PrintProblem.paperOut),
    );
    kitchen.next = const PrintOutcome.failed(PrintProblem.coverOpen);
    await t.tap(find.byKey(const Key('kitchen-reprint')));
    await t.pumpAndSettle();
    expect(_text('Küchenbon nicht gedruckt'), findsOneWidget);
    expect(
      _text('Drucker nicht bereit. Der Deckel ist offen.'),
      findsOneWidget,
    );
  });

  testWidgets('kein Küchenbon fällig (null): kein Hinweis', (t) async {
    final kitchen = await sellWithKitchen(t, null);
    expect(kitchen.calls, ['for:1']);
    expect(_text('Küchenbon nicht gedruckt'), findsNothing);
    expect(find.byKey(const Key('kitchen-reprint')), findsNothing);
    expect(_text('Küchenbon gedruckt.'), findsNothing);
  });

  testWidgets('Küchenbon gedruckt: kein Hinweis', (t) async {
    await sellWithKitchen(t, const PrintOutcome.ok());
    expect(_text('Küchenbon nicht gedruckt'), findsNothing);
    expect(find.byKey(const Key('kitchen-reprint')), findsNothing);
  });

  testWidgets('kein Küchendrucker eingerichtet: der Hinweis sagt es, mit '
      'der Taste zum Nachdrucken', (t) async {
    await sellWithKitchen(t, const PrintOutcome.failed(PrintProblem.notSetUp));
    expect(_text('Küchenbon nicht gedruckt'), findsOneWidget);
    expect(
      _text('Kein Küchendrucker eingerichtet. Es kommt kein Küchenbon.'),
      findsOneWidget,
    );
    expect(_text('Kein Bondrucker eingerichtet.'), findsNothing);
    expect(find.byKey(const Key('kitchen-reprint')), findsOneWidget);
  });

  testWidgets('"Nächster Kunde" wartet nicht auf den Küchenbon', (t) async {
    final hold = Completer<void>();
    await sellWithKitchen(
      t,
      const PrintOutcome.failed(PrintProblem.paperOut),
      hold: hold,
    );
    expect(find.byKey(const Key('next-customer')), findsOneWidget);
    expect(_text('Küchenbon nicht gedruckt'), findsNothing);
    await t.tap(find.byKey(const Key('next-customer')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('next-customer')), findsNothing);
    hold.complete();
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });

  Finder late(String text) => find.descendant(
    of: find.byKey(const Key('late-kitchen')),
    matching: find.text(text),
  );

  testWidgets('scheitert der Küchenbon nach "Nächster Kunde", steht über dem '
      'Bon ein Hinweis mit Bon-Nummer und Grund; "Küchenbon drucken" druckt '
      'ihn, dann ist der Hinweis weg', (t) async {
    final hold = Completer<void>();
    final kitchen = await sellWithKitchen(
      t,
      const PrintOutcome.failed(PrintProblem.paperOut),
      hold: hold,
    );
    await t.tap(find.byKey(const Key('next-customer')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('late-kitchen')), findsNothing);
    kitchen.hold = null;
    hold.complete();
    await t.pumpAndSettle();
    expect(late('Küchenbon nicht gedruckt'), findsOneWidget);
    expect(late('Bon Nr. 1'), findsOneWidget);
    expect(late('Drucker nicht bereit. Das Papier ist leer.'), findsOneWidget);
    expect(
      t.getSize(find.byKey(const Key('late-kitchen-reprint'))).height,
      greaterThanOrEqualTo(64),
    );
    // Er bleibt stehen, auch während der nächste Bon entsteht.
    await tapItem(t, 'cola');
    await t.pump(const Duration(seconds: 30));
    expect(find.byKey(const Key('late-kitchen')), findsOneWidget);

    kitchen.next = const PrintOutcome.ok();
    await t.tap(find.byKey(const Key('late-kitchen-reprint')));
    await t.pumpAndSettle();
    expect(kitchen.calls, ['for:1', 'for:1']);
    expect(find.byKey(const Key('late-kitchen')), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('nachdrucken aus dem Hinweis scheitert wieder: der Hinweis '
      'bleibt mit dem neuen Grund', (t) async {
    final hold = Completer<void>();
    final kitchen = await sellWithKitchen(
      t,
      const PrintOutcome.failed(PrintProblem.paperOut),
      hold: hold,
    );
    await t.tap(find.byKey(const Key('next-customer')));
    await t.pumpAndSettle();
    kitchen.hold = null;
    hold.complete();
    await t.pumpAndSettle();
    kitchen.next = const PrintOutcome.failed(PrintProblem.coverOpen);
    await t.tap(find.byKey(const Key('late-kitchen-reprint')));
    await t.pumpAndSettle();
    expect(late('Drucker nicht bereit. Der Deckel ist offen.'), findsOneWidget);
    expect(late('Bon Nr. 1'), findsOneWidget);
  });

  testWidgets('zwei späte Fehler: der neueste steht da, mit der Zahl der '
      'übrigen; Ausblenden zeigt den älteren', (t) async {
    final hold = Completer<void>();
    final kitchen = await sellWithKitchen(
      t,
      const PrintOutcome.failed(PrintProblem.paperOut),
      hold: hold,
    );
    await t.tap(find.byKey(const Key('next-customer')));
    await t.pumpAndSettle();
    // Der zweite Verkauf, während der erste Küchenbon noch hängt.
    await tapItem(t, 'cola');
    await t.tap(find.byKey(const Key('pay-cash')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('finish-sale')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('next-customer')));
    await t.pumpAndSettle();
    kitchen.hold = null;
    hold.complete();
    await t.pumpAndSettle();
    expect(late('Bon Nr. 2'), findsOneWidget);
    expect(late('Weitere Küchenbons nicht gedruckt: 1'), findsOneWidget);

    await t.tap(find.byKey(const Key('late-kitchen-dismiss')));
    await t.pumpAndSettle();
    expect(late('Bon Nr. 1'), findsOneWidget);
    expect(late('Weitere Küchenbons nicht gedruckt: 1'), findsNothing);
    await t.tap(find.byKey(const Key('late-kitchen-dismiss')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('late-kitchen')), findsNothing);
    expect(kitchen.calls, ['for:1', 'for:2']);
  });

  testWidgets('schon auf "Verkauf fertig" gescheitert und trotzdem weiter: '
      'der Hinweis kommt mit', (t) async {
    await sellWithKitchen(t, const PrintOutcome.failed(PrintProblem.paperOut));
    expect(_text('Küchenbon nicht gedruckt'), findsOneWidget);
    await t.tap(find.byKey(const Key('next-customer')));
    await t.pumpAndSettle();
    expect(late('Bon Nr. 1'), findsOneWidget);
  });

  testWidgets('inzwischen storniert: "Küchenbon drucken" druckt nichts, der '
      'Hinweis geht weg', (t) async {
    final hold = Completer<void>();
    final kitchen = await sellWithKitchen(
      t,
      const PrintOutcome.failed(PrintProblem.paperOut),
      hold: hold,
    );
    await t.tap(find.byKey(const Key('next-customer')));
    await t.pumpAndSettle();
    kitchen.hold = null;
    hold.complete();
    await t.pumpAndSettle();
    expect(late('Bon Nr. 1'), findsOneWidget);
    // Der Gast sagt ab: Bon 1 wird storniert (anderswo als im Bon-Detail).
    final c = containerOf(t);
    final staff = c.read(sessionProvider)!;
    final rows = await queryRows(t, 'SELECT id FROM receipts WHERE number = 1');
    await c
        .read(receiptRepositoryProvider)
        .voidReceipt(rows.single['id']! as String, staff: staff);
    await t.pumpAndSettle();
    kitchen.next = const PrintOutcome.ok();
    await t.tap(find.byKey(const Key('late-kitchen-reprint')));
    await t.pumpAndSettle();
    expect(kitchen.calls, ['for:1']);
    expect(find.byKey(const Key('late-kitchen')), findsNothing);
  });

  testWidgets('Küchenbon gedruckt, dann weiter: kein Hinweis', (t) async {
    await sellWithKitchen(t, const PrintOutcome.ok());
    await t.tap(find.byKey(const Key('next-customer')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('late-kitchen')), findsNothing);
  });
}

/// Was der offene Bon nach einer Preisänderung zeigt.
typedef _Bon = ({
  String total,
  int unitPrice,
  int lines,
  int quantity,
  bool sameLine,
  bool draftKeepsItems,
});

/// Legt eine Cola auf den Bon, ändert ihren Preis auf 4,00 € mit [change]
/// und liest, was der Bon danach zeigt.
Future<_Bon> _billAfterPriceChange(
  WidgetTester t,
  Future<void> Function(ProviderContainer c) change,
) async {
  await pumpKassaWith(t, ['cola']);
  final c = containerOf(t);
  final before = cartOf(t).lines.single;
  await change(c);
  await t.pumpAndSettle();
  final after = cartOf(t);
  final draft = await draftOf(t);
  return (
    total: _total(t),
    unitPrice: after.lines.single.item.priceCents,
    lines: after.lines.length,
    quantity: after.lines.single.quantity,
    sameLine: after.lines.single.lineId == before.lineId,
    draftKeepsItems: draft!.contains('"itemId":"cola"'),
  );
}

void offenerBonTests() {
  // Festgehalten am Verhalten der App (Weg a, Preis unter "Artikel"): der
  // offene Bon behält Zeile und Menge und rechnet mit dem neuen Preis.
  const expected = (
    total: '4,25 €',
    unitPrice: 400,
    lines: 1,
    quantity: 1,
    sameLine: true,
    draftKeepsItems: true,
  );

  testWidgets('offener Bon: Preis am Tablet geändert folgt dem neuen Preis', (
    t,
  ) async {
    final bon = await _billAfterPriceChange(
      t,
      (c) =>
          c.read(catalogRepositoryProvider).updateItem('cola', priceCents: 400),
    );
    expect(bon, expected);
  });

  testWidgets('offener Bon: Preis vom Server wirkt genau so', (t) async {
    final bon = await _billAfterPriceChange(t, (c) async {
      final db = c.read(databaseProvider);
      final server = FakeServer.beispiel();
      final since = server.seq;
      await SyncStateRepository(db).saveRegister(
        registerId: FakeServer.registerId,
        registerName: 'Kassa 1',
        businessId: FakeServer.businessId,
      );
      await db
          .into(db.syncStateRows)
          .insertOnConflictUpdate(
            SyncStateRowsCompanion(
              id: const Value(1),
              pullCursor: Value(since),
              initialPullDone: const Value(true),
            ),
          );
      server.change('items', 'cola', {'priceCents': 400});
      final applied = await c
          .read(serverChangesProvider)
          .applyPage(
            server.page(since),
            at: DateTime(2026, 11, 17, 11),
            since: since,
            registerId: FakeServer.registerId,
          );
      expect(applied, isTrue);
      // Wie nach einer geholten Änderung im Abgleich (`onChanged`).
      c.invalidate(catalogProvider);
    });
    expect(bon, expected);
  });
}
