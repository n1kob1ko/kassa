import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/app.dart';
import 'package:kassa/core/app_language.dart';
import 'package:kassa/core/money.dart';
import 'package:kassa/data/providers.dart';
import 'package:kassa/domain/feature_access.dart';
import 'package:material_ui/material_ui.dart';

import '../support/kassa_pump.dart';
import '../support/pump.dart';

// Bildvergleich der Blätter aus Stufe 1a (Trinkgeld, Teil bar, Rabatt,
// Freier Betrag) in Deutsch und Arabisch, hell und dunkel, und des Bons mit
// Rabatt. Neu erzeugen mit
// `flutter test --update-goldens test/golden/stufe_1a_golden_test.dart`.

/// Erfundene arabische Namen eines Teils der Beispiel-Speisekarte; "Cola
/// 0,33 l" bleibt ohne, damit ein lateinischer Name zu sehen ist.
const _names = {
  'Bowls': {'ar': 'أطباق'},
  'Snacks': {'ar': 'وجبات خفيفة'},
  'Süßes': {'ar': 'حلويات'},
  'Getränke': {'ar': 'مشروبات'},
  'Huhn Bowl': {'ar': 'طبق دجاج'},
  'Tofu Bowl': {'ar': 'طبق توفو'},
  'Gemüse Bowl': {'ar': 'طبق خضار'},
  'Rind Bowl': {'ar': 'طبق لحم بقري'},
  'Teigtaschen': {'ar': 'زلابية'},
  '5 Stück': {'ar': '5 قطع'},
};

/// Kassa mit allen vier Schaltern an, Anna angemeldet, in [language], Cola
/// und Teigtaschen (9,65 €) auf dem Bon.
Future<void> _kassa(
  WidgetTester t,
  AppLanguage language,
  Brightness brightness,
) async {
  await pumpKassa(t, brightness: brightness);
  await containerOf(t).read(translationRepositoryProvider).upsert(_names);
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
  await tapItem(t, 'cola');
  await tapItem(t, 'teigtaschen');
  await t.pumpAndSettle();
}

Future<void> _tap(WidgetTester t, String key) async {
  await t.tap(find.byKey(Key(key)));
  await t.pumpAndSettle();
}

/// Öffnet das Rabatt-Blatt der Zeile an Stelle [index] (Tipp auf ihren
/// Preis: der Name steht in jeder Sprache anders).
Future<void> _openLine(WidgetTester t, int index) async {
  final line = cartOf(t).lines[index];
  await t.tap(
    find.descendant(
      of: find.byKey(Key('line-${line.lineId}')),
      matching: find.text(formatEuro(line.goodsCents)),
    ),
  );
  await t.pumpAndSettle();
}

/// Die vier Blätter, je bis zu dem Bild, das verglichen wird.
final _sheets = <(String, Future<void> Function(WidgetTester))>[
  (
    'trinkgeld',
    (t) async {
      await _tap(t, 'pay-card');
      await _tap(t, 'tip-pays-1000');
    },
  ),
  (
    'teil_bar',
    (t) async {
      await _tap(t, 'pay-cash');
      await _tap(t, 'cash-mode-split');
      await tapKeys(t, '5');
      await t.pumpAndSettle();
    },
  ),
  (
    'rabatt',
    (t) async {
      await _openLine(t, 1);
      await _tap(t, 'discount-reason-regular');
      await _tap(t, 'discount-percent-10');
    },
  ),
  (
    'freier_betrag',
    (t) async {
      await _tap(t, 'open-amount-button');
      await tapKeys(t, '1 2 , 5 0');
      await _tap(t, 'open-rate-10');
    },
  ),
];

void main() {
  for (final (language, dark) in [
    (AppLanguage.de, false),
    (AppLanguage.de, true),
    (AppLanguage.ar, false),
    (AppLanguage.ar, true),
  ]) {
    final look = dark ? 'dunkel' : 'hell';
    final arabic = language == AppLanguage.ar ? '_arabisch' : '';
    for (final (name, open) in _sheets) {
      testWidgets('$name (${language.name}, $look)', (t) async {
        await _kassa(t, language, dark ? Brightness.dark : Brightness.light);
        await open(t);
        expect(t.takeException(), isNull);
        await expectLater(
          find.byType(KassaApp),
          matchesGoldenFile('goldens/1a_$name${arabic}_$look.png'),
        );
      });
    }
  }

  for (final language in [AppLanguage.de, AppLanguage.ar]) {
    final arabic = language == AppLanguage.ar ? '_arabisch' : '';
    testWidgets('Bon mit Rabatt auf einer Zeile und auf dem Bon '
        '(${language.name}, hell)', (t) async {
      await _kassa(t, language, Brightness.light);
      await _openLine(t, 1);
      await _tap(t, 'discount-reason-regular');
      await _tap(t, 'discount-percent-10');
      await _tap(t, 'discount-apply');
      await _tap(t, 'discount-button');
      await _tap(t, 'discount-reason-promotion');
      await _tap(t, 'discount-percent-5');
      await _tap(t, 'discount-apply');
      expect(
        find.byKey(Key('line-discount-${cartOf(t).lines[1].lineId}')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('receipt-discount')), findsOneWidget);
      expect(find.byKey(const Key('discount-sheet')), findsNothing);
      expect(t.takeException(), isNull);
      await expectLater(
        find.byType(KassaApp),
        matchesGoldenFile('goldens/1a_bon_mit_rabatt${arabic}_hell.png'),
      );
    });
  }
}
