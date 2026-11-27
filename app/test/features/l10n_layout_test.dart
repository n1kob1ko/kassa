// Die Hauptbildschirme in allen fünf Sprachen, bei 1280×800 und 1024×600:
// nichts läuft über, kein Text wird abgeschnitten. Arabisch liest von rechts
// nach links, Ziffernfelder und Beträge bleiben links nach rechts.

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/app.dart';
import 'package:kassa/core/app_language.dart';
import 'package:kassa/core/clock.dart';
import 'package:kassa/data/providers.dart';
import 'package:kassa/data/settings_repository.dart';
import 'package:kassa/core/money.dart';
import 'package:kassa/domain/feature_access.dart';
import 'package:kassa/features/kassa/cart_controller.dart';
import 'package:kassa/features/kassa/cart_panel.dart';
import 'package:kassa/features/kassa/category_rail.dart';
import 'package:kassa/features/kassa/modifier_panel.dart';
import 'package:kassa/features/overview/revenue_chart.dart';
import 'package:kassa/l10n/generated/l10n.dart';
import 'package:kassa/ui/tokens.dart';
import 'package:material_ui/material_ui.dart';

import '../support/demo_fixtures.dart';
import '../support/kassa_pump.dart';
import '../support/pump.dart';

const _sizes = [Size(1280, 800), Size(1024, 600)];

/// Ein türkischer Name mit 45 Zeichen für jeden Namen der Speisekarte.
Map<String, Map<String, String>> _longTurkishNames() {
  String long(String s) =>
      '$s uzun Türkçe adı ile çok güzel bir ürün örneği burada'
          .padRight(45, 'ı')
          .substring(0, 45);
  final names = <String>{
    for (final k in catalog.categories) k.name,
    for (final i in catalog.items) ...[i.name, ?i.info],
    for (final tpl in catalog.templates)
      for (final g in tpl.groups) ...[
        g.name,
        for (final o in g.options) o.name,
      ],
  };
  return {
    for (final n in names) n: {'tr': long(n)},
  };
}

/// Prüft das Bild: keine Meldung "overflowed", jeder Text liegt in seinem
/// Elternrahmen und ist ganz zu sehen (nur Auslassungspunkte dürfen kürzen).
void _expectClean(WidgetTester t, String where) {
  final error = t.takeException();
  expect(error, isNull, reason: '$where: $error');
  for (final element in find.byType(RichText).evaluate()) {
    final box = element.renderObject;
    if (box is! RenderParagraph || !box.attached || !box.hasSize) continue;
    if (box.size.isEmpty) continue;
    final text = box.text.toPlainText();
    final rect = MatrixUtils.transformRect(
      box.getTransformTo(null),
      Offset.zero & box.size,
    );
    final parent = box.parent;
    // Ein Stapel ohne Zuschnitt lässt Beschriftungen mit Absicht über den
    // Rand ragen (die Achse der Übersicht: die Zahl mittig auf ihrer Linie).
    final overhangs = parent is RenderStack && parent.clipBehavior == Clip.none;
    if (parent is RenderBox && parent.hasSize && !overhangs) {
      final outer = MatrixUtils.transformRect(
        parent.getTransformTo(null),
        Offset.zero & parent.size,
      );
      expect(
        outer.inflate(0.5).contains(rect.topLeft) &&
            outer.inflate(0.5).contains(rect.bottomRight),
        isTrue,
        reason: '$where: "$text" ragt aus seinem Rahmen ($rect in $outer)',
      );
    }
    if (box.overflow == TextOverflow.ellipsis) continue;
    final needed = box.getMinIntrinsicHeight(box.size.width);
    expect(
      box.didExceedMaxLines || needed > box.size.height + 0.5,
      isFalse,
      reason: '$where: "$text" ist abgeschnitten',
    );
    if (box.maxLines == 1 || !box.softWrap) {
      expect(
        box.getMaxIntrinsicWidth(double.infinity),
        lessThanOrEqualTo(box.size.width + 0.5),
        reason: '$where: "$text" ist abgeschnitten',
      );
    }
  }
}

