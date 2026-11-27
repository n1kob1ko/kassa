// Freier Betrag an der Kassa: Die Taste "Freier Betrag" im Kopf der
// Bon-Spalte öffnet ein Blatt (Betrag über das Zahlenfeld, Steuersatz); "Auf
// den Bon" legt eine eigene Zeile "Diverses 20 %" an.

import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/core/app_language.dart';
import 'package:kassa/core/money.dart';
import 'package:kassa/domain/discount.dart';
import 'package:kassa/domain/feature_access.dart';
import 'package:kassa/features/login/session.dart';
import 'package:kassa/ui/pressable.dart';
import 'package:kassa/ui/primary_button.dart';
import 'package:material_ui/material_ui.dart';

import '../support/cash_pump.dart';
import '../support/kassa_pump.dart';
import '../support/pump.dart';

PrimaryButton buttonOf(WidgetTester t, String key) =>
    t.widget<PrimaryButton>(find.byKey(Key(key)));

/// Ob die Taste einer Auswahl gewählt ist.
bool? _selectedOf(WidgetTester t, String key) => t
    .widget<Pressable>(
      find
          .descendant(
            of: find.byKey(Key(key)),
            matching: find.byType(Pressable),
            matchRoot: true,
          )
          .first,
    )
    .selected;

/// Kassa mit freiem Betrag für [access], angemeldet mit [pin].
Future<void> _open(
  WidgetTester t, {
  FeatureAccess access = FeatureAccess.all,
  String pin = '1234',
  Size size = const Size(1280, 800),
  double textScale = 1.0,
  AppLanguage language = AppLanguage.de,
  FeatureAccess discount = FeatureAccess.off,
}) async {
  await pumpKassa(t, pin: pin, size: size, textScale: textScale);
  await setSettings(
    t,
    (s) => s.copyWith(
      openAmountAccess: access,
      discountAccess: discount,
      language: language,
    ),
  );
}

Future<void> _tap(WidgetTester t, String key) async {
  await t.ensureVisible(find.byKey(Key(key)));
  await t.pumpAndSettle();
  await t.tap(find.byKey(Key(key)));
  await t.pumpAndSettle();
}

/// Öffnet das Blatt, tippt [keys], wählt den Satz [percent] und legt den
/// Betrag auf den Bon.
Future<void> _addOpen(WidgetTester t, String keys, int percent) async {
  await _tap(t, 'open-amount-button');
  await tapKeys(t, keys);
  await _tap(t, 'open-rate-$percent');
  await _tap(t, 'open-amount-add');
}

