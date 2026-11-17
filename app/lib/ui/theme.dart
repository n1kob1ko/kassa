import 'package:material_ui/material_ui.dart';

import 'tokens.dart';

/// Das Thema der App in heller oder dunkler Ansicht. Farben kommen aus
/// [KassaColors], dieselben Namen in beiden Ansichten.
ThemeData kassaTheme(Brightness brightness) {
  final colors =
      brightness == Brightness.dark ? KassaColors.dark : KassaColors.light;
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    fontFamily: KassaTokens.fontFamily,
    fontFamilyFallback: KassaTokens.fontFallback,
  );
  final scheme = ColorScheme.fromSeed(
    seedColor: KassaTokens.accent,
    brightness: brightness,
  ).copyWith(
    primary: colors.accent,
    onPrimary: colors.onAccent,
    surface: colors.card,
    onSurface: colors.ink,
    onSurfaceVariant: colors.ink2,
    outline: colors.line,
    error: colors.red,
  );
  return base.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: colors.ground,
    canvasColor: colors.ground,
    dividerColor: colors.line,
    textTheme: _textTheme(base.textTheme, colors),
    extensions: <ThemeExtension<dynamic>>[colors],
  );
}

TextTheme _textTheme(TextTheme base, KassaColors c) {
  // Tabellenziffern für die ganze App (DESIGN.md, Typography).
  const features = [FontFeature.tabularFigures()];
  TextStyle style(double size, FontWeight weight,
      {double height = 1.25, double spacing = 0}) {
    return TextStyle(
      fontFamily: KassaTokens.fontFamily,
      fontFamilyFallback: KassaTokens.fontFallback,
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: spacing * size,
      color: c.ink,
      fontFeatures: features,
    );
  }

  return base.copyWith(
    displayLarge: style(60, FontWeight.w800, height: 1, spacing: -0.03),
    headlineLarge: style(32, FontWeight.w800, spacing: -0.02),
    headlineMedium: style(22, FontWeight.w800, spacing: -0.01),
    titleLarge: style(20, FontWeight.w800),
    titleMedium: style(16, FontWeight.w800),
    bodyLarge: style(16, FontWeight.w700, height: 1.2),
    bodyMedium: style(15, FontWeight.w700),
    bodySmall: style(13, FontWeight.w600),
    labelLarge: style(14, FontWeight.w700),
    labelMedium: style(13, FontWeight.w600),
    labelSmall: style(10.5, FontWeight.w800, spacing: 0.04),
  );
}

/// Textstile, die über die Textskala des Themas hinausgehen.
class KassaText {
  const KassaText._();

  /// Beträge (Summe, "Zu zahlen"): 40 dp, 800, Tabellenziffern.
  static TextStyle amount(BuildContext context) {
    final c = KassaColors.of(context);
    return TextStyle(
      fontFamily: KassaTokens.fontFamily,
      fontFamilyFallback: KassaTokens.fontFallback,
      fontSize: 40,
      fontWeight: FontWeight.w800,
      height: 1,
      letterSpacing: -0.02 * 40,
      color: c.ink,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }
}
