import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/ui/theme.dart';
import 'package:kassa/ui/tokens.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('Akzent ist Petrol und Schrift ist Figtree', () {
    expect(KassaTokens.accent, const Color(0xFF0F766E));
    expect(
      kassaTheme(Brightness.light).textTheme.bodyMedium!.fontFamily,
      'Figtree',
    );
    expect(kassaTheme(Brightness.dark).brightness, Brightness.dark);
    expect(KassaTokens.minTap, greaterThanOrEqualTo(48));
    expect(KassaTokens.primaryActionHeight, inInclusiveRange(64, 80));
  });

  test('Bewegung liegt zwischen 120 und 320 ms', () {
    expect(KassaTokens.motionFast, const Duration(milliseconds: 120));
    expect(KassaTokens.motionSlow, const Duration(milliseconds: 320));
  });

  test('beide Paletten haben dieselben Namen und den gleichen Akzent', () {
    expect(KassaColors.light.accent, KassaTokens.accent);
    expect(KassaColors.dark.accent, KassaTokens.accent);
    expect(KassaColors.light.ground, const Color(0xFFF3F4F6));
    expect(KassaColors.dark.ground, const Color(0xFF0E1012));
    expect(
      kassaTheme(Brightness.light).extension<KassaColors>(),
      KassaColors.light,
    );
    expect(
      kassaTheme(Brightness.dark).extension<KassaColors>(),
      KassaColors.dark,
    );
  });

  testWidgets('Betragsstil nutzt Tabellenziffern', (tester) async {
    late TextStyle style;
    await tester.pumpWidget(
      MaterialApp(
        theme: kassaTheme(Brightness.light),
        home: Builder(
          builder: (context) {
            style = KassaText.amount(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(style.fontFeatures, contains(const FontFeature.tabularFigures()));
    expect(style.fontFamily, 'Figtree');
    expect(style.fontSize, 40);
    expect(style.fontWeight, FontWeight.w800);
  });
}