void main() {
  testWidgets('12,50 € zu 10 % auf den Bon, bar bezahlt: Zeile "Diverses '
      '10 %" am Bon', (t) async {
    await pumpKassa(t);
    await setSettings(
      t,
      (s) => s.copyWith(openAmountAccess: FeatureAccess.all),
    );
    await t.tap(find.byKey(const Key('open-amount-button')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('open-amount-sheet')), findsOneWidget);
    await tapKeys(t, '1 2 , 5 0');
    expect(textOf(t, const Key('given-field')), '12,50 €');
    // Der Satz fehlt noch.
    expect(buttonOf(t, 'open-amount-add').onPressed, isNull);
    await t.tap(find.byKey(const Key('open-rate-10')));
    await t.pump();
    await t.tap(find.byKey(const Key('open-amount-add')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('open-amount-sheet')), findsNothing);
    expect(find.text('Diverses 10 %'), findsOneWidget);
    expect(textOf(t, const Key('cart-total')), '12,50 €');
    await t.tap(find.byKey(const Key('pay-cash')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('finish-sale')));
    await t.pumpAndSettle();
    expect(
      await queryRows(
        t,
        'SELECT item_id, name, unit_price_cents, gross10_cents '
        'FROM receipt_lines',
      ),
      [
        {
          'item_id': 'open-amount-10',
          'name': 'Diverses 10 %',
          'unit_price_cents': 1250,
          'gross10_cents': 1250,
        },
      ],
    );
  });

  testWidgets('die Taste steht auch am leeren Bon; kein Satz ist vorgewählt; '
      'ohne Betrag bleibt "Auf den Bon" aus', (t) async {
    await _open(t);
    expect(cartOf(t).isEmpty, isTrue);
    expect(find.byKey(const Key('open-amount-button')), findsOneWidget);
    await _tap(t, 'open-amount-button');
    for (final p in [20, 10, 13, 0]) {
      expect(_selectedOf(t, 'open-rate-$p'), isFalse, reason: '$p');
    }
    expect(find.byKey(const Key('open-rate-19')), findsNothing);
    expect(buttonOf(t, 'open-amount-add').onPressed, isNull);
    await _tap(t, 'open-rate-20');
    expect(_selectedOf(t, 'open-rate-20'), isTrue);
    // Satz da, Betrag 0: aus.
    expect(buttonOf(t, 'open-amount-add').onPressed, isNull);
    await tapKeys(t, '0');
    expect(buttonOf(t, 'open-amount-add').onPressed, isNull);
    await tapKeys(t, ', 0 5');
    expect(buttonOf(t, 'open-amount-add').onPressed, isNotNull);
    // Ein Satz ersetzt den anderen.
    await _tap(t, 'open-rate-13');
    expect(_selectedOf(t, 'open-rate-20'), isFalse);
    expect(_selectedOf(t, 'open-rate-13'), isTrue);
    await _tap(t, 'open-amount-add');
    expect(cartOf(t).lines.single.item.id, 'open-amount-13');
    expect(textOf(t, const Key('cart-total')), '0,05 €');
  });

  testWidgets('höchstens 9.999,99 €: eine fünfte Stelle vor dem Komma nimmt '
      'das Zahlenfeld nicht an', (t) async {
    await _open(t);
    await _tap(t, 'open-amount-button');
    await tapKeys(t, '9 9 9 9 9 , 9 9 9');
    expect(textOf(t, const Key('given-field')), '9999,99 €');
    await _tap(t, 'open-rate-0');
    await _tap(t, 'open-amount-add');
    expect(cartOf(t).totalCents, 999999);
  });

  testWidgets('zwei Tipps auf "Auf den Bon" in einem Bild geben eine Zeile; '
      'derselbe Betrag noch einmal gibt eine zweite Zeile', (t) async {
    await _open(t);
    await _tap(t, 'open-amount-button');
    await tapKeys(t, '3');
    await _tap(t, 'open-rate-20');
    await t.tap(find.byKey(const Key('open-amount-add')));
    await t.tap(find.byKey(const Key('open-amount-add')), warnIfMissed: false);
    await t.pumpAndSettle();
    expect(cartOf(t).lines, hasLength(1));
    await _addOpen(t, '3', 20);
    expect(cartOf(t).lines.map((l) => (l.item.id, l.quantity, l.goodsCents)), [
      ('open-amount-20', 1, 300),
      ('open-amount-20', 1, 300),
    ]);
    expect(find.text('Diverses 20 %'), findsNWidgets(2));
    expect(textOf(t, const Key('cart-total')), '6,00 €');
  });

  testWidgets('zurück: nichts kommt auf den Bon', (t) async {
    await _open(t);
    await tapItem(t, 'cola');
    await _tap(t, 'open-amount-button');
    await tapKeys(t, '5');
    await _tap(t, 'open-rate-10');
    await _tap(t, 'open-amount-back');
    expect(find.byKey(const Key('open-amount-sheet')), findsNothing);
    expect(cartOf(t).lines.map((l) => l.item.id), ['cola']);
  });

  testWidgets('solange das Blatt offen ist, nimmt die Artikelfläche keine '
      'Tipps', (t) async {
    await _open(t);
    await tapItem(t, 'cola');
    await _tap(t, 'open-amount-button');
    expect(
      t.widget<AnimatedOpacity>(find.byKey(const Key('item-area-dim'))).opacity,
      0.5,
    );
    await t.tap(find.byKey(const Key('item-cola')), warnIfMissed: false);
    await t.pumpAndSettle();
    expect(cartOf(t).lines.single.quantity, 1);
    expect(find.byKey(const Key('open-amount-sheet')), findsOneWidget);
  });

  testWidgets('Menge mit Plus und Minus; Rabatt wie bei jeder Zeile', (
    t,
  ) async {
    await _open(t, discount: FeatureAccess.all);
    await _addOpen(t, '1 0', 20);
    final id = cartOf(t).lines.single.lineId;
    await _tap(t, 'qty-plus-$id');
    expect(cartOf(t).lines.single.quantity, 2);
    expect(textOf(t, const Key('cart-total')), '20,00 €');
    await t.tap(
      find.descendant(
        of: find.byKey(Key('line-$id')),
        matching: find.text(formatEuro(2000)),
      ),
    );
    await t.pumpAndSettle();
    expect(find.byKey(const Key('discount-sheet')), findsOneWidget);
    expect(find.text('Rabatt auf: 2 × Diverses 20 %'), findsOneWidget);
    await _tap(t, 'discount-reason-regular');
    await _tap(t, 'discount-percent-10');
    await _tap(t, 'discount-apply');
    expect(
      cartOf(t).lines.single.discount,
      const Discount.percent(10, DiscountReason.regular),
    );
    expect(textOf(t, const Key('cart-total')), '18,00 €');
    await _tap(t, 'pay-cash');
    await _tap(t, 'finish-sale');
    expect(
      await queryRows(
        t,
        'SELECT item_id, quantity, discount_cents, gross20_cents '
        'FROM receipt_lines',
      ),
      [
        {
          'item_id': 'open-amount-20',
          'quantity': 2,
          'discount_cents': 200,
          'gross20_cents': 1800,
        },
      ],
    );
  });

  testWidgets('nur Chef: Anna hat die Taste nicht; die Zeile des Chefs bleibt '
      'und geht mit Minus weg', (t) async {
    await _open(t, access: FeatureAccess.chefOnly, pin: '4711');
    expect(find.byKey(const Key('open-amount-button')), findsOneWidget);
    await _addOpen(t, '4 , 2', 0);
    containerOf(t).read(sessionProvider.notifier).logout();
    await t.pumpAndSettle();
    await typePin(t, '1234');
    await t.pumpAndSettle();
    expect(find.byKey(const Key('open-amount-button')), findsNothing);
    final line = cartOf(t).lines.single;
    expect((line.item.id, line.goodsCents), ('open-amount-0', 420));
    expect(find.text('Diverses 0 %'), findsOneWidget);
    await _tap(t, 'qty-minus-${line.lineId}');
    expect(cartOf(t).isEmpty, isTrue);
    expect(find.text('Diverses 0 %'), findsNothing);
  });

  testWidgets('wird der Schalter ausgeschaltet, während das Blatt offen ist, '
      'steht wieder der Bon da; der Betrag am Bon bleibt', (t) async {
    await _open(t);
    await _addOpen(t, '2', 10);
    await _tap(t, 'open-amount-button');
    await setSettings(
      t,
      (s) => s.copyWith(openAmountAccess: FeatureAccess.off),
    );
    expect(find.byKey(const Key('open-amount-sheet')), findsNothing);
    expect(find.byKey(const Key('open-amount-button')), findsNothing);
    expect(textOf(t, const Key('cart-total')), '2,00 €');
  });

  testWidgets('Englisch: die Zeile heißt am Bildschirm in der Bediensprache, '
      'im gespeicherten Bon "Diverses 20 %"', (t) async {
    await _open(t, language: AppLanguage.en);
    expect(textOf(t, const Key('open-amount-button')), 'Open amount');
    await _tap(t, 'open-amount-button');
    expect(find.text('Amount'), findsOneWidget);
    expect(find.text('Tax rate'), findsOneWidget);
    await tapKeys(t, '7 , 5');
    await _tap(t, 'open-rate-20');
    expect(textOf(t, const Key('open-amount-add')), 'Add to receipt');
    await _tap(t, 'open-amount-add');
    expect(find.text('Misc. 20 %'), findsOneWidget);
    expect(find.text('Diverses 20 %'), findsNothing);
    await _tap(t, 'pay-cash');
    await _tap(t, 'finish-sale');
    expect(await queryRows(t, 'SELECT item_id, name FROM receipt_lines'), [
      {'item_id': 'open-amount-20', 'name': 'Diverses 20 %'},
    ]);
  });

  testWidgets('der offene Bon mit freiem Betrag übersteht einen Neustart', (
    t,
  ) async {
    await _open(t);
    await tapItem(t, 'cola');
    await _addOpen(t, '1 2 , 5', 13);
    await t.pumpAndSettle();
    await pumpKassa(t, sameDatabase: true);
    expect(cartOf(t).lines.map((l) => (l.item.id, l.goodsCents)), [
      ('cola', 290),
      ('open-amount-13', 1250),
    ]);
    expect(find.text('Diverses 13 %'), findsOneWidget);
  });

  testWidgets('jede Tippfläche ist mindestens 48 dp: Kopf mit Taste, Blatt, '
      'Bon mit freiem Betrag', (t) async {
    Future<void> expectTapTargets(String where) async {
      final small = <String>[];
      for (final e in find.byType(Pressable).evaluate()) {
        final box = e.renderObject! as RenderBox;
        final size = box.size;
        final shorter = size.width < size.height ? size.width : size.height;
        if (shorter < 47.99) small.add('${e.widget.key ?? e.widget} $size');
      }
      expect(small, isEmpty, reason: where);
    }

    await _open(t);
    await expectTapTargets('leerer Bon');
    final button = t.getSize(find.byKey(const Key('open-amount-button')));
    expect(button.height, greaterThanOrEqualTo(48));
    expect(button.width, greaterThanOrEqualTo(48));
    await _tap(t, 'open-amount-button');
    await expectTapTargets('Blatt');
    for (final p in [20, 10, 13, 0]) {
      expect(
        t.getSize(find.byKey(Key('open-rate-$p'))).height,
        greaterThanOrEqualTo(48),
      );
    }
    await tapKeys(t, '5');
    await _tap(t, 'open-rate-20');
    await _tap(t, 'open-amount-add');
    await expectTapTargets('Bon mit freiem Betrag');
    expect(t.takeException(), isNull);
  });

  testWidgets('auf 1024 × 600: mit Betrag und ohne Satz sagt eine Zeile '
      'unter "Auf den Bon", warum die Taste aus ist; mit Satz ist sie weg', (
    t,
  ) async {
    const screen = Size(1024, 600);
    await _open(t, size: screen);
    await _tap(t, 'open-amount-button');
    expect(find.byKey(const Key('open-amount-reason')), findsNothing);
    await tapKeys(t, '1 2 , 5 0');
    await t.pumpAndSettle();
    expect(buttonOf(t, 'open-amount-add').onPressed, isNull);
    expect(textOf(t, const Key('open-amount-reason')), 'Steuersatz wählen');
    final reason = t.getRect(find.byKey(const Key('open-amount-reason')));
    expect(
      (Offset.zero & screen).intersect(reason),
      reason,
      reason: 'ganz im Bild',
    );
    final button = t.getRect(find.byKey(const Key('open-amount-add')));
    expect(reason.top, greaterThanOrEqualTo(button.bottom));
    expect(
      find.byKey(const Key('open-amount-reason')).hitTestable(),
      findsOneWidget,
    );
    await _tap(t, 'open-rate-10');
    expect(find.byKey(const Key('open-amount-reason')), findsNothing);
    expect(buttonOf(t, 'open-amount-add').onPressed, isNotNull);
    expect(t.takeException(), isNull);
  });

  testWidgets('in jeder Sprache auf 960 × 600 mit Textskala 1,3: nichts läuft '
      'über, weder Kopf noch Blatt noch Zeile', (t) async {
    for (final language in AppLanguage.values) {
      await _open(
        t,
        size: const Size(960, 600),
        textScale: 1.3,
        language: language,
        discount: FeatureAccess.all,
      );
      expect(t.takeException(), isNull, reason: language.name);
      await tapItem(t, 'cola');
      await t.pumpAndSettle();
      expect(t.takeException(), isNull, reason: language.name);
      await _tap(t, 'open-amount-button');
      expect(t.takeException(), isNull, reason: language.name);
      await tapKeys(t, '9 9 9 9 , 9 9');
      await _tap(t, 'open-rate-13');
      expect(t.takeException(), isNull, reason: language.name);
      await _tap(t, 'open-amount-add');
      expect(cartOf(t).lines, hasLength(2), reason: language.name);
      expect(t.takeException(), isNull, reason: language.name);
    }
  });
}