/// Jeder Text unter [scope] ist ganz zu lesen, ohne Auslassungspunkte.
void _expectWhole(WidgetTester t, Finder scope, String where) {
  final texts = find.descendant(of: scope, matching: find.byType(RichText));
  expect(texts, findsWidgets, reason: where);
  for (final e in texts.evaluate()) {
    final box = e.renderObject! as RenderParagraph;
    expect(
      box.didExceedMaxLines,
      isFalse,
      reason: '$where: "${box.text.toPlainText()}" ist gekürzt',
    );
  }
}

/// Nur Arabisch bekommt Zeichen, die Beträge und Namen als eigenen
/// Abschnitt setzen; in den anderen Sprachen bleibt jeder Text, wie er war.
void _expectNoIsolates(WidgetTester t, String where) {
  final isolates = RegExp('[\u2066-\u2069]');
  for (final e in find.byType(RichText).evaluate()) {
    final text = (e.widget as RichText).text.toPlainText();
    expect(
      isolates.hasMatch(text),
      isFalse,
      reason: '$where: "$text" hat Richtungszeichen',
    );
  }
}

Future<void> _setLanguage(WidgetTester t, AppLanguage language) async {
  final repo = containerOf(t).read(settingsRepositoryProvider);
  await repo.save((await repo.current()).copyWith(language: language));
  await t.pumpAndSettle();
}

Future<void> _tap(WidgetTester t, String key) async {
  await t.tap(find.byKey(Key(key)));
  await t.pumpAndSettle();
}

Rect _rect(WidgetTester t, Finder f) => t.getRect(f);

/// Geht durch alle Hauptbildschirme und prüft jedes Bild. [check] bekommt
/// den Namen des Bildes, für Prüfungen nur in einer Sprache.
Future<void> _tour(
  WidgetTester t,
  AppLanguage language,
  Size size, {
  Map<String, Map<String, String>>? names,
  void Function(String screen)? check,
}) async {
  await pumpApp(
    t,
    const KassaApp(),
    overrides: await memoryOverrides(
      clock: FixedClock(DateTime(2026, 11, 17, 11)),
    ),
    size: size,
  );
  await t.pumpAndSettle();
  if (names != null) {
    await containerOf(t).read(translationRepositoryProvider).upsert(names);
  }
  await _setLanguage(t, language);
  final at = '${language.name} ${size.width.toInt()}×${size.height.toInt()}';
  void look(String screen) {
    _expectClean(t, '$at $screen');
    if (!language.isRtl) _expectNoIsolates(t, '$at $screen');
    check?.call(screen);
  }

  look('Anmeldung');
  await typePin(t, '4711');
  await t.pumpAndSettle();

  // Kassa mit Bon (12,90 €) und offenem Auswahl-Feld.
  for (final id in ['fruehlingsrollen', 'mochi', 'bananenkuchen']) {
    await tapItem(t, id);
  }
  await tapItem(t, 'huhn-bowl');
  await t.pumpAndSettle();
  expect(find.byType(ModifierPanel), findsOneWidget);
  look('Kassa');
  await t.tap(find.byKey(Key('cat-${catalog.item('cola').categoryId}')));
  await t.pumpAndSettle();

  await _tap(t, 'pay-cash');
  look('Bar');
  await _tap(t, 'other-amount');
  await tapKeys(t, '2 0');
  await t.pumpAndSettle();
  look('Bar mit Zahlenfeld');
  await _tap(t, 'finish-sale');
  look('Verkauf fertig');
  await _tap(t, 'next-customer');

  await _tap(t, 'tab-Bons');
  await _tap(t, 'receipt-1');
  look('Bons');

  await _tap(t, 'tab-Artikel');
  look('Artikel');

  await _tap(t, 'tab-Übersicht');
  look('Übersicht');

  await _tap(t, 'tab-Abschluss');
  look('Abschluss Tag');
  await _tap(t, 'segment-${lookupL10n(language.locale).closeMonth}');
  look('Abschluss Monat');

  await _tap(t, 'settings');
  look('Einstellungen');

  // Karte Zahlen: zwei Schalter und zwei Regler mit drei Segmenten.
  await t.ensureVisible(find.byKey(const Key('payment-card')));
  await t.pumpAndSettle();
  look('Einstellungen Zahlen');

  // Abschnitt Küche: am Küchendrucker, erst ohne (Hinweis), dann mit
  // eingerichtetem Drucker, Vorschau gezeichnet.
  final repo = containerOf(t).read(settingsRepositoryProvider);
  await repo.save(
    (await repo.current()).copyWith(kitchenMode: KitchenMode.kitchenPrinter),
  );
  await t.pumpAndSettle();
  await t.ensureVisible(find.byKey(const Key('kitchen-no-printer')));
  await t.pumpAndSettle();
  look('Einstellungen Küche ohne Küchendrucker');
  await repo.save(
    (await repo.current()).copyWith(
      kitchenLanguage: language,
      kitchenPrinterKind: PrinterKind.network,
      kitchenPrinterAddress: '192.168.1.60:9100',
      kitchenPrinterName: 'Küche 192.168.1.60',
    ),
  );
  await t.pumpAndSettle();
  await _awaitPreview(t);
  await t.ensureVisible(find.byKey(const Key('kitchen-sample')));
  await t.pumpAndSettle();
  look('Einstellungen Küche');
}

