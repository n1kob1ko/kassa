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
import 'package:kassa/features/kassa/cart_panel.dart';
import 'package:kassa/features/kassa/category_rail.dart';
import 'package:kassa/features/kassa/modifier_panel.dart';
import 'package:kassa/features/overview/revenue_chart.dart';
import 'package:kassa/l10n/generated/l10n.dart';
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
  for (var i = 0; i < 5; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await t.pump();
  }
  await t.pumpAndSettle();
  expect(
    find.descendant(
      of: find.byKey(const Key('kitchen-preview')),
      matching: find.byType(RawImage),
    ),
    findsOneWidget,
  );
  await t.ensureVisible(find.byKey(const Key('kitchen-sample')));
  await t.pumpAndSettle();
  look('Einstellungen Küche');
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
}