/// Wie `tapKeys`, scrollt jede Taste vorher in Sicht (kleiner Bildschirm).
Future<void> _visibleKeys(WidgetTester t, String keys) async {
  for (final k in keys.split(' ')) {
    final name = k == ',' ? 'comma' : k;
    await t.ensureVisible(find.byKey(Key('key-$name')));
    await t.pumpAndSettle();
    await tapKeys(t, k);
  }
}

Future<void> _tapVisible(WidgetTester t, String key) async {
  await t.ensureVisible(find.byKey(Key(key)));
  await t.pumpAndSettle();
  await _tap(t, key);
}

/// Kassa mit allen vier Schaltern der Stufe 1a an, der Chef angemeldet, auf
/// dem Bon eine Huhn Bowl mit Auswahl und 2 × Cola.
Future<void> _openStufe1a(
  WidgetTester t,
  AppLanguage language,
  Size size,
) async {
  await pumpKassa(t, size: size, pin: '4711');
  await setSettings(
    t,
    (s) => s.copyWith(
      language: language,
      splitPaymentEnabled: true,
      cardTipEnabled: true,
      discountAccess: FeatureAccess.all,
      openAmountAccess: FeatureAccess.all,
    ),
  );
  await t.tap(find.byKey(const Key('item-huhn-bowl')));
  await t.pump();
  await t.tap(find.byKey(const Key('opt-bowl/1/0')));
  await t.tap(find.byKey(const Key('opt-bowl/0/1')));
  await t.pump();
  await t.tap(find.byKey(const Key('add-to-cart')));
  await t.pump();
  await tapItem(t, 'cola');
  await tapItem(t, 'cola');
  await t.pumpAndSettle();
}

/// Öffnet das Rabatt-Blatt der ersten Zeile (Tipp auf ihren Preis: der Name
/// steht in jeder Sprache anders).
Future<void> _openLineDiscount(WidgetTester t) async {
  final line = cartOf(t).lines.first;
  await t.tap(
    find.descendant(
      of: find.byKey(Key('line-${line.lineId}')),
      matching: find.text(formatEuro(line.goodsCents)),
    ),
  );
  await t.pumpAndSettle();
}

/// Die vier neuen Blätter und die Karte "Zahlen" nacheinander; [look] prüft
/// jedes Bild.
Future<void> _tourStufe1a(
  WidgetTester t,
  void Function(String screen) look,
) async {
  await _tap(t, 'open-amount-button');
  expect(find.byKey(const Key('open-amount-sheet')), findsOneWidget);
  await _visibleKeys(t, '1 2 , 5 0');
  await _tapVisible(t, 'open-rate-10');
  look('Freier Betrag');
  await _tap(t, 'open-amount-back');

  await _openLineDiscount(t);
  expect(find.byKey(const Key('discount-sheet')), findsOneWidget);
  await _tapVisible(t, 'discount-reason-regular');
  await _tapVisible(t, 'discount-amount');
  await _visibleKeys(t, '2');
  look('Rabatt Zeile mit Zahlenfeld');
  await _tap(t, 'discount-back');

  await _tap(t, 'discount-button');
  expect(find.byKey(const Key('discount-sheet')), findsOneWidget);
  await _tapVisible(t, 'discount-reason-promotion');
  await _tapVisible(t, 'discount-percent-10');
  look('Rabatt Bon');
  await _tap(t, 'discount-back');

  await _tap(t, 'pay-cash');
  await _tap(t, 'cash-mode-split');
  await _visibleKeys(t, '5');
  look('Teil bar');
  await _tap(t, 'cash-back');

  await _tap(t, 'pay-card');
  expect(find.byKey(const Key('tip-sheet')), findsOneWidget);
  look('Trinkgeld');
  await _tapVisible(t, 'tip-other');
  await _visibleKeys(t, '9');
  look('Trinkgeld, Betrag zu klein');
  await _visibleKeys(t, '9');
  look('Trinkgeld mit Zahlenfeld');
  await _tap(t, 'tip-back');

  await _tap(t, 'settings');
  await t.ensureVisible(find.byKey(const Key('payment-card')));
  await t.pumpAndSettle();
  look('Einstellungen Zahlen');
}

void main() {
  for (final language in AppLanguage.values) {
    for (final size in _sizes) {
      testWidgets(
        '${language.name}, ${size.width.toInt()}×${size.height.toInt()}: '
        'kein Überlauf',
        (t) => _tour(t, language, size),
      );
    }
  }

  for (final size in _sizes) {
    testWidgets('tr mit Namen aus 45 Zeichen, ${size.width.toInt()}×'
        '${size.height.toInt()}: kein Überlauf', (t) async {
      final names = _longTurkishNames();
      await _tour(
        t,
        AppLanguage.tr,
        size,
        names: names,
        check: (screen) {
          if (screen != 'Kassa') return;
          // Ein langer Name bricht um oder wird kleiner, aber er bleibt
          // ganz: in der Kategorien-Leiste und im Kopf des Auswahl-Felds.
          _expectWhole(t, find.byType(CategoryRail), 'Kategorien');
          _expectWhole(
            t,
            find.descendant(
              of: find.byType(ModifierPanel),
              matching: find.text(names['Huhn Bowl']!['tr']!),
            ),
            'Kopf des Auswahl-Felds',
          );
        },
      );
    });
  }

  testWidgets('ar: Kategorien rechts, Bon links, Ziffern und Beträge links '
      'nach rechts', (t) async {
    final seen = <String>[];
    await _tour(
      t,
      AppLanguage.ar,
      const Size(1280, 800),
      check: (screen) {
        seen.add(screen);
        switch (screen) {
          case 'Anmeldung':
            final one = _rect(t, find.byKey(const Key('key-1')));
            final three = _rect(t, find.byKey(const Key('key-3')));
            expect(one.center.dx, lessThan(three.center.dx));
          case 'Kassa':
            final rail = _rect(t, find.byType(CategoryRail));
            final items = _rect(t, find.byType(ModifierPanel));
            final cart = _rect(t, find.byType(CartPanel));
            expect(rail.left, greaterThanOrEqualTo(items.right));
            expect(cart.right, lessThanOrEqualTo(items.left));
            // Ein Betrag im Satz steht als eigener Abschnitt von links nach
            // rechts.
            expect(
              find.textContaining(RegExp('\u2066[0-9]+,[0-9]{2} €\u2069')),
              findsWidgets,
            );
            final total = find.text('12,90 €');
            expect(total, findsWidgets);
            for (final e in total.evaluate()) {
              final paragraph = e.findRenderObject()! as RenderParagraph;
              expect(paragraph.textDirection, TextDirection.ltr);
            }
          case 'Übersicht':
            // Das Diagramm ist nicht gespiegelt: die Achse steht links der
            // Balken, die Zeit läuft weiter von links nach rechts.
            final axis = _rect(
              t,
              find.descendant(
                of: find.byType(RevenueChart),
                matching: find.text('0 €'),
              ),
            );
            final bar = _rect(t, find.byKey(const Key('bar-0')));
            expect(axis.right, lessThanOrEqualTo(bar.left));
          case 'Bar mit Zahlenfeld':
            final one = _rect(t, find.byKey(const Key('key-1')));
            final three = _rect(t, find.byKey(const Key('key-3')));
            expect(one.center.dx, lessThan(three.center.dx));
        }
      },
    );
    expect(seen, containsAll(['Anmeldung', 'Kassa', 'Bar mit Zahlenfeld']));
  });

  for (final language in AppLanguage.values) {
    for (final size in _sizes) {
      testWidgets(
        '${language.name} ${size.width.toInt()}×${size.height.toInt()}: die '
        'neuen Blätter ohne Überlauf',
        (t) async {
          await _openStufe1a(t, language, size);
          final at =
              '${language.name} ${size.width.toInt()}×${size.height.toInt()}';
          final seen = <String>[];
          await _tourStufe1a(t, (screen) {
            seen.add(screen);
            _expectClean(t, '$at $screen');
            if (!language.isRtl) _expectNoIsolates(t, '$at $screen');
          });
          expect(seen, hasLength(8));
        },
      );
    }
  }

  testWidgets('ar: Beträge und Zahlenfeld der neuen Blätter stehen von links '
      'nach rechts', (t) async {
    await _openStufe1a(t, AppLanguage.ar, const Size(1280, 800));
    void ltr(String key) {
      final f = find.byKey(Key(key));
      expect(f, findsOneWidget, reason: key);
      expect(Directionality.of(t.element(f)), TextDirection.ltr, reason: key);
    }

    void keypadLtr(String screen) {
      final one = _rect(t, find.byKey(const Key('key-1')));
      final three = _rect(t, find.byKey(const Key('key-3')));
      expect(one.center.dx, lessThan(three.center.dx), reason: screen);
    }

    final seen = <String>[];
    await _tourStufe1a(t, (screen) {
      seen.add(screen);
      // Das Blatt selbst liest von rechts nach links.
      final sheet = switch (screen) {
        'Freier Betrag' => 'open-amount-sheet',
        'Teil bar' => 'cash-mode-split',
        'Einstellungen Zahlen' => 'payment-card',
        _ when screen.startsWith('Rabatt') => 'discount-sheet',
        _ => 'tip-sheet',
      };
      expect(
        Directionality.of(t.element(find.byKey(Key(sheet)))),
        TextDirection.rtl,
        reason: screen,
      );
      switch (screen) {
        case 'Freier Betrag':
          keypadLtr(screen);
        case 'Rabatt Zeile mit Zahlenfeld':
          ltr('discount-new');
          ltr('discount-target');
          keypadLtr(screen);
        case 'Rabatt Bon':
          ltr('discount-new');
        case 'Teil bar':
          ltr('split-rest');
          ltr('cash-total');
          keypadLtr(screen);
        case 'Trinkgeld':
          ltr('tip-due');
          ltr('tip-amount');
        case 'Trinkgeld mit Zahlenfeld':
          ltr('tip-due');
          keypadLtr(screen);
      }
    });
    expect(seen, contains('Trinkgeld mit Zahlenfeld'));
  });

  // Stufe 1b: die Taste "Mehr", die Blätter "Mehr" und "Pfand zurück" und
  // "Bar auszahlen", in allen Sprachen, bei beiden Größen und bei der
  // größten Schrift (1,3).
  for (final language in AppLanguage.values) {
    for (final (size, scale) in [
      for (final size in _sizes) (size, 1.0),
      (const Size(1280, 800), KassaTokens.maxTextScale),
    ]) {
      testWidgets(
        '${language.name} ${size.width.toInt()}×${size.height.toInt()} '
        'Schrift $scale: Mehr, Pfand zurück und Bar auszahlen ohne Überlauf',
        (t) async {
          final at =
              '${language.name} ${size.width.toInt()}×'
              '${size.height.toInt()} $scale';
          final seen = <String>[];
          await _tourDepositReturn(t, language, size, scale, (screen) {
            seen.add(screen);
            _expectClean(t, '$at $screen');
            if (!language.isRtl) _expectNoIsolates(t, '$at $screen');
          });
          expect(seen, hasLength(7));
        },
      );
    }
  }
}

/// Jeder Text unter [key] ist ganz zu lesen, ohne Auslassungspunkte.
void _expectWholeKey(WidgetTester t, String key, String where) =>
    _expectWhole(t, find.byKey(Key(key)), '$where $key');

/// Kassa mit freiem Betrag und Pfand zurück für alle, der Chef angemeldet:
/// die Taste "Mehr", das Blatt "Mehr", das Blatt "Pfand zurück" mit 99
/// Stück, die Kassa mit "Bar auszahlen", "Verkauf fertig" mit "Auszahlen",
/// dann nur Pfand zurück an (seine Taste allein im Kopf); [look] prüft jedes
/// Bild.
Future<void> _tourDepositReturn(
  WidgetTester t,
  AppLanguage language,
  Size size,
  double scale,
  void Function(String screen) look,
) async {
  await pumpKassa(t, size: size, textScale: scale, pin: '4711');
  await setSettings(
    t,
    (s) => s.copyWith(
      language: language,
      openAmountAccess: FeatureAccess.all,
      depositReturnAccess: FeatureAccess.all,
      printerKind: PrinterKind.network,
      printerAddress: '192.168.0.50',
    ),
  );
  final at = '${language.name} ${size.width.toInt()} $scale';
  await tapItem(t, 'cola');
  await t.pumpAndSettle();
  look('Kassa mit Mehr');
  _expectWholeKey(t, 'more-button', at);

  await _tap(t, 'more-button');
  look('Mehr');
  _expectWholeKey(t, 'more-open-amount', at);
  _expectWholeKey(t, 'more-deposit-return', at);

  await _tap(t, 'more-deposit-return');
  await t.tap(find.byKey(const Key('deposit-return-plus-25')));
  await t.pumpAndSettle();
  look('Pfand zurück');
  _expectWholeKey(t, 'deposit-return-add', at);
  await _tap(t, 'deposit-return-back');

  containerOf(t).read(cartProvider.notifier).setDepositReturns({25: 99});
  await t.pumpAndSettle();
  await _tap(t, 'more-button');
  await _tap(t, 'more-deposit-return');
  look('Pfand zurück mit 99');
  _expectWholeKey(t, 'deposit-return-total', at);
  await _tap(t, 'deposit-return-back');

  // Cola 3,15 € und 99 × 0,25 € zurück: −21,60 €.
  look('Kassa mit Bar auszahlen');
  _expectWholeKey(t, 'pay-out', at);
  expect(find.textContaining('21,60'), findsWidgets);

  await _tap(t, 'pay-out');
  look('Auszahlen');
  _expectWholeKey(t, 'payout-done', at);
  await _tap(t, 'next-customer');

  await setSettings(t, (s) => s.copyWith(openAmountAccess: FeatureAccess.off));
  look('Kassa mit Pfand zurück');
  _expectWholeKey(t, 'deposit-return-button', at);
}

/// Lässt das Zeichnen der Vorschau (echtes `dart:ui`) zu Ende laufen: wartet,
/// bis ein Bild unter `kitchen-preview` steht, höchstens rund 5 Sekunden.
Future<void> _awaitPreview(WidgetTester t) async {
  final image = find.descendant(
    of: find.byKey(const Key('kitchen-preview')),
    matching: find.byType(RawImage),
  );
  for (var i = 0; i < 250; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await t.pump();
    if (image.evaluate().isNotEmpty &&
        t.widget<RawImage>(image).image != null) {
      break;
    }
  }
  expect(image, findsOneWidget);
}
